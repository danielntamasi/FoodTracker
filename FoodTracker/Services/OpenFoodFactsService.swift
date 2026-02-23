import Foundation
import os

actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    private let baseURL = "https://world.openfoodfacts.org/api/v2/product"
    private static let writeURL = "https://world.openfoodfacts.org/cgi/product_jqm2.pl"

    // Keychain accounts for OFF app credentials
    static let keychainAccountUserID = "off-user-id"
    static let keychainAccountPassword = "off-password"

    private static let logger = Logger(subsystem: "com.DNT.foodtracker", category: "OpenFoodFacts")

    /// Stable per-device UUID for OFF moderation tracking
    private static var deviceUUID: String {
        let key = "off-device-uuid"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: key)
        return newUUID
    }

    struct CorrectionData {
        let barcode: String
        let caloriesPerServing: Int
        let proteinPerServing: Double
        let carbsPerServing: Double
        let fatPerServing: Double
    }

    struct Product {
        let name: String
        let brand: String?
        let calories: Int
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        let servingSize: String
        let portionGrams: Double
        // Per-100g values for portion recalculation
        let caloriesPer100g: Double
        let proteinPer100g: Double
        let carbsPer100g: Double
        let fatPer100g: Double
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
        guard var components = URLComponents(string: baseURL) else {
            throw LookupError.invalidResponse
        }
        components.path += "/\(barcode).json"
        guard let url = components.url else {
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

        // Always capture per-100g values for portion recalculation
        let calPer100g = asDouble(nutriments["energy-kcal_100g"]) ?? 0
        let protPer100g = asDouble(nutriments["proteins_100g"]) ?? 0
        let carbsPer100g = asDouble(nutriments["carbohydrates_100g"]) ?? 0
        let fatPer100g = asDouble(nutriments["fat_100g"]) ?? 0

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
            portionGrams: servingGrams,
            caloriesPer100g: calPer100g,
            proteinPer100g: protPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g
        )
    }

    // MARK: - Submit Correction

    /// Submits corrected nutrition data back to OpenFoodFacts. Fire-and-forget: errors are logged, never thrown.
    func submitCorrection(_ correction: CorrectionData) async {
        guard let userID = KeychainService.load(account: Self.keychainAccountUserID),
              let password = KeychainService.load(account: Self.keychainAccountPassword),
              !userID.isEmpty, !password.isEmpty else {
            Self.logger.info("OFF correction skipped — no credentials configured")
            return
        }

        guard let url = URL(string: Self.writeURL) else { return }

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "code", value: correction.barcode),
            URLQueryItem(name: "user_id", value: userID),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "nutrition_data_per", value: "serving"),
            URLQueryItem(name: "nutriment_energy-kcal", value: "\(correction.caloriesPerServing)"),
            URLQueryItem(name: "nutriment_proteins", value: String(format: "%.1f", correction.proteinPerServing)),
            URLQueryItem(name: "nutriment_carbohydrates", value: String(format: "%.1f", correction.carbsPerServing)),
            URLQueryItem(name: "nutriment_fat", value: String(format: "%.1f", correction.fatPerServing)),
            URLQueryItem(name: "app_name", value: "FoodTracker"),
            URLQueryItem(name: "app_version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"),
            URLQueryItem(name: "app_uuid", value: Self.deviceUUID),
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("FoodTracker iOS App", forHTTPHeaderField: "User-Agent")
        request.httpBody = bodyComponents.query?.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                Self.logger.info("OFF correction for \(correction.barcode): HTTP \(httpResponse.statusCode) — \(body)")
            }
        } catch {
            Self.logger.error("OFF correction failed for \(correction.barcode): \(error.localizedDescription)")
        }
    }

    private func asDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }
}
