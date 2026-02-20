import WidgetKit
import SwiftUI
import Charts

let widgetAppGroupID = "group.com.DNT.foodtracker"

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

        // Check if synced data is from today
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

    private var macroSegments: [(name: String, value: Double, target: Double, color: Color)] {
        [
            ("Protein", entry.protein, entry.proteinTarget, .blue),
            ("Carbs", entry.carbs, entry.carbsTarget, .orange),
            ("Fat", entry.fat, entry.fatTarget, .purple),
        ].filter { $0.target > 0 }
    }

    private var hasTargets: Bool {
        entry.calorieTarget > 0 || !macroSegments.isEmpty
    }

    var body: some View {
        if hasTargets {
            targetView
        } else {
            noTargetView
        }
    }

    private var targetView: some View {
        HStack(spacing: 16) {
            // Donut chart
            ZStack {
                if !macroSegments.isEmpty {
                    Chart(macroSegments, id: \.name) { segment in
                        SectorMark(
                            angle: .value(segment.name, min(segment.value, segment.target)),
                            innerRadius: .ratio(0.7),
                            angularInset: 2
                        )
                        .foregroundStyle(segment.color)

                        let remaining = max(0, segment.target - segment.value)
                        if remaining > 0 {
                            SectorMark(
                                angle: .value("\(segment.name) Rem", remaining),
                                innerRadius: .ratio(0.7),
                                angularInset: 2
                            )
                            .foregroundStyle(segment.color.opacity(0.15))
                        }
                    }
                    .chartLegend(.hidden)
                }

                VStack(spacing: 1) {
                    Text("\(entry.calories)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                    if entry.calorieTarget > 0 {
                        let remaining = entry.calorieTarget - entry.calories
                        Text("\(abs(remaining)) \(remaining >= 0 ? "left" : "over")")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
                    }
                }
            }
            .frame(maxWidth: 120, maxHeight: .infinity)

            // Macro stats
            VStack(alignment: .leading, spacing: 8) {
                if entry.calorieTarget > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("\(entry.calories) / \(entry.calorieTarget) cal")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                ForEach(macroSegments, id: \.name) { segment in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(segment.name)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(segment.value))/\(Int(segment.target))g")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(segment.color)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(segment.color.opacity(0.15))
                                Capsule()
                                    .fill(segment.color)
                                    .frame(width: geo.size.width * min(segment.value / max(segment.target, 1), 1.0))
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(4)
    }

    private var noTargetView: some View {
        VStack(spacing: 8) {
            Text("\(entry.calories)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text("calories today")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                macroLabel("P", entry.protein, .blue)
                macroLabel("C", entry.carbs, .orange)
                macroLabel("F", entry.fat, .purple)
            }
        }
    }

    private func macroLabel(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(value))g")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Widget Configuration

struct FoodTrackerWidget: Widget {
    let kind = "FoodTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FoodTrackerProvider()) { entry in
            FoodTrackerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
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
