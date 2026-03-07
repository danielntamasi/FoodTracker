import SwiftUI

@Observable
final class NutritionLookup {
    var isLookingUp = false
    var lookupError: String?
    var lookupResults: [USDAService.USDALookupResult] = []
    var selectedResultIndex: Int?
    var isEstimating = false
    var aiEstimate: USDAService.USDALookupResult?

    func lookupNutrition(for name: String) {
        isLookingUp = true
        lookupError = nil
        lookupResults = []
        selectedResultIndex = nil
        aiEstimate = nil

        Task { @MainActor in
            do {
                let results = try await USDAService.shared.lookupFoodOptions(for: name)
                withAnimation {
                    if results.isEmpty {
                        lookupError = "No nutrition data found for \"\(name)\"."
                    } else {
                        lookupResults = results
                    }
                }
            } catch {
                lookupError = error.localizedDescription
            }
            isLookingUp = false
        }
    }

    func runAIEstimate(for name: String) {
        isEstimating = true
        lookupError = nil

        Task { @MainActor in
            do {
                let result = try await FoodAnalysisPipeline.estimateNutrition(for: name)
                withAnimation {
                    aiEstimate = result
                }
            } catch {
                lookupError = error.localizedDescription
            }
            isEstimating = false
        }
    }

    func reset() {
        lookupError = nil
        lookupResults = []
        selectedResultIndex = nil
        aiEstimate = nil
    }
}
