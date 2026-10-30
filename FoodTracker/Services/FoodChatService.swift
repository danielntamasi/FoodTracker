import Foundation
import UIKit

// MARK: - Chat Models

/// The food log the assistant proposes at the end of a reply, parsed from its `<food_log>` block.
struct ChatFoodLog: Codable, Equatable {
    let meal_name: String?
    let items: [ChatFoodItem]

    var totalCalories: Int { Int(items.reduce(0) { $0 + $1.calories }.rounded()) }
    var totalProtein: Double { items.reduce(0) { $0 + $1.protein_grams } }
    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs_grams } }
    var totalFat: Double { items.reduce(0) { $0 + $1.fat_grams } }
}

/// One food in a proposed log. Nutrition values are totals for the portion eaten.
struct ChatFoodItem: Codable, Equatable {
    let name: String
    let portion: String?
    let portion_grams: Double?
    let calories: Double
    let protein_grams: Double
    let carbs_grams: Double
    let fat_grams: Double
}

struct FoodChatMessage: Identifiable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    /// Text shown in the bubble (assistant replies have the `<food_log>` block removed).
    let text: String
    /// Text sent back to the provider on later turns.
    let rawText: String
    var images: [UIImage] = []
    /// Upload-ready JPEGs matching `images`.
    var jpegs: [Data] = []
    var foodLog: ChatFoodLog?
}

/// Sendable snapshot of one conversation turn, as sent to the provider.
struct FoodChatTurn: Sendable {
    let isUser: Bool
    let text: String
    let jpegs: [Data]
}

/// Readable name for a stored model ID: provider, then model, then version, e.g.
/// "claude-sonnet-4-6" → "Claude Sonnet 4.6", "gemini-2.0-flash" → "Gemini Flash 2.0". Date suffixes are dropped.
func aiModelDisplayName(_ id: String) -> String {
    let parts = id.split(separator: "-").map(String.init)
    guard let provider = parts.first else { return id }
    var names: [String] = []
    var version: [String] = []
    for part in parts.dropFirst() {
        if part.allSatisfy(\.isNumber) && part.count >= 8 { continue } // release date
        if part.allSatisfy({ $0.isNumber || $0 == "." }) {
            version.append(part)
        } else {
            names.append(part.capitalized)
        }
    }
    return ([provider.capitalized] + names + (version.isEmpty ? [] : [version.joined(separator: ".")])).joined(separator: " ")
}

/// ID of the model the AI features currently use, recorded on AI-created entries.
func currentAIModelID() -> String {
    switch VisionProvider.selected {
    case .claude: return ClaudeModel.selected.rawValue
    case .gemini: return AppConstants.API.geminiModel
    }
}

// MARK: - Food Chat Service

enum FoodChatService {

    static let systemPrompt = """
    You are the food-logging assistant inside a calorie and macro tracking app. The user tells you what they ate, with photos, text, or both, and the two of you settle on what it was and how much of it, so it can be saved to their food log.

    How to work:
    - Look closely at any photos. Judge portions against plates, cutlery, hands, and packaging. When a nutrition label is visible, read its values exactly rather than estimating.
    - Count what isn't obvious: cooking oil, butter, sauces, dressings, cheese, breading. People underestimate these, and the log is only useful if the numbers are honest.
    - If something that would noticeably change the numbers is unclear (portion size, cooking method, what's inside), ask about it, one or two short questions at a time. For small things, make a sensible assumption and say what you assumed.
    - When the user gives a weight, use it exactly; a kitchen scale beats any estimate.
    - When the user gives a count of items whose size varies a lot (berries, nuts, shrimp, cookies, dumplings, wings), don't fall back on the smallest reference sizes from nutrition databases; use typical supermarket sizes, which are often double those. Say the per-item weight you assumed in your text (for example "assuming about 4 g per raspberry") and put the count and total weight in portion, so the user can correct it.
    - When the user corrects or adds something, update the estimate rather than defending the old one.
    - Keep replies short and conversational. This is a chat on a phone, and the app shows your text exactly as written, so use plain sentences without markdown.

    Proposing a log:
    Whenever you have enough to estimate, end your reply with your current best estimate inside a <food_log> block. The app hides the block and shows it to the user as a card with a "Log it" button. Only the user can save, by tapping that button, so don't say you've logged anything. Because the card already shows the items and numbers, don't repeat them in your text; a one-line summary is plenty. Send the complete, updated block every time the estimate changes. Leave it out only when you can't estimate yet.

    The block holds one JSON object:
    <food_log>{"meal_name": "Chicken Burrito Bowl", "items": [{"name": "grilled chicken breast", "portion": "5 oz", "portion_grams": 140, "calories": 231, "protein_grams": 43, "carbs_grams": 0, "fat_grams": 5}, {"name": "white rice", "portion": "1 cup", "portion_grams": 160, "calories": 205, "protein_grams": 4, "carbs_grams": 45, "fat_grams": 0.5}]}</food_log>

    - One item per distinct food. Use simple, recognizable names.
    - calories, protein_grams, carbs_grams, and fat_grams are totals for the portion the user actually ate, with hidden fats and sauces included.
    - meal_name names the dish or meal when there are several items; use null for a single item.
    """

    /// Sends the conversation so far and returns the assistant's raw reply text.
    /// `system` defaults to the food-logging prompt; feedback reports pass their own.
    static func reply(to turns: [FoodChatTurn], system: String = systemPrompt) async throws -> String {
        let provider = VisionProvider.selected
        guard let apiKey = KeychainService.load(account: provider.keychainAccount),
              !apiKey.isEmpty else {
            throw FoodAnalysisError.noAPIKey
        }

        let request = buildRequest(provider: provider, apiKey: apiKey, turns: limitingPhotos(turns), system: system)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FoodAnalysisError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let detail = errorDetail(from: data) ?? "Please try again."
            throw FoodAnalysisError.apiError("HTTP \(httpResponse.statusCode). \(detail)")
        }

        let text = try extractText(from: data, provider: provider)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw FoodAnalysisError.invalidResponse }
        return text
    }

    /// Splits a raw assistant reply into the text to display and the proposed food log, if any.
    static func parseReply(_ raw: String) -> (text: String, foodLog: ChatFoodLog?) {
        guard let open = raw.range(of: "<food_log>") else {
            return (raw, nil)
        }

        var display = String(raw[..<open.lowerBound])
        var foodLog: ChatFoodLog?
        if let close = raw.range(of: "</food_log>", range: open.upperBound..<raw.endIndex) {
            let json = extractJSON(from: String(raw[open.upperBound..<close.lowerBound]))
            if let data = json.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(ChatFoodLog.self, from: data),
               !decoded.items.isEmpty {
                foodLog = decoded
            }
            display += raw[close.upperBound...]
        }
        return (display.trimmingCharacters(in: .whitespacesAndNewlines), foodLog)
    }

    /// Photo bytes resent per request. 12 MB stays under Gemini's ~20 MB inline limit once base64-encoded.
    static let maxPhotoBytesPerRequest = 12_000_000

    /// Keeps the newest photos within `maxPhotoBytesPerRequest` and drops older ones, leaving a note in their place
    /// so the request stays sendable however long the conversation gets.
    static func limitingPhotos(_ turns: [FoodChatTurn]) -> [FoodChatTurn] {
        var budget = maxPhotoBytesPerRequest
        var limited: [FoodChatTurn] = []
        for turn in turns.reversed() {
            var kept: [Data] = []
            for jpeg in turn.jpegs.reversed() where jpeg.count <= budget {
                kept.insert(jpeg, at: 0)
                budget -= jpeg.count
            }
            let dropped = turn.jpegs.count - kept.count
            guard dropped > 0 else {
                limited.append(turn)
                continue
            }
            // Stop keeping photos once one is dropped, so older turns never keep photos newer ones lost
            budget = 0
            let note = "[\(dropped) earlier photo\(dropped == 1 ? "" : "s") no longer attached]"
            let text = turn.text.isEmpty ? note : note + "\n" + turn.text
            limited.append(FoodChatTurn(isUser: turn.isUser, text: text, jpegs: kept))
        }
        return limited.reversed()
    }

    // MARK: - Product Label Reading

    /// What the AI read off a product's packaging. Nutrition is per serving as printed on the label.
    struct ProductLabel: Decodable {
        var name: String?
        var brand: String?
        var serving_size: String?
        var serving_grams: Double?
        var calories: Double?
        var protein_grams: Double?
        var carbs_grams: Double?
        var fat_grams: Double?
    }

    static let productLabelPrompt = """
    You read packaged-food photos for a calorie tracking app: the front of the package and/or its nutrition facts panel. Reply with only one JSON object, no other text:
    {"name": "Protein Bar Red Velvet", "brand": "David", "serving_size": "1 bar", "serving_grams": 60, "calories": 150, "protein_grams": 28, "carbs_grams": 12, "fat_grams": 2}
    - name is the product name without the brand; brand is the brand. Read them from the package, don't guess.
    - Nutrition is per serving exactly as printed. If the panel only lists per 100 g, use serving_size "100 g" and serving_grams 100.
    - serving_grams is the gram (or ml) weight of one serving when the label states it.
    - Use null for anything you can't read in the photos.
    """

    /// Reads name, brand, serving and per-serving nutrition from photos of a product's packaging.
    static func readProductLabel(_ jpegs: [Data]) async throws -> ProductLabel {
        let raw = try await reply(
            to: [FoodChatTurn(isUser: true, text: "Read this product's packaging.", jpegs: jpegs)],
            system: productLabelPrompt
        )
        guard let data = extractJSON(from: raw).data(using: .utf8),
              let label = try? JSONDecoder().decode(ProductLabel.self, from: data) else {
            throw FoodAnalysisError.invalidResponse
        }
        return label
    }

    // MARK: - Request Builders

    private static func buildRequest(provider: VisionProvider, apiKey: String, turns: [FoodChatTurn], system: String) -> URLRequest {
        let (url, headers, body) = switch provider {
        case .claude:
            (
                URL(string: "https://api.anthropic.com/v1/messages")!,
                [
                    "Content-Type": "application/json",
                    "x-api-key": apiKey,
                    "anthropic-version": "2023-06-01"
                ],
                claudeBody(turns: turns, system: system)
            )
        case .gemini:
            (
                URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(AppConstants.API.geminiModel):generateContent")!,
                [
                    "Content-Type": "application/json",
                    "x-goog-api-key": apiKey
                ],
                geminiBody(turns: turns, system: system)
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func claudeBody(turns: [FoodChatTurn], system: String) -> [String: Any] {
        let messages: [[String: Any]] = turns.map { turn in
            var blocks: [[String: Any]] = turn.jpegs.map { jpeg in
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": jpeg.base64EncodedString()
                    ]
                ]
            }
            if !turn.text.isEmpty {
                blocks.append(["type": "text", "text": turn.text])
            }
            return ["role": turn.isUser ? "user" : "assistant", "content": blocks]
        }

        return [
            "model": ClaudeModel.selected.rawValue,
            "max_tokens": 8192,
            // The whole history (photos included) is resent every turn; cache the shared prefix.
            "cache_control": ["type": "ephemeral"],
            "system": system,
            "messages": messages
        ]
    }

    private static func geminiBody(turns: [FoodChatTurn], system: String) -> [String: Any] {
        let contents: [[String: Any]] = turns.map { turn in
            var parts: [[String: Any]] = turn.jpegs.map { jpeg in
                [
                    "inline_data": [
                        "mime_type": "image/jpeg",
                        "data": jpeg.base64EncodedString()
                    ]
                ]
            }
            if !turn.text.isEmpty {
                parts.append(["text": turn.text])
            }
            return ["role": turn.isUser ? "user" : "model", "parts": parts]
        }

        return [
            "system_instruction": ["parts": [["text": system]]],
            "contents": contents
        ]
    }

    // MARK: - Response Parsing

    private static func extractText(from data: Data, provider: VisionProvider) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FoodAnalysisError.invalidResponse
        }

        switch provider {
        case .claude:
            if json["stop_reason"] as? String == "refusal" {
                throw FoodAnalysisError.apiError("The assistant declined to answer that. Try rephrasing.")
            }
            guard let content = json["content"] as? [[String: Any]] else {
                throw FoodAnalysisError.invalidResponse
            }
            return content.compactMap { $0["text"] as? String }.joined()

        case .gemini:
            guard let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                throw FoodAnalysisError.invalidResponse
            }
            return parts.compactMap { $0["text"] as? String }.joined()
        }
    }

    /// Both providers return `{"error": {"message": ...}}` on failure.
    private static func errorDetail(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else {
            return nil
        }
        return error["message"] as? String
    }
}
