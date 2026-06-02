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

func sanitizeNutrition(
    calories: Double,
    protein: Double,
    carbs: Double,
    fat: Double,
    foodName: String = "",
    portionGrams: Double = 0
) -> (calories: Int, protein: Double, carbs: Double, fat: Double) {
    let result = sanitizeNutritionWithTrace(
        calories: calories, protein: protein, carbs: carbs, fat: fat,
        foodName: foodName, portionGrams: portionGrams
    )
    return (result.calories, result.protein, result.carbs, result.fat)
}

func sanitizeNutritionWithTrace(
    calories: Double,
    protein: Double,
    carbs: Double,
    fat: Double,
    foodName: String = "",
    portionGrams: Double = 0
) -> (calories: Int, protein: Double, carbs: Double, fat: Double, heuristics: [String]) {
    var cal = calories
    var p = protein
    var c = carbs
    var f = fat
    var heuristics: [String] = []

    // 1. Derive calories from macros if zero
    let macroDerived = p * 4 + c * 4 + f * 9
    if cal == 0 && macroDerived > 0 {
        cal = macroDerived
        heuristics.append("macro-derived calories (original was 0)")
    }

    // 2. Macro-calorie consistency check
    if cal > 0 && macroDerived > 0 {
        let divergence = abs(cal - macroDerived) / max(cal, macroDerived)
        if divergence > 0.25 {
            heuristics.append("macro-calorie consistency (divergence: \(Int(divergence * 100))%, \(Int(cal))→\(Int(macroDerived)))")
            cal = macroDerived
        }
    }

    // 3. Physics-based calorie cap: impossible to exceed 9 cal/g (pure fat)
    if portionGrams > 0 {
        let physicsMax = portionGrams * 9
        if cal > physicsMax {
            let scale = physicsMax / cal
            heuristics.append("physics cap (\(Int(cal)) > \(Int(physicsMax)) max for \(Int(portionGrams))g)")
            cal = physicsMax
            p *= scale
            c *= scale
            f *= scale
        }
    }

    return (
        calories: Int(cal.rounded()),
        protein: p.roundedTo(1),
        carbs: c.roundedTo(1),
        fat: f.roundedTo(1),
        heuristics: heuristics
    )
}

// MARK: - Combined Analysis Pipeline

enum FoodAnalysisPipeline {
    /// Text-based nutrition estimation using the selected AI provider.
    static func estimateNutrition(for foodName: String) async throws -> USDAService.USDALookupResult {
        let estimate = try await VisionAPIService.shared.estimateNutrition(for: foodName)

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

    // MARK: - Analyze Image (with optional trace)

    static func analyzeImage(
        _ image: UIImage,
        cookingMethod: CookingMethod? = nil,
        plateSize: PlateSize = .medium
    ) async throws -> [IdentifiedFood] {
        let response = try await VisionAPIService.shared.identifyFoods(in: image, plateSize: plateSize)
        return try await processVisionResponse(response, cookingMethod: cookingMethod, plateSize: plateSize)
    }

    static func analyzeImageWithTrace(
        _ image: UIImage,
        cookingMethod: CookingMethod? = nil,
        plateSize: PlateSize = .medium
    ) async throws -> (foods: [IdentifiedFood], trace: PipelineTrace) {
        var trace = PipelineTrace()
        trace.visionProvider = VisionProvider.selected.rawValue
        trace.plateSize = plateSize.rawValue
        trace.cookingMethodSelection = cookingMethod?.rawValue

        let (response, rawText, prompt) = try await VisionAPIService.shared.identifyFoodsWithRawText(in: image, plateSize: plateSize)
        trace.rawVisionResponseText = rawText
        trace.visionPromptUsed = prompt
        populateVisionTrace(&trace, from: response)

        let (foods, foodTraces) = try await processVisionResponseWithTrace(response, cookingMethod: cookingMethod, plateSize: plateSize)
        trace.foodTraces = foodTraces
        trace.finalResults = foods.map { PipelineTrace.traceIdentifiedFood($0) }
        return (foods, trace)
    }

    static func analyzeImages(
        _ images: [UIImage],
        cookingMethod: CookingMethod? = nil,
        plateSize: PlateSize = .medium
    ) async throws -> [IdentifiedFood] {
        let response = try await VisionAPIService.shared.identifyFoods(images: images, plateSize: plateSize)
        return try await processVisionResponse(response, cookingMethod: cookingMethod, plateSize: plateSize)
    }

    static func analyzeImagesWithTrace(
        _ images: [UIImage],
        cookingMethod: CookingMethod? = nil,
        plateSize: PlateSize = .medium
    ) async throws -> (foods: [IdentifiedFood], trace: PipelineTrace) {
        var trace = PipelineTrace()
        trace.visionProvider = VisionProvider.selected.rawValue
        trace.plateSize = plateSize.rawValue
        trace.cookingMethodSelection = cookingMethod?.rawValue

        let (response, rawText, prompt) = try await VisionAPIService.shared.identifyFoodsWithRawText(images: images, plateSize: plateSize)
        trace.rawVisionResponseText = rawText
        trace.visionPromptUsed = prompt
        populateVisionTrace(&trace, from: response)

        let (foods, foodTraces) = try await processVisionResponseWithTrace(response, cookingMethod: cookingMethod, plateSize: plateSize)
        trace.foodTraces = foodTraces
        trace.finalResults = foods.map { PipelineTrace.traceIdentifiedFood($0) }
        return (foods, trace)
    }

    // MARK: - Process Vision Response

    static func processVisionResponse(
        _ response: VisionFoodResponse,
        cookingMethod: CookingMethod?,
        plateSize: PlateSize
    ) async throws -> [IdentifiedFood] {
        let (foods, _) = try await processVisionResponseInternal(response, cookingMethod: cookingMethod, plateSize: plateSize, collectTrace: false)
        return foods
    }

    static func processVisionResponseWithTrace(
        _ response: VisionFoodResponse,
        cookingMethod: CookingMethod?,
        plateSize: PlateSize
    ) async throws -> (foods: [IdentifiedFood], foodTraces: [PipelineTrace.FoodItemTrace]) {
        return try await processVisionResponseInternal(response, cookingMethod: cookingMethod, plateSize: plateSize, collectTrace: true)
    }

    private static func processVisionResponseInternal(
        _ response: VisionFoodResponse,
        cookingMethod: CookingMethod?,
        plateSize: PlateSize,
        collectTrace: Bool
    ) async throws -> (foods: [IdentifiedFood], foodTraces: [PipelineTrace.FoodItemTrace]) {
        var itemsWithGrouping: [(index: Int, item: VisionIdentifiedItem, mealGroupID: UUID?, mealName: String?)] = []
        var wholeDishResults: [UUID: USDAService.USDALookupResult] = [:]

        for element in response.foods {
            switch element {
            case .meal(let name, let ingredients):
                let groupID = UUID()
                let titleName = name.titleCased()
                for ingredient in ingredients {
                    itemsWithGrouping.append((index: itemsWithGrouping.count, item: ingredient, mealGroupID: groupID, mealName: titleName))
                }
                // Fix 1c: Try whole-dish FNDDS lookup before decomposing into ingredients
                if let fnddsResult = try? await USDAService.shared.lookupPreparedFood(for: name).first,
                   fnddsResult.nutrientsPer100g.calories > 0 {
                    wholeDishResults[groupID] = fnddsResult
                }
            case .standalone(let item):
                itemsWithGrouping.append((index: itemsWithGrouping.count, item: item, mealGroupID: nil, mealName: nil))
            }
        }

        // Fix 1g: Preserve insertion order by indexing tasks and sorting results
        var indexedResults: [(Int, IdentifiedFood, PipelineTrace.FoodItemTrace?)] = []

        await withTaskGroup(of: (Int, IdentifiedFood?, PipelineTrace.FoodItemTrace?).self) { group in
            for entry in itemsWithGrouping {
                let item = entry.item
                let groupID = entry.mealGroupID
                let mealName = entry.mealName
                let originalIndex = entry.index
                let shouldTrace = collectTrace

                // Fix 1c: If whole-dish FNDDS result exists for this meal group, use it
                let wholeDish = groupID.flatMap { wholeDishResults[$0] }

                group.addTask {
                    if item.hasLabelNutrition {
                        return (originalIndex, buildLabelFood(item: item, groupID: groupID, mealName: mealName), nil)
                    } else {
                        let (food, trace) = await buildEstimatedFood(
                            item: item,
                            groupID: groupID,
                            mealName: mealName,
                            cookingMethod: cookingMethod,
                            plateSize: plateSize,
                            collectTrace: shouldTrace,
                            wholeDishResult: wholeDish
                        )
                        return (originalIndex, food, trace)
                    }
                }
            }

            for await (index, food, trace) in group {
                if let food { indexedResults.append((index, food, trace)) }
            }
        }

        indexedResults.sort { $0.0 < $1.0 }
        let foods = indexedResults.map { $0.1 }
        let traces = indexedResults.compactMap { $0.2 }
        return (foods, traces)
    }

    // MARK: - Build Label Food

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

    // MARK: - Build Estimated Food (with optional trace)

    private static func buildEstimatedFood(
        item: VisionIdentifiedItem,
        groupID: UUID?,
        mealName: String?,
        cookingMethod: CookingMethod?,
        plateSize: PlateSize,
        collectTrace: Bool = false,
        wholeDishResult: USDAService.USDALookupResult? = nil
    ) async -> (IdentifiedFood, PipelineTrace.FoodItemTrace?) {
        let effectiveMethod = cookingMethod ?? CookingMethod.from(item.cooking_method)

        // Fix 1b: Area-based plate scaling instead of linear
        let scaledPortionGrams = item.portion_grams * plateSize.portionScale

        var foodTrace: PipelineTrace.FoodItemTrace?
        if collectTrace {
            foodTrace = PipelineTrace.FoodItemTrace(
                foodNameFromVision: item.name,
                portionFromVision: item.portion,
                portionGramsFromVision: item.portion_grams,
                scaledPortionGrams: scaledPortionGrams,
                confidenceScore: item.confidence,
                cookingMethodFromVision: item.cooking_method,
                effectiveCookingMethod: effectiveMethod?.rawValue,
                hiddenCaloriesEstimate: item.hidden_calories_estimate,
                hiddenCaloriesSource: item.hidden_calories_source
            )
        }

        // Fix 1c: Use whole-dish FNDDS result if available, otherwise per-ingredient lookup
        var result: USDAService.USDALookupResult? = wholeDishResult
        if result == nil, effectiveMethod != nil && effectiveMethod != .raw {
            if collectTrace {
                foodTrace?.fnddsAttempted = true
                let (fnddsResults, fnddsQueries) = (try? await USDAService.shared.lookupPreparedFoodWithTrace(for: item.name, cookingMethod: effectiveMethod)) ?? ([], [])
                foodTrace?.fnddsQueries = fnddsQueries
                result = fnddsResults.first
                if let r = result { foodTrace?.fnddsResult = PipelineTrace.traceUSDAResult(r) }
            } else {
                result = try? await USDAService.shared.lookupPreparedFood(for: item.name, cookingMethod: effectiveMethod).first
            }
        }
        if result == nil {
            if collectTrace {
                foodTrace?.fdcAttempted = true
                let (fdcResult, fdcQueries) = (try? await USDAService.shared.lookupFoodWithTrace(for: item.name, cookingMethod: effectiveMethod)) ?? (nil, [])
                foodTrace?.fdcQueries = fdcQueries
                result = fdcResult
                if let r = result { foodTrace?.fdcResult = PipelineTrace.traceUSDAResult(r) }
            } else {
                result = try? await USDAService.shared.lookupFood(for: item.name, cookingMethod: effectiveMethod)
            }
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

            // Fix 1a: Add hidden calories to USDA-derived totals
            if let hiddenCal = item.hidden_calories_estimate, hiddenCal > 0 {
                calories += hiddenCal
                fat += hiddenCal / 9.0
            }
        } else {
            // USDA had no data — use portion-aware AI estimation
            if let aiResult = try? await VisionAPIService.shared.estimateNutrition(for: item.name, portionGrams: scaledPortionGrams) {
                foodTrace?.aiEstimateFallbackUsed = true
                foodTrace?.aiEstimateResult = PipelineTrace.traceAIEstimate(aiResult)

                // AI was told the exact portion — use its values directly, no scaling
                calories = Double(aiResult.calories)
                protein = aiResult.proteinGrams
                carbs = aiResult.carbsGrams
                fat = aiResult.fatGrams

                if let sg = aiResult.servingGrams, sg > 0 {
                    srvGrams = sg
                    calPer100g = Double(aiResult.calories) * (100.0 / sg)
                    protPer100g = aiResult.proteinGrams * (100.0 / sg)
                    carbPer100g = aiResult.carbsGrams * (100.0 / sg)
                    fatPer100g = aiResult.fatGrams * (100.0 / sg)
                }
            } else {
                // Last resort: use vision inline estimates
                foodTrace?.visionInlineEstimatesUsed = true
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

        foodTrace?.finalSource = usedSource.rawValue

        // Sanitization with trace
        let sanitized: (calories: Int, protein: Double, carbs: Double, fat: Double)
        if collectTrace {
            foodTrace?.sanitizationInput = PipelineTrace.NutritionSnapshot(
                calories: calories, protein: protein, carbs: carbs, fat: fat, portionGrams: scaledPortionGrams
            )
            let traced = sanitizeNutritionWithTrace(
                calories: calories, protein: protein, carbs: carbs, fat: fat,
                foodName: item.name, portionGrams: scaledPortionGrams
            )
            sanitized = (traced.calories, traced.protein, traced.carbs, traced.fat)
            foodTrace?.sanitizationOutput = PipelineTrace.NutritionSnapshot(
                calories: Double(traced.calories), protein: traced.protein, carbs: traced.carbs, fat: traced.fat, portionGrams: scaledPortionGrams
            )
            foodTrace?.sanitizationHeuristicsFired = traced.heuristics
        } else {
            sanitized = sanitizeNutrition(
                calories: calories, protein: protein, carbs: carbs, fat: fat,
                foodName: item.name, portionGrams: scaledPortionGrams
            )
        }

        let food = IdentifiedFood(
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

        return (food, foodTrace)
    }

    // MARK: - Helpers

    private static func populateVisionTrace(_ trace: inout PipelineTrace, from response: VisionFoodResponse) {
        for element in response.foods {
            switch element {
            case .meal(let name, let ingredients):
                for item in ingredients {
                    trace.parsedVisionFoods.append(PipelineTrace.traceVisionItem(item, mealName: name))
                }
            case .standalone(let item):
                trace.parsedVisionFoods.append(PipelineTrace.traceVisionItem(item, mealName: nil))
            }
        }
    }
}
