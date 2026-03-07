import SwiftUI
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
        .background(color.opacity(0.12))
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
            ("Protein", proteinCals, DS.Color.protein),
            ("Carbs", carbsCals, DS.Color.carbs),
            ("Fat", fatCals, DS.Color.fat),
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
                donutLabel(pct: proteinPct, name: "P", color: .blue)
                donutLabel(pct: carbsPct, name: "C", color: .orange)
                donutLabel(pct: fatPct, name: "F", color: .purple)
            }
        }
    }

    private func donutLabel(pct: Int, name: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(pct)% \(name)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(DS.Color.textSecondary)
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
            Text("% OF DAILY GOAL")
                .font(DS.Typography.labelS)
                .foregroundStyle(DS.Color.textTertiary)
                .tracking(0.8)

            VStack(spacing: 8) {
                if calorieTarget > 0 {
                    goalBar(label: "Cal", value: calories, target: Double(calorieTarget), color: .gray)
                }
                if proteinTarget > 0 {
                    goalBar(label: "Protein", value: protein, target: Double(proteinTarget), color: DS.Color.protein)
                }
                if carbsTarget > 0 {
                    goalBar(label: "Carbs", value: carbs, target: Double(carbsTarget), color: DS.Color.carbs)
                }
                if fatTarget > 0 {
                    goalBar(label: "Fat", value: fat, target: Double(fatTarget), color: DS.Color.fat)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
        .padding(.horizontal, DS.Spacing.screenEdge)
    }

    private func goalBar(label: String, value: Double, target: Double, color: Color) -> some View {
        let pct = target > 0 ? Int((value / target * 100).rounded()) : 0
        return HStack(spacing: 8) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .frame(width: 48, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                    Capsule().fill(color).frame(width: geo.size.width * min(value / max(target, 1), 1.0), height: 6)
                }
            }
            .frame(height: 6)
            Text("\(pct)%")
                .font(DS.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - Serving Picker

struct ServingPicker: View {
    @Binding var servings: Double

    private let values: [Double]

    init(servings: Binding<Double>) {
        self._servings = servings
        let maxValue = max(20.0, (servings.wrappedValue * 4).rounded(.up) / 4 * 4)
        let count = Int(maxValue / 0.25)
        values = (1...count).map { Double($0) * 0.25 }
    }

    var body: some View {
        Picker("Servings", selection: $servings) {
            ForEach(values, id: \.self) { value in
                Text(formatServings(value)).tag(value)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 120)
    }
}

// MARK: - USDA Result Card

struct USDAResultCard: View {
    let result: USDAService.USDALookupResult
    let isSelected: Bool
    let onTap: () -> Void

    private var servingLabel: String {
        if let desc = result.servingDescription {
            let gramsNote = result.servingGrams.map { " (\(Int($0))g)" } ?? ""
            return "\(desc)\(gramsNote)"
        } else if let grams = result.servingGrams {
            return "\(Int(grams))g"
        }
        return "per 100g"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.description.titleCased())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(servingLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    let scaled = result.perServing
                    Text("\(Int(scaled.calories)) cal")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    coloredMacroText(protein: scaled.protein, carbs: scaled.carbs, fat: scaled.fat)
                        .font(.caption)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Color.success)
                        .imageScale(.large)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s)
                    .fill(DS.Color.backgroundSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.s)
                    .stroke(isSelected ? DS.Color.success : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - USDA Results List

struct USDAResultsList: View {
    let results: [USDAService.USDALookupResult]
    @Binding var selectedIndex: Int?

    var body: some View {
        if results.isEmpty {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("No results found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 8) {
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    USDAResultCard(
                        result: result,
                        isSelected: selectedIndex == index
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIndex = selectedIndex == index ? nil : index
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
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
                Rectangle().fill(DS.Color.backgroundSubtle)
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
