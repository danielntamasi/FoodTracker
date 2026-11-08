import Foundation

/// A food or meal the user usually has by this time of day. `slot` is which one of the day it is:
/// someone who has two protein bars a day gets slot 1 in the morning and slot 2 in the afternoon.
struct KickstartSuggestion: Identifiable {
    /// Habit key plus slot, e.g. "food:david fudge brownie flavored bar#2". Also the dismissal key.
    let id: String
    let name: String
    /// The entries to copy: the latest log of the habit's most common name (one food, or a meal's ingredients)
    let template: [FoodEntry]
    /// Set for meals, which are re-added as a group
    let mealName: String?
    /// 1 for the first of the day, 2 for the second...
    let slot: Int
    /// Usual time of day for this slot, in minutes after midnight (median over the days it was had)
    let usualMinute: Int
    /// Early time (25th percentile): it's offered from an hour before this
    let earlyMinute: Int
    let daysSeen: Int

    var calories: Int { template.reduce(0) { $0 + $1.totalCalories } }
    var iconName: String { template.first?.iconName ?? foodIconName(for: name) }

    /// Today at the usual time, but never later than `now`
    func dateToday(now: Date = Date()) -> Date {
        let usual = Calendar.current.startOfDay(for: now).addingTimeInterval(TimeInterval(usualMinute * 60))
        return min(usual, now)
    }
}

enum KickstartSuggestions {
    /// How far back habits are looked for
    static let lookbackDays = 28
    /// A habit (or its 2nd, 3rd... of the day) shows up on at least this many days...
    static let minDays = 3
    /// ...on at least this share of the logged days since it first showed up (so a habit
    /// started two weeks ago isn't held to the whole four weeks)...
    static let minShare = 0.5
    /// ...and was had within this many days (so a dropped habit stops being offered)
    static let maxDaysSinceLast = 7
    /// Offered once now is within this many minutes of its early time
    static let lookaheadMinutes = 60
    /// The "early time" is this percentile of the days' times: logging times spread out
    /// (milk logged 6:14–9:52), and an everyday morning item should be offered on an early
    /// open, not only once the middle time has passed
    static let earlyPercentile = 0.25
    /// Highest slot looked for (fifth of the same thing in a day)
    static let maxSlots = 5
    /// Foods count as the same habit when their names start with the same word and their
    /// per-serving calories and protein are this close (e.g. bar flavors of one brand)
    static let similarCalories = 0.10
    static let similarProtein = 0.15

    static var isEnabled: Bool {
        get { sharedDefaults.object(forKey: AppConstants.Defaults.kickstartEnabled) as? Bool ?? true }
        set { sharedDefaults.set(newValue, forKey: AppConstants.Defaults.kickstartEnabled) }
    }

    // MARK: Dismissals

    /// Suggestions turned down today (`KickstartSuggestion.id`), stored as "yyyy-MM-dd|id"
    static var dismissedToday: Set<String> {
        let prefix = ExcludedDays.key(for: Date()) + "|"
        let stored = sharedDefaults.stringArray(forKey: AppConstants.Defaults.kickstartDismissed) ?? []
        return Set(stored.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) })
    }

    /// Remembers turned-down suggestions for the rest of today (earlier days are dropped)
    static func dismiss(_ ids: some Sequence<String>) {
        let today = ExcludedDays.key(for: Date())
        let all = dismissedToday.union(ids)
        guard !all.isEmpty else { return }
        sharedDefaults.set(all.sorted().map { "\(today)|\($0)" }, forKey: AppConstants.Defaults.kickstartDismissed)
    }

    // MARK: Suggestions

    /// One logged food or meal: a standalone entry, or all entries of a meal group
    private struct Unit {
        let key: String
        let name: String
        let mealName: String?
        let date: Date
        let entries: [FoodEntry]
    }

    /// Habits from the last four weeks whose early time is before now or within the next hour,
    /// one suggestion per slot not yet logged today. Earliest usual time first.
    static func suggestions(entries: [FoodEntry], now: Date = Date()) -> [KickstartSuggestion] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -lookbackDays, to: today),
              let recentCutoff = calendar.date(byAdding: .day, value: -maxDaysSinceLast, to: today)
        else { return [] }

        let relevant = entries.filter { $0.date >= start }.sorted { $0.date < $1.date }
        let units = makeUnits(relevant)
        let past = units.filter { $0.date < today }
        let loggedToday = Dictionary(grouping: units.filter { calendar.isDate($0.date, inSameDayAs: today) }, by: \.key)
            .mapValues(\.count)
        let loggedDays = Set(past.map { calendar.startOfDay(for: $0.date) })
        guard !loggedDays.isEmpty else { return [] }

        let nowMinute = minuteOfDay(now, calendar)

        var result: [KickstartSuggestion] = []
        for (key, habitUnits) in Dictionary(grouping: past, by: \.key) {
            // The name logged most often stands for the habit; its latest log is what gets copied
            let byName = Dictionary(grouping: habitUnits, by: \.name)
            guard let template = byName.values.max(by: { a, b in
                a.count != b.count ? a.count < b.count : a.last!.date < b.last!.date
            })?.last else { continue }

            let byDay = Dictionary(grouping: habitUnits) { calendar.startOfDay(for: $0.date) }
                .mapValues { $0.map { minuteOfDay($0.date, calendar) }.sorted() }

            for slot in 1...maxSlots {
                // The slot-th time it was had, on each day it was had at least that often
                let slotDays = byDay.compactMapValues { $0.count >= slot ? $0[slot - 1] : nil }
                guard slotDays.count >= minDays,
                      let firstDay = slotDays.keys.min(), let lastDay = slotDays.keys.max(), lastDay >= recentCutoff,
                      Double(slotDays.count) >= Double(loggedDays.filter { $0 >= firstDay }.count) * minShare
                else { break }
                guard slot > loggedToday[key, default: 0] else { continue }

                let minutes = slotDays.values.sorted()
                let early = minutes[Int(Double(minutes.count - 1) * earlyPercentile)]
                guard early <= nowMinute + lookaheadMinutes else { break }
                result.append(KickstartSuggestion(
                    id: "\(key)#\(slot)",
                    name: template.name,
                    template: template.entries,
                    mealName: template.mealName,
                    slot: slot,
                    usualMinute: minutes[minutes.count / 2],
                    earlyMinute: early,
                    daysSeen: slotDays.count
                ))
            }
        }
        return result.sorted {
            $0.usualMinute != $1.usualMinute ? $0.usualMinute < $1.usualMinute : $0.id < $1.id
        }
    }

    private static func minuteOfDay(_ date: Date, _ calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// Turns entries (oldest first) into units with habit keys. Meals are keyed by meal name.
    /// Foods whose names start with the same word and whose numbers are close share a key
    /// (the first such food's name), so flavors of the same bar count as one habit.
    private static func makeUnits(_ entries: [FoodEntry]) -> [Unit] {
        struct Family { let firstWord: String; let calories: Double; let protein: Double; let key: String }
        var families: [Family] = []
        var meals: [UUID: [FoodEntry]] = [:]
        var units: [Unit] = []

        for entry in entries {
            if let groupID = entry.mealGroupID, entry.mealName != nil {
                meals[groupID, default: []].append(entry)
                continue
            }
            guard let name = normalized(entry.name) else { continue }
            let firstWord = String(name.split(separator: " ").first ?? "")
            let calories = Double(entry.calories), protein = entry.proteinGrams
            let key: String
            if let family = families.first(where: {
                $0.firstWord == firstWord
                    && abs($0.calories - calories) <= similarCalories * max($0.calories, calories)
                    && abs($0.protein - protein) <= max(similarProtein * max($0.protein, protein), 1)
            }) {
                key = family.key
            } else {
                key = "food:\(name)"
                families.append(Family(firstWord: firstWord, calories: calories, protein: protein, key: key))
            }
            units.append(Unit(key: key, name: entry.name, mealName: nil, date: entry.date, entries: [entry]))
        }
        for group in meals.values {
            guard let first = group.min(by: { $0.date < $1.date }),
                  let mealName = first.mealName, let name = normalized(mealName) else { continue }
            units.append(Unit(
                key: "meal:\(name)", name: mealName, mealName: mealName, date: first.date,
                entries: group.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            ))
        }
        return units
    }

    private static func normalized(_ name: String) -> String? {
        let key = name.lowercased().trimmingCharacters(in: .whitespaces)
        return key.isEmpty ? nil : key
    }
}
