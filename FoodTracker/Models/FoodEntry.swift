import Foundation
import SwiftData

/// Maps food name keywords to SF Symbol icons
private let iconMappings: [(keywords: [String], icon: String)] = [
    (["chicken", "turkey", "poultry"], "bird"),
    (["beef", "steak", "burger", "meat", "pork", "lamb", "bacon", "sausage"], "flame"),
    (["fish", "salmon", "tuna", "shrimp", "seafood", "sushi"], "fish"),
    (["egg"], "egg"),
    (["coffee", "espresso", "latte", "cappuccino"], "cup.and.saucer"),
    (["tea"], "cup.and.saucer"),
    (["milk", "yogurt", "cheese", "dairy"], "cup.and.saucer.fill"),
    (["water", "juice", "smoothie", "drink", "soda", "cola"], "waterbottle"),
    (["beer", "wine", "cocktail", "alcohol"], "wineglass"),
    (["bread", "toast", "bagel", "muffin", "croissant", "pastry", "cake", "cookie", "donut"], "birthday.cake"),
    (["rice", "noodle", "pasta", "ramen", "pho"], "takeoutbag.and.cup.and.straw"),
    (["pizza"], "triangle"),
    (["salad", "vegetable", "broccoli", "spinach", "kale", "lettuce", "greens"], "leaf"),
    (["fruit", "apple", "banana", "orange", "berry", "grape", "mango", "peach", "pear", "melon", "strawberry"], "carrot"),
    (["nut", "almond", "peanut", "walnut", "cashew"], "leaf.circle"),
    (["protein bar", "energy bar", "granola bar"], "chart.bar"),
    (["ice cream", "frozen"], "snowflake"),
    (["soup", "stew", "chili"], "flame"),
    (["sandwich", "wrap", "burrito", "taco"], "takeoutbag.and.cup.and.straw"),
    (["cereal", "oatmeal", "granola"], "bowl"),
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
        isGeneratedImage: Bool = false
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
    }
}
