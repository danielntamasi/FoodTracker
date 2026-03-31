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

// MARK: - Nutrition Sanity Checking

/// Validates and corrects nutrition values using multiple heuristics.
/// Returns corrected (calories, protein, carbs, fat).
func sanitizeNutrition(
    calories: Double,
    protein: Double,
    carbs: Double,
    fat: Double,
    foodName: String = "",
    portionGrams: Double = 0
) -> (calories: Int, protein: Double, carbs: Double, fat: Double) {
    var cal = calories
    var p = protein
    var c = carbs
    var f = fat

    // 1. Derive calories from macros if zero
    let macroDerived = p * 4 + c * 4 + f * 9
    if cal == 0 && macroDerived > 0 {
        cal = macroDerived
    }

    // 2. Macro-calorie consistency check: if calories differs from macro-derived by >25%, use macro-derived
    if cal > 0 && macroDerived > 0 {
        let divergence = abs(cal - macroDerived) / max(cal, macroDerived)
        if divergence > 0.25 {
            cal = macroDerived
        }
    }

    // 3. Per-food-category range checks (based on portion, rough heuristics)
    let nameLower = foodName.lowercased()
    let maxCalForPortion: Double
    let minCalForPortion: Double

    if nameLower.contains("salad") && !nameLower.contains("pasta") {
        maxCalForPortion = 800
        minCalForPortion = 20
    } else if nameLower.contains("soup") || nameLower.contains("broth") {
        maxCalForPortion = 600
        minCalForPortion = 20
    } else if nameLower.contains("fruit") || nameLower.contains("apple") || nameLower.contains("banana") ||
              nameLower.contains("orange") || nameLower.contains("berry") || nameLower.contains("grape") {
        maxCalForPortion = 400
        minCalForPortion = 10
    } else if nameLower.contains("water") || nameLower.contains("tea") || nameLower.contains("coffee") {
        maxCalForPortion = 100
        minCalForPortion = 0
    } else {
        // General food: scale max by portion size
        let portionFactor = portionGrams > 0 ? portionGrams / 100.0 : 1.0
        maxCalForPortion = max(400 * portionFactor, 1500)
        minCalForPortion = 0
    }

    // Clamp to reasonable range (soft correction)
    if cal > maxCalForPortion && maxCalForPortion > 0 {
        let scale = cal > 0 ? maxCalForPortion / cal : 1.0
        cal = maxCalForPortion
        p *= scale
        c *= scale
        f *= scale
    }
    if cal > 0 && cal < minCalForPortion {
        cal = minCalForPortion
    }

    // 4. Single portion sanity: flag extremely high values
    if cal > 3000 {
        // Very likely an overestimate for a single portion — cap at 3000
        let scale = 3000.0 / cal
        cal = 3000
        p *= scale
        c *= scale
        f *= scale
    }

    return (
        calories: Int(cal.rounded()),
        protein: p.roundedTo(1),
        carbs: c.roundedTo(1),
        fat: f.roundedTo(1)
    )
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

    /// Vision provider identifies foods → USDA looks up macros → returns combined results.
    /// Accepts optional cooking method and plate size for improved accuracy.
    static func analyzeImage(
        _ image: UIImage,
        cookingMethod: CookingMethod? = nil,
        plateSize: PlateSize = .medium
    ) async throws -> [IdentifiedFood] {
        // Step 1: Identify foods using selected vision provider
        let response = try await VisionAPIService.shared.identifyFoods(in: image, plateSize: plateSize)
        return try await processVisionResponse(response, cookingMethod: cookingMethod, plateSize: plateSize)
    }

    /// Multi-angle precision mode: send multiple images for better portion estimation.
    static func analyzeImages(
        _ images: [UIImage],
        cookingMethod: CookingMethod? = nil,
        plateSize: PlateSize = .medium
    ) async throws -> [IdentifiedFood] {
        let response = try await VisionAPIService.shared.identifyFoods(images: images, plateSize: plateSize)
        return try await processVisionResponse(response, cookingMethod: cookingMethod, plateSize: plateSize)
    }

    /// Process a vision response into IdentifiedFood items with USDA/FNDDS lookups and sanity checks.
    /// Also used by PhotoAnalysisView to re-run lookups with different cooking method/plate size without re-calling the vision API.
    static func processVisionResponse(
        _ response: VisionFoodResponse,
        cookingMethod: CookingMethod?,
        plateSize: PlateSize
    ) async throws -> [IdentifiedFood] {
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

        // Step 3: For label items, use values directly. For estimates, look up USDA/FNDDS.
        var results: [IdentifiedFood] = []

        await withTaskGroup(of: IdentifiedFood?.self) { group in
            for entry in itemsWithGrouping {
                let item = entry.item
                let groupID = entry.mealGroupID
                let mealName = entry.mealName

                group.addTask {
                    if item.hasLabelNutrition {
                        return buildLabelFood(item: item, groupID: groupID, mealName: mealName)
                    } else {
                        return await buildEstimatedFood(
                            item: item,
                            groupID: groupID,
                            mealName: mealName,
                            cookingMethod: cookingMethod,
                            plateSize: plateSize
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

    /// Build an IdentifiedFood from a label-sourced vision item (no lookup needed).
    private static func buildLabelFood(
        item: VisionIdentifiedItem,
        groupID: UUID?,
        mealName: String?
    ) -> IdentifiedFood {
        let cal = item.calories ?? 0
        let prot = item.protein_grams ?? 0
        let carb = item.carbs_grams ?? 0
        let f = item.fat_grams ?? 0
        let grams = item.portion_grams
        let scale = grams > 0 ? 100.0 / grams : 1.0
        return IdentifiedFood(
            name: item.name.titleCased(),
            calories: Int(cal.rounded()),
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
            servingGrams: grams,
            confidenceScore: item.confidence
        )
    }

    /// Build an IdentifiedFood from an estimated vision item with USDA/FNDDS lookup.
    private static func buildEstimatedFood(
        item: VisionIdentifiedItem,
        groupID: UUID?,
        mealName: String?,
        cookingMethod: CookingMethod?,
        plateSize: PlateSize
    ) async -> IdentifiedFood {
        // Determine effective cooking method: user-selected overrides, else use vision-detected
        let effectiveMethod = cookingMethod ?? CookingMethod.from(item.cooking_method)

        // Apply plate size scaling to portion grams if plate isn't medium (default)
        let scaledPortionGrams = item.portion_grams * plateSize.portionScale

        // Try FNDDS first for cooked foods (has prepared dish data), then fall back to FDC
        var result: USDAService.USDALookupResult?
        if effectiveMethod != nil && effectiveMethod != .raw {
            result = try? await USDAService.shared.lookupPreparedFood(for: item.name, cookingMethod: effectiveMethod).first
        }
        if result == nil {
            result = try? await USDAService.shared.lookupFood(for: item.name, cookingMethod: effectiveMethod)
        }

        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var detectedServings: Double = 1.0
        var calPer100g: Double?
        var protPer100g: Double?
        var carbPer100g: Double?
        var fatPer100g: Double?
        var srvGrams: Double?
        var usedSource: NutritionSource = .estimate

        if let nutrients = result?.nutrientsPer100g,
           nutrients.calories > 0 || nutrients.protein > 0 || nutrients.carbs > 0 || nutrients.fat > 0 {
            usedSource = .usda
            calPer100g = nutrients.calories
            protPer100g = nutrients.protein
            carbPer100g = nutrients.carbs
            fatPer100g = nutrients.fat

            if let servingGrams = result?.servingGrams, servingGrams > 0 {
                srvGrams = servingGrams
                detectedServings = max(0.25, ((scaledPortionGrams / servingGrams) * 4).rounded() / 4)
                let portionScale = scaledPortionGrams / 100.0
                calories = (nutrients.calories * portionScale)
                protein = (nutrients.protein * portionScale)
                carbs = (nutrients.carbs * portionScale)
                fat = (nutrients.fat * portionScale)
            } else {
                let scale = scaledPortionGrams / 100.0
                calories = nutrients.calories * scale
                protein = nutrients.protein * scale
                carbs = nutrients.carbs * scale
                fat = nutrients.fat * scale
            }
        } else {
            // USDA had no data — use focused text-based AI estimation
            if let aiResult = try? await VisionAPIService.shared.estimateNutrition(for: item.name) {
                if let sg = aiResult.servingGrams, sg > 0 {
                    srvGrams = sg
                    calPer100g = Double(aiResult.calories) * (100.0 / sg)
                    protPer100g = aiResult.proteinGrams * (100.0 / sg)
                    carbPer100g = aiResult.carbsGrams * (100.0 / sg)
                    fatPer100g = aiResult.fatGrams * (100.0 / sg)
                    let portionScale = scaledPortionGrams / sg
                    detectedServings = max(0.25, (portionScale * 4).rounded() / 4)
                    calories = Double(aiResult.calories) * portionScale
                    protein = aiResult.proteinGrams * portionScale
                    carbs = aiResult.carbsGrams * portionScale
                    fat = aiResult.fatGrams * portionScale
                } else {
                    calories = Double(aiResult.calories)
                    protein = aiResult.proteinGrams
                    carbs = aiResult.carbsGrams
                    fat = aiResult.fatGrams
                }
            } else {
                // Last resort: use vision inline estimates
                let rawCal = item.calories ?? 0
                let rawP = item.protein_grams ?? 0
                let rawC = item.carbs_grams ?? 0
                let rawF = item.fat_grams ?? 0
                let macroCalc = rawP * 4 + rawC * 4 + rawF * 9
                calories = rawCal > 0 ? rawCal : macroCalc
                protein = rawP
                carbs = rawC
                fat = rawF
            }
            usedSource = .estimate
        }

        // Enhanced sanity checking
        let sanitized = sanitizeNutrition(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            foodName: item.name,
            portionGrams: scaledPortionGrams
        )

        return IdentifiedFood(
            name: item.name.titleCased(),
            calories: sanitized.calories,
            proteinGrams: sanitized.protein,
            carbsGrams: sanitized.carbs,
            fatGrams: sanitized.fat,
            portionGrams: scaledPortionGrams,
            portionDescription: item.portion,
            source: usedSource,
            mealGroupID: groupID,
            mealName: mealName,
            caloriesPer100g: calPer100g,
            proteinPer100g: protPer100g,
            carbsPer100g: carbPer100g,
            fatPer100g: fatPer100g,
            servingGrams: srvGrams,
            servings: detectedServings,
            hiddenCaloriesEstimate: item.hidden_calories_estimate.map { Int($0.rounded()) },
            hiddenCaloriesSource: item.hidden_calories_source,
            confidenceScore: item.confidence,
            cookingMethod: item.cooking_method
        )
    }
}
