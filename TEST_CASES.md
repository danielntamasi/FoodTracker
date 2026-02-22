# FoodTracker - Comprehensive Test Cases

Manual test plan for the FoodTracker iOS app. All tests are designed for execution on a physical iOS device unless otherwise noted. Simulator-compatible tests are marked with `[SIM]`.

---

## 1. Tab Navigation

### TC-001
- **Category**: Tab Navigation
- **Description**: Verify the floating tab bar displays with all expected elements
- **Preconditions**: App is launched and on the Today screen
- **Steps**:
  1. Observe the bottom of the screen
- **Expected Result**: A floating tab bar with rounded rectangle background and ultra-thin material appears containing four elements: "Today" (fork.knife icon), "History" (calendar icon), a circular blue "+" button in the center, and "Settings" (gearshape icon). The Today tab should be highlighted with the accent color.
- **Priority**: P0

### TC-002
- **Category**: Tab Navigation
- **Description**: Verify switching to the History tab
- **Preconditions**: App is on the Today screen
- **Steps**:
  1. Tap the "History" tab item in the floating tab bar
- **Expected Result**: The History view loads with navigation title "History". The History tab icon and label are now highlighted in the accent color. The Today tab becomes secondary/gray.
- **Priority**: P0

### TC-003
- **Category**: Tab Navigation
- **Description**: Verify switching to the Settings tab
- **Preconditions**: App is on the Today screen
- **Steps**:
  1. Tap the "Settings" tab item in the floating tab bar
- **Expected Result**: The Settings view loads with navigation title "Settings". The Settings tab icon and label are highlighted in the accent color.
- **Priority**: P0

### TC-004
- **Category**: Tab Navigation
- **Description**: Verify switching back to the Today tab
- **Preconditions**: App is on the History or Settings screen
- **Steps**:
  1. Tap the "Today" tab item in the floating tab bar
- **Expected Result**: The Today view loads with navigation title "Today". The Today tab icon and label are highlighted.
- **Priority**: P0

### TC-005
- **Category**: Tab Navigation
- **Description**: Verify the "+" button opens the radial arch menu
- **Preconditions**: App is on any tab
- **Steps**:
  1. Tap the circular blue "+" button in the center of the floating tab bar
- **Expected Result**: The "+" icon rotates 45° to form an "X". A dimming backdrop (black, 0.3 opacity) covers the screen. Five circular option buttons burst outward from the "+" button with staggered spring animations and land in an arch horizontally centered on screen, just above the tab bar. Left to right: "Recent" (clock.arrow.circlepath), "Manual" (pencil), "Photo" (camera), "Upload" (photo.on.rectangle), "Barcode" (barcode.viewfinder). Each has a label below its circle. Edge items droop slightly in an arch curve.
- **Priority**: P0

### TC-006
- **Category**: Tab Navigation
- **Description**: Verify the "+" button has scale animation on press
- **Preconditions**: App is on any tab
- **Steps**:
  1. Press and hold the "+" button without releasing
  2. Observe the button
  3. Release the button
- **Expected Result**: The "+" button scales down to 90% while pressed with a spring animation, then returns to 100% on release.
- **Priority**: P3

### TC-007
- **Category**: Tab Navigation
- **Description**: Verify tab bar has safe area inset so content is not hidden behind it
- **Preconditions**: App is on the Today tab with some food entries logged
- **Steps**:
  1. Scroll the food list to the bottom
- **Expected Result**: The last food entry is fully visible and not obscured by the floating tab bar. There is an 88pt clear safe area inset at the bottom.
- **Priority**: P1

---

## 2. Radial Menu

### TC-008
- **Category**: Radial Menu
- **Description**: Verify "Photo" option launches the photo capture flow
- **Preconditions**: Radial menu is open (tapped "+")
- **Steps**:
  1. Tap "Photo" (camera icon, center item)
- **Expected Result**: The radial menu closes with items flying back into the "+" button (spring animation). After ~350ms the PhotoCaptureView appears as a sheet with a camera interface (or photo library on simulator).
- **Priority**: P0

### TC-009
- **Category**: Radial Menu
- **Description**: Verify "Barcode" option launches the barcode scanner
- **Preconditions**: Radial menu is open. Camera permission granted.
- **Steps**:
  1. Tap "Barcode" (barcode.viewfinder icon, rightmost item)
- **Expected Result**: The radial menu closes, then the BarcodeScannerView appears with camera preview and an overlay reading "Point camera at a barcode".
- **Priority**: P0

### TC-010
- **Category**: Radial Menu
- **Description**: Verify "Manual" option launches the manual entry form
- **Preconditions**: Radial menu is open
- **Steps**:
  1. Tap "Manual" (pencil icon, second from left)
- **Expected Result**: The radial menu closes, then the AddEntryView appears with "Add Food" title, Name/Calories text fields, Macros section, Servings section, Notes section, and AI Lookup button.
- **Priority**: P0

### TC-011
- **Category**: Radial Menu
- **Description**: Verify "Recent" option launches the browse foods view
- **Preconditions**: Radial menu is open
- **Steps**:
  1. Tap "Recent" (clock.arrow.circlepath icon, leftmost item)
- **Expected Result**: The radial menu closes, then the BrowseFoodsView appears with "Browse Foods" title and Cancel button.
- **Priority**: P0

### TC-011b
- **Category**: Radial Menu
- **Description**: Verify "Upload" option launches the photo upload flow
- **Preconditions**: Radial menu is open
- **Steps**:
  1. Tap "Upload" (photo.on.rectangle icon, second from right)
- **Expected Result**: The radial menu closes, then the PhotoUploadView appears with a photo library picker.
- **Priority**: P0

### TC-012
- **Category**: Radial Menu
- **Description**: Verify radial menu can be dismissed by tapping backdrop or X
- **Preconditions**: Radial menu is open
- **Steps**:
  1. Tap the dimming backdrop area (anywhere outside the menu items)
- **Expected Result**: The radial items fly back into the "+" button with spring animation, the backdrop fades out, and the "+" icon rotates back from X to +. No action is triggered.
- **Priority**: P1

### TC-012b
- **Category**: Radial Menu
- **Description**: Verify radial menu can be dismissed by tapping the X button
- **Preconditions**: Radial menu is open
- **Steps**:
  1. Tap the "X" button (the rotated "+" button)
- **Expected Result**: Same as TC-012 — items fly back into button, backdrop fades, icon rotates back to +.
- **Priority**: P1

### TC-013
- **Category**: Radial Menu
- **Description**: Verify radial menu items are horizontally centered on screen
- **Preconditions**: Radial menu is open
- **Steps**:
  1. Observe the position of the "Photo" item (center of the arc)
- **Expected Result**: The center item ("Photo") is horizontally centered on the screen, not centered on the "+" button (which sits right-of-center in the tab bar). A GeometryReader-based correction shifts items left to compensate for the button's offset. Edge items ("Recent", "Barcode") are symmetrically positioned with slight arch droop.
- **Priority**: P2

---

## 3. Manual Entry (AddEntryView)

### TC-014
- **Category**: Manual Entry
- **Description**: Verify saving a minimal entry with only name and calories
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Type "Apple" in the Name field
  2. Type "95" in the Calories field
  3. Tap "Save"
- **Expected Result**: The sheet dismisses. On the Today screen, an entry "Apple" with "95 cal" appears in the current time-of-day section. The entry has the "carrot" icon (fruit keyword match). Macros show 0P, 0C, 0F.
- **Priority**: P0

### TC-015
- **Category**: Manual Entry
- **Description**: Verify saving a full entry with all macros
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Type "Chicken Breast" in the Name field
  2. Type "165" in the Calories field
  3. Type "31" in the Protein field
  4. Type "0" in the Carbs field
  5. Type "3.6" in the Fat field
  6. Tap "Save"
- **Expected Result**: The sheet dismisses. Entry appears with "165 cal" and macros "31P 0C 4F". The icon is "bird" (chicken keyword match).
- **Priority**: P0

### TC-016
- **Category**: Manual Entry
- **Description**: Verify Save button is disabled when name is empty
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Leave the Name field empty
  2. Type "100" in the Calories field
  3. Observe the Save button
- **Expected Result**: The Save button in the toolbar is disabled (grayed out).
- **Priority**: P0

### TC-017
- **Category**: Manual Entry
- **Description**: Verify Save button is disabled when calories is empty
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Type "Banana" in the Name field
  2. Leave the Calories field empty
  3. Observe the Save button
- **Expected Result**: The Save button in the toolbar is disabled.
- **Priority**: P0

### TC-018
- **Category**: Manual Entry
- **Description**: Verify Cancel button dismisses without saving
- **Preconditions**: AddEntryView is displayed with some data entered `[SIM]`
- **Steps**:
  1. Type "Banana" in the Name field
  2. Type "105" in Calories
  3. Tap "Cancel"
- **Expected Result**: The sheet dismisses. No new entry appears on the Today screen.
- **Priority**: P0

### TC-019
- **Category**: Manual Entry
- **Description**: Verify serving presets display and selection
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Scroll to the "Servings" section
  2. Observe the horizontal preset strip
  3. Tap the "2" preset button
- **Expected Result**: A horizontal scrollable row of capsule-shaped buttons from 1/4 to 3 (in 0.25 increments) is displayed. The "2" button becomes highlighted (bold text, accent color background). The "Servings" label reads "2".
- **Priority**: P1

### TC-020
- **Category**: Manual Entry
- **Description**: Verify serving multiplier affects saved values
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Type "Rice" in Name
  2. Type "200" in Calories
  3. Type "4" in Protein, "45" in Carbs, "0.5" in Fat
  4. Select the "2" serving preset
  5. Observe the "Total" row
  6. Tap "Save"
- **Expected Result**: The Total row shows "400 cal" and macros "8P 90C 1F". After saving, the entry on the Today screen shows 400 cal with the multiplied macro values.
- **Priority**: P1

### TC-021
- **Category**: Manual Entry
- **Description**: Verify fractional serving display (unicode fractions)
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Tap the first preset button (0.25)
- **Expected Result**: The serving display shows the unicode fraction character 1/4. Similarly 0.5 shows 1/2, 0.75 shows 3/4, 1.25 shows "1 1/4", 1.5 shows "1 1/2", 1.75 shows "1 3/4".
- **Priority**: P2

### TC-022
- **Category**: Manual Entry
- **Description**: Verify custom serving input
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. In the "Custom" row, clear the default value
  2. Type "1.5" in the custom servings field
- **Expected Result**: The serving display updates to "1 1/2". If calories are entered, the Total row recalculates accordingly.
- **Priority**: P1

### TC-023
- **Category**: Manual Entry
- **Description**: Verify USDA AI Lookup button is disabled when name is empty
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Leave the Name field empty
  2. Observe the "AI Lookup" button
- **Expected Result**: The AI Lookup button is disabled (not tappable).
- **Priority**: P1

### TC-024
- **Category**: Manual Entry
- **Description**: Verify USDA AI Lookup returns results and accept flow
- **Preconditions**: AddEntryView is displayed. Network available. `[SIM]`
- **Steps**:
  1. Type "banana" in the Name field
  2. Tap "AI Lookup"
  3. Wait for the result to appear
  4. Tap the green checkmark button to accept
- **Expected Result**: A ProgressView spinner appears during lookup. After completion, a "USDA Result" section appears showing calories and macros (e.g., ~89 cal, P: 1.1g, C: 22.8g, F: 0.3g). After tapping accept, the Calories, Protein, Carbs, and Fat fields are populated with the USDA values. The USDA result section disappears.
- **Priority**: P1

### TC-025
- **Category**: Manual Entry
- **Description**: Verify USDA AI Lookup dismiss flow
- **Preconditions**: USDA lookup has returned a result in AddEntryView `[SIM]`
- **Steps**:
  1. Tap the red X button to dismiss the USDA result
- **Expected Result**: The USDA result section disappears with an opacity animation. The form fields remain unchanged (still showing whatever was there before).
- **Priority**: P1

### TC-026
- **Category**: Manual Entry
- **Description**: Verify USDA lookup error handling for unknown food
- **Preconditions**: AddEntryView is displayed. Network available. `[SIM]`
- **Steps**:
  1. Type "xyznonexistentfood123" in the Name field
  2. Tap "AI Lookup"
  3. Wait for the result
- **Expected Result**: An error message appears in red text: "No nutrition data found for \"xyznonexistentfood123\"."
- **Priority**: P2

### TC-027
- **Category**: Manual Entry
- **Description**: Verify notes field accepts multi-line input
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Tap the "Optional notes" field
  2. Type "Made with love\nHomemade recipe"
- **Expected Result**: The notes field expands to show multiple lines (3-6 lines limit). The text wraps properly.
- **Priority**: P2

### TC-028
- **Category**: Manual Entry
- **Description**: Verify Total row only appears when servings is not 1 and calories are entered
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Type "100" in Calories
  2. Observe the Servings section (servings = 1)
  3. Change servings to 2
- **Expected Result**: With servings = 1, no "Total" row is visible. After changing to 2, a Total row appears showing "200 cal" with the multiplied macro breakdown.
- **Priority**: P2

---

## 4. Photo Analysis

### TC-029
- **Category**: Photo Analysis
- **Description**: Verify photo capture triggers analysis flow
- **Preconditions**: PhotoCaptureView is displayed. Vision API key is configured in Settings. Physical device with camera.
- **Steps**:
  1. Take a photo of food (e.g., a banana)
  2. Confirm/use the photo
- **Expected Result**: A full-screen cover appears showing the PhotoAnalysisView. The captured image is displayed at the top with a "Identifying food..." progress indicator. After the API responds, the loading text changes to "Looking up nutrition data..." then the identified foods appear in a list with editable fields.
- **Priority**: P0

### TC-030
- **Category**: Photo Analysis
- **Description**: Verify photo analysis shows identified standalone food items
- **Preconditions**: Photo analysis has completed with results (standalone items)
- **Steps**:
  1. Observe the list of identified foods
- **Expected Result**: Each standalone food item appears in its own section with: food name as headline, a SourceBadge (orange "AI Estimate" or green "From Label"), editable Name field, Portion field, Grams field, Calories field, Protein field, Carbs field, and Fat field. All numeric fields have appropriate keyboard types.
- **Priority**: P0

### TC-031
- **Category**: Photo Analysis
- **Description**: Verify photo analysis shows grouped meal items
- **Preconditions**: Photo analysis has completed with results including a grouped meal (e.g., a photo of a bowl with rice, chicken, and vegetables)
- **Steps**:
  1. Observe the grouped meal section
  2. Tap the DisclosureGroup to expand ingredients
- **Expected Result**: The meal group shows with a meal name header (editable), an "AI Estimate" badge, total calories, total macros (P, C, F), and ingredient count (e.g., "3 ingredients"). When expanded, each ingredient shows its name, portion, and editable macro fields (Cal, P, C, F).
- **Priority**: P0

### TC-032
- **Category**: Photo Analysis
- **Description**: Verify editing food values before saving
- **Preconditions**: Photo analysis has completed with results `[SIM]`
- **Steps**:
  1. Change the food name from "banana" to "Large Banana"
  2. Change calories from 105 to 120
  3. Tap "Save"
- **Expected Result**: The sheet dismisses. The entry on the Today screen shows "Large Banana" with 120 cal.
- **Priority**: P0

### TC-033
- **Category**: Photo Analysis
- **Description**: Verify saving multiple identified foods creates separate entries
- **Preconditions**: Photo analysis has completed with 3 identified foods
- **Steps**:
  1. Tap "Save"
- **Expected Result**: All 3 food items are saved as separate FoodEntry records. They all appear on the Today screen. Each entry has the captured photo as a thumbnail. Total calories on the summary card increase by the sum of all 3 items.
- **Priority**: P0

### TC-034
- **Category**: Photo Analysis
- **Description**: Verify saving grouped meal preserves meal group relationship
- **Preconditions**: Photo analysis completed with a grouped meal (e.g., "Bibimbap" with 3 ingredients)
- **Steps**:
  1. Tap "Save"
- **Expected Result**: The meal appears on the Today screen as a single collapsed meal group row showing the meal name, total calories, total macros, and "3 items" count. The photo thumbnail appears on the row. A chevron button allows expanding to see individual ingredients.
- **Priority**: P0

### TC-035
- **Category**: Photo Analysis
- **Description**: Verify editing meal name propagates to all ingredients
- **Preconditions**: Photo analysis completed with a grouped meal
- **Steps**:
  1. Change the meal name text field from "Bibimbap" to "Korean Rice Bowl"
  2. Tap "Save"
- **Expected Result**: All ingredient entries share the same mealGroupID and the mealName is set to "Korean Rice Bowl" for all of them. The meal group on the Today screen shows "Korean Rice Bowl".
- **Priority**: P1

### TC-036
- **Category**: Photo Analysis
- **Description**: Verify Cancel button dismisses without saving
- **Preconditions**: Photo analysis completed with results
- **Steps**:
  1. Tap "Cancel"
- **Expected Result**: The PhotoAnalysisView and PhotoCaptureView both dismiss. No entries are saved. The Today screen is unchanged.
- **Priority**: P0

### TC-037
- **Category**: Photo Analysis
- **Description**: Verify analysis error state with retry option
- **Preconditions**: Vision API key is invalid or network is unavailable
- **Steps**:
  1. Take a photo of food
  2. Wait for the analysis to fail
- **Expected Result**: A ContentUnavailableView appears with "Analysis Failed" label (exclamationmark.triangle icon), the error description, a "Try Again" button, and a "Cancel" button.
- **Priority**: P1

### TC-038
- **Category**: Photo Analysis
- **Description**: Verify "Try Again" retries the analysis
- **Preconditions**: Analysis has failed and error state is shown. Network is now available or API key is valid.
- **Steps**:
  1. Tap "Try Again"
- **Expected Result**: The loading state reappears with "Identifying food..." text. The analysis is retried.
- **Priority**: P1

### TC-039
- **Category**: Photo Analysis
- **Description**: Verify no API key configured shows appropriate error
- **Preconditions**: No vision API key is saved in Keychain for the selected provider
- **Steps**:
  1. Take a photo of food
  2. Wait for the error
- **Expected Result**: Error message reads: "No API key configured. Please add your API key in Settings."
- **Priority**: P0

### TC-040
- **Category**: Photo Analysis
- **Description**: Verify label source items show "From Label" badge and preserve brand names
- **Preconditions**: Photo analysis completed where the AI detected a nutrition label (e.g., photo of a protein bar with visible nutrition facts)
- **Steps**:
  1. Observe the food item with label data
- **Expected Result**: The item shows a green "From Label" SourceBadge. The name preserves the brand name as-is (e.g., "David Protein Bar" not "protein bar"). Calories and macros match the values read from the label. The item has per-100g data fields populated and a serving picker is shown.
- **Priority**: P1

### TC-041
- **Category**: Photo Analysis
- **Description**: Verify Save button is disabled when food list is empty
- **Preconditions**: Photo analysis is complete but somehow no foods were identified (unlikely edge case) or all removed
- **Steps**:
  1. Observe the Save button
- **Expected Result**: The Save button is disabled.
- **Priority**: P2

---

## 5. Barcode Scanning

### TC-042
- **Category**: Barcode Scanning
- **Description**: Verify barcode scanning UI displays camera with guide text
- **Preconditions**: BarcodeScannerView is displayed. Camera permission granted. Physical device.
- **Steps**:
  1. Observe the screen
- **Expected Result**: Full-screen camera preview with a bottom overlay containing "Point camera at a barcode" with a barcode.viewfinder icon. A "Cancel" button is in the top-left (white tint). Title reads "Scan Barcode".
- **Priority**: P0

### TC-043
- **Category**: Barcode Scanning
- **Description**: Verify successful barcode scan and product lookup
- **Preconditions**: BarcodeScannerView is displayed. Network available. Physical device.
- **Steps**:
  1. Point the camera at a food product barcode (EAN-13 or UPC)
  2. Wait for the barcode to be recognized
- **Expected Result**: Haptic success feedback fires. The guide overlay changes to a ProgressView "Looking up product...". After the OpenFoodFacts API returns, a PhotoAnalysisView sheet appears with the product details pre-filled (name, brand, calories, macros, serving size). A blue "Barcode" SourceBadge is shown.
- **Priority**: P0

### TC-044
- **Category**: Barcode Scanning
- **Description**: Verify barcode product has serving picker with per-100g recalculation
- **Preconditions**: Barcode scan has succeeded and the product sheet is showing
- **Steps**:
  1. Observe the serving picker in the product section
  2. Change servings from 1 to 2
- **Expected Result**: A "Servings" row shows the current count and serving description (e.g., "1 x 30g"). A horizontal strip of preset buttons (0.25 to 3.0) is visible. After selecting 2, the calories, protein, carbs, and fat values all double (recalculated from per-100g base values).
- **Priority**: P0

### TC-045
- **Category**: Barcode Scanning
- **Description**: Verify barcode custom serving input recalculates nutrition
- **Preconditions**: Barcode scan has succeeded and product sheet is showing
- **Steps**:
  1. Enter "1.5" in the "Custom servings" field
- **Expected Result**: Nutrition values recalculate to 1.5x the single serving amount. The portion grams field updates to 1.5x the serving gram weight. Values are rounded to 1 decimal place.
- **Priority**: P1

### TC-046
- **Category**: Barcode Scanning
- **Description**: Verify saving a barcode-scanned product
- **Preconditions**: Barcode scan has succeeded and product sheet is showing
- **Steps**:
  1. Tap "Save"
- **Expected Result**: Both the product sheet and barcode scanner dismiss. A new entry appears on the Today screen with the product name (brand + product name, capitalized), the scanned nutrition values, and no photo thumbnail (icon-based display instead).
- **Priority**: P0

### TC-047
- **Category**: Barcode Scanning
- **Description**: Verify barcode scan for unknown product
- **Preconditions**: BarcodeScannerView is displayed. Physical device.
- **Steps**:
  1. Scan a barcode that is not in the OpenFoodFacts database (e.g., a very obscure or local product)
- **Expected Result**: After the lookup, an error overlay appears with an orange exclamation triangle icon, the message "Product not found in database.", and a "Scan Again" button.
- **Priority**: P1

### TC-048
- **Category**: Barcode Scanning
- **Description**: Verify "Scan Again" resets the scanner
- **Preconditions**: Barcode scan failed with an error overlay
- **Steps**:
  1. Tap "Scan Again"
- **Expected Result**: The error overlay disappears. The guide text "Point camera at a barcode" reappears. The scanner is ready to detect a new barcode. The scannedBarcode state is cleared.
- **Priority**: P1

### TC-049
- **Category**: Barcode Scanning
- **Description**: Verify Cancel button dismisses the barcode scanner
- **Preconditions**: BarcodeScannerView is displayed
- **Steps**:
  1. Tap "Cancel"
- **Expected Result**: The barcode scanner sheet dismisses. No entries are created.
- **Priority**: P0

### TC-050
- **Category**: Barcode Scanning
- **Description**: Verify barcode scanner prevents duplicate scans
- **Preconditions**: BarcodeScannerView is displayed. Physical device.
- **Steps**:
  1. Scan a barcode
  2. While the lookup is in progress, point camera at another barcode
- **Expected Result**: The second barcode is ignored. Only the first barcode triggers a lookup. The guard `scannedBarcode == nil && !isLookingUp` prevents re-entry.
- **Priority**: P1

### TC-051
- **Category**: Barcode Scanning
- **Description**: Verify supported barcode formats
- **Preconditions**: BarcodeScannerView is displayed. Physical device.
- **Steps**:
  1. Scan an EAN-8 barcode
  2. Scan an EAN-13 barcode
  3. Scan a UPC-E barcode
  4. Scan a Code 128 barcode
  5. Scan a Code 39 barcode
- **Expected Result**: All five barcode formats are detected and trigger a product lookup.
- **Priority**: P2

---

## 6. Daily Summary

### TC-052
- **Category**: Daily Summary
- **Description**: Verify summary card shows total calories without targets set
- **Preconditions**: No daily targets are configured (all set to 0). At least one entry exists today. `[SIM]`
- **Steps**:
  1. Navigate to the Today tab
- **Expected Result**: A summary card at the top shows the total calories in large bold rounded font (size 48), "calories today" subtitle, and three macro labels below: Protein (blue), Carbs (orange), Fat (purple) showing gram values. No donut chart is present.
- **Priority**: P0

### TC-053
- **Category**: Daily Summary
- **Description**: Verify donut chart and progress bars appear when targets are set
- **Preconditions**: Daily targets are configured (e.g., 2000 cal, 120g protein, 250g carbs, 65g fat). At least one entry exists today. `[SIM]`
- **Steps**:
  1. Navigate to the Today tab
- **Expected Result**: A MacroDonutCard appears showing: a donut chart with colored segments (blue=protein, orange=carbs, purple=fat) with filled and unfilled portions. Inside the donut: current calories in bold, "/ 2000 cal" below, and "X left" or "X over" text. Below the donut: three MacroProgressLabel bars showing value/target with colored progress capsules.
- **Priority**: P0

### TC-054
- **Category**: Daily Summary
- **Description**: Verify "calories left" vs "calories over" display
- **Preconditions**: Daily calorie target is set to 2000 `[SIM]`
- **Steps**:
  1. Log entries totaling less than 2000 calories
  2. Observe the donut center text
  3. Log more entries pushing total above 2000
  4. Observe again
- **Expected Result**: When under target, text reads "X left" in secondary color. When over target, text reads "X over" in red color. The number is the absolute difference between consumed and target.
- **Priority**: P1

### TC-055
- **Category**: Daily Summary
- **Description**: Verify time-of-day sections (Morning, Afternoon, Evening)
- **Preconditions**: Entries exist for different times of day today `[SIM]`
- **Steps**:
  1. Observe the sections on the Today screen
- **Expected Result**: Entries are grouped into sections: "Morning" (sunrise icon, orange tint) for entries before 12:00, "Afternoon" (sun.max icon, yellow tint) for entries 12:00-16:59, "Evening" (moon.stars icon, indigo tint) for entries 17:00+. Each section has a header with the period icon in a colored circle and the period name.
- **Priority**: P1

### TC-056
- **Category**: Daily Summary
- **Description**: Verify sort toggle changes entry order
- **Preconditions**: Multiple entries exist today in the same time period `[SIM]`
- **Steps**:
  1. Observe the default sort order (oldest first within sections, Morning/Afternoon/Evening order)
  2. Tap the arrow button in the first visible section header
  3. Observe the new order
- **Expected Result**: The arrow toggles between up and down. In default (arrow.up) mode, sections go Morning->Afternoon->Evening and entries within sections are chronological. In reverse (arrow.down) mode, sections go Evening->Afternoon->Morning and entries within sections are reverse chronological. The animation uses spring with 0.4 duration.
- **Priority**: P1

### TC-057
- **Category**: Daily Summary
- **Description**: Verify sort preference persists across app launches
- **Preconditions**: None `[SIM]`
- **Steps**:
  1. Toggle the sort order to reverse chronological
  2. Force-quit the app
  3. Relaunch the app
- **Expected Result**: The sort order is still reverse chronological (persisted via UserDefaults "reverseChronological" key).
- **Priority**: P2

### TC-058
- **Category**: Daily Summary
- **Description**: Verify empty state when no entries exist today
- **Preconditions**: No entries exist for today `[SIM]`
- **Steps**:
  1. Navigate to the Today tab
- **Expected Result**: Below the summary card (showing 0 calories), an empty state view appears with a pulsing fork.knife icon (accent color, size 48), "No meals logged today" headline, and "Tap + to add your first meal" subheadline.
- **Priority**: P1

### TC-059
- **Category**: Daily Summary
- **Description**: Verify standalone food entry row display
- **Preconditions**: A standalone entry (no meal group) exists today `[SIM]`
- **Steps**:
  1. Observe the entry row
- **Expected Result**: The row shows: an icon thumbnail (52x52, rounded rectangle, with category-appropriate SF Symbol and color) or photo thumbnail if the entry has a photo, the food name, colored macro text (blue P, orange C, purple F values), and calories on the trailing side ("X cal" in secondary color).
- **Priority**: P0

### TC-060
- **Category**: Daily Summary
- **Description**: Verify meal group row display (collapsed)
- **Preconditions**: A meal group entry exists today (e.g., from photo analysis with grouped items) `[SIM]`
- **Steps**:
  1. Observe the meal group row
- **Expected Result**: The row shows: the photo thumbnail (or icon) from the first entry in the group, the meal name in medium weight, total macros in colored text, "X items" count in tertiary color, total calories on the trailing side, and a chevron.down button on the far right.
- **Priority**: P0

### TC-061
- **Category**: Daily Summary
- **Description**: Verify expanding a meal group
- **Preconditions**: A collapsed meal group exists on the Today screen `[SIM]`
- **Steps**:
  1. Tap the chevron button on a meal group row
- **Expected Result**: The chevron changes to chevron.up with an ease-in-out animation (0.2 duration). Individual ingredient rows appear below the group header, indented (leading inset 32pt). Each shows the same FoodEntryRow format.
- **Priority**: P0

### TC-062
- **Category**: Daily Summary
- **Description**: Verify collapsing an expanded meal group
- **Preconditions**: An expanded meal group exists on the Today screen `[SIM]`
- **Steps**:
  1. Tap the chevron.up button on the expanded meal group
- **Expected Result**: The ingredient rows animate away. The chevron changes back to chevron.down. Only the group summary row remains.
- **Priority**: P1

### TC-063
- **Category**: Daily Summary
- **Description**: Verify tapping a standalone entry opens EditEntryView
- **Preconditions**: A standalone entry exists on the Today screen `[SIM]`
- **Steps**:
  1. Tap on a standalone food entry row
- **Expected Result**: The EditEntryView opens as a sheet, showing the entry details in an immersive hero layout (photo or icon hero).
- **Priority**: P0

### TC-064
- **Category**: Daily Summary
- **Description**: Verify tapping a meal group row opens MealSummaryView
- **Preconditions**: A meal group exists on the Today screen `[SIM]`
- **Steps**:
  1. Tap on the meal group row (not the chevron button)
- **Expected Result**: The MealSummaryView opens as a sheet, showing the meal photo (if available), meal name, total macros, macro donut, ingredient list, and daily goal bars (if targets are set).
- **Priority**: P0

### TC-065
- **Category**: Daily Summary
- **Description**: Verify drag-to-reorder entries
- **Preconditions**: Multiple entries exist in the same time period today `[SIM]`
- **Steps**:
  1. Long-press on an entry row to initiate drag
  2. Drag it to a different position within the section
  3. Release
- **Expected Result**: The entry moves to the new position. The sortOrder field is updated for all affected entries to reflect the new order. The order persists when navigating away and returning.
- **Priority**: P2

### TC-066
- **Category**: Daily Summary
- **Description**: Verify widget data syncs when totals change
- **Preconditions**: Widget is configured on the home screen. Daily targets are set. `[SIM]`
- **Steps**:
  1. Add a new food entry on the Today screen
  2. Go to the home screen
  3. Observe the widget
- **Expected Result**: The widget updates to reflect the new calorie and macro totals. Data is synced via App Group UserDefaults (widgetCalories, widgetProtein, widgetCarbs, widgetFat). WidgetCenter.shared.reloadAllTimelines() is called.
- **Priority**: P1

---

## 7. Swipe Actions

### TC-067
- **Category**: Swipe Actions
- **Description**: Verify swipe actions on a standalone entry in DailySummaryView
- **Preconditions**: A standalone entry exists on the Today screen `[SIM]`
- **Steps**:
  1. Swipe left on the entry row
- **Expected Result**: Three action buttons appear from the right: "Add Again" (green, plus.circle icon), "Edit" (blue, pencil icon), "Delete" (red, trash icon). Full swipe is disabled (allowsFullSwipe: false).
- **Priority**: P0

### TC-068
- **Category**: Swipe Actions
- **Description**: Verify "Delete" swipe action removes the entry
- **Preconditions**: A standalone entry exists on the Today screen `[SIM]`
- **Steps**:
  1. Swipe left on the entry
  2. Tap "Delete"
- **Expected Result**: The entry is deleted with animation. The total calories on the summary card decrease by the deleted entry's calories. The entry no longer appears in the list.
- **Priority**: P0

### TC-069
- **Category**: Swipe Actions
- **Description**: Verify "Edit" swipe action opens EditEntryView
- **Preconditions**: A standalone entry exists on the Today screen `[SIM]`
- **Steps**:
  1. Swipe left on the entry
  2. Tap "Edit"
- **Expected Result**: The EditEntryView opens as a sheet for the selected entry.
- **Priority**: P0

### TC-070
- **Category**: Swipe Actions
- **Description**: Verify "Add Again" swipe action duplicates the entry
- **Preconditions**: A standalone entry "Banana (105 cal)" exists on the Today screen `[SIM]`
- **Steps**:
  1. Swipe left on the Banana entry
  2. Tap "Add Again"
- **Expected Result**: A new "Banana" entry with 105 cal is created with the current timestamp. The total calories increase by 105. The new entry appears in the appropriate time-of-day section. It has the same name, calories, macros, and icon but a new UUID and no photo data.
- **Priority**: P1

### TC-071
- **Category**: Swipe Actions
- **Description**: Verify swipe actions on a collapsed meal group
- **Preconditions**: A collapsed meal group with 3 items exists on the Today screen `[SIM]`
- **Steps**:
  1. Swipe left on the meal group row
- **Expected Result**: Three action buttons appear: "Add Again" (green), "Edit" (blue, opens MealSummaryView), "Delete" (red). The actions apply to the entire group.
- **Priority**: P0

### TC-072
- **Category**: Swipe Actions
- **Description**: Verify "Delete" on a meal group removes all entries in the group
- **Preconditions**: A meal group with 3 entries (totaling 500 cal) exists `[SIM]`
- **Steps**:
  1. Swipe left on the meal group
  2. Tap "Delete"
- **Expected Result**: All 3 entries in the group are deleted. Total calories decrease by 500. The group row and all its children disappear with animation.
- **Priority**: P0

### TC-073
- **Category**: Swipe Actions
- **Description**: Verify "Add Again" on a meal group duplicates all entries
- **Preconditions**: A meal group "Lunch" with 2 entries exists `[SIM]`
- **Steps**:
  1. Swipe left on the meal group
  2. Tap "Add Again"
- **Expected Result**: A new meal group appears with the same meal name ("Lunch"), a new mealGroupID, and 2 new entries with the same names, calories, macros, and icons as the originals. Current date is used. Total calories increase by the sum of the original group.
- **Priority**: P1

### TC-074
- **Category**: Swipe Actions
- **Description**: Verify swipe actions on an expanded child entry within a meal group
- **Preconditions**: A meal group is expanded showing individual ingredient entries `[SIM]`
- **Steps**:
  1. Swipe left on one of the child ingredient rows
- **Expected Result**: The same three action buttons appear: "Add Again" (green), "Edit" (blue), "Delete" (red). These operate on the individual entry only, not the whole group.
- **Priority**: P1

### TC-075
- **Category**: Swipe Actions
- **Description**: Verify deleting a single child from an expanded meal group
- **Preconditions**: A meal group with 3 entries is expanded `[SIM]`
- **Steps**:
  1. Swipe left on one child entry
  2. Tap "Delete"
- **Expected Result**: Only that single entry is deleted. The meal group now shows "2 items" with recalculated total calories and macros. If only 1 entry remains, the group should still display but with "1 items".
- **Priority**: P1

---

## 8. Entry Editing (EditEntryView)

### TC-076
- **Category**: Entry Editing
- **Description**: Verify EditEntryView photo hero layout
- **Preconditions**: An entry with a photo exists. Tap the entry to open EditEntryView. `[SIM]`
- **Steps**:
  1. Observe the EditEntryView layout
- **Expected Result**: The photo fills the top 65% of the screen with scaledToFill. A gradient overlay fades from clear at the top to the extracted dominant color at the bottom. Over the gradient: the food name in white bold title font, metric pills (cal, P, C, F) in capsule badges, and a macro donut chart showing percentage breakdown with colored dots and "X% P/C/F" labels. Two floating buttons at the top: "Edit" (left) and "Done" (right) in capsule shapes with ultra-thin material background.
- **Priority**: P0

### TC-077
- **Category**: Entry Editing
- **Description**: Verify EditEntryView no-photo (icon) hero layout
- **Preconditions**: An entry without a photo exists (e.g., manually added). Tap to open EditEntryView. `[SIM]`
- **Steps**:
  1. Observe the layout
- **Expected Result**: An ambient gradient fills the top 55% using the food category's icon color. A large SF Symbol icon (size 44, inside an 88pt circle with radial glow) is displayed. Below: the food name, metric pills, and macro donut. The background color is derived from the icon category (e.g., green-tinted for "leaf" icon, brown-tinted for "bird" icon).
- **Priority**: P0

### TC-078
- **Category**: Entry Editing
- **Description**: Verify "Done" button dismisses EditEntryView in view mode
- **Preconditions**: EditEntryView is open in view mode (not editing)
- **Steps**:
  1. Tap "Done"
- **Expected Result**: The sheet dismisses. Any changes made in edit mode prior to tapping Done are persisted (since @Bindable directly modifies the model).
- **Priority**: P0

### TC-079
- **Category**: Entry Editing
- **Description**: Verify "Edit" button switches to edit mode
- **Preconditions**: EditEntryView is open in view mode
- **Steps**:
  1. Tap "Edit"
- **Expected Result**: The view transitions (with 0.25s ease-in-out animation) to show editable form fields below the hero. The floating buttons change: "Edit" disappears and is replaced by only "Done" on the right side. Form sections appear: "Food" (Name, Calories), "Macros (Grams)" (Protein, Carbs, Fat), and "AI Lookup" button.
- **Priority**: P0

### TC-080
- **Category**: Entry Editing
- **Description**: Verify editing entry name and calories in edit mode
- **Preconditions**: EditEntryView is in edit mode `[SIM]`
- **Steps**:
  1. Change the Name field to "Grilled Chicken"
  2. Change the Calories field to 200
  3. Tap "Done"
- **Expected Result**: The entry is updated immediately (via @Bindable). The hero view updates to show "Grilled Chicken" and the metric pill shows "200 cal". On the Today screen, the entry row also reflects "Grilled Chicken" and "200 cal".
- **Priority**: P0

### TC-081
- **Category**: Entry Editing
- **Description**: Verify editing macros in edit mode
- **Preconditions**: EditEntryView is in edit mode `[SIM]`
- **Steps**:
  1. Change Protein to 30
  2. Change Carbs to 5
  3. Change Fat to 8
  4. Tap "Done"
- **Expected Result**: The hero updates: metric pills show new values, the macro donut recalculates percentages. On the Today screen, the entry's colored macro text updates.
- **Priority**: P0

### TC-082
- **Category**: Entry Editing
- **Description**: Verify USDA lookup in edit mode
- **Preconditions**: EditEntryView is in edit mode. Entry name is "chicken breast". Network available. `[SIM]`
- **Steps**:
  1. Tap "AI Lookup"
  2. Wait for the result
- **Expected Result**: A spinner appears next to the button. After completion, the entry's calories, protein, carbs, and fat fields are directly updated with USDA values (no accept/dismiss flow like AddEntryView - values are applied immediately).
- **Priority**: P1

### TC-083
- **Category**: Entry Editing
- **Description**: Verify USDA lookup error in edit mode
- **Preconditions**: EditEntryView is in edit mode. Enter a nonsense food name. `[SIM]`
- **Steps**:
  1. Change name to "xyznonexistent"
  2. Tap "AI Lookup"
- **Expected Result**: An error message appears in red text below the lookup button: "No nutrition data found for \"xyznonexistent\"."
- **Priority**: P2

### TC-084
- **Category**: Entry Editing
- **Description**: Verify "% of Daily Goal" bars appear when targets are set
- **Preconditions**: Daily targets are configured. EditEntryView is open in view mode (not editing). `[SIM]`
- **Steps**:
  1. Observe below the hero
- **Expected Result**: A "% of Daily Goal" section appears with progress bars for Cal, Protein, Carbs, and Fat (only those with targets > 0). Each bar shows: label, a filled/unfilled capsule progress bar, and percentage text. The percentage represents what fraction of the daily goal this single entry contributes.
- **Priority**: P1

### TC-085
- **Category**: Entry Editing
- **Description**: Verify timestamp display in EditEntryView
- **Preconditions**: EditEntryView is open for an entry created today `[SIM]`
- **Steps**:
  1. Observe the timestamp below the daily goal bars
- **Expected Result**: Shows "Today at X:XX AM/PM" in white semi-transparent caption text. For yesterday's entries: "Yesterday at X:XX AM/PM". For older: "MMM d at X:XX AM/PM".
- **Priority**: P2

---

## 9. History View

### TC-086
- **Category**: History View
- **Description**: Verify entries are grouped by date in reverse chronological order
- **Preconditions**: Entries exist across multiple dates `[SIM]`
- **Steps**:
  1. Navigate to the History tab
- **Expected Result**: Entries are grouped into sections by date. Most recent date appears first. Each section header shows the date string on the left and total calories for that day on the right (in secondary color).
- **Priority**: P0

### TC-087
- **Category**: History View
- **Description**: Verify empty history state
- **Preconditions**: No entries exist in the database `[SIM]`
- **Steps**:
  1. Navigate to the History tab
- **Expected Result**: A ContentUnavailableView appears with "No History" title, a calendar icon, and description "Your food entries will appear here."
- **Priority**: P1

### TC-088
- **Category**: History View
- **Description**: Verify standalone entry swipe actions in History
- **Preconditions**: A standalone entry exists in a past date section `[SIM]`
- **Steps**:
  1. Swipe left on the entry
- **Expected Result**: Same three swipe actions as Today screen: "Add Again" (green), "Edit" (blue), "Delete" (red). "Add Again" creates a new entry with today's date.
- **Priority**: P0

### TC-089
- **Category**: History View
- **Description**: Verify meal group display and expand in History
- **Preconditions**: A meal group exists in a past date `[SIM]`
- **Steps**:
  1. Observe the meal group row
  2. Tap the chevron button
- **Expected Result**: The meal group row displays the same as in DailySummaryView (meal name, total cal, item count, chevron). On expansion, individual ingredient rows appear with 16pt leading indent. Each has its own swipe actions.
- **Priority**: P1

### TC-090
- **Category**: History View
- **Description**: Verify tapping an entry in History opens EditEntryView
- **Preconditions**: An entry exists in History `[SIM]`
- **Steps**:
  1. Tap on a standalone entry in History
- **Expected Result**: The EditEntryView sheet opens for that entry. Edits are applied immediately via @Bindable.
- **Priority**: P0

### TC-091
- **Category**: History View
- **Description**: Verify tapping a meal group in History opens MealSummaryView
- **Preconditions**: A meal group exists in History `[SIM]`
- **Steps**:
  1. Tap on the meal group row (not the chevron)
- **Expected Result**: MealSummaryView opens as a sheet showing the full meal details.
- **Priority**: P1

### TC-092
- **Category**: History View
- **Description**: Verify "Add Again" from History adds to today
- **Preconditions**: An entry from a past date exists in History `[SIM]`
- **Steps**:
  1. Swipe left on a past entry
  2. Tap "Add Again"
  3. Navigate to the Today tab
- **Expected Result**: A new entry with the same name, calories, macros, and icon appears on the Today screen with the current date/time. Total calories for today increase.
- **Priority**: P1

### TC-093
- **Category**: History View
- **Description**: Verify deleting an entry from History
- **Preconditions**: An entry exists in History `[SIM]`
- **Steps**:
  1. Swipe left on the entry
  2. Tap "Delete"
- **Expected Result**: The entry is removed with animation. If it was the last entry for that date, the date section header also disappears.
- **Priority**: P0

---

## 10. Meal Summary View

### TC-094
- **Category**: Meal Summary View
- **Description**: Verify MealSummaryView with photo
- **Preconditions**: A meal group with a photo exists. Open MealSummaryView for it. `[SIM]`
- **Steps**:
  1. Observe the layout
- **Expected Result**: The photo fills the top 65% of the screen with a gradient fading to the extracted dominant color. Over the gradient: meal name in white bold title, metric pills (cal, P, C, F), and a macro donut chart with percentage breakdown. A "Done" button capsule is in the top-right.
- **Priority**: P0

### TC-095
- **Category**: Meal Summary View
- **Description**: Verify MealSummaryView without photo
- **Preconditions**: A meal group without a photo exists (e.g., manually created via Add Again). Open MealSummaryView. `[SIM]`
- **Steps**:
  1. Observe the layout
- **Expected Result**: The meal name appears in bold title with padding at top. Metric pills and macro donut are displayed without a photo hero. The background uses the default system grouped background color.
- **Priority**: P1

### TC-096
- **Category**: Meal Summary View
- **Description**: Verify ingredient list in MealSummaryView
- **Preconditions**: MealSummaryView is open for a meal with 3 ingredients `[SIM]`
- **Steps**:
  1. Observe the ingredient list section
- **Expected Result**: A header reads "3 items" in white semi-transparent text. Below, a rounded rectangle container shows each ingredient with: name on the left (white, subheadline), calories on the right (white semi-transparent, caption). Dividers separate ingredients. The container has a white semi-transparent (0.08) background.
- **Priority**: P1

### TC-097
- **Category**: Meal Summary View
- **Description**: Verify daily goal bars in MealSummaryView
- **Preconditions**: Daily targets are set. MealSummaryView is open. `[SIM]`
- **Steps**:
  1. Observe below the ingredient list
- **Expected Result**: A "% of Daily Goal" section shows progress bars for Cal, Protein, Carbs, and Fat. Each bar shows the meal's contribution as a percentage of the daily target. The bars use colored capsules against a white semi-transparent track.
- **Priority**: P1

### TC-098
- **Category**: Meal Summary View
- **Description**: Verify timestamp in MealSummaryView
- **Preconditions**: MealSummaryView is open `[SIM]`
- **Steps**:
  1. Observe the timestamp at the bottom
- **Expected Result**: Shows the earliest entry date in the group: "Today at X:XX AM/PM", "Yesterday at X:XX AM/PM", or "MMM d at X:XX AM/PM".
- **Priority**: P2

### TC-099
- **Category**: Meal Summary View
- **Description**: Verify "Done" button dismisses MealSummaryView
- **Preconditions**: MealSummaryView is open
- **Steps**:
  1. Tap "Done"
- **Expected Result**: The sheet dismisses, returning to the previous view.
- **Priority**: P0

### TC-100
- **Category**: Meal Summary View
- **Description**: Verify dominant color extraction from meal photo
- **Preconditions**: A meal group with a food photo exists
- **Steps**:
  1. Open the MealSummaryView
  2. Observe the background color
- **Expected Result**: The background color is derived from the bottom 20% of the meal photo, averaged and darkened (0.3 factor in dark mode, 0.55 in light mode). This creates a cohesive visual transition from the photo to the content below.
- **Priority**: P2

---

## 11. Browse Foods

### TC-101
- **Category**: Browse Foods
- **Description**: Verify frequent foods section shows top 5 by count
- **Preconditions**: Multiple entries exist with repeated food names (e.g., "Banana" logged 5 times, "Rice" 3 times, "Chicken" 2 times, etc.) `[SIM]`
- **Steps**:
  1. Open the Browse Foods view (via Quick Add -> Browse Recent)
- **Expected Result**: A "Frequent" section shows up to 5 foods, sorted by count (descending), then by most recent date. Each row shows: icon, food name, colored macro text, calories on the right, and a count multiplier (e.g., "x5"). Tapping a food adds it immediately.
- **Priority**: P1

### TC-102
- **Category**: Browse Foods
- **Description**: Verify recent foods section shows up to 10 unique non-today foods
- **Preconditions**: Multiple entries exist from past days `[SIM]`
- **Steps**:
  1. Open the Browse Foods view
  2. Observe the "Recent" section
- **Expected Result**: Up to 10 unique food names from past days (not today) appear in reverse chronological order. Duplicates are de-duplicated (case-insensitive, trimmed). Each row shows the icon, name, colored macro text, and calories.
- **Priority**: P1

### TC-103
- **Category**: Browse Foods
- **Description**: Verify tapping a food in Browse adds it to today
- **Preconditions**: Browse Foods view is open with foods listed `[SIM]`
- **Steps**:
  1. Tap on a food item (e.g., "Banana 105 cal")
- **Expected Result**: The Browse Foods sheet dismisses. A new "Banana" entry with 105 cal appears on the Today screen with the current date/time and the same macros and icon as the original.
- **Priority**: P0

### TC-104
- **Category**: Browse Foods
- **Description**: Verify empty Browse Foods state
- **Preconditions**: No entries exist in the database `[SIM]`
- **Steps**:
  1. Open the Browse Foods view
- **Expected Result**: A ContentUnavailableView shows "No Foods Yet" with a fork.knife icon and description "Foods you've added will appear here for quick access."
- **Priority**: P1

### TC-105
- **Category**: Browse Foods
- **Description**: Verify Cancel button in Browse Foods
- **Preconditions**: Browse Foods view is open `[SIM]`
- **Steps**:
  1. Tap "Cancel"
- **Expected Result**: The sheet dismisses without adding any entries.
- **Priority**: P1

---

## 12. Settings

### TC-106
- **Category**: Settings
- **Description**: Verify vision provider picker defaults to Gemini
- **Preconditions**: Fresh install, no provider selection made `[SIM]`
- **Steps**:
  1. Navigate to Settings
  2. Observe the Vision Provider section
- **Expected Result**: The picker shows "Gemini 2.0 Flash" as the selected provider (default).
- **Priority**: P1

### TC-107
- **Category**: Settings
- **Description**: Verify switching vision provider
- **Preconditions**: Settings view is displayed `[SIM]`
- **Steps**:
  1. Change the Vision Provider picker from "Gemini 2.0 Flash" to "Claude Sonnet 4.6"
- **Expected Result**: The provider selection updates. The API Key section header changes to "Claude Sonnet 4.6 API Key". The API key field loads the stored key for Claude (or is empty if none saved). The footer text shows "Get your key from console.anthropic.com."
- **Priority**: P0

### TC-108
- **Category**: Settings
- **Description**: Verify saving a vision API key
- **Preconditions**: Settings view displayed, provider selected `[SIM]`
- **Steps**:
  1. Enter an API key in the API Key field
  2. Tap "Save API Key"
- **Expected Result**: An alert appears with title "API Key Saved" and message "Your API key has been securely saved." The key is stored in Keychain under the provider's keychainAccount.
- **Priority**: P0

### TC-109
- **Category**: Settings
- **Description**: Verify API key visibility toggle
- **Preconditions**: An API key is entered in the field `[SIM]`
- **Steps**:
  1. Observe the field (should be SecureField with dots)
  2. Tap the eye icon
  3. Observe the field (should now show plain text)
  4. Tap the eye.slash icon
- **Expected Result**: The field toggles between SecureField (dots) and TextField (plain text). The button icon toggles between eye and eye.slash.
- **Priority**: P1

### TC-110
- **Category**: Settings
- **Description**: Verify Save API Key button is disabled when field is empty
- **Preconditions**: Settings view displayed `[SIM]`
- **Steps**:
  1. Clear the API Key field
  2. Observe the "Save API Key" button
- **Expected Result**: The button is disabled.
- **Priority**: P1

### TC-111
- **Category**: Settings
- **Description**: Verify USDA API key section
- **Preconditions**: Settings view displayed `[SIM]`
- **Steps**:
  1. Observe the "USDA API Key (Optional)" section
- **Expected Result**: The section shows: an API Key input field (SecureField by default), an eye toggle, a "Save USDA Key" button, and footer text explaining the free key benefit (1,000 vs 30 requests/hour) with the signup URL.
- **Priority**: P1

### TC-112
- **Category**: Settings
- **Description**: Verify saving a USDA API key
- **Preconditions**: Settings view displayed `[SIM]`
- **Steps**:
  1. Enter a USDA API key
  2. Tap "Save USDA Key"
- **Expected Result**: An alert appears confirming the key was saved. The key is stored in Keychain under account "usda-api-key".
- **Priority**: P1

### TC-113
- **Category**: Settings
- **Description**: Verify daily target fields save to UserDefaults
- **Preconditions**: Settings view displayed `[SIM]`
- **Steps**:
  1. Set Calories to 2000
  2. Set Protein to 120
  3. Set Carbs to 250
  4. Set Fat to 65
  5. Navigate away and back to Settings
- **Expected Result**: All values persist. They are stored immediately via UserDefaults onChange handlers. The Today screen now shows a donut chart with progress bars instead of the simple calorie count.
- **Priority**: P0

### TC-114
- **Category**: Settings
- **Description**: Verify setting a target to 0 disables it
- **Preconditions**: Daily targets are configured. Settings view displayed. `[SIM]`
- **Steps**:
  1. Set Protein to 0
  2. Navigate to the Today screen
- **Expected Result**: The donut chart no longer shows a protein segment. The progress bar section does not show a Protein bar. If all targets are 0, the donut card is replaced by the simple calorie count display.
- **Priority**: P1

### TC-115
- **Category**: Settings
- **Description**: Verify keyboard Done button on target fields
- **Preconditions**: Settings view displayed, tapped a target field `[SIM]`
- **Steps**:
  1. Tap the Calories field
  2. Observe the keyboard toolbar
  3. Tap "Done"
- **Expected Result**: A keyboard toolbar appears with a "Done" button on the right. Tapping it dismisses the keyboard.
- **Priority**: P2

### TC-116
- **Category**: Settings
- **Description**: Verify About section
- **Preconditions**: Settings view displayed `[SIM]`
- **Steps**:
  1. Scroll to the "About" section
- **Expected Result**: Shows two rows: "Version" with "1.0.0" on the right (secondary color), and "Nutrition Data" with "USDA FoodData Central" on the right.
- **Priority**: P3

### TC-117
- **Category**: Settings
- **Description**: Verify API key loads when switching providers
- **Preconditions**: Both Claude and Gemini API keys are saved in Keychain `[SIM]`
- **Steps**:
  1. Select Claude provider
  2. Observe the API key field (should show Claude key)
  3. Select Gemini provider
  4. Observe the API key field (should show Gemini key)
- **Expected Result**: Each time the provider is changed, the API key field loads the corresponding key from Keychain. The eye visibility resets to hidden (SecureField).
- **Priority**: P1

---

## 13. Widget

### TC-118
- **Category**: Widget
- **Description**: Verify widget displays with targets set
- **Preconditions**: Widget added to home screen. Daily targets configured. At least one entry today.
- **Steps**:
  1. Observe the widget on the home screen
- **Expected Result**: A medium-size widget shows: left side - a donut chart with filled/unfilled macro segments and calorie count in the center (with "X left" or "X over" text); right side - flame icon with "calories / target cal" and three macro progress bars (Protein, Carbs, Fat) with name, value/target, and colored capsule bars.
- **Priority**: P1

### TC-119
- **Category**: Widget
- **Description**: Verify widget displays without targets set
- **Preconditions**: Widget added to home screen. No daily targets configured.
- **Steps**:
  1. Observe the widget
- **Expected Result**: A centered display showing: large calorie count (bold, rounded, size 36), "calories today" subtitle, and a row of macro labels (P, C, F) with gram values.
- **Priority**: P1

### TC-120
- **Category**: Widget
- **Description**: Verify widget resets at midnight
- **Preconditions**: Widget shows data from today (e.g., 1500 cal)
- **Steps**:
  1. Wait until after midnight (or advance device date past midnight)
  2. Observe the widget after the next timeline refresh
- **Expected Result**: The widget shows 0 calories and 0g for all macros because the widgetLastSync timestamp is no longer "today". The timeline provider checks isDateInToday on the sync timestamp.
- **Priority**: P1

### TC-121
- **Category**: Widget
- **Description**: Verify widget timeline refresh interval
- **Preconditions**: Widget is added to home screen
- **Steps**:
  1. Check the timeline policy in code
- **Expected Result**: The widget uses a TimelineProvider with `.after(nextUpdate)` policy where nextUpdate is 15 minutes from now.
- **Priority**: P3

### TC-122
- **Category**: Widget
- **Description**: Verify widget uses App Group UserDefaults for data
- **Preconditions**: App is configured with App Group "group.com.DNT.foodtracker"
- **Steps**:
  1. Add a food entry in the app
  2. Observe if the widget picks up the data
- **Expected Result**: The DailySummaryView syncs totalCalories, totalProtein, totalCarbs, totalFat, and all daily targets to the App Group UserDefaults (suiteName "group.com.DNT.foodtracker"). The widget reads from the same suite. WidgetCenter.shared.reloadAllTimelines() triggers an immediate refresh.
- **Priority**: P1

---

## 14. Image Handling

### TC-123
- **Category**: Image Handling
- **Description**: Verify large images are resized before API upload
- **Preconditions**: Physical device with camera
- **Steps**:
  1. Take a high-resolution photo (e.g., 4032x3024)
  2. The photo is sent for analysis
- **Expected Result**: The `prepareImageForUpload` function resizes the image so the max dimension is 1536 pixels. The aspect ratio is preserved. The image is compressed as JPEG starting at 0.8 quality.
- **Priority**: P1

### TC-124
- **Category**: Image Handling
- **Description**: Verify image compression stays under 4MB limit
- **Preconditions**: Physical device with camera
- **Steps**:
  1. Take a detailed, high-resolution photo
  2. The photo is processed by prepareImageForUpload
- **Expected Result**: The function iterates compression quality from 0.8 down to 0.2 in 0.1 steps until the JPEG data is under 4MB (4,000,000 bytes). If even 0.2 quality is over 4MB, it returns the 0.2 quality data anyway.
- **Priority**: P1

### TC-125
- **Category**: Image Handling
- **Description**: Verify photo thumbnail is saved with entries from photo analysis
- **Preconditions**: Photo analysis completed and entries saved
- **Steps**:
  1. Check a saved entry's photoData
- **Expected Result**: The photo is stored as JPEG data at 0.5 compression quality. All entries from the same photo analysis share the same thumbnail data. The photo data is stored with @Attribute(.externalStorage) in SwiftData.
- **Priority**: P1

### TC-126
- **Category**: Image Handling
- **Description**: Verify entries from barcode scan have no photo data
- **Preconditions**: An entry created via barcode scanning exists
- **Steps**:
  1. Observe the entry row on the Today screen
- **Expected Result**: The entry shows an icon thumbnail (FoodIconThumbnail) instead of a photo. The photoData is nil. The icon is determined by foodIconName() keyword matching.
- **Priority**: P2

### TC-127
- **Category**: Image Handling
- **Description**: Verify ImagePicker falls back to photo library on simulator
- **Preconditions**: Running on iOS Simulator `[SIM]`
- **Steps**:
  1. Open the photo capture flow
- **Expected Result**: Since the camera is unavailable on Simulator, UIImagePickerController falls back to .photoLibrary source type. The user can select a photo from the library.
- **Priority**: P2

---

## 15. Data Model

### TC-128
- **Category**: Data Model
- **Description**: Verify FoodEntry creation with all fields
- **Preconditions**: App is running `[SIM]`
- **Steps**:
  1. Add a food entry via manual input with all fields filled
  2. Verify the entry is persisted by force-quitting and relaunching
- **Expected Result**: The entry persists across app launches. All fields (id, name, calories, proteinGrams, carbsGrams, fatGrams, date, notes, iconName, sortOrder) are correctly stored in SwiftData.
- **Priority**: P0

### TC-129
- **Category**: Data Model
- **Description**: Verify meal group relationship via mealGroupID
- **Preconditions**: A meal group has been created (via photo analysis with grouped items) `[SIM]`
- **Steps**:
  1. Expand the meal group on the Today screen
  2. Verify each child entry
- **Expected Result**: All entries in the group share the same mealGroupID (UUID). They all have the same mealName value. The groupedDisplayItems() function correctly groups them by mealGroupID.
- **Priority**: P0

### TC-130
- **Category**: Data Model
- **Description**: Verify food icon name mapping
- **Preconditions**: None `[SIM]`
- **Steps**:
  1. Add entries with various food names: "chicken breast", "grilled salmon", "banana", "coffee", "pizza", "caesar salad"
  2. Observe the icons
- **Expected Result**: "chicken breast" -> "bird" icon, "grilled salmon" -> "fish" icon, "banana" -> "carrot" icon (fruit keyword), "coffee" -> "cup.and.saucer" icon, "pizza" -> "triangle" icon, "caesar salad" -> "leaf" icon. Unknown foods default to "fork.knife".
- **Priority**: P2

### TC-131
- **Category**: Data Model
- **Description**: Verify sortOrder field for drag reorder persistence
- **Preconditions**: Entries have been reordered via drag `[SIM]`
- **Steps**:
  1. Reorder entries
  2. Navigate to History and back to Today
- **Expected Result**: Entries maintain their reordered position. The sortOrder field is an Int? that determines display order. Entries with sortOrder take precedence over those without (sorted by date).
- **Priority**: P2

### TC-132
- **Category**: Data Model
- **Description**: Verify entry deletion cascade does not affect other entries
- **Preconditions**: Multiple entries exist including some in meal groups `[SIM]`
- **Steps**:
  1. Delete a standalone entry
  2. Verify other entries and meal groups are unaffected
- **Expected Result**: Only the targeted entry is removed. Other entries, including those in meal groups, remain intact with correct data.
- **Priority**: P0

---

## 16. Edge Cases and Error Handling

### TC-133
- **Category**: Edge Cases
- **Description**: Verify app behavior with no API keys configured
- **Preconditions**: No API keys saved in Keychain `[SIM]`
- **Steps**:
  1. Try to analyze a photo
- **Expected Result**: The analysis fails with the error: "No API key configured. Please add your API key in Settings."
- **Priority**: P0

### TC-134
- **Category**: Edge Cases
- **Description**: Verify USDA service falls back to DEMO_KEY
- **Preconditions**: No USDA API key saved in Keychain `[SIM]`
- **Steps**:
  1. Add a food manually
  2. Tap AI Lookup
- **Expected Result**: The USDA lookup still works using the DEMO_KEY (limited to 30 requests/hour). Results are returned normally.
- **Priority**: P1

### TC-135
- **Category**: Edge Cases
- **Description**: Verify USDA rate limit error message (DEMO_KEY)
- **Preconditions**: No USDA API key saved. Have made 30+ requests in the last hour. `[SIM]`
- **Steps**:
  1. Trigger a USDA lookup
- **Expected Result**: Error message reads: "USDA rate limit exceeded. DEMO_KEY allows 30 requests/hour. Get a free key at fdc.nal.usda.gov/api-key-signup and add it in Settings."
- **Priority**: P2

### TC-136
- **Category**: Edge Cases
- **Description**: Verify USDA rate limit error message (custom key)
- **Preconditions**: Custom USDA API key is saved. Rate limit exceeded.
- **Steps**:
  1. Trigger a USDA lookup
- **Expected Result**: Error message reads: "USDA rate limit exceeded. Rate limit exceeded (1,000 requests/hour). Try again later."
- **Priority**: P2

### TC-137
- **Category**: Edge Cases
- **Description**: Verify network error handling for vision API
- **Preconditions**: Device is in airplane mode. Vision API key is configured.
- **Steps**:
  1. Take a photo and attempt analysis
- **Expected Result**: After a timeout, the error state shows with a "Network error: ..." message. The "Try Again" and "Cancel" buttons are available.
- **Priority**: P1

### TC-138
- **Category**: Edge Cases
- **Description**: Verify network error handling for barcode lookup
- **Preconditions**: Device is in airplane mode
- **Steps**:
  1. Scan a barcode
- **Expected Result**: An error overlay appears with "Network error: ..." message and a "Scan Again" button.
- **Priority**: P1

### TC-139
- **Category**: Edge Cases
- **Description**: Verify app in dark mode
- **Preconditions**: Device is set to dark mode `[SIM]`
- **Steps**:
  1. Navigate through all screens: Today, History, Settings, AddEntry, EditEntry, PhotoAnalysis, BarcodeScanner, Browse Foods, MealSummaryView
- **Expected Result**: All views render correctly in dark mode. Text is readable. Background colors use systemGroupedBackground and secondarySystemGroupedBackground. The floating tab bar uses ultraThinMaterial. EditEntryView dominant color uses 0.3 darken factor (vs 0.55 in light mode). Icon colors and macro colors remain vibrant.
- **Priority**: P1

### TC-140
- **Category**: Edge Cases
- **Description**: Verify app in light mode
- **Preconditions**: Device is set to light mode `[SIM]`
- **Steps**:
  1. Navigate through all screens
- **Expected Result**: All views render correctly in light mode. Text is readable. Contrast is sufficient. EditEntryView dominant color uses 0.55 darken factor.
- **Priority**: P1

### TC-141
- **Category**: Edge Cases
- **Description**: Verify portrait lock
- **Preconditions**: App launched. Device rotated to landscape.
- **Steps**:
  1. Rotate the device to landscape
- **Expected Result**: The app remains in portrait orientation. The UI does not rotate.
- **Priority**: P1

### TC-142
- **Category**: Edge Cases
- **Description**: Verify zero-calorie entry handling
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Enter "Water" as name
  2. Enter "0" as calories
  3. Save
- **Expected Result**: The entry is saved with 0 calories. It appears on the Today screen showing "0 cal". The summary card total is unaffected by this entry's calorie contribution.
- **Priority**: P2

### TC-143
- **Category**: Edge Cases
- **Description**: Verify very large calorie values
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Enter "Feast" as name
  2. Enter "99999" as calories
  3. Save
- **Expected Result**: The entry saves correctly. The summary card displays the large number without truncation. The donut chart (if targets set) shows the over-target state correctly.
- **Priority**: P2

### TC-144
- **Category**: Edge Cases
- **Description**: Verify JSON parsing with trailing commas from AI
- **Preconditions**: Vision API returns JSON with trailing commas (common AI output issue)
- **Steps**:
  1. (Code review verification) Check decodeVisionResponse function
- **Expected Result**: The function first tries standard JSON decoding. If that fails, it strips trailing commas before `}` and `]` using regex, then retries. This handles common AI formatting issues.
- **Priority**: P2

### TC-145
- **Category**: Edge Cases
- **Description**: Verify JSON extraction from markdown code blocks
- **Preconditions**: Vision API wraps response in ```json ... ``` markers
- **Steps**:
  1. (Code review verification) Check extractJSON function
- **Expected Result**: The function handles: markdown code blocks (```json ... ```), plain text with embedded JSON (extracts outermost { ... }), and raw JSON. It returns the cleaned JSON string for decoding.
- **Priority**: P2

### TC-146
- **Category**: Edge Cases
- **Description**: Verify titleCased() string extension
- **Preconditions**: None `[SIM]`
- **Steps**:
  1. (Code review) Verify "white rice".titleCased() returns "White Rice"
  2. Verify "CHICKEN BREAST".titleCased() returns "Chicken Breast"
  3. Verify "a".titleCased() returns "A"
- **Expected Result**: Each word's first letter is capitalized, rest are lowercased. Used for displaying AI-identified food names in a consistent format.
- **Priority**: P3

### TC-147
- **Category**: Edge Cases
- **Description**: Verify app handles entries from future dates (clock skew)
- **Preconditions**: An entry with a future date exists in the database `[SIM]`
- **Steps**:
  1. Navigate to the Today screen
  2. Navigate to History
- **Expected Result**: The entry does not appear on the Today screen (isDateInToday check fails). It appears in History grouped under its date. No crashes or visual issues.
- **Priority**: P3

### TC-148
- **Category**: Edge Cases
- **Description**: Verify camera permission denial for photo capture
- **Preconditions**: Camera permission has been denied for the app. Physical device.
- **Steps**:
  1. Open the photo capture flow
- **Expected Result**: The UIImagePickerController handles the permission denial gracefully. If camera is unavailable, it falls back to photo library (per the isSourceTypeAvailable check).
- **Priority**: P1

### TC-149
- **Category**: Edge Cases
- **Description**: Verify camera permission denial for barcode scanner
- **Preconditions**: Camera permission has been denied. Physical device.
- **Steps**:
  1. Open the barcode scanner
- **Expected Result**: The AVCaptureDevice.default returns nil, the capture session fails to set up, and the camera preview is blank. The guide text is still visible. The user needs to grant permission in Settings.
- **Priority**: P1

### TC-150
- **Category**: Edge Cases
- **Description**: Verify app handles OpenFoodFacts response with missing nutrition data
- **Preconditions**: Network available. Physical device.
- **Steps**:
  1. Scan a barcode for a product that exists in OpenFoodFacts but has incomplete nutrition data
- **Expected Result**: Missing nutrient values default to 0. The product still shows with its name and brand. The user can manually edit values before saving.
- **Priority**: P2

### TC-151
- **Category**: Edge Cases
- **Description**: Verify OpenFoodFacts per-serving vs per-100g fallback
- **Preconditions**: Network available
- **Steps**:
  1. (Code review) Check the OpenFoodFactsService lookup method
- **Expected Result**: The service prefers `energy-kcal_serving` when available (suffix `_serving`). If not present, it falls back to `_100g` values. Per-100g values are always captured separately for portion recalculation regardless of which mode is used.
- **Priority**: P2

### TC-152
- **Category**: Edge Cases
- **Description**: Verify Keychain service delete-before-save behavior
- **Preconditions**: An API key is already saved `[SIM]`
- **Steps**:
  1. Save a new API key for the same account
- **Expected Result**: The KeychainService.save() method first deletes the existing key, then saves the new one. This prevents duplicate entries in the Keychain.
- **Priority**: P2

### TC-153
- **Category**: Edge Cases
- **Description**: Verify vision pipeline USDA fallback to AI estimates
- **Preconditions**: USDA returns no data (empty nutrients) for a food item
- **Steps**:
  1. Analyze a photo where USDA has no match for an identified food
- **Expected Result**: The pipeline falls back to the AI-provided calorie and macro estimates from the vision response. The food still appears with values (not zero), marked with "AI Estimate" source badge.
- **Priority**: P1

### TC-154
- **Category**: Edge Cases
- **Description**: Verify concurrent USDA lookups during photo analysis
- **Preconditions**: Photo analysis identifies multiple foods
- **Steps**:
  1. Analyze a photo with 5+ food items
- **Expected Result**: The FoodAnalysisPipeline uses withTaskGroup for concurrent USDA lookups. All foods are resolved in parallel, reducing total wait time. Results maintain correct food-nutrient pairings.
- **Priority**: P2

### TC-155
- **Category**: Edge Cases
- **Description**: Verify scroll dismisses keyboard in Settings
- **Preconditions**: Settings view is displayed with keyboard open `[SIM]`
- **Steps**:
  1. Tap on a daily target field to open the keyboard
  2. Scroll the form
- **Expected Result**: The keyboard dismisses interactively as the user scrolls (scrollDismissesKeyboard(.interactively) modifier).
- **Priority**: P2

---

## 16. Capitalization Consistency

### TC-156
- **Category**: Capitalization
- **Description**: Verify names are title-cased when saving via AddEntryView
- **Preconditions**: AddEntryView is displayed `[SIM]`
- **Steps**:
  1. Enter "chicken breast" (all lowercase) as the food name
  2. Enter valid calories and tap Save
- **Expected Result**: The saved entry's name is "Chicken Breast" (title-cased via `titleCased()`).
- **Priority**: P1

### TC-157
- **Category**: Capitalization
- **Description**: Verify names are title-cased when saving via PhotoAnalysisView
- **Preconditions**: PhotoAnalysisView has identified foods `[SIM]`
- **Steps**:
  1. Tap Save to save identified foods
- **Expected Result**: All saved entries have title-cased names. `PhotoAnalysisView.saveAll()` applies `food.name.titleCased()`.
- **Priority**: P1

### TC-158
- **Category**: Capitalization
- **Description**: Verify label items from vision are also title-cased
- **Preconditions**: AI vision identifies a nutrition label item
- **Steps**:
  1. (Code review) Check `FoodAnalysisPipeline` for label items
- **Expected Result**: Label items use `item.name.titleCased()` (line 583 in FoodAnalysisService.swift). Previously label items preserved raw AI casing.
- **Priority**: P2

### TC-159
- **Category**: Capitalization
- **Description**: Verify barcode product names are title-cased
- **Preconditions**: Barcode is scanned and product is found
- **Steps**:
  1. (Code review) Check OpenFoodFactsService display name generation
- **Expected Result**: `displayName` uses `.titleCased()` instead of `.capitalized` for consistent behavior across all entry points.
- **Priority**: P2

### TC-160
- **Category**: Capitalization
- **Description**: Verify one-time historic entry name migration
- **Preconditions**: App has existing entries with inconsistent casing `[SIM]`
- **Steps**:
  1. Launch the app for the first time after the update
- **Expected Result**: `FoodTrackerApp.migrateEntryNames()` runs once (tracked by `didMigrateEntryNameCasing` UserDefaults key), title-casing all existing entry names and meal names. Subsequent launches skip the migration.
- **Priority**: P0

### TC-161
- **Category**: Capitalization
- **Description**: Verify EditEntryView title-cases name on Done
- **Preconditions**: EditEntryView is in editing mode `[SIM]`
- **Steps**:
  1. Change the food name to "grilled salmon"
  2. Tap Done (finish editing)
- **Expected Result**: The name is title-cased to "Grilled Salmon" and the icon is updated via `foodIconName()`.
- **Priority**: P1

---

## 17. Edit Entry — Cancel Button

### TC-162
- **Category**: Edit Entry Cancel
- **Description**: Verify Cancel button appears in editing mode
- **Preconditions**: EditEntryView is displayed, tap Edit `[SIM]`
- **Steps**:
  1. Tap the Edit button
  2. Observe the floating buttons
- **Expected Result**: Two floating buttons appear: "Cancel" on the left and "Done" on the right. The edit form is visible below.
- **Priority**: P0

### TC-163
- **Category**: Edit Entry Cancel
- **Description**: Verify Cancel reverts all changes
- **Preconditions**: EditEntryView is in editing mode `[SIM]`
- **Steps**:
  1. Change the name from "Chicken" to "Fish"
  2. Change calories from 200 to 500
  3. Change protein from 30 to 10
  4. Tap Cancel
- **Expected Result**: Name reverts to "Chicken", calories to 200, protein to 30. The edit form disappears. The hero section displays the original values.
- **Priority**: P0

### TC-164
- **Category**: Edit Entry Cancel
- **Description**: Verify Done preserves changes and title-cases
- **Preconditions**: EditEntryView is in editing mode `[SIM]`
- **Steps**:
  1. Change the name to "grilled chicken"
  2. Change calories to 300
  3. Tap Done
- **Expected Result**: Name becomes "Grilled Chicken" (title-cased). Calories stay at 300. Changes persist in SwiftData.
- **Priority**: P0

### TC-165
- **Category**: Edit Entry Cancel
- **Description**: Verify original values are captured on edit start
- **Preconditions**: Entry has name="Pasta", calories=400, protein=15 `[SIM]`
- **Steps**:
  1. Tap Edit, then immediately tap Cancel without making changes
- **Expected Result**: Entry remains unchanged: name="Pasta", calories=400, protein=15.
- **Priority**: P1

---

## 18. Edit Entry — Barcode Scan

### TC-166
- **Category**: Edit Barcode Scan
- **Description**: Verify Scan Barcode button appears in edit mode
- **Preconditions**: EditEntryView is in editing mode `[SIM]`
- **Steps**:
  1. Scroll down to the lookup section
- **Expected Result**: Two options visible: "AI Lookup" with sparkles icon and "Scan Barcode" with barcode.viewfinder icon, separated by a divider.
- **Priority**: P0

### TC-167
- **Category**: Edit Barcode Scan
- **Description**: Verify barcode scan opens scanner sheet
- **Preconditions**: EditEntryView is in editing mode. Physical device.
- **Steps**:
  1. Tap "Scan Barcode"
- **Expected Result**: `EditBarcodeScannerView` opens as a sheet with camera preview, "Point camera at a barcode" guide text, and a Cancel button.
- **Priority**: P0

### TC-168
- **Category**: Edit Barcode Scan
- **Description**: Verify successful barcode scan populates entry fields
- **Preconditions**: EditBarcodeScannerView is open. Physical device. Network available.
- **Steps**:
  1. Scan a known product barcode
- **Expected Result**: The scanner haptic fires, "Looking up product..." appears, the product is found via OpenFoodFacts, the scanner dismisses, and the entry's name, calories, protein, carbs, and fat are updated with the scanned product's values. The icon is also updated via `foodIconName()`.
- **Priority**: P0

### TC-169
- **Category**: Edit Barcode Scan
- **Description**: Verify barcode scan error shows retry option
- **Preconditions**: EditBarcodeScannerView is open. Physical device.
- **Steps**:
  1. Scan a barcode for a product not in OpenFoodFacts
- **Expected Result**: Error overlay shows "Product not found in database." with a warning icon and "Scan Again" button. Tapping Scan Again resets the scanner to accept a new barcode.
- **Priority**: P1

### TC-170
- **Category**: Edit Barcode Scan
- **Description**: Verify Cancel dismisses barcode scanner without changes
- **Preconditions**: EditBarcodeScannerView is open. Physical device.
- **Steps**:
  1. Tap Cancel
- **Expected Result**: The scanner sheet dismisses. The entry's values remain unchanged.
- **Priority**: P1

---

## 19. Drag-and-Drop Stability

### TC-171
- **Category**: Drag Reorder
- **Description**: Verify initial sortOrders are assigned on first load
- **Preconditions**: Today has multiple entries, some with nil sortOrder `[SIM]`
- **Steps**:
  1. Open the Today screen
- **Expected Result**: `assignInitialSortOrders()` runs on appear, assigning sequential `sortOrder` values to entries that have nil. Entries with existing sortOrder keep their values.
- **Priority**: P1

### TC-172
- **Category**: Drag Reorder
- **Description**: Verify drag-and-drop reorders entries correctly
- **Preconditions**: Today has 3+ standalone entries `[SIM]`
- **Steps**:
  1. Long-press an entry to start dragging
  2. Move it above or below another entry
  3. Release
- **Expected Result**: The entry moves to the new position smoothly. Other entries shift to accommodate. After release, all entries have unique sequential sortOrder values. Items do not disappear or jump.
- **Priority**: P0

### TC-173
- **Category**: Drag Reorder
- **Description**: Verify meal group entries get contiguous sortOrders
- **Preconditions**: Today has a meal group and standalone entries `[SIM]`
- **Steps**:
  1. Drag the meal group to a new position
- **Expected Result**: All entries within the meal group receive contiguous sequential sortOrder values (each entry gets its own value, incrementing). The group moves as a unit.
- **Priority**: P1

---

## 20. History Performance Tile

### TC-174
- **Category**: History Performance
- **Description**: Verify performance tile appears when entries exist
- **Preconditions**: At least one food entry exists. History tab selected `[SIM]`
- **Steps**:
  1. Open the History tab
- **Expected Result**: A performance tile appears at the top with "Performance" heading, a segmented picker (Week/Month/Year), a bar chart, and macro summary. Default selection is "Week".
- **Priority**: P0

### TC-175
- **Category**: History Performance
- **Description**: Verify performance tile is hidden when no entries
- **Preconditions**: No food entries in the database `[SIM]`
- **Steps**:
  1. Open the History tab
- **Expected Result**: The performance tile does not appear. The "No History" empty state is shown instead.
- **Priority**: P1

### TC-176
- **Category**: History Performance
- **Description**: Verify Week view shows 7 daily bars
- **Preconditions**: Entries exist for the past 7 days. Daily targets set `[SIM]`
- **Steps**:
  1. Select "Week" in the segmented picker
- **Expected Result**: 7 bars appear (Mon–Sun labels, or "Today" for the current day). Each bar shows the day's total calories. A dashed horizontal rule marks the calorie target. Bars exceeding the target are red-tinted; others are accent-colored.
- **Priority**: P0

### TC-177
- **Category**: History Performance
- **Description**: Verify Month view shows 4 weekly bars
- **Preconditions**: Entries exist for the past month `[SIM]`
- **Steps**:
  1. Select "Month" in the segmented picker
- **Expected Result**: 4 bars appear with "MMM d" labels (week start dates). Each bar shows the daily average calories for that week. The target line represents the daily calorie target.
- **Priority**: P1

### TC-178
- **Category**: History Performance
- **Description**: Verify Year view shows 12 monthly bars
- **Preconditions**: Entries exist for the past year `[SIM]`
- **Steps**:
  1. Select "Year" in the segmented picker
- **Expected Result**: 12 bars appear with month abbreviation labels (Jan, Feb, ...). Each bar shows the daily average calories for that month.
- **Priority**: P1

### TC-179
- **Category**: History Performance
- **Description**: Verify daily average macro summary with targets
- **Preconditions**: Daily targets are set. Entries exist for the week `[SIM]`
- **Steps**:
  1. Select "Week" and observe the macro summary below the chart
- **Expected Result**: "Daily Average" label appears with pills showing: Cal (value/target), P (value/target), C (value/target), F (value/target). Each shows a percentage. Percentages between 90-110% are green; others are secondary.
- **Priority**: P1

### TC-180
- **Category**: History Performance
- **Description**: Verify chart without targets set
- **Preconditions**: No daily targets set (all zero). Entries exist `[SIM]`
- **Steps**:
  1. Open History tab
- **Expected Result**: The bar chart shows calorie bars without a dashed target line. No red bars. The macro summary section is not shown.
- **Priority**: P2

---

## Summary

| Priority | Count | Description |
|----------|-------|-------------|
| P0       | 46    | Critical functionality - must work for the app to be usable |
| P1       | 66    | High importance - core features that should work correctly |
| P2       | 47    | Medium importance - edge cases and polish |
| P3       | 8     | Low importance - minor UI details and uncommon scenarios |
| **Total**| **167** | |

### Testing Notes

- **Physical device required**: Tests involving camera (TC-029 through TC-051, TC-123-124, TC-148-149, TC-167-170) require a physical iOS device. Barcode scanning is not possible on the simulator.
- **`[SIM]` marker**: Tests marked with `[SIM]` can be executed on the iOS Simulator.
- **API keys**: Many tests require valid API keys (Claude/Gemini for vision, USDA for nutrition lookup). Configure these in Settings before running those tests.
- **Network dependency**: Tests involving USDA lookup, OpenFoodFacts, or vision API calls require network connectivity.
- **Dark/Light mode**: Appearance tests (TC-139, TC-140) should be run in both modes by toggling in iOS Settings or Simulator.
- **Widget testing**: Widget tests require adding the FoodTrackerWidgetExtension widget to the home screen and verifying App Group entitlements are correctly configured.
