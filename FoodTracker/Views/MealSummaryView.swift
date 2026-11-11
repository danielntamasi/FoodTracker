import SwiftUI

struct MealSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let mealGroup: MealGroup

    @State private var extractedColor: Color?
    @State private var isFavorite = false
    @State private var isGeneratingImage = false
    /// Set when the meal's time was changed, so Apple Health is updated once when the sheet closes
    @State private var timeChanged = false

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
        return iconHeroColor(for: iconName)
    }

    /// The meal's time (its earliest item). Setting it moves every item by the same amount, so a meal
    /// put together in the morning can be moved to lunch in one go.
    private var mealTime: Binding<Date> {
        Binding(
            get: { mealGroup.entries.map(\.date).min() ?? Date() },
            set: { newTime in
                guard let earliest = mealGroup.entries.map(\.date).min() else { return }
                let shift = newTime.timeIntervalSince(earliest)
                guard shift != 0 else { return }
                for entry in mealGroup.entries { entry.date = entry.date.addingTimeInterval(shift) }
                timeChanged = true
            }
        )
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
                                iconHeightRatio: nil,
                                isGeneratingImage: isGeneratingImage
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

                                HStack {
                                    Label("Time", systemImage: "clock")
                                        .font(DS.Typography.labelL)
                                        .foregroundStyle(DS.Color.textPrimary)
                                    Spacer()
                                    DatePicker("Time", selection: mealTime, displayedComponents: [.date, .hourAndMinute])
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(DS.Color.backgroundElevated)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
                                .padding(.horizontal, 20)
                                .accessibilityHint("Moves every item in this meal")
                            }
                            .padding(.top, 12)
                        }
                        .padding(.bottom, 20)
                    }
                }
                .background(DS.Color.backgroundSecondary)
                .toolbar(.hidden, for: .navigationBar)

                GlassGroup {
                HStack {
                    Button {
                        isFavorite = FavoriteFoods.toggle(mealGroup.name)
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isFavorite ? DS.Color.carbs : DS.Color.overlayText)
                            .frame(height: 20)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassControl()
                    }
                    .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                    Spacer()
                    Button { dismiss() } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Color.overlayText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassControl()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                }
            }
        }
        .onAppear {
            if let uiImage = mealImage {
                extractedColor = dominantColor(from: uiImage, colorScheme: colorScheme)
            }
            isFavorite = FavoriteFoods.isFavorite(mealGroup.name)
        }
        .onDisappear {
            guard timeChanged else { return }
            let entries = mealGroup.entries
            Task { for entry in entries { await HealthKitService.shared.updateEntry(entry) } }
        }
        .task(id: mealGroup.id) {
            guard mealImage == nil,
                  ImagePlaygroundService.isAvailable,
                  ImagePlaygroundService.isEnabled,
                  let firstEntry = mealGroup.entries.first,
                  !firstEntry.isGeneratedImage else { return }
            isGeneratingImage = true
            if let imageData = await ImagePlaygroundService.shared.generateImage(for: mealGroup.name) {
                guard !Task.isCancelled else { return }
                firstEntry.photoData = imageData
                firstEntry.isGeneratedImage = true
                if let uiImage = UIImage(data: imageData) {
                    extractedColor = dominantColor(from: uiImage, colorScheme: colorScheme)
                }
            }
            if !Task.isCancelled { isGeneratingImage = false }
        }
    }
}
