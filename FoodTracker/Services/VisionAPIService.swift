import Foundation
import UIKit

// MARK: - Unified Vision API Service

actor VisionAPIService {
    static let shared = VisionAPIService()

    // MARK: - Identify Foods (Image)

    func identifyFoods(in image: UIImage, plateSize: PlateSize = .medium) async throws -> VisionFoodResponse {
        let provider = VisionProvider.selected
        guard let apiKey = KeychainService.load(account: provider.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        guard let jpegData = prepareImageForUpload(image) else {
            throw FoodAnalysisError.invalidImage
        }

        let base64Image = jpegData.base64EncodedString()
        let prompt = visionPrompt(plateSize: plateSize)
        let request = buildVisionRequest(provider: provider, apiKey: apiKey, base64Images: [base64Image], prompt: prompt)
        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("Analysis failed (HTTP \(httpResponse.statusCode)). Please try again.")
        }

        let text = try extractText(from: data, provider: provider)
        return try decodeVisionResponse(from: text)
    }

    func identifyFoodsWithRawText(in image: UIImage, plateSize: PlateSize = .medium) async throws -> (response: VisionFoodResponse, rawText: String, prompt: String) {
        let provider = VisionProvider.selected
        guard let apiKey = KeychainService.load(account: provider.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        guard let jpegData = prepareImageForUpload(image) else {
            throw FoodAnalysisError.invalidImage
        }

        let base64Image = jpegData.base64EncodedString()
        let prompt = visionPrompt(plateSize: plateSize)
        let request = buildVisionRequest(provider: provider, apiKey: apiKey, base64Images: [base64Image], prompt: prompt)
        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("Analysis failed (HTTP \(httpResponse.statusCode)). Please try again.")
        }

        let text = try extractText(from: data, provider: provider)
        let parsed = try decodeVisionResponse(from: text)
        return (response: parsed, rawText: text, prompt: prompt)
    }

    func identifyFoodsWithRawText(images: [UIImage], plateSize: PlateSize = .medium) async throws -> (response: VisionFoodResponse, rawText: String, prompt: String) {
        let provider = VisionProvider.selected
        guard let apiKey = KeychainService.load(account: provider.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        var base64Images: [String] = []
        for image in images {
            guard let jpegData = prepareImageForUpload(image) else {
                throw FoodAnalysisError.invalidImage
            }
            base64Images.append(jpegData.base64EncodedString())
        }

        let prompt = multiAngleVisionPrompt(plateSize: plateSize)
        let request = buildVisionRequest(provider: provider, apiKey: apiKey, base64Images: base64Images, prompt: prompt)
        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("Analysis failed (HTTP \(httpResponse.statusCode)). Please try again.")
        }

        let text = try extractText(from: data, provider: provider)
        let parsed = try decodeVisionResponse(from: text)
        return (response: parsed, rawText: text, prompt: prompt)
    }

    // MARK: - Identify Foods (Multi-Angle Precision Mode)

    func identifyFoods(images: [UIImage], plateSize: PlateSize = .medium) async throws -> VisionFoodResponse {
        let provider = VisionProvider.selected
        guard let apiKey = KeychainService.load(account: provider.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        var base64Images: [String] = []
        for image in images {
            guard let jpegData = prepareImageForUpload(image) else {
                throw FoodAnalysisError.invalidImage
            }
            base64Images.append(jpegData.base64EncodedString())
        }

        let prompt = multiAngleVisionPrompt(plateSize: plateSize)
        let request = buildVisionRequest(provider: provider, apiKey: apiKey, base64Images: base64Images, prompt: prompt)
        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("Analysis failed (HTTP \(httpResponse.statusCode)). Please try again.")
        }

        let text = try extractText(from: data, provider: provider)
        return try decodeVisionResponse(from: text)
    }

    // MARK: - Estimate Nutrition (Text)

    func estimateNutrition(for foodName: String, portionGrams: Double? = nil) async throws -> AIEstimateResult {
        let provider = VisionProvider.selected
        guard let apiKey = KeychainService.load(account: provider.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        let request = buildEstimateRequest(provider: provider, apiKey: apiKey, foodName: foodName, portionGrams: portionGrams)
        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("AI estimation failed. Please try again.")
        }

        let text = try extractText(from: data, provider: provider)
        return try decodeEstimateResponse(from: text)
    }

    // MARK: - Request Builders

    private func buildVisionRequest(provider: VisionProvider, apiKey: String, base64Images: [String], prompt: String) -> URLRequest {
        let (url, headers, body) = switch provider {
        case .claude:
            (
                URL(string: "https://api.anthropic.com/v1/messages")!,
                [
                    "Content-Type": "application/json",
                    "x-api-key": apiKey,
                    "anthropic-version": "2023-06-01"
                ],
                claudeVisionBody(base64Images: base64Images, prompt: prompt)
            )
        case .gemini:
            (
                URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(AppConstants.API.geminiModel):generateContent")!,
                [
                    "Content-Type": "application/json",
                    "x-goog-api-key": apiKey
                ],
                geminiVisionBody(base64Images: base64Images, prompt: prompt)
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildEstimateRequest(provider: VisionProvider, apiKey: String, foodName: String, portionGrams: Double? = nil) -> URLRequest {
        let prompt = nutritionEstimatePrompt(portionGrams: portionGrams) + foodName
        let (url, headers, body) = switch provider {
        case .claude:
            (
                URL(string: "https://api.anthropic.com/v1/messages")!,
                [
                    "Content-Type": "application/json",
                    "x-api-key": apiKey,
                    "anthropic-version": "2023-06-01"
                ],
                claudeEstimateBody(prompt: prompt)
            )
        case .gemini:
            (
                URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(AppConstants.API.geminiModel):generateContent")!,
                [
                    "Content-Type": "application/json",
                    "x-goog-api-key": apiKey
                ],
                geminiEstimateBody(prompt: prompt)
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Provider-Specific Bodies

    private func claudeVisionBody(base64Images: [String], prompt: String) -> [String: Any] {
        var contentBlocks: [[String: Any]] = []
        for base64Image in base64Images {
            contentBlocks.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64Image
                ]
            ])
        }
        contentBlocks.append([
            "type": "text",
            "text": prompt
        ])

        return [
            "model": AppConstants.API.claudeModel,
            "max_tokens": 4096,
            "system": "You are an expert food identification and nutrition estimation assistant. Analyze carefully, reason through portion sizes and hidden calories step by step, then respond with valid JSON.",
            "messages": [
                [
                    "role": "user",
                    "content": contentBlocks
                ]
            ]
        ]
    }

    private func geminiVisionBody(base64Images: [String], prompt: String) -> [String: Any] {
        var parts: [[String: Any]] = []
        for base64Image in base64Images {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": base64Image
                ]
            ])
        }
        parts.append(["text": prompt])

        return [
            "contents": [
                [
                    "parts": parts
                ]
            ]
        ]
    }

    private func claudeEstimateBody(prompt: String) -> [String: Any] {
        [
            "model": AppConstants.API.claudeModel,
            "max_tokens": 512,
            "system": "You are a nutrition estimation assistant. Always respond with valid JSON only.",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
    }

    private func geminiEstimateBody(prompt: String) -> [String: Any] {
        [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
    }

    // MARK: - Response Text Extraction

    private func extractText(from data: Data, provider: VisionProvider) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FoodAnalysisError.invalidResponse
        }

        switch provider {
        case .claude:
            guard let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String else {
                throw FoodAnalysisError.invalidResponse
            }
            return text

        case .gemini:
            guard let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                throw FoodAnalysisError.invalidResponse
            }
            return text
        }
    }

    // MARK: - Network

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw FoodAnalysisError.networkError(error)
        }
    }
}

// MARK: - Shared Prompts

func visionPrompt(plateSize: PlateSize = .medium) -> String {
    """
    Analyze every food item in this photo. For each item, determine which mode applies:

    MODE 1 – NUTRITION LABEL VISIBLE: If you can see a nutrition facts label or printed nutritional information, READ the exact values from the label. Use the brand/product name as-is. Set "source": "label".

    MODE 2 – NO LABEL: For each food without a label, reason through these steps before estimating:

    1. IDENTIFY: What specific food is this? Note the cooking method (grilled, fried, baked, steamed, sautéed, etc.)
    2. PLATE REFERENCE: The plate/bowl is approximately \(plateSize.diameterInches) inches in diameter. Use this as your size reference.
    3. VOLUME: Estimate the volume of each food item (cups, pieces, or dimensions in inches) relative to the plate.
    4. WEIGHT: Convert volume to weight in grams using food density. Be generous — people typically underestimate portions.
    5. COOKING METHOD: How does the cooking method affect nutrition?
       - Frying: food absorbs oil equal to ~10-15% of its weight
       - Sautéing: typically 1-2 tbsp oil added (120-240 cal)
       - Roasting with oil: typically 1-2 tbsp oil (120-240 cal)
       - Grilling: minimal added fat but some fat renders out
    6. HIDDEN CALORIES: Estimate ALL added fats, oils, butter, sauces, dressings not visible as separate items:
       - Oil sheen or pooling visible? → estimate tablespoons (1 tbsp oil = 120 cal)
       - Sauce, gravy, or dressing? → estimate amount and type
       - Cheese, cream, butter, mayo? → estimate amount
       - Breading or batter? → estimate flour + oil absorption
       Include these hidden calories IN the total calories field.
    7. NUTRITION: Calculate final per-portion nutrition. The calories field MUST include hidden calories from step 6.

    Use simple USDA-friendly base names (e.g., "chicken breast" not "pan-seared chicken"). Report the cooking method in "cooking_method" field.

    GROUPING: Multiple items → group under "meal_name" with "ingredients" array. Single item → standalone.

    After your reasoning, return valid JSON in this format:
    {"foods": [
      {"meal_name": "Steak Dinner", "ingredients": [
        {"name": "ribeye steak", "portion": "8 oz", "portion_grams": 227, "source": "estimate", "cooking_method": "grilled", "calories": 574, "protein_grams": 48, "carbs_grams": 0, "fat_grams": 40, "hidden_calories_estimate": 30, "hidden_calories_source": "grill butter baste", "confidence": 4},
        {"name": "mashed potatoes", "portion": "1 cup", "portion_grams": 210, "source": "estimate", "cooking_method": "boiled", "calories": 270, "protein_grams": 4, "carbs_grams": 35, "fat_grams": 12, "hidden_calories_estimate": 33, "hidden_calories_source": "butter and cream", "confidence": 3},
        {"name": "broccoli", "portion": "1 cup", "portion_grams": 156, "source": "estimate", "cooking_method": "steamed", "calories": 55, "protein_grams": 3.7, "carbs_grams": 11, "fat_grams": 0.6, "hidden_calories_estimate": 0, "hidden_calories_source": null, "confidence": 4}
      ]}
    ]}

    confidence: 1-5 scale (1=very uncertain, 5=very confident). Consider: is the food clearly visible? Can you tell the cooking method? Is the portion size easy to judge?
    """
}

func multiAngleVisionPrompt(plateSize: PlateSize = .medium) -> String {
    """
    You are provided with multiple photos of the SAME meal from different angles. Image 1 is typically top-down, and subsequent images are from the side or at an angle.

    Use ALL images together to improve your portion size and volume estimation:
    - Top-down view: reveals food spread/area on the plate
    - Side view: reveals food HEIGHT, pile depth, sauce pooling, and layering
    - Cross-reference views to estimate volume more accurately than either alone

    \(visionPrompt(plateSize: plateSize))
    """
}

func nutritionEstimatePrompt(portionGrams: Double? = nil) -> String {
    let portionContext: String
    if let grams = portionGrams, grams > 0 {
        portionContext = """
        IMPORTANT: The user has a specific portion of approximately \(Int(grams)) grams. \
        Estimate nutrition for exactly \(Int(grams))g of this food — do NOT estimate for a generic serving. \
        Set serving_grams to \(Int(grams)) and describe the portion accordingly.
        """
    } else {
        portionContext = "Provide your best estimate for a single standard serving."
    }

    return """
    Estimate the nutrition for this food item. \(portionContext)

    Reason step by step:
    1. What is this food and how is it typically prepared?
    2. What are the main macronutrient sources?
    3. If it's a prepared/cooked dish, what cooking fats, oils, sauces, or dressings are typically included?
    4. Calculate total nutrition including any hidden calories from cooking.\(portionGrams != nil ? "\n5. Scale all values to the specified \(Int(portionGrams!))g portion." : "")

    After reasoning, return valid JSON in this format:
    {"name": "Chicken Fajita", "serving_description": "1 fajita", "serving_grams": 220, "calories": 350, "protein_grams": 28, "carbs_grams": 26, "fat_grams": 14}

    Rules:
    - For prepared/cooked dishes, include ALL ingredients (cooking oil, sauces, etc.) in the nutrition total
    - Include a human-readable serving_description (e.g. "1 bowl", "1 plate", "1 sandwich", "1 cup")
    - Include serving_grams as the weight in grams of the portion you estimated
    - Be accurate — users depend on these values for dietary tracking
    - Err slightly high rather than low for calorie-dense prepared foods

    The food to estimate:
    """
}

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
private func prepareImageForUpload(_ image: UIImage, maxDimension: CGFloat = AppConstants.API.maxImageDimension, maxBytes: Int = AppConstants.API.maxImageBytes) -> Data? {
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

    for quality in stride(from: 0.8, through: 0.2, by: -0.1) {
        if let data = resized.jpegData(compressionQuality: quality), data.count <= maxBytes {
            return data
        }
    }
    return resized.jpegData(compressionQuality: 0.2)
}
