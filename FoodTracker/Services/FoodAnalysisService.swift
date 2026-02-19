import Foundation
import UIKit

struct IdentifiedFood: Identifiable {
    var id = UUID()
    var name: String
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var portionGrams: Double
    var portionDescription: String
}

// Gemini response model
struct GeminiIdentifiedItem: Codable {
    let name: String
    let portion: String
    let portion_grams: Double
}

struct GeminiFoodResponse: Codable {
    let foods: [GeminiIdentifiedItem]
}

enum FoodAnalysisError: LocalizedError {
    case noAPIKey
    case invalidImage
    case networkError(Error)
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Gemini API key in Settings."
        case .invalidImage:
            return "Could not process the image."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Could not parse the response."
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

// MARK: - Gemini Vision Service

actor GeminiAPIService {
    static let shared = GeminiAPIService()

    private let model = "gemini-2.0-flash"

    func identifyFoods(in image: UIImage) async throws -> [GeminiIdentifiedItem] {
        guard let apiKey = KeychainService.load(), !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw FoodAnalysisError.invalidImage
        }

        let base64Image = jpegData.base64EncodedString()
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!

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
                            "text": """
                            Identify every food item in this photo. For each item, estimate the portion size in grams.
                            Return ONLY valid JSON with no additional text, in this exact format:
                            {"foods": [{"name": "grilled chicken breast", "portion": "1 breast (6 oz)", "portion_grams": 170}]}
                            Use common, simple food names that would match USDA database searches (e.g. "white rice" not "steamed jasmine rice").
                            Be specific but concise. List each distinct food item separately.
                            """
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw FoodAnalysisError.apiError(message)
            }
            throw FoodAnalysisError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse Gemini response: candidates[0].content.parts[0].text
        guard let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = responseJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw FoodAnalysisError.invalidResponse
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw FoodAnalysisError.invalidResponse
        }

        do {
            let geminiResponse = try JSONDecoder().decode(GeminiFoodResponse.self, from: jsonData)
            return geminiResponse.foods
        } catch {
            throw FoodAnalysisError.invalidResponse
        }
    }

    private func extractJSON(from text: String) -> String {
        if let range = text.range(of: "```json\n") {
            let start = range.upperBound
            if let endRange = text.range(of: "\n```", range: start..<text.endIndex) {
                return String(text[start..<endRange.lowerBound])
            }
        }
        if let range = text.range(of: "```\n") {
            let start = range.upperBound
            if let endRange = text.range(of: "\n```", range: start..<text.endIndex) {
                return String(text[start..<endRange.lowerBound])
            }
        }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text
    }
}

// MARK: - USDA FoodData Central Service

actor USDAService {
    static let shared = USDAService()

    private let baseURL = "https://api.nal.usda.gov/fdc/v1/foods/search"
    private let apiKey = "DEMO_KEY"

    struct NutrientsPer100g {
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
    }

    func lookupNutrients(for foodName: String) async throws -> NutrientsPer100g {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: foodName),
            URLQueryItem(name: "pageSize", value: "1"),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy")
        ]

        guard let url = components.url else {
            throw FoodAnalysisError.invalidResponse
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw FoodAnalysisError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("USDA API error")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foods = json["foods"] as? [[String: Any]],
              let firstFood = foods.first,
              let nutrients = firstFood["foodNutrients"] as? [[String: Any]] else {
            return NutrientsPer100g() // Return zeroes if not found
        }

        var result = NutrientsPer100g()

        // USDA nutrient IDs: 1008=Energy(kcal), 1003=Protein, 1005=Carbs, 1004=Fat
        for nutrient in nutrients {
            guard let nutrientId = nutrient["nutrientId"] as? Int,
                  let value = nutrient["value"] as? Double else { continue }

            switch nutrientId {
            case 1008: result.calories = value
            case 1003: result.protein = value
            case 1005: result.carbs = value
            case 1004: result.fat = value
            default: break
            }
        }

        return result
    }
}

// MARK: - Combined Analysis Pipeline

enum FoodAnalysisPipeline {
    /// Gemini identifies foods → USDA looks up macros → returns combined results
    static func analyzeImage(_ image: UIImage) async throws -> [IdentifiedFood] {
        // Step 1: Gemini identifies foods and portions
        let geminiItems = try await GeminiAPIService.shared.identifyFoods(in: image)

        // Step 2: Look up each food in USDA for accurate macros
        var results: [IdentifiedFood] = []

        await withTaskGroup(of: IdentifiedFood?.self) { group in
            for item in geminiItems {
                group.addTask {
                    let nutrients = (try? await USDAService.shared.lookupNutrients(for: item.name))
                        ?? USDAService.NutrientsPer100g()

                    let scale = item.portion_grams / 100.0

                    return IdentifiedFood(
                        name: item.name,
                        calories: Int(nutrients.calories * scale),
                        proteinGrams: (nutrients.protein * scale * 10).rounded() / 10,
                        carbsGrams: (nutrients.carbs * scale * 10).rounded() / 10,
                        fatGrams: (nutrients.fat * scale * 10).rounded() / 10,
                        portionGrams: item.portion_grams,
                        portionDescription: item.portion
                    )
                }
            }

            for await food in group {
                if let food { results.append(food) }
            }
        }

        return results
    }
}
