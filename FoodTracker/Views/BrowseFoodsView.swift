import SwiftUI
import SwiftData

struct BrowseFoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

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

    var body: some View {
        NavigationStack {
            List {
                if !frequentFoods.isEmpty {
                    Section("Frequent") {
                        ForEach(Array(frequentFoods.enumerated()), id: \.offset) { _, food in
                            Button {
                                addFood(name: food.name, calories: food.calories, protein: food.protein, carbs: food.carbs, fat: food.fat, iconName: food.iconName, photoData: food.photoData, servingDescription: food.servingDescription, servingGrams: food.servingGrams)
                            } label: {
                                HStack {
                                    Image(systemName: food.iconName ?? "fork.knife")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
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
                                            .foregroundStyle(.secondary)
                                        Text("\u{00D7}\(food.count)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
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
                                        .foregroundStyle(.secondary)
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

                if frequentFoods.isEmpty && recentFoods.isEmpty {
                    ContentUnavailableView(
                        "No Foods Yet",
                        systemImage: "fork.knife",
                        description: Text("Foods you've added will appear here for quick access.")
                    )
                }
            }
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
        dismiss()
    }
}
