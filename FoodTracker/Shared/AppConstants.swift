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
    }
}

enum ClaudeModel: String, CaseIterable, Identifiable {
    case opus48 = "claude-opus-4-8"
    case opus47 = "claude-opus-4-7"
    case opus46 = "claude-opus-4-6"
    case sonnet46 = "claude-sonnet-4-6"
    case haiku45 = "claude-haiku-4-5-20251001"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opus48: return "Opus 4.8"
        case .opus47: return "Opus 4.7"
        case .opus46: return "Opus 4.6"
        case .sonnet46: return "Sonnet 4.6"
        case .haiku45: return "Haiku 4.5"
        }
    }

    static var selected: ClaudeModel {
        get {
            if let raw = UserDefaults.standard.string(forKey: AppConstants.Defaults.claudeModel),
               let model = ClaudeModel(rawValue: raw) {
                return model
            }
            return .sonnet46
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: AppConstants.Defaults.claudeModel)
        }
    }
}
