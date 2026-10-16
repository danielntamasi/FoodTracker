import Foundation
import os

// MARK: - Accuracy Tracker

/// Tracks user corrections to AI-estimated nutrition values to identify systematic biases.
/// Stores correction history as a JSON file in the app's documents directory.
actor AccuracyTracker {
    static let shared = AccuracyTracker()
    private let logger = Logger(subsystem: "com.DNT.foodtracker", category: "AccuracyTracker")

    private var corrections: [CorrectionRecord] = []
    private var loaded = false

    struct CorrectionRecord: Codable, Identifiable {
        let id: UUID
        let date: Date
        let foodName: String
        let source: String // "estimate", "usda", "barcode"
        // Original AI/USDA values
        let originalCalories: Int
        let originalProtein: Double
        let originalCarbs: Double
        let originalFat: Double
        // User-corrected values
        let correctedCalories: Int
        let correctedProtein: Double
        let correctedCarbs: Double
        let correctedFat: Double

        var calorieDelta: Int { correctedCalories - originalCalories }
        var calorieErrorPercent: Double {
            guard originalCalories > 0 else { return 0 }
            return Double(calorieDelta) / Double(originalCalories) * 100
        }
    }

    /// Summary of correction patterns for a food category.
    struct AccuracySummary {
        let totalCorrections: Int
        let averageCalorieError: Double
        let averageCalorieErrorPercent: Double
        let mostCorrectedFoods: [(name: String, count: Int)]
        let systematicBias: String // "underestimates", "overestimates", or "balanced"
    }

    // MARK: - Public API

    /// Record a user correction to an AI-estimated entry.
    func recordCorrection(
        foodName: String,
        source: NutritionSource,
        originalCalories: Int,
        originalProtein: Double,
        originalCarbs: Double,
        originalFat: Double,
        correctedCalories: Int,
        correctedProtein: Double,
        correctedCarbs: Double,
        correctedFat: Double
    ) {
        loadIfNeeded()
        // Only record if there's a meaningful difference
        let calDiff = abs(correctedCalories - originalCalories)
        let macroDiff = abs(correctedProtein - originalProtein) + abs(correctedCarbs - originalCarbs) + abs(correctedFat - originalFat)
        guard calDiff > 5 || macroDiff > 1.0 else { return }

        let record = CorrectionRecord(
            id: UUID(),
            date: Date(),
            foodName: foodName.lowercased(),
            source: source.rawValue,
            originalCalories: originalCalories,
            originalProtein: originalProtein,
            originalCarbs: originalCarbs,
            originalFat: originalFat,
            correctedCalories: correctedCalories,
            correctedProtein: correctedProtein,
            correctedCarbs: correctedCarbs,
            correctedFat: correctedFat
        )

        corrections.append(record)
        save()
        logger.info("Recorded correction for '\(foodName)': \(originalCalories) → \(correctedCalories) cal")
    }

    /// Get a summary of correction patterns.
    func summary() -> AccuracySummary {
        loadIfNeeded()
        guard !corrections.isEmpty else {
            return AccuracySummary(
                totalCorrections: 0,
                averageCalorieError: 0,
                averageCalorieErrorPercent: 0,
                mostCorrectedFoods: [],
                systematicBias: "balanced"
            )
        }

        let avgError = corrections.reduce(0.0) { $0 + Double($1.calorieDelta) } / Double(corrections.count)
        let avgErrorPercent = corrections.reduce(0.0) { $0 + $1.calorieErrorPercent } / Double(corrections.count)

        // Count corrections by food name
        var foodCounts: [String: Int] = [:]
        for c in corrections {
            foodCounts[c.foodName, default: 0] += 1
        }
        let topFoods = foodCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { (name: $0.key, count: $0.value) }

        let bias: String
        if avgErrorPercent < -10 { bias = "underestimates" }
        else if avgErrorPercent > 10 { bias = "overestimates" }
        else { bias = "balanced" }

        return AccuracySummary(
            totalCorrections: corrections.count,
            averageCalorieError: avgError,
            averageCalorieErrorPercent: avgErrorPercent,
            mostCorrectedFoods: topFoods,
            systematicBias: bias
        )
    }

    /// Get correction records for display in Settings.
    func recentCorrections(limit: Int = 20) -> [CorrectionRecord] {
        loadIfNeeded()
        return Array(corrections.suffix(limit).reversed())
    }

    /// Clear all correction history.
    /// Writes the full correction history to a CSV file for sharing; nil when there is nothing to export.
    func exportCSV() -> URL? {
        loadIfNeeded()
        guard !corrections.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        func field(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        func num(_ value: Double) -> String { String(format: "%.1f", value) }

        var lines = ["date,food,source,original_calories,original_protein,original_carbs,original_fat,corrected_calories,corrected_protein,corrected_carbs,corrected_fat,calorie_delta,calorie_error_percent"]
        for r in corrections.sorted(by: { $0.date < $1.date }) {
            lines.append([
                formatter.string(from: r.date), field(r.foodName), r.source,
                "\(r.originalCalories)", num(r.originalProtein), num(r.originalCarbs), num(r.originalFat),
                "\(r.correctedCalories)", num(r.correctedProtein), num(r.correctedCarbs), num(r.correctedFat),
                "\(r.calorieDelta)", num(r.calorieErrorPercent)
            ].joined(separator: ","))
        }

        let day = formatter.string(from: Date()).prefix(10)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FoodTracker_Corrections_\(day).csv")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            logger.error("Failed to export corrections: \(error.localizedDescription)")
            return nil
        }
    }

    func clearHistory() {
        corrections = []
        save()
    }

    // MARK: - Persistence

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("accuracy_corrections.json")
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([CorrectionRecord].self, from: data) else {
            return
        }
        corrections = records
        logger.info("Loaded \(records.count) correction records")
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(corrections)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save corrections: \(error.localizedDescription)")
        }
    }
}
