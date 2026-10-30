import Foundation
import SwiftData

/// Maps food name keywords to SF Symbol icons
private let iconMappings: [(keywords: [String], icon: String)] = [
    (["chicken", "turkey", "poultry"], "bird"),
    (["beef", "steak", "burger", "meat", "pork", "lamb", "bacon", "sausage"], "frying.pan"),
    (["fish", "salmon", "tuna", "shrimp", "seafood", "sushi"], "fish"),
    // Before "egg" so "veggie" doesn't match it
    (["salad", "vegetable", "veggie", "broccoli", "spinach", "kale", "lettuce", "greens", "tomato", "cucumber"], "leaf"),
    (["egg"], "oval.portrait.fill"),
    (["coffee", "espresso", "latte", "cappuccino"], "cup.and.saucer"),
    (["tea"], "cup.and.saucer"),
    (["protein bar", "energy bar", "granola bar"], "bolt.fill"),
    (["milk", "yogurt", "cheese", "dairy"], "cup.and.saucer.fill"),
    (["water", "juice", "smoothie", "shake", "drink", "soda", "cola"], "waterbottle"),
    (["beer", "wine", "cocktail", "alcohol"], "wineglass"),
    (["bread", "toast", "bagel", "muffin", "croissant", "pastry", "cake", "cookie", "donut", "tortilla", "pretzel"], "birthday.cake"),
    (["rice", "noodle", "pasta", "ramen", "pho"], "takeoutbag.and.cup.and.straw"),
    (["pizza"], "triangle"),
    (["fruit", "apple", "banana", "orange", "berry", "berries", "grape", "mango", "peach", "pear", "melon", "strawberry"], "carrot"),
    (["nut", "almond", "peanut", "walnut", "cashew"], "leaf.circle"),
    (["ice cream", "frozen"], "snowflake"),
    (["soup", "stew", "chili"], "cup.and.heat.waves.fill"),
    (["sandwich", "wrap", "burrito", "taco"], "takeoutbag.and.cup.and.straw"),
    (["cereal", "oatmeal", "granola"], "sun.horizon"),
]

func foodIconName(for name: String) -> String {
    let lowered = name.lowercased()
    for mapping in iconMappings {
        for keyword in mapping.keywords {
            if lowered.contains(keyword) {
                return mapping.icon
            }
        }
    }
    return "fork.knife"
}

/// Where an entry's numbers came from. Used to track how far off the AI tools are.
enum EntrySource: String, Codable {
    case aiChatPhoto   // AI Chat, conversation included a photo
    case aiChatText    // AI Chat, text only
    case aiPhoto       // older one-shot photo analysis
    case barcode
    case aiEstimate    // Search / Add Entry "AI Estimate" (text only)
    case database      // USDA database result
    case manual        // typed in by hand
    case imported      // CSV import

    var isAI: Bool {
        switch self {
        case .aiChatPhoto, .aiChatText, .aiPhoto, .aiEstimate: return true
        case .barcode, .database, .manual, .imported: return false
        }
    }

    var label: String {
        switch self {
        case .aiChatPhoto: return "AI Chat (photo)"
        case .aiChatText: return "AI Chat (text)"
        case .aiPhoto: return "Photo analysis"
        case .barcode: return "Barcode"
        case .aiEstimate: return "AI estimate"
        case .database: return "USDA database"
        case .manual: return "Manual entry"
        case .imported: return "CSV import"
        }
    }
}

@Model
final class FoodEntry {
    var id: UUID
    var name: String
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var date: Date
    @Attribute(.externalStorage) var photoData: Data?
    var notes: String
    var mealGroupID: UUID?
    var mealName: String?
    var iconName: String?
    var sortOrder: Int?
    var servings: Double = 1.0
    var servingDescription: String?
    var servingGrams: Double?
    var barcode: String?
    var isGeneratedImage: Bool = false
    /// How the entry was created (`EntrySource` raw value); nil for entries made before this was tracked.
    var entrySource: String?
    /// Claude/Gemini model that produced the numbers, for AI-created entries.
    var aiModel: String?

    var totalCalories: Int { Int((Double(calories) * servings).rounded()) }
    var totalProteinGrams: Double { (proteinGrams * servings).roundedTo(1) }
    var totalCarbsGrams: Double { (carbsGrams * servings).roundedTo(1) }
    var totalFatGrams: Double { (fatGrams * servings).roundedTo(1) }

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        date: Date = Date(),
        photoData: Data? = nil,
        notes: String = "",
        mealGroupID: UUID? = nil,
        mealName: String? = nil,
        iconName: String? = nil,
        sortOrder: Int? = nil,
        servings: Double = 1.0,
        servingDescription: String? = nil,
        servingGrams: Double? = nil,
        barcode: String? = nil,
        isGeneratedImage: Bool = false,
        entrySource: EntrySource? = nil,
        aiModel: String? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.date = date
        self.photoData = photoData
        self.notes = notes
        self.mealGroupID = mealGroupID
        self.mealName = mealName
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.servings = servings
        self.servingDescription = servingDescription
        self.servingGrams = servingGrams
        self.barcode = barcode
        self.isGeneratedImage = isGeneratedImage
        self.entrySource = entrySource?.rawValue
        self.aiModel = aiModel
    }
}
