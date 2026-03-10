import Foundation
import UIKit

// MARK: - Unified Vision API Service

actor VisionAPIService {
    static let shared = VisionAPIService()

    // MARK: - Identify Foods (Image)

    func identifyFoods(in image: UIImage) async throws -> VisionFoodResponse {
        let provider = VisionProvider.selected
        guard let apiKey = KeychainService.load(account: provider.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        guard let jpegData = prepareImageForUpload(image) else {
            throw FoodAnalysisError.invalidImage
        }

        let base64Image = jpegData.base64EncodedString()
        let request = buildVisionRequest(provider: provider, apiKey: apiKey, base64Image: base64Image)
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

    func estimateNutrition(for foodName: String) async throws -> AIEstimateResult {
        let provider = VisionProvider.selected
        guard let apiKey = KeychainService.load(account: provider.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        let request = buildEstimateRequest(provider: provider, apiKey: apiKey, foodName: foodName)
        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("AI estimation failed. Please try again.")
        }

        let text = try extractText(from: data, provider: provider)
        return try decodeEstimateResponse(from: text)
    }

    // MARK: - Request Builders

    private func buildVisionRequest(provider: VisionProvider, apiKey: String, base64Image: String) -> URLRequest {
        let (url, headers, body) = switch provider {
        case .claude:
            (
                URL(string: "https://api.anthropic.com/v1/messages")!,
                [
                    "Content-Type": "application/json",
                    "x-api-key": apiKey,
                    "anthropic-version": "2023-06-01"
                ],
                claudeVisionBody(base64Image: base64Image)
            )
        case .gemini:
            (
                URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(AppConstants.API.geminiModel):generateContent")!,
                [
                    "Content-Type": "application/json",
                    "x-goog-api-key": apiKey
                ],
                geminiVisionBody(base64Image: base64Image)
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

    private func buildEstimateRequest(provider: VisionProvider, apiKey: String, foodName: String) -> URLRequest {
        let (url, headers, body) = switch provider {
        case .claude:
            (
                URL(string: "https://api.anthropic.com/v1/messages")!,
                [
                    "Content-Type": "application/json",
                    "x-api-key": apiKey,
                    "anthropic-version": "2023-06-01"
                ],
                claudeEstimateBody(foodName: foodName)
            )
        case .gemini:
            (
                URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(AppConstants.API.geminiModel):generateContent")!,
                [
                    "Content-Type": "application/json",
                    "x-goog-api-key": apiKey
                ],
                geminiEstimateBody(foodName: foodName)
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

    private func claudeVisionBody(base64Image: String) -> [String: Any] {
        [
            "model": AppConstants.API.claudeModel,
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
    }

    private func geminiVisionBody(base64Image: String) -> [String: Any] {
        [
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
    }

    private func claudeEstimateBody(foodName: String) -> [String: Any] {
        [
            "model": AppConstants.API.claudeModel,
            "max_tokens": 512,
            "system": "You are a nutrition estimation assistant. Always respond with valid JSON only.",
            "messages": [
                [
                    "role": "user",
                    "content": nutritionEstimatePrompt + foodName
                ]
            ]
        ]
    }

    private func geminiEstimateBody(foodName: String) -> [String: Any] {
        [
            "contents": [
                [
                    "parts": [
                        ["text": nutritionEstimatePrompt + foodName]
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

private let visionPrompt = """
Analyze every food item in this photo. For each item, determine which mode applies:

MODE 1 – NUTRITION LABEL VISIBLE: If you can see a nutrition facts label or printed nutritional information for an item, READ the exact values from the label. Use the brand/product name as-is (e.g. "David Protein Bar", not "protein bar"). Set "source": "label" and include the numeric values you read.

MODE 2 – NO LABEL: If there is no nutrition label visible for an item, identify it using simple, generic USDA database names. Drop cooking methods from names: use "garlic" not "sauteed garlic", "mushrooms" not "sauteed mushrooms", "beef tenderloin" not "pan-seared filet mignon", "asparagus" not "roasted asparagus". Estimate portion size. Set "source": "estimate". Include your best estimate for "calories", "protein_grams", "carbs_grams", and "fat_grams" but food name accuracy and portion size matter most.

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
