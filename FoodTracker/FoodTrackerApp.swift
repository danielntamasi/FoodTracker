import SwiftUI
import SwiftData

// MARK: - Appearance Mode

/// Which side the + button sits on in the iOS 26 tab bar, so it's under the thumb.
enum Handedness: String, CaseIterable, Identifiable {
    case right, left
    var id: String { rawValue }

    var label: String {
        switch self {
        case .right: return "Right-handed"
        case .left: return "Left-handed"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static var current: AppearanceMode {
        let raw = sharedDefaults.string(forKey: AppConstants.Defaults.appearanceMode) ?? "system"
        return AppearanceMode(rawValue: raw) ?? .system
    }
}

@main
struct FoodTrackerApp: App {
    @AppStorage(AppConstants.Defaults.appearanceMode, store: sharedDefaults)
    private var appearanceMode: String = "system"
    @State private var showDatabaseAlert = false

    init() {
        sharedDefaults.register(defaults: [
            AppConstants.Defaults.imagePlaygroundEnabled: true
        ])
    }

    private var resolvedColorScheme: ColorScheme? {
        AppearanceMode(rawValue: appearanceMode)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedColorScheme)
                .tint(DS.Color.protein)
                .onAppear {
                    migrateEntryNames()
                    migrateEntryIcons()
                    if isUsingInMemoryStore { showDatabaseAlert = true }
                }
                .alert("Database Error", isPresented: $showDatabaseAlert) {
                    Button("Continue") { }
                } message: {
                    Text("Your data couldn't be loaded. The app is running with a temporary empty database. Your previous entries may still be recoverable — try restarting the app.")
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// One-time migration: title-case all existing food entry names for consistent capitalization.
    private func migrateEntryNames() {
        let key = AppConstants.Defaults.didMigrateNameCasing
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

    /// One-time migration: icons are stored per entry, so recompute them after the keyword list changes
    /// (meat no longer shows a flame, and egg/cereal pointed at symbols that don't exist).
    private func migrateEntryIcons() {
        let key = AppConstants.Defaults.didMigrateIconNames
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let context = sharedModelContainer.mainContext
        guard let entries = try? context.fetch(FetchDescriptor<FoodEntry>()) else { return }
        for entry in entries {
            let icon = foodIconName(for: entry.name)
            if entry.iconName != icon {
                entry.iconName = icon
            }
        }
    }
}
