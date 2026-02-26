import Foundation
import UIKit

// MARK: - Shared prompt

private let visionPrompt = """
Analyze every food item in this photo. For each item, determine which mode applies:

MODE 1 – NUTRITION LABEL VISIBLE: If you can see a nutrition facts label or printed nutritional information for an item, READ the exact values from the label. Use the brand/product name as-is (e.g. "David Protein Bar", not "protein bar"). Set "source": "label" and include the numeric values you read.

MODE 2 – NO LABEL: If there is no nutrition label visible for an item, identify it using common USDA-compatible names (e.g. "white rice" not "steamed jasmine rice"). Estimate portion size. Set "source": "estimate". Include your best estimate for "calories", "protein_grams", "carbs_grams", and "fat_grams" based on the identified portion.

GROUPING: If there are multiple food items in the photo, ALWAYS group them under a single "meal_name" with an "ingredients" array. The meal_name should be a natural description of the whole plate or meal (e.g. "Steak with Sides", "Chicken and Vegetables", "Lunch Plate"). Only return a standalone item (without meal_name/ingredients) if there is literally one single food item in the entire photo.

Return ONLY valid JSON with no additional text, in this exact format:
{"foods": [
  {"meal_name": "Steak Dinner", "ingredients": [
    {"name": "ribeye steak", "portion": "8 oz", "portion_grams": 227, "source": "estimate", "calories": 544, "protein_grams": 48, "carbs_grams": 0, "fat_grams": 38},
    {"name": "mashed potatoes", "portion": "1 cup", "portion_grams": 210, "source": "estimate", "calories": 237, "protein_grams": 4, "carbs_grams": 35, "fat_grams": 9},
    {"name": "steamed broccoli", "portion": "1 cup", "portion_grams": 156, "source": "estimate", "calories": 55, "protein_grams": 3.7, "carbs_grams": 11, "fat_grams": 0.6}
  ]}
]}
"""

// MARK: - Text-based nutrition estimation prompt

private let nutritionEstimatePrompt = """
Estimate the nutrition for this food item. Provide your best estimate for a single standard serving.

Return ONLY valid JSON with no additional text, in this exact format:
{"name": "Chicken Fajita", "serving_description": "1 fajita", "serving_grams": 220, "calories": 350, "protein_grams": 28, "carbs_grams": 26, "fat_grams": 14}

Rules:
- Use a realistic standard serving size
- For prepared/cooked dishes, estimate the complete dish nutrition (all ingredients combined)
- Include a human-readable serving_description (e.g. "1 bowl", "1 plate", "1 sandwich", "1 cup")
- Include serving_grams as the approximate weight of that serving in grams
- Be accurate — users depend on these values for dietary tracking

The food to estimate:
"""

// MARK: - AI Nutrition Estimate Result

struct AIEstimateResult {
    let name: String
    let servingDescription: String?
    let servingGrams: Double?
    let calories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
}

private func decodeEstimateResponse(from text: String) throws -> AIEstimateResult {
    let jsonString = extractJSON(from: text)

    guard let data = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw FoodAnalysisError.apiError("Could not parse AI nutrition estimate.")
    }

    let name = json["name"] as? String ?? ""
    let servingDesc = json["serving_description"] as? String
    let servingGrams = json["serving_grams"] as? Double
    let calories = json["calories"] as? Double ?? 0
    let protein = json["protein_grams"] as? Double ?? 0
    let carbs = json["carbs_grams"] as? Double ?? 0
    let fat = json["fat_grams"] as? Double ?? 0

    return AIEstimateResult(
        name: name,
        servingDescription: servingDesc,
        servingGrams: servingGrams,
        calories: Int(calories),
        proteinGrams: protein,
        carbsGrams: carbs,
        fatGrams: fat
    )
}

// MARK: - Image Preparation

/// Resizes and compresses an image to stay under the API size limit (~4MB JPEG).
private func prepareImageForUpload(_ image: UIImage, maxDimension: CGFloat = 1536, maxBytes: Int = 4_000_000) -> Data? {
    // Step 1: Resize if larger than maxDimension
    let size = image.size
    let resized: UIImage
    if max(size.width, size.height) > maxDimension {
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    } else {
        resized = image
    }

    // Step 2: Compress, lowering quality until under maxBytes
    for quality in stride(from: 0.8, through: 0.2, by: -0.1) {
        if let data = resized.jpegData(compressionQuality: quality), data.count <= maxBytes {
            return data
        }
    }
    return resized.jpegData(compressionQuality: 0.2)
}

// MARK: - Claude Vision Service

actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"

    func identifyFoods(in image: UIImage) async throws -> VisionFoodResponse {
        guard let apiKey = KeychainService.load(account: VisionProvider.claude.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        guard let jpegData = prepareImageForUpload(image) else {
            throw FoodAnalysisError.invalidImage
        }

        let base64Image = jpegData.base64EncodedString()

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": "You are a food identification assistant. Always respond with valid JSON only.",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": visionPrompt
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("Analysis failed (HTTP \(httpResponse.statusCode)). Please try again.")
        }

        guard let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = responseJSON["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw FoodAnalysisError.invalidResponse
        }

        return try decodeVisionResponse(from: text)
    }

    func estimateNutrition(for foodName: String) async throws -> AIEstimateResult {
        guard let apiKey = KeychainService.load(account: VisionProvider.claude.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 512,
            "system": "You are a nutrition estimation assistant. Always respond with valid JSON only.",
            "messages": [
                [
                    "role": "user",
                    "content": nutritionEstimatePrompt + foodName
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("AI estimation failed. Please try again.")
        }

        guard let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = responseJSON["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw FoodAnalysisError.invalidResponse
        }

        return try decodeEstimateResponse(from: text)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw FoodAnalysisError.networkError(error)
        }
    }
}

// MARK: - Gemini Vision Service

actor GeminiAPIService {
    static let shared = GeminiAPIService()

    private let model = "gemini-2.0-flash"

    func identifyFoods(in image: UIImage) async throws -> VisionFoodResponse {
        guard let apiKey = KeychainService.load(account: VisionProvider.gemini.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        guard let jpegData = prepareImageForUpload(image) else {
            throw FoodAnalysisError.invalidImage
        }

        let base64Image = jpegData.base64EncodedString()
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": visionPrompt
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FoodAnalysisError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("Analysis failed (HTTP \(httpResponse.statusCode)). Please try again.")
        }

        guard let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = responseJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw FoodAnalysisError.invalidResponse
        }

        return try decodeVisionResponse(from: text)
    }
    func estimateNutrition(for foodName: String) async throws -> AIEstimateResult {
        guard let apiKey = KeychainService.load(account: VisionProvider.gemini.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": nutritionEstimatePrompt + foodName]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FoodAnalysisError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("AI estimation failed. Please try again.")
        }

        guard let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = responseJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw FoodAnalysisError.invalidResponse
        }

        return try decodeEstimateResponse(from: text)
    }
}

// MARK: - Shared JSON Parsing

private func decodeVisionResponse(from text: String) throws -> VisionFoodResponse {
    let jsonString = extractJSON(from: text)

    guard let jsonData = jsonString.data(using: .utf8) else {
        throw FoodAnalysisError.apiError("Response was not valid text.")
    }

    do {
        return try JSONDecoder().decode(VisionFoodResponse.self, from: jsonData)
    } catch is DecodingError {
        // Try a lenient fallback: strip trailing commas and retry
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

private func extractJSON(from text: String) -> String {
    // Handle ```json ... ``` (with optional whitespace/newlines)
    if let range = text.range(of: "```(?:json)?\\s*\n", options: .regularExpression) {
        let start = range.upperBound
        if let endRange = text.range(of: "\n\\s*```", options: .regularExpression, range: start..<text.endIndex) {
            return String(text[start..<endRange.lowerBound])
        }
    }
    // Fallback: extract outermost { ... }
    if let start = text.firstIndex(of: "{"),
       let end = text.lastIndex(of: "}") {
        return String(text[start...end])
    }
    return text
}

// MARK: - Combined Analysis Pipeline

enum FoodAnalysisPipeline {
    /// Text-based nutrition estimation using the selected AI provider.
    /// Returns a USDALookupResult-compatible result for use in search/add flows.
    static func estimateNutrition(for foodName: String) async throws -> USDAService.USDALookupResult {
        let estimate: AIEstimateResult
        switch VisionProvider.selected {
        case .claude:
            estimate = try await ClaudeAPIService.shared.estimateNutrition(for: foodName)
        case .gemini:
            estimate = try await GeminiAPIService.shared.estimateNutrition(for: foodName)
        }

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
        let response: VisionFoodResponse
        switch VisionProvider.selected {
        case .claude:
            response = try await ClaudeAPIService.shared.identifyFoods(in: image)
        case .gemini:
            response = try await GeminiAPIService.shared.identifyFoods(in: image)
        }

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
                        // Label items: title-case brand names for consistency
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
                        // Try USDA first (with better matching); fall back to AI-provided estimates
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
                                // Calculate how many servings the detected portion represents
                                srvGrams = servingGrams
                                detectedServings = (item.portion_grams / servingGrams * 100).rounded() / 100
                                // Per-serving values (scale per-100g by servingGrams/100)
                                let servingScale = servingGrams / 100.0
                                calories = Int((nutrients.calories * servingScale).rounded())
                                protein = (nutrients.protein * servingScale * 10).rounded() / 10
                                carbs = (nutrients.carbs * servingScale * 10).rounded() / 10
                                fat = (nutrients.fat * servingScale * 10).rounded() / 10
                            } else {
                                // No serving info — treat detected portion as 1 serving
                                let scale = item.portion_grams / 100.0
                                calories = Int(nutrients.calories * scale)
                                protein = (nutrients.protein * scale * 10).rounded() / 10
                                carbs = (nutrients.carbs * scale * 10).rounded() / 10
                                fat = (nutrients.fat * scale * 10).rounded() / 10
                            }
                        } else {
                            // Use AI-estimated values from the vision response
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
