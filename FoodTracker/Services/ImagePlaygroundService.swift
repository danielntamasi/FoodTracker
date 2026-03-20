import SwiftUI
import os

#if canImport(ImagePlayground)
import ImagePlayground
#endif

actor ImagePlaygroundService {
    static let shared = ImagePlaygroundService()
    private let logger = Logger(subsystem: "com.DNT.FoodTracker", category: "imagePlayground")

    /// Whether Image Playground is available on this device
    @MainActor
    static var isAvailable: Bool {
        #if canImport(ImagePlayground)
        if #available(iOS 18.4, *) {
            return ImagePlaygroundViewController.isAvailable
        }
        #endif
        return false
    }

    /// Whether the user has enabled generated food images
    static var isEnabled: Bool {
        get { sharedDefaults.bool(forKey: AppConstants.Defaults.imagePlaygroundEnabled) }
        set { sharedDefaults.set(newValue, forKey: AppConstants.Defaults.imagePlaygroundEnabled) }
    }

    /// Generate a food image using the animation style.
    /// Strips brand names and packaging-triggering words, then retries with
    /// progressively simplified names on `unsupportedLanguage`.
    func generateImage(for foodName: String) async -> Data? {
        #if canImport(ImagePlayground)
        guard #available(iOS 18.4, *) else { return nil }

        let cleaned = stripForPrompt(foodName)
        let namesToTry = [cleaned] + simplifiedNames(for: cleaned)
        logger.info("Generating image for: \(foodName) → prompt name: \(cleaned)")

        for (index, name) in namesToTry.enumerated() {
            let prompt = buildPrompt(for: name)
            if index > 0 {
                logger.info("Retrying with simplified name: \(name)")
            }
            do {
                let creator = try await ImageCreator()
                for try await createdImage in creator.images(for: [.text(prompt)], style: .animation, limit: 1) {
                    let cg = createdImage.cgImage
                    logger.info("Native image size: \(cg.width)x\(cg.height), bpp: \(cg.bitsPerPixel)")
                    let uiImage = UIImage(cgImage: cg)
                    if let pngData = uiImage.pngData() {
                        logger.info("Generated image for '\(name)' (\(pngData.count) bytes)")
                        return pngData
                    }
                }
            } catch let error as ImageCreator.Error where error == .unsupportedLanguage {
                logger.info("Unsupported language for '\(name)', will try simplified name")
                continue
            } catch {
                logger.warning("Image generation failed for '\(name)': \(error.localizedDescription)")
                return nil
            }
        }
        #endif
        return nil
    }

    /// Generate progressively simplified versions of a food name for retry.
    /// Strips parentheticals, then drops leading words (brand names tend to be prefixes).
    private func simplifiedNames(for name: String) -> [String] {
        let stripped = name.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        let words = stripped.split(separator: " ").map(String.init)
        guard words.count > 2 else { return [] }

        var results: [String] = []
        for drop in 1...min(2, words.count - 2) {
            let simplified = words.dropFirst(drop).joined(separator: " ")
            if simplified != name {
                results.append(simplified)
            }
        }
        return results
    }

    /// Words that trigger the model to draw packaging/containers with text labels.
    private static let packagingWords: Set<String> = [
        "bottle", "bottled", "box", "boxed", "can", "canned", "carton", "container",
        "cup", "jar", "jug", "pack", "package", "packaged", "packet", "pouch",
        "sachet", "tin", "tinned", "tub", "wrapper", "wrapped"
    ]

    /// Common food-related words. When we hit one of these while scanning from
    /// the left, we know the brand name has ended and the food description starts.
    private static let foodWords: Set<String> = [
        // proteins
        "chicken", "beef", "pork", "turkey", "salmon", "tuna", "shrimp", "fish",
        "egg", "eggs", "tofu", "tempeh", "steak", "lamb", "sausage", "bacon",
        "ham", "jerky", "venison", "bison", "duck", "crab", "lobster", "scallop",
        // dairy
        "milk", "cheese", "yogurt", "butter", "cream", "whey", "casein", "cottage",
        "mozzarella", "cheddar", "parmesan", "ricotta", "gouda", "brie", "feta",
        // grains & baked
        "bread", "rice", "pasta", "oat", "oats", "oatmeal", "wheat", "flour",
        "corn", "cereal", "granola", "bagel", "muffin", "tortilla", "wrap",
        "cracker", "pretzel", "waffle", "pancake", "croissant", "biscuit", "roll",
        // fruits
        "apple", "banana", "orange", "berry", "berries", "strawberry", "blueberry",
        "raspberry", "grape", "mango", "pineapple", "peach", "pear", "cherry",
        "lemon", "lime", "watermelon", "coconut", "avocado", "fig", "plum", "kiwi",
        // vegetables
        "broccoli", "spinach", "kale", "carrot", "potato", "tomato", "onion",
        "pepper", "cucumber", "lettuce", "celery", "mushroom", "garlic", "bean",
        "beans", "pea", "peas", "lentil", "lentils", "corn", "squash", "zucchini",
        "cauliflower", "cabbage", "asparagus", "artichoke", "beet", "radish",
        // nuts & seeds
        "almond", "peanut", "walnut", "cashew", "pecan", "pistachio", "hazelnut",
        "macadamia", "nut", "nuts", "seed", "seeds", "sunflower", "flax", "chia",
        // sweets & snacks
        "chocolate", "cocoa", "cookie", "brownie", "cake", "pie", "ice",
        "candy", "caramel", "vanilla", "honey", "maple", "sugar", "syrup",
        "chip", "chips", "popcorn", "trail",
        // beverages
        "coffee", "tea", "juice", "smoothie", "soda", "water", "lemonade",
        "matcha", "espresso", "kombucha", "cider",
        // prepared foods
        "soup", "stew", "chili", "curry", "salad", "sandwich", "burger", "pizza",
        "taco", "burrito", "sushi", "ramen", "noodle", "noodles", "dumpling",
        "falafel", "hummus", "guacamole", "salsa",
        // descriptors that indicate food content
        "protein", "collagen", "whey", "bar", "meal", "snack",
    ]

    /// Strip brand names (leading non-food words) and packaging-triggering words
    /// so the model draws the food itself, not a branded container.
    private func stripForPrompt(_ name: String) -> String {
        // Remove parentheticals
        var cleaned = name.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        // Remove packaging words
        let words = cleaned.split(separator: " ").map(String.init)
        let filtered = words.filter { !Self.packagingWords.contains($0.lowercased()) }
        if !filtered.isEmpty {
            cleaned = filtered.joined(separator: " ")
        }

        // Strip leading brand-name words by scanning until we hit a food word.
        // e.g. "Friendly Farms Oat Original Oat Milk" → "Oat Original Oat Milk"
        // e.g. "David Peanut Butter Chocolate Chunk Flavored Bar" → "Peanut Butter Chocolate Chunk Flavored Bar"
        let parts = cleaned.split(separator: " ").map(String.init)
        if parts.count > 2 {
            for (i, word) in parts.enumerated() {
                if Self.foodWords.contains(word.lowercased()) {
                    if i > 0 {
                        cleaned = parts[i...].joined(separator: " ")
                    }
                    break
                }
            }
        }

        return cleaned.isEmpty ? name : cleaned
    }

    private func buildPrompt(for foodName: String) -> String {
        "A close-up of \(foodName), fresh ingredients, appetizing, vibrant colors, clean simple background"
    }
}
