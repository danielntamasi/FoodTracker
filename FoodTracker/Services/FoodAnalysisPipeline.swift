import Foundation
import UIKit

// MARK: - Shared JSON Parsing

func decodeVisionResponse(from text: String) throws -> VisionFoodResponse {
    let jsonString = extractJSON(from: text)

    guard let jsonData = jsonString.data(using: .utf8) else {
        throw FoodAnalysisError.apiError("Response was not valid text.")
    }

    do {
        return try JSONDecoder().decode(VisionFoodResponse.self, from: jsonData)
    } catch is DecodingError {
        let cleaned = jsonString
            .replacingOccurrences(of: ",\\s*\\}", with: "}", options: .regularExpression)
            .replacingOccurrences(of: ",\\s*\\]", with: "]", options: .regularExpression)
        if let cleanedData = cleaned.data(using: .utf8),
           let result = try? JSONDecoder().decode(VisionFoodResponse.self, from: cleanedData) {
            return result
        }

        throw FoodAnalysisError.apiError("Could not parse AI response. Try taking a clearer photo.")
    } catch {
        throw FoodAnalysisError.apiError("Could not parse AI response: \(error.localizedDescription)")
    }
}

func extractJSON(from text: String) -> String {
    if let range = text.range(of: "```(?:json)?\\s*\n", options: .regularExpression) {
        let start = range.upperBound
        if let endRange = text.range(of: "\n\\s*```", options: .regularExpression, range: start..<text.endIndex) {
            return String(text[start..<endRange.lowerBound])
        }
    }
    if let start = text.firstIndex(of: "{"),
       let end = text.lastIndex(of: "}") {
        return String(text[start...end])
    }
    return text
}

// MARK: - Combined Analysis Pipeline

enum FoodAnalysisPipeline {
    /// Text-based nutrition estimation using the selected AI provider.
    static func estimateNutrition(for foodName: String) async throws -> USDAService.USDALookupResult {
        let estimate = try await VisionAPIService.shared.estimateNutrition(for: foodName)

        // Convert to per-100g values if serving grams is known, otherwise store as-is
        let per100g: USDAService.NutrientsPer100g
        if let grams = estimate.servingGrams, grams > 0 {
            let scale = 100.0 / grams
            per100g = USDAService.NutrientsPer100g(
                calories: Double(estimate.calories) * scale,
                protein: estimate.proteinGrams * scale,
                carbs: estimate.carbsGrams * scale,
                fat: estimate.fatGrams * scale
            )
        } else {
            per100g = USDAService.NutrientsPer100g(
                calories: Double(estimate.calories),
                protein: estimate.proteinGrams,
                carbs: estimate.carbsGrams,
                fat: estimate.fatGrams
            )
        }

        return USDAService.USDALookupResult(
            description: estimate.name.isEmpty ? foodName : estimate.name,
            nutrientsPer100g: per100g,
            servingDescription: estimate.servingDescription,
            servingGrams: estimate.servingGrams
        )
    }

    /// Vision provider identifies foods → USDA looks up macros → returns combined results
    static func analyzeImage(_ image: UIImage) async throws -> [IdentifiedFood] {
        // Step 1: Identify foods using selected vision provider
        let response = try await VisionAPIService.shared.identifyFoods(in: image)

        // Step 2: Flatten elements, assigning mealGroupID for grouped meals
        var itemsWithGrouping: [(item: VisionIdentifiedItem, mealGroupID: UUID?, mealName: String?)] = []

        for element in response.foods {
            switch element {
            case .meal(let name, let ingredients):
                let groupID = UUID()
                let titleName = name.titleCased()
                for ingredient in ingredients {
                    itemsWithGrouping.append((item: ingredient, mealGroupID: groupID, mealName: titleName))
                }
            case .standalone(let item):
                itemsWithGrouping.append((item: item, mealGroupID: nil, mealName: nil))
            }
        }

        // Step 3: For label items, use values directly. For estimates, look up USDA.
        var results: [IdentifiedFood] = []

        await withTaskGroup(of: IdentifiedFood?.self) { group in
            for entry in itemsWithGrouping {
                let item = entry.item
                let groupID = entry.mealGroupID
                let mealName = entry.mealName

                group.addTask {
                    if item.hasLabelNutrition {
                        let cal = item.calories ?? 0
                        let prot = item.protein_grams ?? 0
                        let carb = item.carbs_grams ?? 0
                        let f = item.fat_grams ?? 0
                        let grams = item.portion_grams
                        let scale = grams > 0 ? 100.0 / grams : 1.0
                        return IdentifiedFood(
                            name: item.name.titleCased(),
                            calories: Int(cal),
                            proteinGrams: prot,
                            carbsGrams: carb,
                            fatGrams: f,
                            portionGrams: grams,
                            portionDescription: item.portion,
                            source: .label,
                            mealGroupID: groupID,
                            mealName: mealName,
                            caloriesPer100g: cal * scale,
                            proteinPer100g: prot * scale,
                            carbsPer100g: carb * scale,
                            fatPer100g: f * scale,
                            servingGrams: grams
                        )
                    } else {
                        let result = try? await USDAService.shared.lookupFood(for: item.name)

                        let calories: Int
                        let protein: Double
                        let carbs: Double
                        let fat: Double
                        var detectedServings: Double = 1.0
                        var calPer100g: Double?
                        var protPer100g: Double?
                        var carbPer100g: Double?
                        var fatPer100g: Double?
                        var srvGrams: Double?

                        if let nutrients = result?.nutrientsPer100g,
                           nutrients.calories > 0 || nutrients.protein > 0 || nutrients.carbs > 0 || nutrients.fat > 0 {
                            calPer100g = nutrients.calories
                            protPer100g = nutrients.protein
                            carbPer100g = nutrients.carbs
                            fatPer100g = nutrients.fat

                            if let servingGrams = result?.servingGrams, servingGrams > 0 {
                                srvGrams = servingGrams
                                detectedServings = (item.portion_grams / servingGrams).roundedTo(2)
                                let servingScale = servingGrams / 100.0
                                calories = Int((nutrients.calories * servingScale).rounded())
                                protein = (nutrients.protein * servingScale).roundedTo(1)
                                carbs = (nutrients.carbs * servingScale).roundedTo(1)
                                fat = (nutrients.fat * servingScale).roundedTo(1)
                            } else {
                                let scale = item.portion_grams / 100.0
                                calories = Int(nutrients.calories * scale)
                                protein = (nutrients.protein * scale).roundedTo(1)
                                carbs = (nutrients.carbs * scale).roundedTo(1)
                                fat = (nutrients.fat * scale).roundedTo(1)
                            }
                        } else {
                            calories = Int(item.calories ?? 0)
                            protein = item.protein_grams ?? 0
                            carbs = item.carbs_grams ?? 0
                            fat = item.fat_grams ?? 0
                        }

                        return IdentifiedFood(
                            name: item.name.titleCased(),
                            calories: calories,
                            proteinGrams: protein,
                            carbsGrams: carbs,
                            fatGrams: fat,
                            portionGrams: item.portion_grams,
                            portionDescription: item.portion,
                            source: .estimate,
                            mealGroupID: groupID,
                            mealName: mealName,
                            caloriesPer100g: calPer100g,
                            proteinPer100g: protPer100g,
                            carbsPer100g: carbPer100g,
                            fatPer100g: fatPer100g,
                            servingGrams: srvGrams,
                            servings: detectedServings
                        )
                    }
                }
            }

            for await food in group {
                if let food { results.append(food) }
            }
        }

        return results
    }
}
