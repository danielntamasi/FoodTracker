import Foundation

enum AppConstants {
    enum API {
        static let geminiModel = "gemini-2.0-flash"
        static let maxImageDimension: CGFloat = 1536
        static let maxImageBytes = 4_000_000
    }

    enum Keychain {
        static let claudeAPIKey = "claude-api-key"
        static let geminiAPIKey = "gemini-api-key"
        static let usdaAPIKey = "usda-api-key"
        static let offUserID = "off-user-id"
        static let offPassword = "off-password"
    }

    enum USDA {
        static let energyNutrientID = 1008
        static let proteinNutrientID = 1003
        static let carbsNutrientID = 1005
        static let fatNutrientID = 1004
    }

    enum Defaults {
        static let visionProvider = "visionProvider"
        static let reverseChronological = "reverseChronological"
        static let offDeviceUUID = "off-device-uuid"
        static let didMigrateNameCasing = "didMigrateEntryNameCasing"
        static let widgetCalories = "widgetCalories"
        static let widgetProtein = "widgetProtein"
        static let widgetCarbs = "widgetCarbs"
        static let widgetFat = "widgetFat"
        static let widgetLastSync = "widgetLastSync"
        static let favoriteFoodNames = "favoriteFoodNames"
        static let imagePlaygroundEnabled = "imagePlaygroundEnabled"
        static let appearanceMode = "appearanceMode"
        static let claudeModel = "claudeModel"
        static let claudeModelList = "claudeModelList"
    }
}

/// A Claude model the user can pick in Settings. The list comes from the Anthropic
/// Models API (cached in UserDefaults), falling back to `builtIn` until the first fetch.
struct ClaudeModel: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String

    var rawValue: String { id }

    static func == (lhs: ClaudeModel, rhs: ClaudeModel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let defaultID = "claude-sonnet-4-6"

    static let builtIn: [ClaudeModel] = [
        ClaudeModel(id: "claude-opus-4-8", displayName: "Opus 4.8"),
        ClaudeModel(id: "claude-opus-4-7", displayName: "Opus 4.7"),
        ClaudeModel(id: "claude-opus-4-6", displayName: "Opus 4.6"),
        ClaudeModel(id: "claude-sonnet-5-5", displayName: "Sonnet 5.5"),
        ClaudeModel(id: "claude-sonnet-4-6", displayName: "Sonnet 4.6"),
        ClaudeModel(id: "claude-haiku-4-5-20251001", displayName: "Haiku 4.5"),
    ]

    /// Models to offer in the picker: the last fetched list (or `builtIn`), always including the current selection.
    static var available: [ClaudeModel] {
        var models = builtIn
        if let data = UserDefaults.standard.data(forKey: AppConstants.Defaults.claudeModelList),
           let cached = try? JSONDecoder().decode([ClaudeModel].self, from: data),
           !cached.isEmpty {
            models = cached
        }
        let selectedID = UserDefaults.standard.string(forKey: AppConstants.Defaults.claudeModel) ?? defaultID
        if !models.contains(where: { $0.id == selectedID }) {
            models.append(ClaudeModel(id: selectedID, displayName: selectedID))
        }
        return models
    }

    static var selected: ClaudeModel {
        get {
            let id = UserDefaults.standard.string(forKey: AppConstants.Defaults.claudeModel) ?? defaultID
            return available.first { $0.id == id } ?? ClaudeModel(id: id, displayName: id)
        }
        set {
            UserDefaults.standard.set(newValue.id, forKey: AppConstants.Defaults.claudeModel)
        }
    }

    /// Fetches the models this API key can use (newest first) and caches them.
    /// Returns the updated picker list, or nil if there is no key or the request failed.
    static func refreshAvailable() async -> [ClaudeModel]? {
        guard let apiKey = KeychainService.load(account: AppConstants.Keychain.claudeAPIKey),
              !apiKey.isEmpty else {
            return nil
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=1000")!)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            return nil
        }

        let models: [ClaudeModel] = entries.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            return ClaudeModel(id: id, displayName: entry["display_name"] as? String ?? id)
        }
        guard !models.isEmpty, let encoded = try? JSONEncoder().encode(models) else {
            return nil
        }
        UserDefaults.standard.set(encoded, forKey: AppConstants.Defaults.claudeModelList)
        return available
    }
}
