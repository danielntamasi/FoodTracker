import SwiftUI
import SwiftData

@main
struct FoodTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { migrateEntryNames() }
        }
        .modelContainer(sharedModelContainer)
    }

    /// One-time migration: title-case all existing food entry names for consistent capitalization.
    private func migrateEntryNames() {
        let key = "didMigrateEntryNameCasing"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<FoodEntry>()
        guard let entries = try? context.fetch(descriptor) else { return }
        for entry in entries {
            let titleCased = entry.name.titleCased()
            if entry.name != titleCased {
                entry.name = titleCased
            }
            if let mealName = entry.mealName {
                let titleMeal = mealName.titleCased()
                if mealName != titleMeal {
                    entry.mealName = titleMeal
                }
            }
        }
    }
}
