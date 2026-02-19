import Foundation
import SwiftData

let appGroupID = "group.com.DNT.foodtracker"

/// Main app ModelContainer — uses the default location (Application Support).
var sharedModelContainer: ModelContainer = {
    let schema = Schema([FoodEntry.self])
    return try! ModelContainer(for: schema)
}()
