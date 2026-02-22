import Foundation
import SwiftData

let appGroupID = "group.com.DNT.foodtracker"

/// Main app ModelContainer — uses the default location (Application Support).
/// Falls back to in-memory store if the persistent store can't be created (e.g. corrupted database).
let sharedModelContainer: ModelContainer = {
    let schema = Schema([FoodEntry.self])
    do {
        return try ModelContainer(for: schema)
    } catch {
        // Persistent store failed — fall back to in-memory so the app doesn't crash
        print("⚠️ Failed to create persistent ModelContainer: \(error.localizedDescription). Using in-memory store.")
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}()
