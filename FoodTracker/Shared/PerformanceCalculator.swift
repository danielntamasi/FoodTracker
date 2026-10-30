import SwiftUI

// MARK: - Performance Window

/// How far back the History performance card averages.
enum PerformanceWindow: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case quarter = 90
    case year = 365

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .week: return "7D"
        case .month: return "30D"
        case .quarter: return "90D"
        case .year: return "1Y"
        }
    }

    var title: String {
        switch self {
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .quarter: return "Last 90 days"
        case .year: return "Last year"
        }
    }
}

// MARK: - Performance Thresholds

enum PerformanceThresholds {
    /// Ratio bounds for "on target" (±10%)
    static let onTargetLow = 0.9
    static let onTargetHigh = 1.1
    /// Beyond ±20% is "way off"
    static let severeOverThreshold = 1.2
    static let severeUnderThreshold = 0.8
}

// MARK: - Target Status

enum TargetStatus: Equatable {
    case noTarget
    case onTarget
    case over(percent: Int, severe: Bool)
    case under(percent: Int, severe: Bool)

    init(average: Double, target: Int) {
        guard target > 0 else { self = .noTarget; return }
        let ratio = average / Double(target)
        let percent = Int((abs(ratio - 1) * 100).rounded())
        if ratio > PerformanceThresholds.onTargetHigh {
            self = .over(percent: percent, severe: ratio > PerformanceThresholds.severeOverThreshold)
        } else if ratio < PerformanceThresholds.onTargetLow {
            self = .under(percent: percent, severe: ratio < PerformanceThresholds.severeUnderThreshold)
        } else {
            self = .onTarget
        }
    }

    /// Compact chip text: nothing when on target (the checkmark says it), else the percent
    var shortLabel: String? {
        switch self {
        case .noTarget, .onTarget: return nil
        case .over(let percent, _), .under(let percent, _): return "\(percent)%"
        }
    }

    var label: String {
        switch self {
        case .noTarget: return "No goal"
        case .onTarget: return "On target"
        case .over(let percent, _): return "\(percent)% over"
        case .under(let percent, _): return "\(percent)% under"
        }
    }

    var color: Color {
        switch self {
        case .noTarget: return DS.Color.textTertiary
        case .onTarget: return DS.Color.success
        case .over(_, let severe), .under(_, let severe):
            return severe ? DS.Color.danger : DS.Color.carbs
        }
    }

    var iconName: String {
        switch self {
        case .noTarget: return "minus"
        case .onTarget: return "checkmark"
        case .over: return "arrow.up"
        case .under: return "arrow.down"
        }
    }
}

// MARK: - Day Log

enum DayStatus {
    case empty, complete, partial, excluded
}

/// One logged day in the window, with whether it looks partially logged.
struct DayLog: Identifiable {
    let date: Date
    let calories: Int
    /// Why the day looks partial; empty when it looks complete
    let partialReasons: [String]
    /// Left out of the averages by the user
    let isExcluded: Bool

    var id: Date { date }
    var isPartial: Bool { !partialReasons.isEmpty }
}

/// Days the user left out of the performance averages, kept as "yyyy-MM-dd" keys.
enum ExcludedDays {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String { formatter.string(from: date) }

    static func load() -> Set<String> {
        Set(sharedDefaults.stringArray(forKey: AppConstants.Defaults.performanceExcludedDays) ?? [])
    }

    static func save(_ keys: Set<String>) {
        sharedDefaults.set(Array(keys).sorted(), forKey: AppConstants.Defaults.performanceExcludedDays)
    }
}

// MARK: - Summary

struct MacroAverage: Identifiable {
    let macro: MacroType
    let average: Double
    let target: Int

    var id: MacroType { macro }
    var status: TargetStatus { TargetStatus(average: average, target: target) }
}

struct PerformanceSummary {
    let window: PerformanceWindow
    /// Days in the window with at least one entry that count toward the averages
    /// (logged and not left out)
    let loggedDays: Int
    /// Every logged day in the window, newest first, including left-out ones
    let days: [DayLog]
    /// One status per day in the window, oldest first
    let dayStatuses: [DayStatus]
    let averages: [MacroAverage]

    var missingDays: Int { window.rawValue - days.count }
    var excludedCount: Int { days.filter(\.isExcluded).count }
    var partialDays: [DayLog] { days.filter { $0.isPartial || $0.isExcluded } }
    var partialCountedCount: Int { days.filter { $0.isPartial && !$0.isExcluded }.count }
    var coverage: Double { Double(loggedDays) / Double(window.rawValue) }

    var hasTargets: Bool { averages.contains { $0.target > 0 } }
    var onTargetCount: Int { averages.filter { $0.status == .onTarget }.count }
    var targetedCount: Int { averages.filter { $0.target > 0 }.count }
}

// MARK: - Performance Calculator

enum PerformanceCalculator {
    /// A day under this share of the calorie goal (or of the typical day, without a goal) looks partial
    static let lowCalorieShare = 0.6
    /// A day missing lunch or dinner looks partial when it's also under this share
    static let missingMealShare = 0.85

    /// Average daily totals over the `window` complete days before today. Days with nothing
    /// logged are skipped, as are days the user left out (`excluded` day keys). Today is left
    /// out because a half-logged day drags every average down.
    static func summary(
        entries: [FoodEntry],
        window: PerformanceWindow,
        excluded: Set<String> = [],
        now: Date = Date()
    ) -> PerformanceSummary {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -window.rawValue, to: end)!

        var byDay: [Date: [FoodEntry]] = [:]
        for entry in entries where entry.date >= start && entry.date < end {
            byDay[calendar.startOfDay(for: entry.date), default: []].append(entry)
        }

        let dailyCalories = byDay.mapValues { $0.reduce(0) { $0 + $1.totalCalories } }
        let reference = referenceCalories(dailyCalories: Array(dailyCalories.values))

        let days = byDay.keys.sorted(by: >).map { day in
            let dayEntries = byDay[day] ?? []
            let calories = dailyCalories[day] ?? 0
            return DayLog(
                date: day,
                calories: calories,
                partialReasons: partialReasons(entries: dayEntries, calories: calories, reference: reference),
                isExcluded: excluded.contains(ExcludedDays.key(for: day))
            )
        }

        var calories = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
        let countedDays = Set(days.filter { !$0.isExcluded }.map(\.date))
        for (day, dayEntries) in byDay where countedDays.contains(day) {
            for entry in dayEntries {
                calories += Double(entry.totalCalories)
                protein += entry.totalProteinGrams
                carbs += entry.totalCarbsGrams
                fat += entry.totalFatGrams
            }
        }

        let daysByDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        let dayStatuses: [DayStatus] = (0..<window.rawValue).map { offset in
            guard let day = daysByDate[calendar.date(byAdding: .day, value: offset, to: start)!] else { return .empty }
            if day.isExcluded { return .excluded }
            return day.isPartial ? .partial : .complete
        }
        let divisor = Double(max(countedDays.count, 1))
        let totals: [MacroType: Double] = [.calories: calories, .protein: protein, .carbs: carbs, .fat: fat]
        let averages = MacroType.allCases.map { macro in
            MacroAverage(macro: macro, average: (totals[macro] ?? 0) / divisor, target: macro.target)
        }
        return PerformanceSummary(window: window, loggedDays: countedDays.count, days: days, dayStatuses: dayStatuses, averages: averages)
    }

    /// The calorie goal, or without one the median logged day
    private static func referenceCalories(dailyCalories: [Int]) -> Double {
        if DailyTarget.calories > 0 { return Double(DailyTarget.calories) }
        let sorted = dailyCalories.sorted()
        guard !sorted.isEmpty else { return 0 }
        return Double(sorted[sorted.count / 2])
    }

    /// Why a day looks partially logged: very low calories, or no lunch/dinner on a lowish day.
    /// A missing breakfast alone isn't flagged, since plenty of people skip it.
    private static func partialReasons(entries: [FoodEntry], calories: Int, reference: Double) -> [String] {
        guard reference > 0 else { return [] }
        let share = Double(calories) / reference
        let periods = Set(entries.map { TimeOfDay.from($0.date) })

        var reasons: [String] = []
        if share < lowCalorieShare {
            reasons.append("Only \(calories.formatted()) kcal")
        }
        if share < missingMealShare {
            if !periods.contains(.afternoon) { reasons.append("No lunch logged") }
            if !periods.contains(.evening) { reasons.append("No dinner logged") }
        }
        return reasons
    }
}
