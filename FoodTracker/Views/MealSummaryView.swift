import SwiftUI
import Charts

struct MealSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let mealGroup: MealGroup

    @State private var extractedColor: Color?

    private var totalCalories: Int { mealGroup.entries.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { mealGroup.entries.reduce(0) { $0 + $1.proteinGrams } }
    private var totalCarbs: Double { mealGroup.entries.reduce(0) { $0 + $1.carbsGrams } }
    private var totalFat: Double { mealGroup.entries.reduce(0) { $0 + $1.fatGrams } }

    private var proteinCals: Double { proteinCalories(totalProtein) }
    private var carbsCals: Double { carbCalories(totalCarbs) }
    private var fatCals: Double { fatCalories(totalFat) }
    private var totalMacroCals: Double { totalMacroCalories(protein: totalProtein, carbs: totalCarbs, fat: totalFat) }

    private var macroPcts: (protein: Int, carbs: Int, fat: Int) {
        macroPercentages(protein: totalProtein, carbs: totalCarbs, fat: totalFat)
    }

    private var mealImage: UIImage? {
        for entry in mealGroup.entries {
            if let data = entry.photoData, let img = UIImage(data: data) {
                return img
            }
        }
        return nil
    }

    private var bgColor: Color {
        if let extracted = extractedColor { return extracted }
        let iconName = mealGroup.entries.first?.iconName ?? foodIconName(for: mealGroup.name)
        return iconDarkColor(for: iconName)
    }

    private var formattedTimestamp: String {
        guard let earliest = mealGroup.entries.map(\.date).min() else { return "" }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(earliest) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInYesterday(earliest) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }
        return formatter.string(from: earliest)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                GeometryReader { fullGeo in
                    ScrollView {
                        VStack(spacing: 0) {
                            if let uiImage = mealImage {
                                ZStack(alignment: .bottom) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: fullGeo.size.width, height: fullGeo.size.height * 0.65)
                                        .clipped()

                                    LinearGradient(
                                        stops: [
                                            .init(color: .clear, location: 0.0),
                                            .init(color: bgColor.opacity(0.3), location: 0.3),
                                            .init(color: bgColor.opacity(0.85), location: 0.7),
                                            .init(color: bgColor, location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: fullGeo.size.height * 0.65 * 0.6)

                                    VStack(spacing: 12) {
                                        Text(mealGroup.name)
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.center)
                                            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

                                        HStack(spacing: 12) {
                                            MetricPill(value: "\(totalCalories)", label: "cal", color: .white)
                                            MetricPill(value: formatMacro(totalProtein), label: "P", color: .blue)
                                            MetricPill(value: formatMacro(totalCarbs), label: "C", color: .orange)
                                            MetricPill(value: formatMacro(totalFat), label: "F", color: .purple)
                                        }

                                        if totalMacroCals > 0 {
                                            HeroMacroDonut(proteinCals: proteinCals, carbsCals: carbsCals, fatCals: fatCals, proteinPct: macroPcts.protein, carbsPct: macroPcts.carbs, fatPct: macroPcts.fat)
                                        }
                                    }
                                    .padding(.bottom, 16)
                                    .padding(.horizontal, 16)
                                }
                                .frame(height: fullGeo.size.height * 0.65)
                            } else {
                                let iconName = mealGroup.entries.first?.iconName ?? foodIconName(for: mealGroup.name)
                                let iconClr = foodIconColor(for: iconName)

                                ZStack(alignment: .bottom) {
                                    LinearGradient(
                                        stops: [
                                            .init(color: iconClr.opacity(0.35), location: 0.0),
                                            .init(color: bgColor.opacity(0.6), location: 0.5),
                                            .init(color: bgColor, location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )

                                    VStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    RadialGradient(
                                                        colors: [iconClr.opacity(0.25), .clear],
                                                        center: .center,
                                                        startRadius: 20,
                                                        endRadius: 90
                                                    )
                                                )
                                                .frame(width: 180, height: 180)

                                            Image(systemName: iconName)
                                                .font(.system(size: 44, weight: .light))
                                                .foregroundStyle(iconClr)
                                                .frame(width: 88, height: 88)
                                                .background(iconClr.opacity(0.12))
                                                .clipShape(Circle())
                                        }

                                        Text(mealGroup.name)
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.center)
                                            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

                                        HStack(spacing: 12) {
                                            MetricPill(value: "\(totalCalories)", label: "cal", color: .white)
                                            MetricPill(value: formatMacro(totalProtein), label: "P", color: .blue)
                                            MetricPill(value: formatMacro(totalCarbs), label: "C", color: .orange)
                                            MetricPill(value: formatMacro(totalFat), label: "F", color: .purple)
                                        }

                                        if totalMacroCals > 0 {
                                            HeroMacroDonut(proteinCals: proteinCals, carbsCals: carbsCals, fatCals: fatCals, proteinPct: macroPcts.protein, carbsPct: macroPcts.carbs, fatPct: macroPcts.fat)
                                        }
                                    }
                                    .padding(.bottom, 16)
                                    .padding(.horizontal, 16)
                                }
                                .padding(.top, 44)
                            }

                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(mealGroup.entries.count) items")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 8)

                                    VStack(spacing: 0) {
                                        ForEach(Array(mealGroup.entries.enumerated()), id: \.element.id) { index, entry in
                                            HStack {
                                                Text(entry.name)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.white.opacity(0.9))
                                                Spacer()
                                                Text("\(entry.calories) cal")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.5))
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            if index < mealGroup.entries.count - 1 {
                                                Divider().opacity(0.3).padding(.leading, 16)
                                            }
                                        }
                                    }
                                    .background(.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 20)
                                }

                                if DailyTarget.hasTargets {
                                    DailyGoalBarsView(
                                        calories: Double(totalCalories),
                                        protein: totalProtein,
                                        carbs: totalCarbs,
                                        fat: totalFat
                                    )
                                }

                                Text(formattedTimestamp)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.top, 4)
                            }
                            .padding(.top, 12)
                        }
                        .padding(.bottom, 20)
                    }
                }
                .background(bgColor)
                .toolbar(.hidden, for: .navigationBar)

                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial.opacity(0.6))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .onAppear {
            if let uiImage = mealImage {
                extractedColor = dominantColor(from: uiImage, colorScheme: colorScheme)
            }
        }
    }
}
