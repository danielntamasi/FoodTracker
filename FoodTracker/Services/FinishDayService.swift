import Foundation

/// One suggested way to finish the day: a snack or small meal, as a whole plan for the rest of today.
struct FinishDayOption: Identifiable {
    let id = UUID()
    let title: String
    let note: String
    let items: [FinishDayPick]

    var totals: Nutrients { items.reduce(Nutrients()) { $0 + $1.item.totals } }
}

/// One item of an option, which the user can pick on its own. `optionTitle` names the meal group
/// it's logged in when picked together with other items of the same option.
struct FinishDayPick: Identifiable {
    let id = UUID()
    let item: FinishDayItem
    let optionTitle: String
}

enum FinishDayItem {
    /// One of the user's usual foods, so its numbers come from their own log
    case usual(FinishDayFood, servings: Double)
    /// One of the user's usual meals, re-added whole
    case meal(FinishDayMeal)
    /// Something not in their history; numbers are the assistant's estimate
    case new(name: String, portion: String?, nutrients: Nutrients)

    var name: String {
        switch self {
        case .usual(let food, _): return food.name
        case .meal(let meal): return meal.name
        case .new(let name, _, _): return name.titleCased()
        }
    }

    var amount: String? {
        switch self {
        case .usual(let food, let servings):
            if let description = food.template.servingDescription, !description.isEmpty {
                return "\(formatServings(servings)) × \(description)"
            }
            if let grams = food.template.servingGrams, grams > 0 { return "\(Int((grams * servings).rounded()))g" }
            return "\(formatServings(servings)) serving\(servings > 1 ? "s" : "")"
        case .meal(let meal): return meal.entries.map(\.name).joined(separator: ", ")
        case .new(_, let portion, _): return portion
        }
    }

    var totals: Nutrients {
        switch self {
        case .usual(let food, let servings): return food.perServing * servings
        case .meal(let meal): return meal.totals
        case .new(_, _, let nutrients): return nutrients
        }
    }

    var isEstimate: Bool { if case .new = self { return true } else { return false } }
}

/// Everything the assistant is told about the user's day.
struct FinishDayContext {
    let now: Date
    let goals: Nutrients
    let current: Nutrients
    let eatenToday: [FoodEntry]
    let foods: [FinishDayFood]
    let meals: [FinishDayMeal]
}

/// "Finish the day strong": a conversation with the selected AI provider that suggests what to eat
/// for the rest of today, built mostly from the user's usual foods so it's realistic and at home.
enum FinishDayService {
    struct Reply {
        let text: String
        let options: [FinishDayOption]
    }

    static let systemPrompt = """
    You help someone finish their day of eating well. They track calories and macros and want to land close \
    to their daily goals, but above all you suggest food a person would actually enjoy eating at this time \
    of day: satisfying, sensible portions, real snacks or small meals.

    Rules:
    - Build options mostly from their usual foods (listed with an id; they probably have them at home). \
    Combine them into something that makes sense together (e.g. pita + turkey + cheese as a sandwich, \
    yogurt + fruit). You may add one or two simple extra ingredients when it turns them into a proper meal.
    - Portions must be normal: never several servings of a drink or plain bread, at most 1–2 of any bar.
    - Variety: give exactly 3 options that are genuinely different (e.g. a savory small meal, a lighter \
    snack, something sweet or comforting). Don't reuse the same main food in every option.
    - Each option on its own is the plan for the rest of today. Aim for calories close to the remaining \
    calories, and protein as close to its goal as is reasonable. Calories and protein matter most.
    - If a goal is already met or over, avoid adding more of it (e.g. carbs over: lean on protein and fat). \
    Never suggest going well over the calorie goal. If they're basically done, say so and offer light options.
    - It's fine to fall short rather than suggest an odd combination just to hit numbers.
    - They may send photos of food they have on hand (the fridge, a pantry shelf, a package or its label). \
    Say briefly what you see, then build the 3 options around those foods, combined with usual foods where \
    it makes sense. Photographed foods are new items: name them specifically (brand and flavor if visible), \
    use the label's numbers for the portion when a nutrition label is readable, otherwise estimate. If a \
    photo is unclear, say what you're assuming rather than asking.

    Reply with at most two short, friendly sentences, then the options exactly in this format:
    <options>[{"title": "Turkey Pita Sandwich", "note": "Filling and high protein", "items": [{"usual": 3, "servings": 1}, {"name": "cucumber", "portion": "1/2 cup sliced", "calories": 8, "protein_grams": 0.3, "carbs_grams": 2, "fat_grams": 0}]}]</options>

    - Usual foods: {"usual": id, "servings": n} with n in steps of 0.5 (0.25 is fine for foods measured by weight). \
    Their numbers come from the user's log, so don't add any.
    - Usual meals: {"meal": id} (added whole).
    - Anything else: name, portion, and your best calories/protein_grams/carbs_grams/fat_grams estimate for that portion.
    - title: up to 4 words. note: up to 10 words on why it works.
    The user can pick single items from any option. When they reply (e.g. "no bars", "something warm"),     give 3 new options following their wishes. When they say what they've picked, those are already part     of their day: suggest 3 options for only what's left after them, without repeating their picks.
    """

    /// Sent with photos (alone, or after the user's note) so the assistant knows what they're for
    static let photosMessage = "This is food I have on hand right now. Plan the rest of my day with it."

    /// The first message: the day so far, the goals and what's usual.
    static func contextMessage(_ c: FinishDayContext) -> String {
        let time = c.now.formatted(.dateTime.weekday(.wide).hour().minute())
        var lines = ["It's \(time)."]

        func goalLine(_ name: String, _ now: Double, _ goal: Double, _ unit: String) -> String? {
            guard goal > 0 else { return nil }
            let left = goal - now
            let state = left >= 0 ? "\(Int(left.rounded()))\(unit) left" : "\(Int((-left).rounded()))\(unit) OVER"
            return "- \(name): \(Int(now.rounded())) of \(Int(goal))\(unit) (\(state))"
        }
        lines.append("\nToday so far vs goals:")
        lines += [goalLine("Calories", c.current.calories, c.goals.calories, " cal"),
                  goalLine("Protein", c.current.protein, c.goals.protein, "g"),
                  goalLine("Carbs", c.current.carbs, c.goals.carbs, "g"),
                  goalLine("Fat", c.current.fat, c.goals.fat, "g")].compactMap { $0 }

        lines.append("\nEaten today:")
        if c.eatenToday.isEmpty { lines.append("- nothing yet") }
        for entry in c.eatenToday.sorted(by: { $0.date < $1.date }) {
            let at = entry.date.formatted(date: .omitted, time: .shortened)
            lines.append("- \(at): \(entry.name) (\(entry.totals.summary))")
        }

        lines.append("\nUsual foods (id. name — one serving: numbers; how often in the last \(FinishDayHistory.lookbackDays) days; when):")
        for (index, food) in c.foods.enumerated() {
            var serving = food.template.servingDescription ?? ""
            if let grams = food.template.servingGrams, grams > 0 { serving += serving.isEmpty ? "\(Int(grams))g" : " (\(Int(grams))g)" }
            let usual = food.usualServings == 1 ? "" : ", usually \(formatServings(food.usualServings)) servings"
            lines.append("\(index). \(food.name) — \(serving.isEmpty ? "1 serving" : serving): \(food.perServing.summary); \(food.daysLogged) days, mostly \(food.usualTime)\(usual)")
        }
        if !c.meals.isEmpty {
            lines.append("\nUsual meals (id. name: whole meal numbers; what's in it):")
            for (index, meal) in c.meals.enumerated() {
                lines.append("\(index). \(meal.name): \(meal.totals.summary); \(meal.entries.map(\.name).joined(separator: ", "))")
            }
        }
        lines.append("\nWhat should I have for the rest of today?")
        return lines.joined(separator: "\n")
    }

    /// The user's picks so far, and what that leaves, asking for options for the rest
    static func recalculateMessage(picks: [FinishDayPick], current: Nutrients, goals: Nutrients) -> String {
        let planned = picks.reduce(Nutrients()) { $0 + $1.item.totals }
        let after = current + planned
        var lines = ["I've picked these (already part of my day now):"]
        for pick in picks {
            lines.append("- \(pick.item.name)\(pick.item.amount.map { " (\($0))" } ?? ""): \(pick.item.totals.summary)")
        }
        func left(_ name: String, _ value: Double, _ goal: Double, _ unit: String) -> String? {
            guard goal > 0 else { return nil }
            let rest = goal - value
            return rest >= 0 ? "\(name) \(Int(rest.rounded()))\(unit) left" : "\(name) \(Int((-rest).rounded()))\(unit) OVER"
        }
        let state = [left("calories", after.calories, goals.calories, ""), left("protein", after.protein, goals.protein, "g"),
                     left("carbs", after.carbs, goals.carbs, "g"), left("fat", after.fat, goals.fat, "g")].compactMap { $0 }
        lines.append("With them: \(state.joined(separator: ", ")). What should I have for what's left?")
        return lines.joined(separator: "\n")
    }

    static func reply(to turns: [FoodChatTurn], context: FinishDayContext) async throws -> Reply {
        let raw = try await FoodChatService.reply(to: turns, system: systemPrompt)
        return parse(raw, context: context)
    }

    // MARK: Parsing

    private struct OptionDTO: Decodable {
        let title: String
        let note: String?
        let items: [ItemDTO]
    }

    private struct ItemDTO: Decodable {
        let usual: Int?
        let meal: Int?
        let servings: Double?
        let name: String?
        let portion: String?
        let calories: Double?
        let protein_grams: Double?
        let carbs_grams: Double?
        let fat_grams: Double?
    }

    static func parse(_ raw: String, context: FinishDayContext) -> Reply {
        guard let open = raw.range(of: "<options>") else {
            return Reply(text: raw.trimmingCharacters(in: .whitespacesAndNewlines), options: [])
        }
        let text = String(raw[..<open.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rest = raw[open.upperBound...]
        let json = rest.range(of: "</options>").map { String(rest[..<$0.lowerBound]) } ?? String(rest)
        guard let data = json.data(using: .utf8),
              let dtos = try? JSONDecoder().decode([OptionDTO].self, from: data) else {
            return Reply(text: text, options: [])
        }
        let options = dtos.compactMap { dto -> FinishDayOption? in
            let items = dto.items.compactMap { item(from: $0, context: context) }
                .map { FinishDayPick(item: $0, optionTitle: dto.title) }
            guard !items.isEmpty else { return nil }
            return FinishDayOption(title: dto.title, note: dto.note ?? "", items: items)
        }
        return Reply(text: text, options: options)
    }

    private static func item(from dto: ItemDTO, context: FinishDayContext) -> FinishDayItem? {
        if let index = dto.usual, context.foods.indices.contains(index) {
            let servings = max(0.25, ((dto.servings ?? 1) * 4).rounded() / 4)
            return .usual(context.foods[index], servings: servings)
        }
        if let index = dto.meal, context.meals.indices.contains(index) {
            return .meal(context.meals[index])
        }
        guard let name = dto.name, !name.isEmpty, let calories = dto.calories else { return nil }
        let nutrients = Nutrients(calories: calories, protein: dto.protein_grams ?? 0,
                                  carbs: dto.carbs_grams ?? 0, fat: dto.fat_grams ?? 0)
        guard isValidNutrition(calories: Int(calories.rounded()), protein: nutrients.protein,
                               carbs: nutrients.carbs, fat: nutrients.fat) else { return nil }
        return .new(name: name, portion: dto.portion, nutrients: nutrients)
    }
}
