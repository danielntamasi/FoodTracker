import Foundation

/// Calories, protein, carbs and fat as one value, for today's totals, goals and suggestion amounts.
struct Nutrients: Equatable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    static func + (a: Nutrients, b: Nutrients) -> Nutrients {
        Nutrients(calories: a.calories + b.calories, protein: a.protein + b.protein,
                  carbs: a.carbs + b.carbs, fat: a.fat + b.fat)
    }

    static func * (a: Nutrients, k: Double) -> Nutrients {
        Nutrients(calories: a.calories * k, protein: a.protein * k, carbs: a.carbs * k, fat: a.fat * k)
    }

    static var goals: Nutrients {
        Nutrients(calories: Double(DailyTarget.calories), protein: Double(DailyTarget.protein),
                  carbs: Double(DailyTarget.carbs), fat: Double(DailyTarget.fat))
    }

    static func totals(of entries: [FoodEntry]) -> Nutrients {
        entries.reduce(Nutrients()) { $0 + $1.totals }
    }

    /// "520 cal, 30P/45C/18F"
    var summary: String {
        "\(Int(calories.rounded())) cal, \(Int(protein.rounded()))P/\(Int(carbs.rounded()))C/\(Int(fat.rounded()))F"
    }
}

extension FoodEntry {
    var totals: Nutrients {
        Nutrients(calories: Double(totalCalories), protein: totalProteinGrams, carbs: totalCarbsGrams, fat: totalFatGrams)
    }
    var perServing: Nutrients {
        Nutrients(calories: Double(calories), protein: proteinGrams, carbs: carbsGrams, fat: fatGrams)
    }
}

/// A food the user logs often (so it's likely at home).
struct FinishDayFood: Identifiable {
    /// Lowercased name
    let id: String
    /// The latest log of it, copied when added
    let template: FoodEntry
    let daysLogged: Int
    /// When it's usually had: "morning", "afternoon" or "evening"
    let usualTime: String
    /// Servings usually logged at once
    let usualServings: Double

    var name: String { template.name }
    var perServing: Nutrients { template.perServing }
}

/// A meal the user logs often, re-added whole.
struct FinishDayMeal: Identifiable {
    let id: String
    let name: String
    /// The latest log's entries, copied when added
    let entries: [FoodEntry]
    let daysLogged: Int
    var totals: Nutrients { Nutrients.totals(of: entries) }
}

/// The user's usual foods and meals from recent history, which "Finish the Day" builds suggestions from.
enum FinishDayHistory {
    static let lookbackDays = 60
    static let minDays = 2
    static let maxFoods = 40
    static let maxMeals = 10

    static func usualFoods(entries: [FoodEntry]) -> [FinishDayFood] {
        let calendar = Calendar.current
        let foods = entries.filter { $0.mealGroupID == nil && $0.calories > 0 }
        let byName = Dictionary(grouping: foods) { $0.name.lowercased().trimmingCharacters(in: .whitespaces) }
        return byName.compactMap { key, logs -> FinishDayFood? in
            let days = Set(logs.map { calendar.startOfDay(for: $0.date) }).count
            guard !key.isEmpty, days >= minDays, let latest = logs.max(by: { $0.date < $1.date }) else { return nil }
            let servings = logs.map(\.servings).sorted()
            return FinishDayFood(
                id: key,
                template: latest,
                daysLogged: days,
                usualTime: mostCommonTime(logs.map(\.date)),
                usualServings: servings[servings.count / 2]
            )
        }
        .sorted { $0.daysLogged != $1.daysLogged ? $0.daysLogged > $1.daysLogged : $0.name < $1.name }
        .prefix(maxFoods)
        .map { $0 }
    }

    static func usualMeals(entries: [FoodEntry]) -> [FinishDayMeal] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: entries.filter { $0.mealGroupID != nil && $0.mealName != nil }) { $0.mealGroupID! }
        let byName = Dictionary(grouping: groups.values) { ($0.first?.mealName ?? "").lowercased() }
        return byName.compactMap { key, logs -> FinishDayMeal? in
            let days = Set(logs.compactMap { $0.first.map { calendar.startOfDay(for: $0.date) } }).count
            guard !key.isEmpty, days >= minDays,
                  let latest = logs.max(by: { ($0.first?.date ?? .distantPast) < ($1.first?.date ?? .distantPast) }),
                  let name = latest.first?.mealName else { return nil }
            return FinishDayMeal(id: key, name: name, entries: latest.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }, daysLogged: days)
        }
        .sorted { $0.daysLogged > $1.daysLogged }
        .prefix(maxMeals)
        .map { $0 }
    }

    private static func mostCommonTime(_ dates: [Date]) -> String {
        let labels = dates.map { date -> String in
            switch Calendar.current.component(.hour, from: date) {
            case ..<12: return "morning"
            case 12..<17: return "afternoon"
            default: return "evening"
            }
        }
        return Dictionary(grouping: labels, by: { $0 }).max { $0.value.count < $1.value.count }?.key ?? "evening"
    }
}
