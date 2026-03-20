import Foundation

enum AppConstants {
    enum API {
        static let claudeModel = "claude-sonnet-4-6"
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
    }
}
