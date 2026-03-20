import SwiftUI
import SwiftData

// MARK: - Shared Defaults

let sharedDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

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

    if colorScheme == .dark {
        let factor = 0.3
        return Color(red: r * factor, green: g * factor, blue: b * factor)
    } else {
        // Light mode: blend toward white for a soft pastel background
        let blend = 0.85
        return Color(red: r + (1 - r) * blend, green: g + (1 - g) * blend, blue: b + (1 - b) * blend)
    }
}

// MARK: - Icon Hero Color (adaptive for hero backgrounds)

func iconHeroColor(for iconName: String) -> Color {
    // Adaptive: dark values (low range 0.05-0.24) for dark mode,
    // light pastels (high range 0.88-0.96) for light mode
    func adaptive(darkR: Double, darkG: Double, darkB: Double,
                  lightR: Double, lightG: Double, lightB: Double) -> Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: darkR, green: darkG, blue: darkB, alpha: 1)
            } else {
                return UIColor(red: lightR, green: lightG, blue: lightB, alpha: 1)
            }
        })
    }

    switch iconName {
    case "bird": return adaptive(darkR: 0.15, darkG: 0.10, darkB: 0.05, lightR: 0.95, lightG: 0.92, lightB: 0.88)
    case "flame": return adaptive(darkR: 0.21, darkG: 0.09, darkB: 0.05, lightR: 0.96, lightG: 0.90, lightB: 0.88)
    case "fish": return adaptive(darkR: 0.05, darkG: 0.15, darkB: 0.15, lightR: 0.88, lightG: 0.95, lightB: 0.95)
    case "egg": return adaptive(darkR: 0.22, darkG: 0.19, darkB: 0.08, lightR: 0.96, lightG: 0.95, lightB: 0.89)
    case "cup.and.saucer": return adaptive(darkR: 0.14, darkG: 0.09, darkB: 0.05, lightR: 0.94, lightG: 0.91, lightB: 0.88)
    case "cup.and.saucer.fill": return adaptive(darkR: 0.10, darkG: 0.15, darkB: 0.20, lightR: 0.90, lightG: 0.93, lightB: 0.96)
    case "waterbottle": return adaptive(darkR: 0.05, darkG: 0.15, darkB: 0.18, lightR: 0.88, lightG: 0.94, lightB: 0.96)
    case "wineglass": return adaptive(darkR: 0.15, darkG: 0.05, darkB: 0.10, lightR: 0.95, lightG: 0.88, lightB: 0.92)
    case "birthday.cake": return adaptive(darkR: 0.18, darkG: 0.08, darkB: 0.12, lightR: 0.96, lightG: 0.90, lightB: 0.93)
    case "takeoutbag.and.cup.and.straw": return adaptive(darkR: 0.20, darkG: 0.12, darkB: 0.05, lightR: 0.96, lightG: 0.92, lightB: 0.88)
    case "triangle": return adaptive(darkR: 0.22, darkG: 0.08, darkB: 0.05, lightR: 0.96, lightG: 0.90, lightB: 0.88)
    case "leaf": return adaptive(darkR: 0.05, darkG: 0.15, darkB: 0.05, lightR: 0.88, lightG: 0.95, lightB: 0.88)
    case "carrot": return adaptive(darkR: 0.24, darkG: 0.14, darkB: 0.05, lightR: 0.96, lightG: 0.93, lightB: 0.88)
    case "leaf.circle": return adaptive(darkR: 0.12, darkG: 0.15, darkB: 0.08, lightR: 0.92, lightG: 0.94, lightB: 0.89)
    case "chart.bar": return adaptive(darkR: 0.10, darkG: 0.12, darkB: 0.18, lightR: 0.91, lightG: 0.92, lightB: 0.95)
    case "snowflake": return adaptive(darkR: 0.12, darkG: 0.19, darkB: 0.22, lightR: 0.92, lightG: 0.95, lightB: 0.96)
    case "bowl": return adaptive(darkR: 0.20, darkG: 0.14, darkB: 0.06, lightR: 0.96, lightG: 0.93, lightB: 0.89)
    default: return adaptive(darkR: 0.12, darkG: 0.12, darkB: 0.14, lightR: 0.92, lightG: 0.92, lightB: 0.94)
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
        photoData: entry.isGeneratedImage ? nil : entry.photoData,
        iconName: entry.iconName ?? foodIconName(for: entry.name),
        servings: entry.servings,
        servingDescription: entry.servingDescription,
        servingGrams: entry.servingGrams
    )
    modelContext.insert(newEntry)
    Task { await HealthKitService.shared.syncEntry(newEntry) }
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
            photoData: entry.isGeneratedImage ? nil : entry.photoData,
            mealGroupID: newGroupID,
            mealName: mealName,
            iconName: entry.iconName ?? foodIconName(for: entry.name),
            servings: entry.servings,
            servingDescription: entry.servingDescription,
            servingGrams: entry.servingGrams
        )
        modelContext.insert(newEntry)
        Task { await HealthKitService.shared.syncEntry(newEntry) }
    }
}

// MARK: - DailyTarget Extension

extension DailyTarget {
    static var hasTargets: Bool {
        calories > 0 || protein > 0 || carbs > 0 || fat > 0
    }
}

// MARK: - Title Case Helper

extension String {
    /// Capitalizes the first letter of each word (e.g. "white rice" → "White Rice")
    func titleCased() -> String {
        self.lowercased()
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
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
        protein: (protPer100g * scale).roundedTo(1),
        carbs: (carbsPer100g * scale).roundedTo(1),
        fat: (fatPer100g * scale).roundedTo(1)
    )
}

// MARK: - Favorite Foods

enum FavoriteFoods {
    private static let key = AppConstants.Defaults.favoriteFoodNames

    private static var names: Set<String> {
        get { Set(sharedDefaults.stringArray(forKey: key) ?? []) }
        set { sharedDefaults.set(Array(newValue), forKey: key) }
    }

    static func isFavorite(_ name: String) -> Bool {
        names.contains(name.lowercased().trimmingCharacters(in: .whitespaces))
    }

    @discardableResult
    static func toggle(_ name: String) -> Bool {
        let canonical = name.lowercased().trimmingCharacters(in: .whitespaces)
        guard !canonical.isEmpty else { return false }
        var current = names
        if current.contains(canonical) {
            current.remove(canonical)
            names = current
            return false
        } else {
            current.insert(canonical)
            names = current
            return true
        }
    }
}
