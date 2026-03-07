import Foundation

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
    // Barcode string if this food came from a barcode scan
    var barcode: String?
}

// MARK: - Vision Provider Selection

enum VisionProvider: String, CaseIterable, Identifiable {
    case claude = "Claude Sonnet 4.6"
    case gemini = "Gemini 2.0 Flash"

    var id: String { rawValue }

    var keychainAccount: String {
        switch self {
        case .claude: return AppConstants.Keychain.claudeAPIKey
        case .gemini: return AppConstants.Keychain.geminiAPIKey
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
            if let raw = UserDefaults.standard.string(forKey: AppConstants.Defaults.visionProvider),
               let provider = VisionProvider(rawValue: raw) {
                return provider
            }
            return .gemini
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: AppConstants.Defaults.visionProvider)
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

