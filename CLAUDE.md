# FoodTracker

iOS calorie and macro tracking app. Users add food entries via photo (AI vision), barcode scanning, or manual input. The app shows daily summaries, macro breakdowns, and history.

## Tech Stack

- **Language:** Swift, SwiftUI
- **Data:** SwiftData (single `FoodEntry` model)
- **Min Target:** iOS 17+ (SwiftData requirement)
- **Build:** Xcode project (no SPM dependencies)
- **No tests** currently
- **Orientation:** Portrait only (locked)

## Project Structure

```
FoodTracker/
├── FoodTrackerApp.swift          # App entry point, shared ModelContainer, App Group migration
├── FoodTracker.entitlements      # App Group: group.com.DNT.foodtracker
├── Models/
│   └── FoodEntry.swift           # @Model + foodIconName() helper
├── Shared/
│   └── SharedConfig.swift        # appGroupID, sharedDefaults, sharedModelContainer
├── Services/
│   ├── FoodAnalysisService.swift  # Vision providers, USDA lookup, analysis pipeline, all service types
│   ├── KeychainService.swift      # Keychain wrapper for API key storage
│   └── OpenFoodFactsService.swift # Barcode → nutrition lookup via OpenFoodFacts API
└── Views/
    ├── ContentView.swift          # Root TabView: Today, History, Settings
    ├── DailySummaryView.swift     # Main screen: donut chart with "cal left", time-of-day sections, sort toggle, meal grouping
    ├── AddEntryView.swift         # Manual food entry form
    ├── EditEntryView.swift        # Edit existing entries with USDA lookup
    ├── PhotoCaptureView.swift     # Camera/photo picker → triggers PhotoAnalysisView
    ├── PhotoAnalysisView.swift    # Shows AI-identified foods, editable fields, save all; also used for barcode results
    ├── BarcodeScannerView.swift   # AVFoundation barcode camera + OpenFoodFacts lookup
    ├── HistoryView.swift          # Past entries grouped by date
    └── SettingsView.swift         # Vision provider picker, API key management, USDA key, daily targets

FoodTrackerWidget/
├── FoodTrackerWidget.swift                # WidgetKit extension: medium widget with donut chart + macro stats
├── FoodTrackerWidgetExtension.entitlements # App Group: group.com.DNT.foodtracker
├── Assets.xcassets/
└── Info.plist
```

## Architecture Notes

- **Single model:** `FoodEntry` is the only SwiftData model. Fields: `id`, `name`, `calories`, `proteinGrams`, `carbsGrams`, `fatGrams`, `date`, `photoData`, `mealGroupID`, `mealName`, `notes`, `iconName`, `sortOrder`. Meal grouping uses `mealGroupID` (shared UUID) + `mealName` fields, not relationships.
- **App Group:** `group.com.DNT.foodtracker` shared between main app and widget. `SharedConfig.swift` provides `appGroupID`, `sharedDefaults` (UserDefaults suite), and `sharedModelContainer` (SwiftData at shared URL). All UserDefaults access uses `sharedDefaults`. `FoodTrackerApp.init()` migrates legacy UserDefaults on first launch.
- **`foodIconName()`:** Free function in `FoodEntry.swift` that maps food names to SF Symbol icons via keyword matching.
- **Vision pipeline:** `FoodAnalysisPipeline.analyzeImage()` → vision provider identifies foods → USDA looks up macros (falls back to AI estimates). Defined in `FoodAnalysisService.swift`.
- **Two vision providers:** Claude Sonnet 4.6 and Gemini 2.0 Flash, selectable in Settings. Provider config (including keychain accounts) lives in `VisionProvider` enum. Service actors: `ClaudeAPIService`, `GeminiAPIService`.
- **USDA service:** `USDAService` actor uses a user-provided API key from Keychain (account: `usda-api-key`), falling back to `DEMO_KEY` if none set. Free keys available at fdc.nal.usda.gov/api-key-signup (1,000 req/hr vs 30/hr).
- **Barcode flow:** `BarcodeScannerView` → `OpenFoodFactsService` → presents results in `PhotoAnalysisView(foods:)`.
- **Photo flow:** `PhotoCaptureView` → captures image → `PhotoAnalysisView(image:)` → runs `FoodAnalysisPipeline`.
- **PhotoAnalysisView dual init:** `init(image:)` for photo analysis, `init(foods:)` for barcode/pre-resolved results.
- **DailySummaryView components:** `FoodEntryRow`, `MealEntryRow`, `MacroLabel`, `MacroDonutCard` (shows "X left/over"), `MacroProgressLabel`. Uses `TimeOfDay` enum for Morning/Afternoon/Evening sections and `EntryDisplayItem` enum for grouping logic. `groupedDisplayItems()` free function reused by `HistoryView`. Supports drag-to-reorder via `sortOrder` field. Reverse chronological toggle (arrow button) persisted in `sharedDefaults`.
- **Widget:** `FoodTrackerWidgetExtension` — `.systemMedium` widget showing donut chart with calories left + macro progress bars. Uses `TimelineProvider` that reads from shared SwiftData store and App Group UserDefaults. Refreshes every 30 min.
- **DailyTarget:** UserDefaults wrapper in `SettingsView.swift` for calorie/macro targets (uses `sharedDefaults`).
- **SourceBadge:** View in `PhotoAnalysisView.swift`.
- **User preferences** stored via App Group `UserDefaults` (vision provider, daily targets, sort order) and Keychain (API keys for vision providers and USDA).

## Conventions

- Commit messages: imperative mood, short description of change (e.g., "Fix photo capture not dismissing after saving food entries")
- No external dependencies — everything is built with Apple frameworks
- API keys are never hardcoded; stored in Keychain, entered via Settings
- **Always update CLAUDE.md before committing** to reflect any structural or architectural changes made during the session (new files, new model fields, new types, changed flows, etc.)

## Building

Open `FoodTracker.xcodeproj` in Xcode and build for iOS Simulator or device. Camera features require a physical device. The app requires `NSCameraUsageDescription` (set in Info.plist or Xcode target settings).

**Widget setup:** After opening the project, select both the FoodTracker and FoodTrackerWidgetExtension targets, go to Signing & Capabilities, and add the App Groups capability with identifier `group.com.DNT.foodtracker`.
