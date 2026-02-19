import Foundation

actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    private let baseURL = "https://world.openfoodfacts.org/api/v2/product"

    struct Product {
        let name: String
        let brand: String?
        let calories: Int
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        let servingSize: String
        let portionGrams: Double
    }

    enum LookupError: LocalizedError {
        case productNotFound
        case networkError(Error)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .productNotFound:
                return "Product not found in database."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Could not read product data."
            }
        }
    }

    func lookup(barcode: String) async throws -> Product {
        guard let url = URL(string: "\(baseURL)/\(barcode).json") else {
            throw LookupError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("FoodTracker iOS App", forHTTPHeaderField: "User-Agent")

        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw LookupError.productNotFound
            }
            data = responseData
        } catch let error as LookupError {
            throw error
        } catch {
            throw LookupError.networkError(error)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any] else {
            throw LookupError.productNotFound
        }

        let name = product["product_name"] as? String ?? "Unknown Product"
        let brand = product["brands"] as? String

        // Prefer per-serving nutriments, fall back to per-100g
        let nutriments = product["nutriments"] as? [String: Any] ?? [:]

        let hasServing = nutriments["energy-kcal_serving"] != nil
        let suffix = hasServing ? "_serving" : "_100g"

        let calories = asDouble(nutriments["energy-kcal\(suffix)"]) ?? 0
        let protein = asDouble(nutriments["proteins\(suffix)"]) ?? 0
        let carbs = asDouble(nutriments["carbohydrates\(suffix)"]) ?? 0
        let fat = asDouble(nutriments["fat\(suffix)"]) ?? 0

        let servingSize = product["serving_size"] as? String ?? (hasServing ? "1 serving" : "100g")
        let servingGrams = asDouble(product["serving_quantity"]) ?? (hasServing ? 0 : 100)

        let displayName: String
        if let brand, !brand.isEmpty {
            displayName = "\(brand) \(name)".titleCased()
        } else {
            displayName = name.titleCased()
        }

        return Product(
            name: displayName,
            brand: brand,
            calories: Int(calories),
            proteinGrams: (protein * 10).rounded() / 10,
            carbsGrams: (carbs * 10).rounded() / 10,
            fatGrams: (fat * 10).rounded() / 10,
            servingSize: servingSize,
            portionGrams: servingGrams
        )
    }

    private func asDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }
}
