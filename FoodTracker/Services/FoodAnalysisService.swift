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

    // Portion selection support (barcode + label items)
    // Per-100g base values for recalculating when servings change
    var caloriesPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    // The weight in grams of one serving
    var servingGrams: Double?
    // How many servings the user selected (default 1)
    var servings: Double = 1.0
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

        guard let jpegData = prepareImageForUpload(image) else {
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
        throw FoodAnalysisError.apiError("Response was not valid text.")
    }

    do {
        return try JSONDecoder().decode(VisionFoodResponse.self, from: jsonData)
    } catch let decodingError as DecodingError {
        // Try a lenient fallback: strip trailing commas and retry
        let cleaned = jsonString
            .replacingOccurrences(of: ",\\s*\\}", with: "}", options: .regularExpression)
            .replacingOccurrences(of: ",\\s*\\]", with: "]", options: .regularExpression)
        if let cleanedData = cleaned.data(using: .utf8),
           let result = try? JSONDecoder().decode(VisionFoodResponse.self, from: cleanedData) {
            return result
        }

        // Provide a meaningful error with context
        let detail: String
        switch decodingError {
        case .keyNotFound(let key, _):
            detail = "Missing key: \(key.stringValue)"
        case .typeMismatch(let type, let context):
            detail = "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let context):
            detail = "Missing value for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let context):
            detail = "Data corrupted: \(context.debugDescription)"
        @unknown default:
            detail = decodingError.localizedDescription
        }
        throw FoodAnalysisError.apiError("Could not parse AI response. \(detail)")
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

    struct USDALookupResult {
        var description: String
        var nutrientsPer100g: NutrientsPer100g
        var servingDescription: String?
        var servingGrams: Double?

        /// Nutrients scaled to one serving (or per-100g if no serving info)
        var perServing: NutrientsPer100g {
            guard let grams = servingGrams, grams > 0 else { return nutrientsPer100g }
            let scale = grams / 100.0
            return NutrientsPer100g(
                calories: (nutrientsPer100g.calories * scale * 10).rounded() / 10,
                protein: (nutrientsPer100g.protein * scale * 10).rounded() / 10,
                carbs: (nutrientsPer100g.carbs * scale * 10).rounded() / 10,
                fat: (nutrientsPer100g.fat * scale * 10).rounded() / 10
            )
        }
    }

    /// Looks up a food with better matching (prefers raw, penalizes dried/canned) and extracts serving info.
    func lookupFood(for foodName: String) async throws -> USDALookupResult {
        // Clean query: strip parenthetical content and special chars that cause USDA API errors
        let cleanedName = foodName
            .replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let query = cleanedName.isEmpty ? foodName : cleanedName

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "5"),
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
              !foods.isEmpty else {
            return USDALookupResult(description: foodName, nutrientsPer100g: NutrientsPer100g())
        }

        // Score each result: prefer "raw", penalize processed forms
        let penaltyKeywords = ["dried", "dehydrated", "powder", "concentrate", "canned", "juice", "frozen", "infant formula"]
        let bestFood = foods.max { a, b in
            scoreFood(a, penaltyKeywords: penaltyKeywords) < scoreFood(b, penaltyKeywords: penaltyKeywords)
        } ?? foods[0]

        // Extract nutrients
        var nutrients = NutrientsPer100g()
        if let foodNutrients = bestFood["foodNutrients"] as? [[String: Any]] {
            for nutrient in foodNutrients {
                guard let nutrientId = nutrient["nutrientId"] as? Int,
                      let value = nutrient["value"] as? Double else { continue }
                switch nutrientId {
                case 1008: nutrients.calories = value
                case 1003: nutrients.protein = value
                case 1005: nutrients.carbs = value
                case 1004: nutrients.fat = value
                default: break
                }
            }
        }

        // Extract serving info from foodMeasures
        let desc = bestFood["description"] as? String ?? foodName
        var servingDesc: String?
        var servingGrams: Double?

        if let measures = bestFood["foodMeasures"] as? [[String: Any]] {
            // Find a reasonable household measure (skip "Quantity not specified" and empty entries)
            for measure in measures {
                guard let gramWeight = measure["gramWeight"] as? Double, gramWeight > 0,
                      let dissText = measure["disseminationText"] as? String,
                      !dissText.isEmpty,
                      !dissText.lowercased().contains("not specified") else { continue }
                servingDesc = dissText
                servingGrams = gramWeight
                break
            }
        }

        // Fallback 1: use servingSize field from search results
        if servingGrams == nil,
           let size = bestFood["servingSize"] as? Double, size > 0 {
            servingGrams = size
            let unit = bestFood["servingSizeUnit"] as? String ?? "g"
            servingDesc = "1 serving (\(Int(size))\(unit))"
        }

        // Fallback 2: fetch detail endpoint for foodPortions
        if servingGrams == nil, let fdcId = bestFood["fdcId"] as? Int {
            if let portion = try? await fetchServingFromDetail(fdcId: fdcId) {
                servingDesc = portion.description
                servingGrams = portion.grams
            }
        }

        return USDALookupResult(
            description: desc,
            nutrientsPer100g: nutrients,
            servingDescription: servingDesc,
            servingGrams: servingGrams
        )
    }

    /// Fetches serving info from the USDA detail endpoint when the search results lack it.
    private func fetchServingFromDetail(fdcId: Int) async throws -> (description: String, grams: Double)? {
        let detailURL = "https://api.nal.usda.gov/fdc/v1/food/\(fdcId)"
        var components = URLComponents(string: detailURL)!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        guard let url = components.url else { return nil }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let portions = json["foodPortions"] as? [[String: Any]] else {
            return nil
        }

        for portion in portions {
            guard let gramWeight = portion["gramWeight"] as? Double, gramWeight > 0 else { continue }

            // Build a readable description from amount + unit + modifier
            let amount = portion["amount"] as? Double
            let unitName = (portion["measureUnit"] as? [String: Any])?["name"] as? String
            let modifier = portion["modifier"] as? String

            var parts: [String] = []
            if let amount, amount > 0 {
                parts.append(amount.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(amount))" : String(format: "%.1f", amount))
            }
            if let unitName, !unitName.isEmpty, unitName.lowercased() != "quantity not specified" {
                parts.append(unitName)
            }
            if let modifier, !modifier.isEmpty {
                parts.append("(\(modifier))")
            }

            let desc = parts.isEmpty ? "1 serving" : parts.joined(separator: " ")
            return (description: desc, grams: gramWeight)
        }
        return nil
    }

    private func scoreFood(_ food: [String: Any], penaltyKeywords: [String]) -> Int {
        let desc = (food["description"] as? String ?? "").lowercased()
        var score = 0
        if desc.contains("raw") { score += 10 }
        for keyword in penaltyKeywords {
            if desc.contains(keyword) { score -= 5 }
        }
        return score
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

                        if let nutrients = result?.nutrientsPer100g,
                           nutrients.calories > 0 || nutrients.protein > 0 || nutrients.carbs > 0 || nutrients.fat > 0 {
                            let scale = item.portion_grams / 100.0
                            calories = Int(nutrients.calories * scale)
                            protein = (nutrients.protein * scale * 10).rounded() / 10
                            carbs = (nutrients.carbs * scale * 10).rounded() / 10
                            fat = (nutrients.fat * scale * 10).rounded() / 10
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
