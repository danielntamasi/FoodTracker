import SwiftUI

struct MealSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let mealGroup: MealGroup

    @State private var extractedColor: Color?

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
                                                Text("\(entry.totalCalories) cal")
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
