# FoodTracker

An iOS calorie and macro tracking app built with SwiftUI and SwiftData. Log food via AI photo analysis, barcode scanning, USDA database search, or manual entry — all with a premium dark design system.

## Features

- **AI photo analysis** — Snap a photo and let Claude Sonnet 4.6 or Gemini 2.0 Flash identify foods, estimate portions, and compute macros using chain-of-thought reasoning with cooking method detection, plate size calibration, and hidden calorie estimation.
- **Precision multi-angle mode** — Capture 2–3 photos from different angles for higher-accuracy portion estimation.
- **Barcode scanning** — Instant lookup via OpenFoodFacts, with a community-correction flow when you edit values.
- **USDA database search** — Multi-result lookup with scoring, cooking-method matching, and FNDDS prepared-food support.
- **AI nutrition estimates** — Text-based fallback when database lookups miss.
- **Unified search** — Recent foods, USDA results, AI estimates, and manual entry in one screen.
- **Build your own meal** — Compose named meals from multiple ingredients using any input method.
- **Favorites & quick re-add** — Star foods and meals, tap to re-log from the browse sheet.
- **Daily summary** — Card-based list with donut chart, time-of-day grouping, swipe actions, and drag-to-reorder across sections.
- **Immersive detail views** — Full-bleed hero photos with dominant-color gradients, or AI-generated illustrations via Apple Image Playground when no photo exists.
- **Performance dashboard** — Week/month/year adherence tracking with bar charts, dot matrices, streaks, and trend analysis.
- **Accuracy tracker** — Records your corrections to AI estimates and surfaces systematic bias over time.
- **Apple Health sync** — Writes dietary samples for calories, protein, carbs, and fat.
- **Home Screen widget** — Medium widget with donut chart and macro progress.
- **Adaptive light/dark design system** — Centralized `DS` tokens, with user-controlled appearance mode.

## Tech Stack

- **Language:** Swift, SwiftUI
- **Data:** SwiftData (`@Model`)
- **Minimum target:** iOS 17+
- **Dependencies:** None — built entirely on Apple frameworks
- **Vision providers:** Claude Sonnet 4.6 (Anthropic API) or Gemini 2.0 Flash (Google API)
- **Nutrition data:** USDA FoodData Central + OpenFoodFacts

## Building

1. Clone and open `FoodTracker.xcodeproj` in Xcode 15+.
2. Select the FoodTracker target → **Signing & Capabilities**:
   - Add your Apple Developer team.
   - Add the **App Groups** capability with identifier `group.com.DNT.foodtracker` (needed by both the app and widget targets).
   - Add the **HealthKit** capability.
3. Build for an iOS 17+ simulator or device. Camera features require a physical device.

## API Keys

The app never hardcodes credentials. On first launch, open **Settings** to enter:

- **Vision provider key** (Claude or Gemini) — required for photo and text AI analysis.
- **USDA FoodData Central key** — optional but recommended. Free at [fdc.nal.usda.gov/api-key-signup](https://fdc.nal.usda.gov/api-key-signup) (1,000 req/hr vs the shared `DEMO_KEY`'s 30/hr).
- **OpenFoodFacts credentials** — optional, only needed if you want to submit barcode corrections back upstream.

Keys are stored in the iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (no iCloud sync).

## Project Structure

```
FoodTracker/
├── Models/             # SwiftData FoodEntry
├── Shared/             # Design system, shared views, helpers, constants
├── Services/           # Vision pipeline, USDA, OpenFoodFacts, HealthKit, Image Playground
└── Views/              # SwiftUI screens
FoodTrackerWidget/      # WidgetKit extension
```

See [`CLAUDE.md`](./CLAUDE.md) for a detailed architectural walkthrough.
