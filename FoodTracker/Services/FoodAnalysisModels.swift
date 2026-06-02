import Foundation

// MARK: - Nutrition Source

enum NutritionSource: String, Codable {
    case label
    case estimate
    case barcode
    case usda

    var displayLabel: String {
        switch self {
        case .label: return "From Label"
        case .estimate: return "AI Estimate"
        case .barcode: return "Barcode"
        case .usda: return "USDA"
        }
    }

    var badgeColor: String {
        switch self {
        case .label: return "green"
        case .estimate: return "orange"
        case .barcode: return "blue"
        case .usda: return "teal"
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

    // Accuracy enhancement fields (Phase 1)
    var hiddenCaloriesEstimate: Int?
    var hiddenCaloriesSource: String?
    var confidenceScore: Int?
    var cookingMethod: String?
}

// MARK: - Cooking Method

enum CookingMethod: String, CaseIterable, Identifiable {
    case raw = "Raw"
    case grilled = "Grilled"
    case fried = "Fried"
    case baked = "Baked"
    case steamed = "Steamed"
    case sauteed = "Sautéed"
    case roasted = "Roasted"
    case boiled = "Boiled"
    case airFried = "Air Fried"
    case other = "Other"

    var id: String { rawValue }

    var usdaQueryTerm: String {
        switch self {
        case .raw: return "raw"
        case .grilled: return "grilled"
        case .fried: return "fried"
        case .baked: return "baked"
        case .steamed: return "steamed"
        case .sauteed: return "sauteed"
        case .roasted: return "roasted"
        case .boiled: return "boiled"
        case .airFried: return "air fried"
        case .other: return ""
        }
    }

    var iconName: String {
        switch self {
        case .raw: return "leaf"
        case .grilled: return "flame"
        case .fried: return "drop.fill"
        case .baked: return "rectangle.inset.filled"
        case .steamed: return "cloud"
        case .sauteed: return "frying.pan"
        case .roasted: return "flame.fill"
        case .boiled: return "drop.circle"
        case .airFried: return "wind"
        case .other: return "ellipsis.circle"
        }
    }

    /// Attempts to match a string from the vision API to a CookingMethod.
    /// Checks longer terms first (e.g., "air fried" before "fried") to avoid false matches.
    static func from(_ string: String?) -> CookingMethod? {
        guard let string = string?.lowercased() else { return nil }
        // Sort by query term length descending so "air fried" matches before "fried"
        let sorted = allCases.filter { !$0.usdaQueryTerm.isEmpty }
            .sorted { $0.usdaQueryTerm.count > $1.usdaQueryTerm.count }
        return sorted.first { string.contains($0.usdaQueryTerm) }
    }
}

// MARK: - Plate Size

enum PlateSize: String, CaseIterable, Identifiable {
    case small = "Small ~8\""
    case medium = "Medium ~10\""
    case large = "Large ~12\""

    var id: String { rawValue }

    var diameterInches: Double {
        switch self {
        case .small: return 8
        case .medium: return 10.5
        case .large: return 12
        }
    }

    /// Scaling factor relative to a standard 10.5" dinner plate.
    /// Uses area-based scaling: food area scales with diameter squared.
    var portionScale: Double {
        let standardDiameter = 10.5
        return pow(diameterInches / standardDiameter, 2)
    }
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
    // Accuracy enhancement fields
    let hidden_calories_estimate: Double?
    let hidden_calories_source: String?
    let confidence: Int?
    let cooking_method: String?

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

