# Macro Tracker — Premium Redesign Spec
**Target:** iOS · SwiftUI · Athlete-first · Dark, single-theme

---

## 1. Design Philosophy

The current app communicates data. The redesign should make the user **feel** their progress. Every screen should answer one question instantly without the user having to parse anything.

Inspiration axis: Oura's depth and restraint + Apple Fitness+'s energy.

Three principles:
- **Clarity over clutter.** One dominant number per screen zone. Everything else is supporting cast.
- **Depth, not flatness.** Layered surfaces, not cards sitting on white.
- **Color with intention.** Three macro colors are sacred. Everything else is near-monochrome.

---

## 2. Color System

### Base Palette

```swift
// Background layers — always dark, never pure black
BackgroundPrimary:   #0A0D12   // deepest layer — screen bg
BackgroundSecondary: #12161E   // cards, sheets
BackgroundElevated:  #1A1F2B   // modals, pickers, overlays
BackgroundSubtle:    #1F2535   // inline inputs, table rows

// Borders
BorderSubtle:        rgba(255,255,255, 0.06)
BorderStrong:        rgba(255,255,255, 0.12)

// Text
TextPrimary:         #F0F3FA   // headlines, key numbers
TextSecondary:       #8892A4   // labels, subtext
TextTertiary:        #4E566A   // placeholder, disabled

// Macro colors — sacred, never change meaning
Protein:             #4D8CF5   // blue
Carbs:               #F5A623   // amber (warmer than current orange)
Fat:                 #A776F5   // violet

// System accents
AccentSuccess:       #34C77B   // on-target, streaks
AccentWarning:       #F5A623   // over on carbs/fat (shares with Carbs intentionally)
AccentDanger:        #F05A5A   // significantly over goal

// Glow colors (used only in ring/progress shadows)
GlowProtein:         rgba(77, 140, 245, 0.35)
GlowCarbs:           rgba(245, 166, 35, 0.35)
GlowFat:             rgba(167, 118, 245, 0.35)
GlowCalorie:         rgba(77, 140, 245, 0.20)
```

### Gradient Definitions

```swift
// Main calorie ring gradient — goes from protein-blue to fat-violet
CalorieRingGradient: AngularGradient(
    colors: [#4D8CF5, #A776F5, #4D8CF5],
    center: .center
)

// Card shimmer background (very subtle)
CardShimmer: LinearGradient(
    colors: [#1A1F2B, #1F2535],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Hero section bg — very subtle radial glow behind ring
HeroGlow: RadialGradient(
    colors: [rgba(77,140,245,0.08), .clear],
    center: .center,
    startRadius: 0,
    endRadius: 200
)
```

---

## 3. Typography System

Use **SF Pro Display** for all large numbers and **SF Pro Rounded** for labels and pill text. Both are built into iOS — no imports needed.

```swift
// Scale
DisplayXL:    Font.system(size: 72, weight: .bold, design: .default)   // not used yet, reserved
DisplayL:     Font.system(size: 56, weight: .bold, design: .default)    // main calorie number
DisplayM:     Font.system(size: 36, weight: .semibold, design: .default)// section totals
NumberL:      Font.system(size: 24, weight: .semibold, design: .rounded) // macro gram values
NumberM:      Font.system(size: 17, weight: .medium, design: .rounded)   // food item calories
LabelL:       Font.system(size: 15, weight: .medium, design: .rounded)   // macro labels
LabelM:       Font.system(size: 13, weight: .medium, design: .rounded)   // secondary labels
LabelS:       Font.system(size: 11, weight: .semibold, design: .rounded) // caps labels, e.g. "MORNING"
Caption:      Font.system(size: 12, weight: .regular, design: .rounded)  // timestamps, sub-items

// All numbers in tables and rings use .monospacedDigit() modifier
// to prevent layout jitter as values change
```

---

## 4. Spacing & Layout

```swift
// Spacing tokens
SpaceXS:  4
SpaceS:   8
SpaceM:   16
SpaceL:   24
SpaceXL:  32
SpaceXXL: 48

// Corner radii
RadiusS:  10
RadiusM:  16
RadiusL:  24
RadiusXL: 32  // full-rounded pill: height/2

// Screen horizontal padding
ScreenEdge: 20

// Card inner padding
CardPaddingH: 16
CardPaddingV: 14
```

---

## 5. Component Library

### 5.1 The Base Card

All cards share the same substrate. Never use `.white` or system gray backgrounds.

```swift
struct AppCard<Content: View>: View {
    var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "12161E"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
    }
}
```

### 5.2 Macro Pill

Replaces the current inline "183P · 220C · 83F" text. Three distinct pill chips.

```swift
struct MacroPill: View {
    let value: Int
    let goal: Int
    let unit: String        // "P", "C", "F"
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(color.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        // If over goal: background becomes color.opacity(0.22), add subtle ring
    }
}
```

### 5.3 Gradient Progress Ring

The centerpiece of the Today screen. Replaces the flat colored donut.

```swift
struct CalorieRing: View {
    let consumed: Int
    let goal: Int
    let lineWidth: CGFloat = 18

    var progress: Double { min(Double(consumed) / Double(goal), 1.0) }

    var body: some View {
        ZStack {
            // Track (background ring)
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: lineWidth)

            // Glow layer (blur duplicate underneath)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: "4D8CF5"), Color(hex: "A776F5")],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: 8)
                .opacity(0.5)

            // Actual ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: "4D8CF5"), Color(hex: "A776F5")],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progress)

            // Center content
            VStack(spacing: 2) {
                Text("\(consumed)")
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundColor(Color(hex: "F0F3FA"))
                Text("/ \(goal) cal")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "8892A4"))
                Text("\(goal - consumed) left")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "4D8CF5"))
            }
        }
    }
}
```

### 5.4 Macro Arc Indicators

Sits below the main ring. Three compact arcs, one per macro. Replaces the flat progress bars.

```swift
struct MacroArc: View {
    let label: String
    let current: Int
    let goal: Int
    let color: Color
    let arcSize: CGFloat = 64

    var progress: Double { min(Double(current) / Double(goal), 1.0) }
    var isOver: Bool { current > goal }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 5)
                    .frame(width: arcSize, height: arcSize)

                // Fill — turns danger color if over
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isOver ? Color(hex: "F05A5A") : color,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: arcSize, height: arcSize)
                    .shadow(color: color.opacity(0.4), radius: 4)

                VStack(spacing: 0) {
                    Text("\(current)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(isOver ? Color(hex: "F05A5A") : Color(hex: "F0F3FA"))
                    Text("g")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "8892A4"))
                }
            }

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "8892A4"))
                .textCase(.uppercase)
                .tracking(0.5)

            Text("/ \(goal)g")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(Color(hex: "4E566A"))
        }
    }
}
```

### 5.5 Food Entry Row

Replaces the current flat list rows. Each row has a left icon zone, name, macro pills, and calorie count.

```swift
struct FoodRow: View {
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let image: Image?  // optional — from AI vision capture

    var body: some View {
        HStack(spacing: 12) {
            // Icon zone
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 44, height: 44)

                if let image = image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "4E566A"))
                }
            }

            // Name + macro pills
            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundColor(Color(hex: "F0F3FA"))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    MacroPill(value: protein, goal: 999, unit: "P", color: Color(hex: "4D8CF5"))
                    MacroPill(value: carbs,   goal: 999, unit: "C", color: Color(hex: "F5A623"))
                    MacroPill(value: fat,     goal: 999, unit: "F", color: Color(hex: "A776F5"))
                }
            }

            Spacer()

            Text("\(calories)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Color(hex: "F0F3FA"))
        }
        .padding(.vertical, 4)
    }
}
```

### 5.6 Meal Section Header

Replaces the current icon + "Morning" label. More structured, shows meal subtotals.

```swift
struct MealSectionHeader: View {
    let title: String        // "Morning", "Afternoon", "Evening"
    let icon: String         // SF Symbol name
    let totalCalories: Int
    let totalProtein: Int

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "8892A4"))
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "8892A4"))
                    .tracking(0.8)
            }
            Spacer()
            Text("\(totalCalories) cal")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Color(hex: "4E566A"))
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }
}
```

### 5.7 Tab Bar

Custom tab bar — do not use the system `TabView` default appearance.

```swift
// Tab bar sits on a frosted glass base
// Background: ultraThinMaterial tinted with BackgroundPrimary at 0.7 opacity
// Active icon: filled SF symbol, AccentColor (Protein blue)
// Inactive icon: outlined SF symbol, TextTertiary
// The center "+" button is a 56pt circle, gradient fill (Protein → Fat gradient), 
//   shadow: Color(hex:"4D8CF5").opacity(0.4), radius: 12

// Icons:
// Today:   "fork.knife" / "fork.knife" (filled)
// History: "chart.bar" / "chart.bar.fill"
// Add:     "plus" (always centered, always full gradient)
// Settings:"gearshape" / "gearshape.fill"
```

---

## 6. Screen-by-Screen Specifications

### 6.1 Today Screen

**Layout top → bottom:**

```
[Status Bar]

[Screen Title Area]
  "Today"  — DisplayM weight, TextPrimary
  Subtitle: Day + date in LabelM, TextSecondary
  Right side: Avatar/profile icon (future)

[Hero Card — full width, SpaceM horizontal margins]
  Background: CardShimmer gradient
  Border: BorderSubtle
  Corner: RadiusXL (24)
  
  Inside:
    [Radial glow layer — very subtle blue behind ring, see HeroGlow]
    
    [CalorieRing — 200pt diameter]
    
    [Macro Arcs Row — HStack evenly spaced]
      MacroArc(Protein, blue)
      MacroArc(Carbs, amber)
      MacroArc(Fat, violet)
    
    SpaceM bottom padding

[Meal Sections — scrollable, no dividers between sections]
  Each section:
    MealSectionHeader (Morning / Afternoon / Evening)
    AppCard {
      VStack(spacing: 0) {
        ForEach(items) { item in
          FoodRow(...)
          if notLast { Divider().overlay(Color.white.opacity(0.06)) }
        }
      }
    }
    SpaceM between sections

[Bottom safe area padding for custom tab bar]
```

**Specific behavior notes:**
- On scroll, the hero card collapses: ring shrinks to 36pt inline circle with calorie count. This appears in the navigation bar area. Use `ScrollViewReader` + `GeometryReader` to detect scroll offset and drive this with an animation.
- Pull to refresh re-fetches today's data.
- Long press on any `FoodRow` → context menu: Edit, Delete, Copy to Meal.

---

### 6.2 History Screen

**The current bar chart is the biggest visual problem.** Replace it entirely.

**Weekly Performance Section:**

```
[Weekly Ring Row]
  7 circles in an HStack, one per day (S M T W T F S)
  Each circle: 36pt
    - Filled with CalorieRingGradient if on target
    - Filled AccentDanger if significantly over
    - Outlined (BorderStrong) if under/logged
    - Gray if no data
  Below each: day letter, TextTertiary, LabelS
  
  Current day has a subtle white dot below it

[Summary Row below rings]
  Left:  "6 of 7 on target" — LabelM, TextSecondary
  Right: "86%" — NumberL, AccentSuccess (green)

[Avg deficit line]
  "↓ 191 cal/day avg" — small, TextTertiary, with a tiny downward arrow SF symbol
```

**Monthly View:**

Replace the 4-dot (W1/W2/W3/W4) row with a proper calendar grid:

```
[Month name + year] — centered, bold
[7 column day grid — S M T W T F S headers]
[Day cells: small circles, color-coded by performance]
  - Green gradient circle: on target
  - Red outline: missed / significantly over
  - Gray dot: logged but off
  - Empty: no data
```

**Daily History List:**

```
Each day row (tap to expand):
  Left:  Date in NumberM weight
  Right: Total cal in NumberM + macro pills (P/C/F chips)
  
  Expanded: slides open to show FoodRow items, same as Today screen
  Transition: spring animation, no abrupt jump

  [Left edge accent bar — 3pt wide, full height of card]
    Color: AccentSuccess if on target, AccentDanger if significantly over, 
           TextTertiary if no goal data
```

---

### 6.3 Food Detail Sheet (Couscous, Protein Shake, etc.)

This is currently a full-screen modal. Keep it as a sheet but redesign:

```
[Hero image — full bleed, top of sheet]
  Height: 260pt
  Gradient overlay from transparent → BackgroundSecondary (bottom 40%)
  
  [Food name overlaid at bottom of image]
    DisplayM weight, TextPrimary
    Shadow for legibility

[Macro summary row — just below image]
  Four chips in an HStack:
    Calorie chip: gray background
    Protein chip: blue background (MacroPill style but larger — 16pt text)
    Carbs chip: amber
    Fat chip: violet

[Macro donut — 120pt, same gradient style as CalorieRing]
  Centered, with percentage legend to the right

[% of Daily Goal Section]
  Card with four rows: Cal / Protein / Carbs / Fat
  Each row: label left, slim progress bar (6pt height, rounded), percentage right
  Bar colors match macro colors
  Bar track: Color.white.opacity(0.08)

[Serving & Time]
  "1 × 3/4 cup cooked (528g)" — LabelM, TextSecondary
  "Today at 11:44 AM" — Caption, TextTertiary

[Action buttons]
  Edit (ghost button) | Delete (ghost, danger color)
```

---

### 6.4 Settings Screen

The current settings screen is pure form. It doesn't need to be exciting, but it should match the design language.

```
[Provider Section]
  Card with row: "Vision Provider" label + "Claude Sonnet 4.6" value + chevron
  
[API Keys Section]  
  Use SecureField with eye toggle
  Save button: full-width, gradient fill (primary action style)
  
[Account Section]
  Username row

[Appearance Section — ADD THIS]
  This screen should have toggleable options:
  - Accent color picker (offer 4 presets — default blue, teal, amber, rose)
  - Calorie display: "remaining" vs "consumed" in ring center
  - Show macro grams vs percentages on Today pills

[General]
  Standard rows with chevron: About, Privacy, etc.

All section headers:
  Text in LabelS, TextTertiary, .uppercase, tracking(0.8)
  No background header boxes — just the text above each card group
```

---

### 6.5 Food Add Flow (the "+" button)

Not visible in screenshots but critical to redesign:

```
[Bottom sheet rises — not a full modal push]
  Sheet has three large action tiles in a grid:
  
  [Camera / Scan]   [Search]   [Manual Entry]
  
  Each tile: AppCard with centered SF symbol (32pt) + label below
  Symbol color: AccentColor
  
  Recently logged items appear below as FoodRow entries 
  (quick re-log without searching)
```

---

## 7. Animation Specifications

These are non-negotiable for the premium feel. SwiftUI can handle all of them natively.

| Interaction | Animation |
|---|---|
| App launch → Today screen | Ring draws from 0% with `spring(response: 1.2, dampingFraction: 0.75)` |
| New food logged | Counter animates up, ring arc extends, use `withAnimation` on the value change |
| Meal section expand/collapse | `.spring(response: 0.45, dampingFraction: 0.82)` height animation |
| Sheet presentation | `.interactiveDismissDisabled(false)`, custom detent at 85% screen height |
| Food row swipe-to-delete | Standard but with AccentDanger background revealed |
| Over-goal state | Macro arc pulses once (scale 1.0 → 1.04 → 1.0) when it crosses 100% |
| Day circle tap in History | Scale spring: `scaleEffect(isSelected ? 1.15 : 1.0)` |
| Tab switch | SF symbols animate between outline and filled with `.symbolEffect(.bounce)` |

---

## 8. SwiftUI Implementation Notes

### Color Extension
```swift
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

### Design Tokens File
Create `DesignSystem.swift` as a single source of truth:

```swift
enum DS {
    enum Color {
        static let backgroundPrimary   = SwiftUI.Color(hex: "0A0D12")
        static let backgroundSecondary = SwiftUI.Color(hex: "12161E")
        static let backgroundElevated  = SwiftUI.Color(hex: "1A1F2B")
        static let textPrimary         = SwiftUI.Color(hex: "F0F3FA")
        static let textSecondary       = SwiftUI.Color(hex: "8892A4")
        static let textTertiary        = SwiftUI.Color(hex: "4E566A")
        static let protein             = SwiftUI.Color(hex: "4D8CF5")
        static let carbs               = SwiftUI.Color(hex: "F5A623")
        static let fat                 = SwiftUI.Color(hex: "A776F5")
        static let success             = SwiftUI.Color(hex: "34C77B")
        static let danger              = SwiftUI.Color(hex: "F05A5A")
        static let border              = SwiftUI.Color.white.opacity(0.07)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s:  CGFloat = 8
        static let m:  CGFloat = 16
        static let l:  CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let s:  CGFloat = 10
        static let m:  CGFloat = 16
        static let l:  CGFloat = 24
    }
}
```

### App-Wide Setup
In your `App.swift` or root view:

```swift
.preferredColorScheme(.dark)                       // Force dark always
.tint(DS.Color.protein)                            // System tint = protein blue
.background(DS.Color.backgroundPrimary)
```

### The `.appCard()` ViewModifier
```swift
struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(DS.Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                            .strokeBorder(DS.Color.border, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func appCard() -> some View { modifier(AppCardModifier()) }
}
```

---

## 9. What NOT to Do

These are existing patterns to eliminate entirely:

| Current | Replace with |
|---|---|
| White card backgrounds | `DS.Color.backgroundSecondary` |
| Flat donut chart | Gradient `CalorieRing` with glow |
| "183P · 220C · 83F" inline text | `MacroPill` chips |
| Flat horizontal progress bars | `MacroArc` circles |
| Bar chart in History | Day-circle ring row |
| System gray section headers | Uppercase `LabelS` tracking text |
| System tab bar default | Custom frosted glass tab bar |
| Purple/blue/orange donut on food detail | Gradient donut matching main ring style |
| Plain `List` style rows | `AppCard` + `FoodRow` components |

---

## 10. Priority Order for Implementation

If shipping incrementally, attack in this order:

1. **`DesignSystem.swift`** — tokens file, zero visual change, zero risk
2. **Force dark + background color** — immediate perceived quality jump
3. **`CalorieRing` + `MacroArc`** — Today screen hero, highest visibility
4. **`AppCard` modifier + `FoodRow`** — replaces all list rows across the app
5. **`MacroPill` chip** — small but everywhere
6. **Custom tab bar**
7. **History screen** — day circles + expanded day cards
8. **Food detail sheet** — hero image treatment
9. **Settings screen** — last, least impactful

---

*End of spec. Every component described here is implementable in SwiftUI with no third-party dependencies.*
