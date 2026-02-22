# FoodTracker — View Inventory

## Tab Views (main screens)

| View | File | Description |
|------|------|-------------|
| **ContentView** | `ContentView.swift` | Root — custom floating tab bar with radial arch menu (+), manages all sheet presentations |
| **DailySummaryView** | `DailySummaryView.swift` | "Today" tab — calorie/macro summary card (donut chart when targets set), food entries in Morning/Afternoon/Evening sections, drag-to-reorder |
| **HistoryView** | `HistoryView.swift` | "History" tab — past entries grouped by date (collapsible), performance tile (week/month/year adherence stats) |
| **SettingsView** | `SettingsView.swift` | "Settings" tab — vision provider picker, API keys (vision + USDA), daily targets |

## Entry Creation Sheets (launched from radial menu)

| View | File | Description |
|------|------|-------------|
| **AddEntryView** | `AddEntryView.swift` | Manual entry form — name, calories, macros, USDA lookup, serving multiplier (0.25–3x) |
| **PhotoCaptureView** | `PhotoCaptureView.swift` | Camera capture → hands off to PhotoAnalysisView |
| **PhotoUploadView** | *(in PhotoCaptureView.swift)* | Photo library picker → hands off to PhotoAnalysisView |
| **PhotoAnalysisView** | `PhotoAnalysisView.swift` | AI-identified foods list — editable names/macros, meal grouping, serving pickers for barcode items, Save All |
| **BarcodeScannerView** | `BarcodeScannerView.swift` | AVFoundation camera scanner → OpenFoodFacts lookup → presents results in PhotoAnalysisView |
| **BrowseFoodsView** | *(in ContentView.swift)* | Top 5 frequent + 10 recent unique foods — tap to quick-add |

## Detail/Edit Sheets (launched from entry rows)

| View | File | Description |
|------|------|-------------|
| **EditEntryView** | `EditEntryView.swift` | Immersive hero sheet — photo/icon gradient hero, read mode (name, metric pills, donut, daily goal bars), edit mode (form fields, USDA lookup, barcode scan, serving multiplier) |
| **MealSummaryView** | `MealSummaryView.swift` | Immersive hero sheet for meal groups — photo hero, ingredient list, macro donut, daily goal bars |
| **EditBarcodeScannerView** | *(in EditEntryView.swift)* | Lightweight barcode scanner within edit flow — scans and updates entry directly |

## Reusable Components

| View | File | Description |
|------|------|-------------|
| **FoodEntryRow** | DailySummaryView.swift | Entry row — photo/icon thumbnail, name, colored macros, calories |
| **MealEntryRow** | DailySummaryView.swift | Meal group row — thumbnail, meal name, total macros, item count, expand chevron |
| **MacroDonutCard** | DailySummaryView.swift | Summary donut chart with animated cal/macro numbers |
| **MacroProgressLabel** | DailySummaryView.swift | Animated number + progress bar for a single macro |
| **FoodIconThumbnail** | DailySummaryView.swift | Colored SF Symbol in rounded rect (no-photo fallback) |
| **CachedThumbnailImage** | SharedHelpers.swift | Async-decoded 52×52 photo thumbnail |
| **MetricPill** | SharedHelpers.swift | Capsule badge showing a single metric (e.g. "120 cal") |
| **HeroMacroDonut** | SharedHelpers.swift | Macro donut with percentage labels (used in EditEntry + MealSummary heroes) |
| **DailyGoalBarsView** | SharedHelpers.swift | "% of Daily Goal" progress bars |
| **SourceBadge** | PhotoAnalysisView.swift | Colored capsule label — "AI Estimate" / "From Label" / "Barcode" |
| **PerformanceTileView** | HistoryView.swift | Adherence stats with dot matrix, streaks, trends |
| **PerformanceInfoView** | HistoryView.swift | Info sheet explaining performance metrics |

## Widget

| View | File | Description |
|------|------|-------------|
| **FoodTrackerWidget** | FoodTrackerWidget.swift | `.systemMedium` — donut chart + macro progress bars (or simple cal count when no targets) |
