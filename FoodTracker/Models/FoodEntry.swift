import Foundation
import SwiftData

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

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        date: Date = Date(),
        photoData: Data? = nil,
        notes: String = ""
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
    }
}
