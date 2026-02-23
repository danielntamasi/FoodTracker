import Foundation

// MARK: - USDA FoodData Central Service

actor USDAService {
    static let shared = USDAService()

    private let baseURL = "https://api.nal.usda.gov/fdc/v1/foods/search"
    static let keychainAccount = "usda-api-key"

    private var apiKey: String {
        KeychainService.load(account: Self.keychainAccount) ?? "DEMO_KEY"
    }

    struct NutrientsPer100g {
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
    }

    struct USDALookupResult {
        var description: String
        var nutrientsPer100g: NutrientsPer100g
        var servingDescription: String?
        var servingGrams: Double?

        /// Nutrients scaled to one serving (or per-100g if no serving info)
        var perServing: NutrientsPer100g {
            guard let grams = servingGrams, grams > 0 else { return nutrientsPer100g }
            let scale = grams / 100.0
            return NutrientsPer100g(
                calories: (nutrientsPer100g.calories * scale * 10).rounded() / 10,
                protein: (nutrientsPer100g.protein * scale * 10).rounded() / 10,
                carbs: (nutrientsPer100g.carbs * scale * 10).rounded() / 10,
                fat: (nutrientsPer100g.fat * scale * 10).rounded() / 10
            )
        }
    }

    /// Looks up a food with better matching (prefers raw, penalizes dried/canned) and extracts serving info.
    func lookupFood(for foodName: String) async throws -> USDALookupResult {
        // Clean query: strip parenthetical content and special chars that cause USDA API errors
        let cleanedName = foodName
            .replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let query = cleanedName.isEmpty ? foodName : cleanedName

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
            return USDALookupResult(description: foodName, nutrientsPer100g: NutrientsPer100g())
        }

        // Score each result: prefer "raw", penalize processed forms
        let penaltyKeywords = ["dried", "dehydrated", "powder", "concentrate", "canned", "juice", "frozen", "infant formula"]
        let bestFood = foods.max { a, b in
            scoreFood(a, penaltyKeywords: penaltyKeywords) < scoreFood(b, penaltyKeywords: penaltyKeywords)
        } ?? foods[0]

        // Extract nutrients
        var nutrients = NutrientsPer100g()
        if let foodNutrients = bestFood["foodNutrients"] as? [[String: Any]] {
            for nutrient in foodNutrients {
                guard let nutrientId = nutrient["nutrientId"] as? Int,
                      let value = nutrient["value"] as? Double else { continue }
                switch nutrientId {
                case 1008: nutrients.calories = value
                case 1003: nutrients.protein = value
                case 1005: nutrients.carbs = value
                case 1004: nutrients.fat = value
                default: break
                }
            }
        }

        // Extract serving info from foodMeasures
        let desc = bestFood["description"] as? String ?? foodName
        var servingDesc: String?
        var servingGrams: Double?

        if let measures = bestFood["foodMeasures"] as? [[String: Any]] {
            // Find a reasonable household measure (skip "Quantity not specified" and empty entries)
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

        // Fallback 1: use servingSize field from search results
        if servingGrams == nil,
           let size = bestFood["servingSize"] as? Double, size > 0 {
            servingGrams = size
            let unit = bestFood["servingSizeUnit"] as? String ?? "g"
            servingDesc = "1 serving (\(Int(size))\(unit))"
        }

        // Fallback 2: fetch detail endpoint for foodPortions
        if servingGrams == nil, let fdcId = bestFood["fdcId"] as? Int {
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

    private func scoreFood(_ food: [String: Any], penaltyKeywords: [String]) -> Int {
        let desc = (food["description"] as? String ?? "").lowercased()
        var score = 0
        if desc.contains("raw") { score += 10 }
        for keyword in penaltyKeywords {
            if desc.contains(keyword) { score -= 5 }
        }
        return score
    }

}
