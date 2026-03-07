import SwiftUI

// MARK: - Hero Photo Section

/// Shared hero layout for immersive detail views (EditEntryView, MealSummaryView).
/// Shows either a full-bleed photo with gradient fade or an icon-based gradient hero.
struct HeroPhotoSection: View {
    let image: UIImage?
    let title: String
    let iconName: String
    let bgColor: Color
    let totalCalories: Int
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let geoWidth: CGFloat
    let geoHeight: CGFloat

    /// Height ratio for photo hero (0.65 for EditEntryView, 0.65 for MealSummaryView)
    var photoHeightRatio: CGFloat = 0.65
    /// Height ratio for icon hero (0.55 for EditEntryView, nil for MealSummaryView — uses auto)
    var iconHeightRatio: CGFloat? = 0.55

    private var proteinCals: Double { proteinCalories(totalProtein) }
    private var carbsCals: Double { carbCalories(totalCarbs) }
    private var fatCals: Double { fatCalories(totalFat) }
    private var totalMacroCals: Double { totalMacroCalories(protein: totalProtein, carbs: totalCarbs, fat: totalFat) }

    private var macroPcts: (protein: Int, carbs: Int, fat: Int) {
        macroPercentages(protein: totalProtein, carbs: totalCarbs, fat: totalFat)
    }

    var body: some View {
        if let uiImage = image {
            photoHero(uiImage: uiImage)
        } else {
            iconHero
        }
    }

    // MARK: - Photo Hero

    private func photoHero(uiImage: UIImage) -> some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: geoWidth, height: geoHeight * photoHeightRatio)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: DS.Color.backgroundSecondary.opacity(0.3), location: 0.3),
                    .init(color: DS.Color.backgroundSecondary.opacity(0.85), location: 0.7),
                    .init(color: DS.Color.backgroundSecondary, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: geoHeight * photoHeightRatio * 0.6)

            heroContent
                .padding(.bottom, 16)
                .padding(.horizontal, 16)
        }
        .frame(height: geoHeight * photoHeightRatio)
    }

    // MARK: - Icon Hero

    private var iconHero: some View {
        let iconClr = foodIconColor(for: iconName)

        return ZStack(alignment: .bottom) {
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

                heroContent
            }
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
        }
        .frame(height: iconHeightRatio.map { geoHeight * $0 })
        .if(iconHeightRatio == nil) { view in
            view.padding(.top, 44)
        }
    }

    // MARK: - Shared Content

    private var heroContent: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

            HStack(spacing: 12) {
                MetricPill(value: "\(totalCalories)", label: "cal", color: .white)
                MetricPill(value: formatMacro(totalProtein), label: "P", color: DS.Color.protein)
                MetricPill(value: formatMacro(totalCarbs), label: "C", color: DS.Color.carbs)
                MetricPill(value: formatMacro(totalFat), label: "F", color: DS.Color.fat)
            }

            if totalMacroCals > 0 {
                HeroMacroDonut(proteinCals: proteinCals, carbsCals: carbsCals, fatCals: fatCals, proteinPct: macroPcts.protein, carbsPct: macroPcts.carbs, fatPct: macroPcts.fat)
            }
        }
    }
}

// MARK: - Conditional Modifier

private extension View {
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
