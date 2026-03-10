import SwiftUI
import SwiftData

struct BrowseFoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    /// When set, saves as an IngredientItem instead of a FoodEntry (used by BuildMealView)
    var onIngredientAdded: ((IngredientItem) -> Void)?

    private var frequentFoods: [(name: String, calories: Int, protein: Double, carbs: Double, fat: Double, count: Int, iconName: String?, photoData: Data?, servingDescription: String?, servingGrams: Double?)] {
        var groups: [String: (name: String, calories: Int, protein: Double, carbs: Double, fat: Double, count: Int, iconName: String?, photoData: Data?, servingDescription: String?, servingGrams: Double?, latestDate: Date)] = [:]
        for entry in allEntries {
            let key = entry.name.lowercased().trimmingCharacters(in: .whitespaces)
            if key.isEmpty { continue }
            if var existing = groups[key] {
                existing.count += 1
                if entry.date > existing.latestDate {
                    existing.latestDate = entry.date
                    if entry.photoData != nil { existing.photoData = entry.photoData }
                    if entry.servingDescription != nil { existing.servingDescription = entry.servingDescription }
                    if entry.servingGrams != nil { existing.servingGrams = entry.servingGrams }
                }
                groups[key] = existing
            } else {
                groups[key] = (name: entry.name, calories: entry.totalCalories, protein: entry.totalProteinGrams, carbs: entry.totalCarbsGrams, fat: entry.totalFatGrams, count: 1, iconName: entry.iconName, photoData: entry.photoData, servingDescription: entry.servingDescription, servingGrams: entry.servingGrams, latestDate: entry.date)
            }
        }
        return Array(
            groups.values
                .sorted {
                    if $0.count != $1.count { return $0.count > $1.count }
                    return $0.latestDate > $1.latestDate
                }
                .prefix(5)
                .map { ($0.name, $0.calories, $0.protein, $0.carbs, $0.fat, $0.count, $0.iconName, $0.photoData, $0.servingDescription, $0.servingGrams) }
        )
    }

    private var recentMeals: [(name: String, entries: [FoodEntry], totalCalories: Int, totalProtein: Double, totalCarbs: Double, totalFat: Double)] {
        var groupsByID: [UUID: (name: String, entries: [FoodEntry], latestDate: Date)] = [:]
        for entry in allEntries {
            guard let groupID = entry.mealGroupID, let mealName = entry.mealName else { continue }
            if var existing = groupsByID[groupID] {
                existing.entries.append(entry)
                if entry.date > existing.latestDate { existing.latestDate = entry.date }
                groupsByID[groupID] = existing
            } else {
                groupsByID[groupID] = (name: mealName, entries: [entry], latestDate: entry.date)
            }
        }
        var seenNames: Set<String> = []
        let sorted = groupsByID.values.sorted { $0.latestDate > $1.latestDate }
        var result: [(name: String, entries: [FoodEntry], totalCalories: Int, totalProtein: Double, totalCarbs: Double, totalFat: Double)] = []
        for group in sorted {
            let key = group.name.lowercased().trimmingCharacters(in: .whitespaces)
            if key.isEmpty || seenNames.contains(key) { continue }
            seenNames.insert(key)
            let totalCal = group.entries.reduce(0) { $0 + $1.totalCalories }
            let totalP = group.entries.reduce(0.0) { $0 + $1.totalProteinGrams }
            let totalC = group.entries.reduce(0.0) { $0 + $1.totalCarbsGrams }
            let totalF = group.entries.reduce(0.0) { $0 + $1.totalFatGrams }
            result.append((name: group.name, entries: group.entries, totalCalories: totalCal, totalProtein: totalP, totalCarbs: totalC, totalFat: totalF))
            if result.count >= 5 { break }
        }
        return result
    }

    private var recentFoods: [FoodEntry] {
        let calendar = Calendar.current
        var seen: Set<String> = []
        var result: [FoodEntry] = []
        for entry in allEntries {
            if calendar.isDateInToday(entry.date) { continue }
            let key = entry.name.lowercased().trimmingCharacters(in: .whitespaces)
            if key.isEmpty { continue }
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(entry)
            if result.count >= 10 { break }
        }
        return result
    }

    private enum FavoriteItem {
        case food(name: String, calories: Int, protein: Double, carbs: Double, fat: Double, iconName: String?, photoData: Data?, servingDescription: String?, servingGrams: Double?)
        case meal(name: String, entries: [FoodEntry], totalCalories: Int, totalProtein: Double, totalCarbs: Double, totalFat: Double)

        var displayName: String {
            switch self {
            case .food(let name, _, _, _, _, _, _, _, _): return name
            case .meal(let name, _, _, _, _, _): return name
            }
        }
    }

    private var favoriteItems: [FavoriteItem] {
        var items: [FavoriteItem] = []
        var seenKeys: Set<String> = []

        // Favorite individual foods (non-meal entries)
        var latestByName: [String: FoodEntry] = [:]
        for entry in allEntries {
            if entry.mealGroupID != nil { continue }
            let key = entry.name.lowercased().trimmingCharacters(in: .whitespaces)
            if key.isEmpty { continue }
            guard FavoriteFoods.isFavorite(key) else { continue }
            if let existing = latestByName[key] {
                if entry.date > existing.date { latestByName[key] = entry }
            } else {
                latestByName[key] = entry
            }
        }
        for entry in latestByName.values.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }) {
            let key = entry.name.lowercased().trimmingCharacters(in: .whitespaces)
            seenKeys.insert(key)
            items.append(.food(name: entry.name, calories: entry.totalCalories, protein: entry.totalProteinGrams, carbs: entry.totalCarbsGrams, fat: entry.totalFatGrams, iconName: entry.iconName, photoData: entry.photoData, servingDescription: entry.servingDescription, servingGrams: entry.servingGrams))
        }

        // Favorite meals
        var mealsByID: [UUID: (name: String, entries: [FoodEntry], latestDate: Date)] = [:]
        for entry in allEntries {
            guard let groupID = entry.mealGroupID, let mealName = entry.mealName else { continue }
            if var existing = mealsByID[groupID] {
                existing.entries.append(entry)
                if entry.date > existing.latestDate { existing.latestDate = entry.date }
                mealsByID[groupID] = existing
            } else {
                mealsByID[groupID] = (name: mealName, entries: [entry], latestDate: entry.date)
            }
        }
        var seenMealNames: Set<String> = []
        for group in mealsByID.values.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }) {
            let key = group.name.lowercased().trimmingCharacters(in: .whitespaces)
            if key.isEmpty || seenKeys.contains(key) || seenMealNames.contains(key) { continue }
            guard FavoriteFoods.isFavorite(key) else { continue }
            seenMealNames.insert(key)
            let totalCal = group.entries.reduce(0) { $0 + $1.totalCalories }
            let totalP = group.entries.reduce(0.0) { $0 + $1.totalProteinGrams }
            let totalC = group.entries.reduce(0.0) { $0 + $1.totalCarbsGrams }
            let totalF = group.entries.reduce(0.0) { $0 + $1.totalFatGrams }
            items.append(.meal(name: group.name, entries: group.entries, totalCalories: totalCal, totalProtein: totalP, totalCarbs: totalC, totalFat: totalF))
        }

        return items
    }

    var body: some View {
        NavigationStack {
            List {
                if !favoriteItems.isEmpty {
                    Section("Favorites") {
                        ForEach(Array(favoriteItems.enumerated()), id: \.offset) { _, item in
                            switch item {
                            case .food(let name, let calories, let protein, let carbs, let fat, let iconName, let photoData, let servingDescription, let servingGrams):
                                Button {
                                    addFood(name: name, calories: calories, protein: protein, carbs: carbs, fat: fat, iconName: iconName, photoData: photoData, servingDescription: servingDescription, servingGrams: servingGrams)
                                } label: {
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .font(.title3)
                                            .foregroundStyle(DS.Color.carbs)
                                            .frame(width: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(name)
                                                .font(.body)
                                            coloredMacroText(protein: protein, carbs: carbs, fat: fat)
                                                .font(.caption)
                                        }
                                        Spacer()
                                        Text("\(calories) cal")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(DS.Color.textSecondary)
                                    }
                                }
                                .tint(.primary)
                            case .meal(let name, let entries, let totalCalories, let totalProtein, let totalCarbs, let totalFat):
                                Button {
                                    if let onIngredientAdded {
                                        for entry in entries {
                                            onIngredientAdded(IngredientItem(
                                                name: entry.name,
                                                calories: entry.calories,
                                                proteinGrams: entry.proteinGrams,
                                                carbsGrams: entry.carbsGrams,
                                                fatGrams: entry.fatGrams,
                                                servings: entry.servings,
                                                servingDescription: entry.servingDescription,
                                                servingGrams: entry.servingGrams
                                            ))
                                        }
                                        dismiss()
                                    } else {
                                        quickAddMealGroup(entries, mealName: name, into: modelContext)
                                        dismiss()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .font(.title3)
                                            .foregroundStyle(DS.Color.carbs)
                                            .frame(width: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(name)
                                                .font(.body)
                                            Text("\(entries.count) ingredient\(entries.count == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundStyle(DS.Color.textTertiary)
                                            coloredMacroText(protein: totalProtein, carbs: totalCarbs, fat: totalFat)
                                                .font(.caption)
                                        }
                                        Spacer()
                                        Text("\(totalCalories) cal")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(DS.Color.textSecondary)
                                    }
                                }
                                .tint(.primary)
                            }
                        }
                    }
                }

                if !frequentFoods.isEmpty {
                    Section("Frequent") {
                        ForEach(Array(frequentFoods.enumerated()), id: \.offset) { _, food in
                            Button {
                                addFood(name: food.name, calories: food.calories, protein: food.protein, carbs: food.carbs, fat: food.fat, iconName: food.iconName, photoData: food.photoData, servingDescription: food.servingDescription, servingGrams: food.servingGrams)
                            } label: {
                                HStack {
                                    Image(systemName: food.iconName ?? "fork.knife")
                                        .font(.title3)
                                        .foregroundStyle(DS.Color.textSecondary)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(food.name)
                                            .font(.body)
                                        coloredMacroText(protein: food.protein, carbs: food.carbs, fat: food.fat)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(food.calories) cal")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(DS.Color.textSecondary)
                                        Text("\u{00D7}\(food.count)")
                                            .font(.caption2)
                                            .foregroundStyle(DS.Color.textTertiary)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                if !recentMeals.isEmpty {
                    Section("Recent Meals") {
                        ForEach(Array(recentMeals.enumerated()), id: \.offset) { _, meal in
                            Button {
                                if let onIngredientAdded {
                                    for entry in meal.entries {
                                        onIngredientAdded(IngredientItem(
                                            name: entry.name,
                                            calories: entry.calories,
                                            proteinGrams: entry.proteinGrams,
                                            carbsGrams: entry.carbsGrams,
                                            fatGrams: entry.fatGrams,
                                            servings: entry.servings,
                                            servingDescription: entry.servingDescription,
                                            servingGrams: entry.servingGrams
                                        ))
                                    }
                                    dismiss()
                                } else {
                                    quickAddMealGroup(meal.entries, mealName: meal.name, into: modelContext)
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "square.stack.3d.up")
                                        .font(.title3)
                                        .foregroundStyle(DS.Color.textSecondary)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(meal.name)
                                            .font(.body)
                                        Text("\(meal.entries.count) ingredient\(meal.entries.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(DS.Color.textTertiary)
                                        coloredMacroText(protein: meal.totalProtein, carbs: meal.totalCarbs, fat: meal.totalFat)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    Text("\(meal.totalCalories) cal")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                if !recentFoods.isEmpty {
                    Section("Recent") {
                        ForEach(recentFoods) { entry in
                            Button {
                                addFood(name: entry.name, calories: entry.totalCalories, protein: entry.totalProteinGrams, carbs: entry.totalCarbsGrams, fat: entry.totalFatGrams, iconName: entry.iconName, photoData: entry.photoData, servingDescription: entry.servingDescription, servingGrams: entry.servingGrams)
                            } label: {
                                HStack {
                                    Image(systemName: entry.iconName ?? "fork.knife")
                                        .font(.title3)
                                        .foregroundStyle(DS.Color.textSecondary)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name)
                                            .font(.body)
                                        coloredMacroText(protein: entry.totalProteinGrams, carbs: entry.totalCarbsGrams, fat: entry.totalFatGrams)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    Text("\(entry.totalCalories) cal")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                if favoriteItems.isEmpty && frequentFoods.isEmpty && recentMeals.isEmpty && recentFoods.isEmpty {
                    ContentUnavailableView(
                        "No Foods Yet",
                        systemImage: "fork.knife",
                        description: Text("Foods you've added will appear here for quick access.")
                    )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DS.Color.backgroundPrimary)
            .navigationTitle("Browse Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addFood(name: String, calories: Int, protein: Double, carbs: Double, fat: Double, iconName: String?, photoData: Data? = nil, servingDescription: String? = nil, servingGrams: Double? = nil) {
        if let onIngredientAdded {
            onIngredientAdded(IngredientItem(
                name: name,
                calories: calories,
                proteinGrams: protein,
                carbsGrams: carbs,
                fatGrams: fat,
                servingDescription: servingDescription,
                servingGrams: servingGrams
            ))
            dismiss()
            return
        }
        let entry = FoodEntry(
            name: name,
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            photoData: photoData,
            iconName: iconName ?? foodIconName(for: name),
            servings: 1.0,
            servingDescription: servingDescription,
            servingGrams: servingGrams
        )
        modelContext.insert(entry)
        Task { await HealthKitService.shared.syncEntry(entry) }
        dismiss()
    }
}
