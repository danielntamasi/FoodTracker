import Foundation
import UIKit

// MARK: - Nutrition Source

enum NutritionSource: String, Codable {
    case label
    case estimate
    case barcode

    var displayLabel: String {
        switch self {
        case .label: return "From Label"
        case .estimate: return "AI Estimate"
        case .barcode: return "Barcode"
        }
    }

    var badgeColor: String {
        switch self {
        case .label: return "green"
        case .estimate: return "orange"
        case .barcode: return "blue"
        }
    }
}

struct IdentifiedFood: Identifiable {
    var id = UUID()
    var name: String
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var portionGrams: Double
    var portionDescription: String
    var source: NutritionSource = .estimate
    var mealGroupID: UUID?
    var mealName: String?
}

// MARK: - Vision Provider Selection

enum VisionProvider: String, CaseIterable, Identifiable {
    case claude = "Claude Sonnet 4.6"
    case gemini = "Gemini 2.0 Flash"

    var id: String { rawValue }

    var keychainAccount: String {
        switch self {
        case .claude: return "claude-api-key"
        case .gemini: return "gemini-api-key"
        }
    }

    var keyInstructions: String {
        switch self {
        case .claude: return "Get your key from console.anthropic.com"
        case .gemini: return "Get a free key from aistudio.google.com"
        }
    }

    static var selected: VisionProvider {
        get {
            if let raw = UserDefaults.standard.string(forKey: "visionProvider"),
               let provider = VisionProvider(rawValue: raw) {
                return provider
            }
            return .gemini
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "visionProvider")
        }
    }
}

// Vision response model (shared by both providers)
struct VisionIdentifiedItem: Codable {
    let name: String
    let portion: String
    let portion_grams: Double
    let source: String?
    let calories: Double?
    let protein_grams: Double?
    let carbs_grams: Double?
    let fat_grams: Double?

    var nutritionSource: NutritionSource {
        switch source {
        case "label": return .label
        default: return .estimate
        }
    }

    var hasLabelNutrition: Bool {
        source == "label" && calories != nil
    }
}

// Polymorphic element: either a grouped meal or a standalone item
enum VisionFoodElement: Codable {
    case meal(name: String, ingredients: [VisionIdentifiedItem])
    case standalone(VisionIdentifiedItem)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let mealName = try container.decodeIfPresent(String.self, forKey: .meal_name),
           let ingredients = try container.decodeIfPresent([VisionIdentifiedItem].self, forKey: .ingredients) {
            self = .meal(name: mealName, ingredients: ingredients)
        } else {
            let item = try VisionIdentifiedItem(from: decoder)
            self = .standalone(item)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .meal(let name, let ingredients):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .meal_name)
            try container.encode(ingredients, forKey: .ingredients)
        case .standalone(let item):
            try item.encode(to: encoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case meal_name, ingredients
    }
}

struct VisionFoodResponse: Codable {
    let foods: [VisionFoodElement]
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
            return "No API key configured. Please add your API key in Settings."
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

// MARK: - Shared prompt

private let visionPrompt = """
Analyze every food item in this photo. For each item, determine which mode applies:

MODE 1 – NUTRITION LABEL VISIBLE: If you can see a nutrition facts label or printed nutritional information for an item, READ the exact values from the label. Use the brand/product name as-is (e.g. "David Protein Bar", not "protein bar"). Set "source": "label" and include the numeric values you read.

MODE 2 – NO LABEL: If there is no nutrition label visible for an item, identify it using common USDA-compatible names (e.g. "white rice" not "steamed jasmine rice"). Estimate portion size. Set "source": "estimate". Include your best estimate for "calories", "protein_grams", "carbs_grams", and "fat_grams" based on the identified portion.

GROUPING: If multiple items are clearly part of one composite dish (e.g., bibimbap, burrito bowl, stir fry, pasta dish), group them under a "meal_name" with an "ingredients" array. Standalone items (a banana, a protein bar) should NOT be grouped.

Return ONLY valid JSON with no additional text, in this exact format:
{"foods": [
  {"meal_name": "Bibimbap", "ingredients": [
    {"name": "white rice", "portion": "1 cup", "portion_grams": 185, "source": "estimate", "calories": 240, "protein_grams": 4.4, "carbs_grams": 53, "fat_grams": 0.4},
    {"name": "fried egg", "portion": "1 large", "portion_grams": 46, "source": "estimate", "calories": 90, "protein_grams": 6.3, "carbs_grams": 0.4, "fat_grams": 7}
  ]},
  {"name": "David Protein Bar", "portion": "1 bar (50g)", "portion_grams": 50, "source": "label", "calories": 200, "protein_grams": 20, "carbs_grams": 22, "fat_grams": 7},
  {"name": "banana", "portion": "1 medium", "portion_grams": 118, "source": "estimate", "calories": 105, "protein_grams": 1.3, "carbs_grams": 27, "fat_grams": 0.4}
]}

A photo may contain a mix of grouped meals and standalone items.
"""

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

        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw FoodAnalysisError.invalidImage
        }

        let base64Image = jpegData.base64EncodedString()

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
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
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw FoodAnalysisError.apiError(message)
            }
            throw FoodAnalysisError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = responseJSON["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw FoodAnalysisError.invalidResponse
        }

        return try decodeVisionResponse(from: text)
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
                            "text": visionPrompt
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
}

// MARK: - Shared JSON Parsing

private func decodeVisionResponse(from text: String) throws -> VisionFoodResponse {
    let jsonString = extractJSON(from: text)

    guard let jsonData = jsonString.data(using: .utf8) else {
        throw FoodAnalysisError.invalidResponse
    }

    do {
        return try JSONDecoder().decode(VisionFoodResponse.self, from: jsonData)
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

// MARK: - USDA FoodData Central Service

actor USDAService {
    static let shared = USDAService()

    private let baseURL = "https://api.nal.usda.gov/fdc/v1/foods/search"
    static let keychainAccount = "usda-api-key"

    private var apiKey: String {
        KeychainService.load(account: Self.keychainAccount) ?? "DEMO_KEY"
    }

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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.apiError("USDA: invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                let isDemo = KeychainService.load(account: Self.keychainAccount) == nil
                let hint = isDemo
                    ? "DEMO_KEY allows 30 requests/hour. Get a free key at fdc.nal.usda.gov/api-key-signup and add it in Settings."
                    : "Rate limit exceeded (1,000 requests/hour). Try again later."
                throw FoodAnalysisError.apiError("USDA rate limit exceeded. \(hint)")
            }
            throw FoodAnalysisError.apiError("USDA API error (HTTP \(httpResponse.statusCode))")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foods = json["foods"] as? [[String: Any]],
              let firstFood = foods.first,
              let nutrients = firstFood["foodNutrients"] as? [[String: Any]] else {
            return NutrientsPer100g()
        }

        var result = NutrientsPer100g()

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

// MARK: - Title Case Helper

extension String {
    /// Capitalizes the first letter of each word (e.g. "white rice" → "White Rice")
    func titleCased() -> String {
        self.lowercased()
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

// MARK: - Combined Analysis Pipeline

enum FoodAnalysisPipeline {
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
                        // Label items: keep brand names as-is
                        return IdentifiedFood(
                            name: item.name,
                            calories: Int(item.calories ?? 0),
                            proteinGrams: item.protein_grams ?? 0,
                            carbsGrams: item.carbs_grams ?? 0,
                            fatGrams: item.fat_grams ?? 0,
                            portionGrams: item.portion_grams,
                            portionDescription: item.portion,
                            source: .label,
                            mealGroupID: groupID,
                            mealName: mealName
                        )
                    } else {
                        // Try USDA first; fall back to AI-provided estimates
                        let nutrients = try? await USDAService.shared.lookupNutrients(for: item.name)
                        let usdaHasData = nutrients != nil
                            && (nutrients!.calories > 0 || nutrients!.protein > 0
                                || nutrients!.carbs > 0 || nutrients!.fat > 0)

                        let calories: Int
                        let protein: Double
                        let carbs: Double
                        let fat: Double

                        if usdaHasData {
                            let scale = item.portion_grams / 100.0
                            calories = Int(nutrients!.calories * scale)
                            protein = (nutrients!.protein * scale * 10).rounded() / 10
                            carbs = (nutrients!.carbs * scale * 10).rounded() / 10
                            fat = (nutrients!.fat * scale * 10).rounded() / 10
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
                            mealName: mealName
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
