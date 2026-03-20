import WidgetKit
import SwiftUI

// MARK: - Widget Design Tokens (mirrors DS from main app)

// IMPORTANT: Hex values must match DS.Color in DesignSystem.swift
private enum W {
    private static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: trimmed).scanHexInt64(&int)
            let r = CGFloat((int >> 16) & 0xFF) / 255
            let g = CGFloat((int >> 8) & 0xFF) / 255
            let b = CGFloat(int & 0xFF) / 255
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
    }

    private static func adaptiveOpacity(lightBase: UIColor, lightAlpha: CGFloat, darkBase: UIColor, darkAlpha: CGFloat) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? darkBase.withAlphaComponent(darkAlpha)
                : lightBase.withAlphaComponent(lightAlpha)
        })
    }

    static let bgStart       = adaptive(light: "FFFFFF", dark: "1A1F2B")
    static let bgEnd         = adaptive(light: "F0F0F5", dark: "1F2535")
    static let textPrimary   = adaptive(light: "1C1C1E", dark: "F0F3FA")
    static let textSecondary = adaptive(light: "6C6C70", dark: "9BA3B5")
    static let textTertiary  = adaptive(light: "AEAEB2", dark: "4E566A")
    static let protein       = adaptive(light: "3478F6", dark: "4D8CF5")
    static let carbs         = adaptive(light: "E09500", dark: "F5A623")
    static let fat           = adaptive(light: "8F5DE0", dark: "A776F5")
    static let danger        = adaptive(light: "D93030", dark: "F05A5A")
    static let ringTrack     = adaptiveOpacity(lightBase: .black, lightAlpha: 0.06, darkBase: .white, darkAlpha: 0.06)
    static let overlayText   = adaptive(light: "1C1C1E", dark: "FFFFFF")
}

private let widgetAppGroupID = "group.com.DNT.foodtracker"

// MARK: - Timeline Entry

struct FoodTrackerEntry: TimelineEntry {
    let date: Date
    let calories: Int
    let calorieTarget: Int
    let protein: Double
    let proteinTarget: Double
    let carbs: Double
    let carbsTarget: Double
    let fat: Double
    let fatTarget: Double

    static var placeholder: FoodTrackerEntry {
        FoodTrackerEntry(
            date: .now,
            calories: 1200, calorieTarget: 2000,
            protein: 80, proteinTarget: 120,
            carbs: 150, carbsTarget: 250,
            fat: 40, fatTarget: 65
        )
    }
}

// MARK: - Timeline Provider

struct FoodTrackerProvider: TimelineProvider {
    func placeholder(in context: Context) -> FoodTrackerEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (FoodTrackerEntry) -> Void) {
        completion(context.isPreview ? .placeholder : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FoodTrackerEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> FoodTrackerEntry {
        let defaults = UserDefaults(suiteName: widgetAppGroupID) ?? .standard

        let lastSync = defaults.double(forKey: "widgetLastSync")
        let isToday = Calendar.current.isDateInToday(Date(timeIntervalSince1970: lastSync))

        return FoodTrackerEntry(
            date: .now,
            calories: isToday ? defaults.integer(forKey: "widgetCalories") : 0,
            calorieTarget: defaults.integer(forKey: "calorieTarget"),
            protein: isToday ? defaults.double(forKey: "widgetProtein") : 0,
            proteinTarget: Double(defaults.integer(forKey: "proteinTarget")),
            carbs: isToday ? defaults.double(forKey: "widgetCarbs") : 0,
            carbsTarget: Double(defaults.integer(forKey: "carbsTarget")),
            fat: isToday ? defaults.double(forKey: "widgetFat") : 0,
            fatTarget: Double(defaults.integer(forKey: "fatTarget"))
        )
    }
}

// MARK: - Widget View

struct FoodTrackerWidgetView: View {
    let entry: FoodTrackerEntry

    private var macroSegments: [(label: String, value: Double, target: Double, color: Color)] {
        [
            ("Protein", entry.protein, entry.proteinTarget, W.protein),
            ("Carbs", entry.carbs, entry.carbsTarget, W.carbs),
            ("Fat", entry.fat, entry.fatTarget, W.fat),
        ].filter { $0.target > 0 }
    }

    var body: some View {
        HStack(spacing: 12) {
            miniCalorieRing

            if !macroSegments.isEmpty {
                macroBarSection
            } else {
                macroPillSection
            }

            // Add button column
            VStack {
                Spacer()
                addButton
            }
        }
        .widgetURL(URL(string: "foodtracker://open"))
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(
                    colors: [W.bgStart, W.bgEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [W.protein.opacity(0.06), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 200
                )
            }
        }
    }

    // MARK: - Calorie Ring

    private var miniCalorieRing: some View {
        let progress: Double = entry.calorieTarget > 0
            ? min(Double(entry.calories) / Double(entry.calorieTarget), 1.0)
            : 0
        let remaining = entry.calorieTarget - entry.calories

        return ZStack {
            // Track
            Circle()
                .stroke(W.ringTrack, lineWidth: 8)

            // Progress arc with gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [W.protein, W.protein, W.fat, W.fat],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(max(360 * progress, 1))
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: W.protein.opacity(0.5), radius: 6)
                .shadow(color: W.fat.opacity(0.3), radius: 8)

            // Center text
            VStack(spacing: 1) {
                Text("\(entry.calories)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(W.textPrimary)
                    .minimumScaleFactor(0.7)

                if entry.calorieTarget > 0 {
                    Text("\(abs(remaining)) \(remaining >= 0 ? "left" : "over")")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(remaining >= 0 ? W.protein : W.danger)
                } else {
                    Text("cal")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(W.textSecondary)
                }
            }
        }
        .frame(width: 90, height: 90)
    }

    // MARK: - Macro Progress Bars (targets set)

    private var macroBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(macroSegments, id: \.label) { segment in
                macroProgressBar(
                    label: segment.label,
                    value: segment.value,
                    target: segment.target,
                    color: segment.color
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macroProgressBar(label: String, value: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 0) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(W.textSecondary)
                Spacer()
                Text("\(Int(value))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text("/\(Int(target))g")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(W.textTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(value / max(target, 1), 1.0))
                        .shadow(color: color.opacity(0.3), radius: 3)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Macro Pills (no targets)

    private var macroPillSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                macroPill(value: Int(entry.protein), unit: "P", color: W.protein)
                macroPill(value: Int(entry.carbs), unit: "C", color: W.carbs)
                macroPill(value: Int(entry.fat), unit: "F", color: W.fat)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func macroPill(value: Int, unit: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(color.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Add Button

    private var addButton: some View {
        Link(destination: URL(string: "foodtracker://add")!) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(W.overlayText)
                .frame(width: 28, height: 28)
                .background(
                    LinearGradient(
                        colors: [W.protein, W.fat],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: W.protein.opacity(0.4), radius: 4, y: 2)
        }
    }
}

// MARK: - Widget Configuration

struct FoodTrackerWidget: Widget {
    let kind = "FoodTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FoodTrackerProvider()) { entry in
            FoodTrackerWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Summary")
        .description("Track your calories and macros at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct FoodTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        FoodTrackerWidget()
    }
}
