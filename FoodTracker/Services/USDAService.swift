import Foundation

// MARK: - USDA FoodData Central Service

actor USDAService {
    static let shared = USDAService()

    private let baseURL = "https://api.nal.usda.gov/fdc/v1/foods/search"
    static let keychainAccount = AppConstants.Keychain.usdaAPIKey

    private var cachedAPIKey: String?

    private var apiKey: String {
        if let cached = cachedAPIKey { return cached }
        let key = KeychainService.load(account: Self.keychainAccount) ?? "DEMO_KEY"
        cachedAPIKey = key
        return key
    }

    func invalidateAPIKeyCache() {
        cachedAPIKey = nil
    }

    struct NutrientsPer100g {
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
    }

    struct USDALookupResult: Identifiable {
        let id = UUID()
        var description: String
        var nutrientsPer100g: NutrientsPer100g
        var servingDescription: String?
        var servingGrams: Double?

        /// Nutrients scaled to one serving (or per-100g if no serving info)
        var perServing: NutrientsPer100g {
            guard let grams = servingGrams, grams > 0 else { return nutrientsPer100g }
            let scale = grams / 100.0
            return NutrientsPer100g(
                calories: (nutrientsPer100g.calories * scale).roundedTo(1),
                protein: (nutrientsPer100g.protein * scale).roundedTo(1),
                carbs: (nutrientsPer100g.carbs * scale).roundedTo(1),
                fat: (nutrientsPer100g.fat * scale).roundedTo(1)
            )
        }
    }

    /// Looks up a food and returns the single best result.
    func lookupFood(for foodName: String) async throws -> USDALookupResult {
        let results = try await lookupFoodOptions(for: foodName)
        guard let first = results.first else {
            return USDALookupResult(description: foodName, nutrientsPer100g: NutrientsPer100g())
        }
        return first
    }

    /// Looks up a food and returns up to 5 scored/de-duped results with serving info.
    func lookupFoodOptions(for foodName: String) async throws -> [USDALookupResult] {
        // Clean query: strip parenthetical content and special chars that cause USDA API errors
        let cleanedName = foodName
            .replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let afterParens = cleanedName.isEmpty ? foodName : cleanedName

        // Strip cooking methods for better USDA matching
        let words = afterParens.split(separator: " ").map { String($0) }
        let stripped = words.filter { !Self.cookingMethods.contains($0.lowercased()) }
        let query = stripped.isEmpty ? afterParens : stripped.joined(separator: " ")

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "5"),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy")
        ]

        guard let url = components.url else {
            throw FoodAnalysisError.invalidResponse
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw FoodAnalysisError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.apiError("USDA: invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                let isDemo = KeychainService.load(account: Self.keychainAccount) == nil
                let hint = isDemo
                    ? "DEMO_KEY allows 30 requests/hour. Get a free key at fdc.nal.usda.gov/api-key-signup and add it in Settings."
                    : "Rate limit exceeded (1,000 requests/hour). Try again later."
                throw FoodAnalysisError.apiError("USDA rate limit exceeded. \(hint)")
            }
            throw FoodAnalysisError.apiError("USDA API error (HTTP \(httpResponse.statusCode))")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foods = json["foods"] as? [[String: Any]],
              !foods.isEmpty else {
            return []
        }

        let queryLower = query.lowercased()
        let penaltyKeywords = ["dried", "dehydrated", "powder", "concentrate", "canned", "juice", "frozen", "infant formula"]
        let sortedFoods = foods.sorted { a, b in
            scoreFood(a, query: queryLower, penaltyKeywords: penaltyKeywords) > scoreFood(b, query: queryLower, penaltyKeywords: penaltyKeywords)
        }

        var results: [USDALookupResult] = []
        for food in sortedFoods {
            let result = await buildResult(from: food, fallbackName: foodName)
            // Skip results with no nutrition data
            let per100g = result.nutrientsPer100g
            guard per100g.calories > 0 || per100g.protein > 0 || per100g.carbs > 0 || per100g.fat > 0 else { continue }
            results.append(result)
        }

        return results
    }

    /// Builds a USDALookupResult from a single USDA food JSON object, extracting nutrients and serving info.
    private func buildResult(from food: [String: Any], fallbackName: String) async -> USDALookupResult {
        var nutrients = NutrientsPer100g()
        if let foodNutrients = food["foodNutrients"] as? [[String: Any]] {
            for nutrient in foodNutrients {
                guard let nutrientId = nutrient["nutrientId"] as? Int,
                      let value = nutrient["value"] as? Double else { continue }
                switch nutrientId {
                case AppConstants.USDA.energyNutrientID: nutrients.calories = value
                case AppConstants.USDA.proteinNutrientID: nutrients.protein = value
                case AppConstants.USDA.carbsNutrientID: nutrients.carbs = value
                case AppConstants.USDA.fatNutrientID: nutrients.fat = value
                default: break
                }
            }
        }

        // Derive calories from macros if USDA entry is missing energy nutrient
        if nutrients.calories == 0 && (nutrients.protein > 0 || nutrients.carbs > 0 || nutrients.fat > 0) {
            nutrients.calories = (nutrients.protein * 4 + nutrients.carbs * 4 + nutrients.fat * 9).roundedTo(1)
        }

        let desc = food["description"] as? String ?? fallbackName
        var servingDesc: String?
        var servingGrams: Double?

        if let measures = food["foodMeasures"] as? [[String: Any]] {
            for measure in measures {
                guard let gramWeight = measure["gramWeight"] as? Double, gramWeight > 0,
                      let dissText = measure["disseminationText"] as? String,
                      !dissText.isEmpty,
                      !dissText.lowercased().contains("not specified") else { continue }
                servingDesc = dissText
                servingGrams = gramWeight
                break
            }
        }

        if servingGrams == nil,
           let size = food["servingSize"] as? Double, size > 0 {
            servingGrams = size
            let unit = food["servingSizeUnit"] as? String ?? "g"
            servingDesc = "1 serving (\(Int(size))\(unit))"
        }

        if servingGrams == nil, let fdcId = food["fdcId"] as? Int {
            if let portion = try? await fetchServingFromDetail(fdcId: fdcId) {
                servingDesc = portion.description
                servingGrams = portion.grams
            }
        }

        return USDALookupResult(
            description: desc,
            nutrientsPer100g: nutrients,
            servingDescription: servingDesc,
            servingGrams: servingGrams
        )
    }

    /// Fetches serving info from the USDA detail endpoint when the search results lack it.
    private func fetchServingFromDetail(fdcId: Int) async throws -> (description: String, grams: Double)? {
        let detailURL = "https://api.nal.usda.gov/fdc/v1/food/\(fdcId)"
        var components = URLComponents(string: detailURL)!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        guard let url = components.url else { return nil }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let portions = json["foodPortions"] as? [[String: Any]] else {
            return nil
        }

        for portion in portions {
            guard let gramWeight = portion["gramWeight"] as? Double, gramWeight > 0 else { continue }

            // Build a readable description from amount + unit + modifier
            let amount = portion["amount"] as? Double
            let unitName = (portion["measureUnit"] as? [String: Any])?["name"] as? String
            let modifier = portion["modifier"] as? String

            var parts: [String] = []
            if let amount, amount > 0 {
                parts.append(amount.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(amount))" : String(format: "%.1f", amount))
            }
            if let unitName, !unitName.isEmpty, unitName.lowercased() != "quantity not specified" {
                parts.append(unitName)
            }
            if let modifier, !modifier.isEmpty {
                parts.append("(\(modifier))")
            }

            let desc = parts.isEmpty ? "1 serving" : parts.joined(separator: " ")
            return (description: desc, grams: gramWeight)
        }
        return nil
    }

    private static let cookingMethods: Set<String> = [
        "sauteed", "sautéed", "grilled", "roasted", "baked", "fried",
        "steamed", "boiled", "braised", "broiled", "poached", "smoked",
        "pan-fried", "stir-fried", "deep-fried", "air-fried",
        "diced", "chopped", "sliced", "minced", "mashed", "pureed",
        "blanched", "charred", "toasted", "seasoned", "marinated",
        "glazed", "caramelized", "crispy", "creamy"
    ]

    private func scoreFood(_ food: [String: Any], query: String, penaltyKeywords: [String]) -> Int {
        let desc = (food["description"] as? String ?? "").lowercased()
        var score = 0

        // Only prefer "raw" if the query itself mentions it
        if query.contains("raw") && desc.contains("raw") { score += 5 }

        // Penalize processed/specialty forms
        for keyword in penaltyKeywords {
            if desc.contains(keyword) { score -= 5 }
        }

        // Bonus for exact query word match (all query words appear in description)
        let queryWords = query.split(separator: " ").map { String($0) }
        let allMatch = queryWords.allSatisfy { desc.contains($0) }
        if allMatch { score += 3 }

        // Prefer entries that include energy data
        if let foodNutrients = food["foodNutrients"] as? [[String: Any]] {
            let hasEnergy = foodNutrients.contains { ($0["nutrientId"] as? Int) == AppConstants.USDA.energyNutrientID }
            if hasEnergy { score += 2 }
        }

        return score
    }

}
