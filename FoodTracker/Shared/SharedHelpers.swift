import SwiftUI
import SwiftData

// MARK: - Shared Defaults

let sharedDefaults = UserDefaults(suiteName: appGroupID)!

// MARK: - Format Servings

func formatServings(_ value: Double) -> String {
    let whole = Int(value)
    let frac = value - Double(whole)
    let fracStr: String?
    if abs(frac - 0.25) < 0.001 { fracStr = "\u{00BC}" }
    else if abs(frac - 0.5) < 0.001 { fracStr = "\u{00BD}" }
    else if abs(frac - 0.75) < 0.001 { fracStr = "\u{00BE}" }
    else if abs(frac) < 0.001 { fracStr = nil }
    else { return String(format: "%.2g", value) }

    if let f = fracStr {
        return whole > 0 ? "\(whole)\(f)" : f
    }
    return "\(whole)"
}

// MARK: - Serving Presets

let servingPresets: [Double] = stride(from: 0.25, through: 3.0, by: 0.25).map { $0 }

// MARK: - Macro Calorie Calculations

/// Protein calories (4 cal/g)
func proteinCalories(_ grams: Double) -> Double { grams * 4 }
/// Carb calories (4 cal/g)
func carbCalories(_ grams: Double) -> Double { grams * 4 }
/// Fat calories (9 cal/g)
func fatCalories(_ grams: Double) -> Double { grams * 9 }
/// Total macro-derived calories
func totalMacroCalories(protein: Double, carbs: Double, fat: Double) -> Double {
    proteinCalories(protein) + carbCalories(carbs) + fatCalories(fat)
}

/// Macro percentages as (protein%, carbs%, fat%) — all zero if total is zero
func macroPercentages(protein: Double, carbs: Double, fat: Double) -> (protein: Int, carbs: Int, fat: Int) {
    let total = totalMacroCalories(protein: protein, carbs: carbs, fat: fat)
    guard total > 0 else { return (0, 0, 0) }
    return (
        protein: Int((proteinCalories(protein) / total * 100).rounded()),
        carbs: Int((carbCalories(carbs) / total * 100).rounded()),
        fat: Int((fatCalories(fat) / total * 100).rounded())
    )
}

// MARK: - Format Macro

func formatMacro(_ value: Double) -> String {
    value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
}

// MARK: - Dominant Color Extraction

func dominantColor(from image: UIImage, colorScheme: ColorScheme) -> Color? {
    guard let cgImage = image.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    let sampleHeight = max(height / 5, 1)
    let yOffset = height - sampleHeight
    guard let cropped = cgImage.cropping(to: CGRect(x: 0, y: yOffset, width: width, height: sampleHeight)) else { return nil }

    let ciImage = CIImage(cgImage: cropped)
    let filter = CIFilter(name: "CIAreaAverage", parameters: [
        kCIInputImageKey: ciImage,
        kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
    ])
    guard let outputImage = filter?.outputImage else { return nil }

    var bitmap = [UInt8](repeating: 0, count: 4)
    let context = CIContext(options: [.workingColorSpace: kCFNull!])
    context.render(outputImage, toBitmap: &bitmap, rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8, colorSpace: nil)

    let r = Double(bitmap[0]) / 255.0
    let g = Double(bitmap[1]) / 255.0
    let b = Double(bitmap[2]) / 255.0
    let darkenFactor: Double = colorScheme == .dark ? 0.3 : 0.55
    return Color(red: r * darkenFactor, green: g * darkenFactor, blue: b * darkenFactor)
}

// MARK: - Icon Dark Color (for hero backgrounds)

func iconDarkColor(for iconName: String) -> Color {
    switch iconName {
    case "bird": return Color(red: 0.15, green: 0.10, blue: 0.05)
    case "flame": return Color(red: 0.21, green: 0.09, blue: 0.05)
    case "fish": return Color(red: 0.05, green: 0.15, blue: 0.15)
    case "egg": return Color(red: 0.22, green: 0.19, blue: 0.08)
    case "cup.and.saucer": return Color(red: 0.14, green: 0.09, blue: 0.05)
    case "cup.and.saucer.fill": return Color(red: 0.10, green: 0.15, blue: 0.20)
    case "waterbottle": return Color(red: 0.05, green: 0.15, blue: 0.18)
    case "wineglass": return Color(red: 0.15, green: 0.05, blue: 0.10)
    case "birthday.cake": return Color(red: 0.18, green: 0.08, blue: 0.12)
    case "takeoutbag.and.cup.and.straw": return Color(red: 0.20, green: 0.12, blue: 0.05)
    case "triangle": return Color(red: 0.22, green: 0.08, blue: 0.05)
    case "leaf": return Color(red: 0.05, green: 0.15, blue: 0.05)
    case "carrot": return Color(red: 0.24, green: 0.14, blue: 0.05)
    case "leaf.circle": return Color(red: 0.12, green: 0.15, blue: 0.08)
    case "chart.bar": return Color(red: 0.10, green: 0.12, blue: 0.18)
    case "snowflake": return Color(red: 0.12, green: 0.19, blue: 0.22)
    case "bowl": return Color(red: 0.20, green: 0.14, blue: 0.06)
    default: return Color(red: 0.12, green: 0.12, blue: 0.14)
    }
}

// MARK: - Quick Add Helpers

func quickAddEntry(_ entry: FoodEntry, into modelContext: ModelContext) {
    let newEntry = FoodEntry(
        name: entry.name,
        calories: entry.calories,
        proteinGrams: entry.proteinGrams,
        carbsGrams: entry.carbsGrams,
        fatGrams: entry.fatGrams,
        photoData: entry.photoData,
        iconName: entry.iconName ?? foodIconName(for: entry.name),
        servings: entry.servings
    )
    modelContext.insert(newEntry)
}

func quickAddMealGroup(_ entries: [FoodEntry], mealName: String?, into modelContext: ModelContext) {
    let newGroupID = UUID()
    for entry in entries {
        let newEntry = FoodEntry(
            name: entry.name,
            calories: entry.calories,
            proteinGrams: entry.proteinGrams,
            carbsGrams: entry.carbsGrams,
            fatGrams: entry.fatGrams,
            photoData: entry.photoData,
            mealGroupID: newGroupID,
            mealName: mealName,
            iconName: entry.iconName ?? foodIconName(for: entry.name),
            servings: entry.servings
        )
        modelContext.insert(newEntry)
    }
}

// MARK: - DailyTarget Extension

extension DailyTarget {
    static var hasTargets: Bool {
        calories > 0 || protein > 0 || carbs > 0 || fat > 0
    }
}

// MARK: - Per-100g to Per-Serving Conversion

/// Converts per-100g nutrition values to per-serving values given serving weight in grams.
/// Returns (calories, protein, carbs, fat) scaled to one serving.
func perServingFromPer100g(
    calPer100g: Double, protPer100g: Double, carbsPer100g: Double, fatPer100g: Double,
    servingGrams: Double
) -> (calories: Int, protein: Double, carbs: Double, fat: Double) {
    let scale = servingGrams / 100.0
    return (
        calories: Int((calPer100g * scale).rounded()),
        protein: (protPer100g * scale * 10).rounded() / 10,
        carbs: (carbsPer100g * scale * 10).rounded() / 10,
        fat: (fatPer100g * scale * 10).rounded() / 10
    )
}
