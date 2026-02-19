import Foundation
import UIKit

struct IdentifiedFood: Codable, Identifiable {
    var id = UUID()
    var name: String
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var quantity: String

    enum CodingKeys: String, CodingKey {
        case name, calories, quantity
        case proteinGrams = "protein_g"
        case carbsGrams = "carbs_g"
        case fatGrams = "fat_g"
    }

    init(name: String, calories: Int, proteinGrams: Double, carbsGrams: Double, fatGrams: Double, quantity: String) {
        self.name = name
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.quantity = quantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.calories = try container.decode(Int.self, forKey: .calories)
        self.proteinGrams = try container.decode(Double.self, forKey: .proteinGrams)
        self.carbsGrams = try container.decode(Double.self, forKey: .carbsGrams)
        self.fatGrams = try container.decode(Double.self, forKey: .fatGrams)
        self.quantity = try container.decode(String.self, forKey: .quantity)
    }
}

struct FoodAnalysisResponse: Codable {
    let foods: [IdentifiedFood]
}

enum ClaudeAPIError: LocalizedError {
    case noAPIKey
    case invalidImage
    case networkError(Error)
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Claude API key in Settings."
        case .invalidImage:
            return "Could not process the image."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Could not parse Claude's response."
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"

    private let systemPrompt = """
    You are a food nutrition analyst. When shown a photo of food, identify each food item \
    and estimate its nutritional content. Return ONLY valid JSON with no additional text, \
    in this exact format:
    {"foods": [{"name": "Food Name", "calories": 350, "protein_g": 25.0, "carbs_g": 30.0, "fat_g": 12.0, "quantity": "1 serving"}]}
    Be as accurate as possible with your estimates. If you see multiple food items, \
    list each one separately. Use reasonable portion sizes.
    """

    func analyzeImage(_ image: UIImage) async throws -> [IdentifiedFood] {
        guard let apiKey = KeychainService.load(), !apiKey.isEmpty else {
            throw ClaudeAPIError.noAPIKey
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw ClaudeAPIError.invalidImage
        }

        let base64Image = jpegData.base64EncodedString()

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
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
                            "text": "Identify the food in this image and estimate the calories and macronutrients for each item."
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

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ClaudeAPIError.apiError(message)
            }
            throw ClaudeAPIError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse the Claude API response
        guard let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = responseJSON["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ClaudeAPIError.invalidResponse
        }

        // Extract JSON from the response text (Claude might wrap it in markdown code blocks)
        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeAPIError.invalidResponse
        }

        do {
            let analysisResponse = try JSONDecoder().decode(FoodAnalysisResponse.self, from: jsonData)
            return analysisResponse.foods
        } catch {
            throw ClaudeAPIError.invalidResponse
        }
    }

    private func extractJSON(from text: String) -> String {
        // Try to find JSON between code block markers
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
        // If no code blocks, try to find raw JSON
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text
    }
}
