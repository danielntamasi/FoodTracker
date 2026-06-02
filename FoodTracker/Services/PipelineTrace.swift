import Foundation

struct PipelineTrace: Codable {
    var timestamp = Date()
    var visionProvider = ""
    var plateSize = ""
    var cookingMethodSelection: String?

    var visionPromptUsed = ""
    var rawVisionResponseText: String?
    var parsedVisionFoods: [VisionItemTrace] = []
    var visionError: String?

    var foodTraces: [FoodItemTrace] = []

    // MARK: - Per-Food Trace

    struct FoodItemTrace: Codable {
        var foodNameFromVision: String
        var portionFromVision: String
        var portionGramsFromVision: Double
        var scaledPortionGrams: Double
        var confidenceScore: Int?
        var cookingMethodFromVision: String?
        var effectiveCookingMethod: String?
        var hiddenCaloriesEstimate: Double?
        var hiddenCaloriesSource: String?

        var fnddsAttempted = false
        var fnddsQueries: [USDAQueryTrace] = []
        var fnddsResult: USDAResultTrace?

        var fdcAttempted = false
        var fdcQueries: [USDAQueryTrace] = []
        var fdcResult: USDAResultTrace?

        var aiEstimateFallbackUsed = false
        var aiEstimateResult: AIEstimateTrace?
        var visionInlineEstimatesUsed = false
        var finalSource = ""

        var sanitizationInput: NutritionSnapshot?
        var sanitizationOutput: NutritionSnapshot?
        var sanitizationHeuristicsFired: [String] = []
    }

    struct USDAQueryTrace: Codable {
        var query: String
        var dataType: String
        var resultCount: Int
        var topResults: [USDAResultTrace]
    }

    struct USDAResultTrace: Codable {
        var description: String
        var caloriesPer100g: Double
        var proteinPer100g: Double
        var carbsPer100g: Double
        var fatPer100g: Double
        var servingDescription: String?
        var servingGrams: Double?
    }

    struct AIEstimateTrace: Codable {
        var name: String
        var servingDescription: String?
        var servingGrams: Double?
        var calories: Int
        var proteinGrams: Double
        var carbsGrams: Double
        var fatGrams: Double
    }

    struct NutritionSnapshot: Codable {
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var portionGrams: Double
    }

    struct VisionItemTrace: Codable {
        var name: String
        var portion: String
        var portionGrams: Double
        var source: String?
        var calories: Double?
        var proteinGrams: Double?
        var carbsGrams: Double?
        var fatGrams: Double?
        var hiddenCaloriesEstimate: Double?
        var hiddenCaloriesSource: String?
        var confidence: Int?
        var cookingMethod: String?
        var mealName: String?
    }

    struct FoodResultTrace: Codable {
        var name: String
        var calories: Int
        var proteinGrams: Double
        var carbsGrams: Double
        var fatGrams: Double
        var portionGrams: Double
        var portionDescription: String
        var source: String
    }

    var finalResults: [FoodResultTrace] = []
}

// MARK: - Conversion Helpers

extension PipelineTrace {
    static func traceVisionItem(_ item: VisionIdentifiedItem, mealName: String?) -> VisionItemTrace {
        VisionItemTrace(
            name: item.name,
            portion: item.portion,
            portionGrams: item.portion_grams,
            source: item.source,
            calories: item.calories,
            proteinGrams: item.protein_grams,
            carbsGrams: item.carbs_grams,
            fatGrams: item.fat_grams,
            hiddenCaloriesEstimate: item.hidden_calories_estimate,
            hiddenCaloriesSource: item.hidden_calories_source,
            confidence: item.confidence,
            cookingMethod: item.cooking_method,
            mealName: mealName
        )
    }

    static func traceUSDAResult(_ result: USDAService.USDALookupResult) -> USDAResultTrace {
        USDAResultTrace(
            description: result.description,
            caloriesPer100g: result.nutrientsPer100g.calories,
            proteinPer100g: result.nutrientsPer100g.protein,
            carbsPer100g: result.nutrientsPer100g.carbs,
            fatPer100g: result.nutrientsPer100g.fat,
            servingDescription: result.servingDescription,
            servingGrams: result.servingGrams
        )
    }

    static func traceAIEstimate(_ result: AIEstimateResult) -> AIEstimateTrace {
        AIEstimateTrace(
            name: result.name,
            servingDescription: result.servingDescription,
            servingGrams: result.servingGrams,
            calories: result.calories,
            proteinGrams: result.proteinGrams,
            carbsGrams: result.carbsGrams,
            fatGrams: result.fatGrams
        )
    }

    static func traceIdentifiedFood(_ food: IdentifiedFood) -> FoodResultTrace {
        FoodResultTrace(
            name: food.name,
            calories: food.calories,
            proteinGrams: food.proteinGrams,
            carbsGrams: food.carbsGrams,
            fatGrams: food.fatGrams,
            portionGrams: food.portionGrams,
            portionDescription: food.portionDescription,
            source: food.source.rawValue
        )
    }
}
