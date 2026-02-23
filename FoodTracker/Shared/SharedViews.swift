import SwiftUI
import UIKit
import Charts

// MARK: - Metric Pill

struct MetricPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(value).font(.subheadline).fontWeight(.bold)
            Text(label).font(.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Hero Macro Donut

struct HeroMacroDonut: View {
    let proteinCals: Double
    let carbsCals: Double
    let fatCals: Double
    let proteinPct: Int
    let carbsPct: Int
    let fatPct: Int
    var size: CGFloat = 80

    var body: some View {
        let segments: [(name: String, cals: Double, color: Color)] = [
            ("Protein", proteinCals, Color.macroProtein),
            ("Carbs", carbsCals, Color.macroCarbs),
            ("Fat", fatCals, Color.macroFat),
        ].filter { $0.cals > 0 }

        HStack(spacing: 12) {
            Chart(segments, id: \.name) { segment in
                SectorMark(
                    angle: .value(segment.name, segment.cals),
                    innerRadius: .ratio(0.65),
                    angularInset: 2
                )
                .foregroundStyle(segment.color)
            }
            .chartLegend(.hidden)
            .frame(width: size, height: size)

            VStack(alignment: .leading, spacing: 4) {
                donutLabel(pct: proteinPct, name: "P", color: .macroProtein)
                donutLabel(pct: carbsPct, name: "C", color: .macroCarbs)
                donutLabel(pct: fatPct, name: "F", color: .macroFat)
            }
        }
    }

    private func donutLabel(pct: Int, name: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(pct)% \(name)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Daily Goal Bars

struct DailyGoalBarsView: View {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let calorieTarget: Int
    let proteinTarget: Int
    let carbsTarget: Int
    let fatTarget: Int

    init(calories: Double, protein: Double, carbs: Double, fat: Double,
         calorieTarget: Int = DailyTarget.calories,
         proteinTarget: Int = DailyTarget.protein,
         carbsTarget: Int = DailyTarget.carbs,
         fatTarget: Int = DailyTarget.fat) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.carbsTarget = carbsTarget
        self.fatTarget = fatTarget
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("% of Daily Goal")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6))

            VStack(spacing: 8) {
                if calorieTarget > 0 {
                    goalBar(label: "Cal", value: calories, target: Double(calorieTarget), color: .gray)
                }
                if proteinTarget > 0 {
                    goalBar(label: "Protein", value: protein, target: Double(proteinTarget), color: .macroProtein)
                }
                if carbsTarget > 0 {
                    goalBar(label: "Carbs", value: carbs, target: Double(carbsTarget), color: .macroCarbs)
                }
                if fatTarget > 0 {
                    goalBar(label: "Fat", value: fat, target: Double(fatTarget), color: .macroFat)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func goalBar(label: String, value: Double, target: Double, color: Color) -> some View {
        let pct = target > 0 ? Int((value / target * 100).rounded()) : 0
        return HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 48, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1)).frame(height: 6)
                    Capsule().fill(color).frame(width: geo.size.width * min(value / max(target, 1), 1.0), height: 6)
                }
            }
            .frame(height: 6)
            Text("\(pct)%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - Cached Thumbnail Image

struct CachedThumbnailImage: View {
    let photoData: Data?
    var size: CGFloat = 52

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(Color(.systemGray5))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: photoData) {
            guard let data = photoData else {
                uiImage = nil
                return
            }
            uiImage = UIImage(data: data)
        }
    }
}
