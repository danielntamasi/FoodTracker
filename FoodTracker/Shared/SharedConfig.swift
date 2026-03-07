import Foundation
import SwiftData
import os

let appGroupID = "group.com.DNT.foodtracker"

// MARK: - Rounding Helper

extension Double {
    /// Rounds to the specified number of decimal places.
    func roundedTo(_ places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}

private let logger = Logger(subsystem: "com.DNT.FoodTracker", category: "storage")

/// Main app ModelContainer — uses the default location (Application Support).
/// Falls back to in-memory store if the persistent store can't be created (e.g. corrupted database).
let sharedModelContainer: ModelContainer = {
    let schema = Schema([FoodEntry.self])
    do {
        return try ModelContainer(for: schema)
    } catch {
        // Persistent store failed — fall back to in-memory so the app doesn't crash
        logger.error("Failed to create persistent ModelContainer: \(error.localizedDescription). Using in-memory store.")
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create both persistent and in-memory ModelContainer: \(error.localizedDescription)")
        }
    }
}()
