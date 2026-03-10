import SwiftUI

struct MealSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let mealGroup: MealGroup

    @State private var extractedColor: Color?
    @State private var isFavorite = false

    private var totalCalories: Int { mealGroup.entries.reduce(0) { $0 + $1.totalCalories } }
    private var totalProtein: Double { mealGroup.entries.reduce(0) { $0 + $1.totalProteinGrams } }
    private var totalCarbs: Double { mealGroup.entries.reduce(0) { $0 + $1.totalCarbsGrams } }
    private var totalFat: Double { mealGroup.entries.reduce(0) { $0 + $1.totalFatGrams } }

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
                            HeroPhotoSection(
                                image: mealImage,
                                title: mealGroup.name,
                                iconName: mealGroup.entries.first?.iconName ?? foodIconName(for: mealGroup.name),
                                bgColor: bgColor,
                                totalCalories: totalCalories,
                                totalProtein: totalProtein,
                                totalCarbs: totalCarbs,
                                totalFat: totalFat,
                                geoWidth: fullGeo.size.width,
                                geoHeight: fullGeo.size.height,
                                iconHeightRatio: nil
                            )

                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(mealGroup.entries.count) items")
                                        .font(DS.Typography.labelS)
                                        .foregroundStyle(DS.Color.textTertiary)
                                        .tracking(0.8)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 8)

                                    VStack(spacing: 0) {
                                        ForEach(Array(mealGroup.entries.enumerated()), id: \.element.id) { index, entry in
                                            HStack {
                                                Text(entry.name)
                                                    .font(DS.Typography.labelL)
                                                    .foregroundStyle(DS.Color.textPrimary)
                                                Spacer()
                                                Text("\(entry.totalCalories) cal")
                                                    .font(DS.Typography.caption)
                                                    .foregroundStyle(DS.Color.textTertiary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            if index < mealGroup.entries.count - 1 {
                                                Divider().opacity(0.3).padding(.leading, 16)
                                            }
                                        }
                                    }
                                    .background(DS.Color.backgroundElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
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
                .background(DS.Color.backgroundSecondary)
                .toolbar(.hidden, for: .navigationBar)

                HStack {
                    Button {
                        isFavorite = FavoriteFoods.toggle(mealGroup.name)
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isFavorite ? DS.Color.carbs : .white)
                            .frame(height: 20)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial.opacity(0.6))
                            .clipShape(Capsule())
                    }
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
            isFavorite = FavoriteFoods.isFavorite(mealGroup.name)
        }
    }
}
