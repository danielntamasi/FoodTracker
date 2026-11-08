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
                donutLabel(pct: proteinPct, name: "P", color: DS.Color.protein)
                donutLabel(pct: carbsPct, name: "C", color: DS.Color.carbs)
                donutLabel(pct: fatPct, name: "F", color: DS.Color.fat)
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
        .background(DS.Color.backgroundSubtle)
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
                    Capsule().fill(DS.Color.ringTrack).frame(height: 6)
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
        let current = servings.wrappedValue
        let snapped = max(0.25, (current * 4).rounded() / 4)
        let maxValue = max(20.0, (snapped * 4).rounded(.up) / 4 * 4)
        let count = Int(maxValue / 0.25)
        var values = (1...count).map { Double($0) * 0.25 }
        // A count set from grams eaten (e.g. 1.37) gets its own row, so the picker has a matching tag
        if current > 0, !values.contains(where: { abs($0 - current) < 0.001 }) {
            values.append(current)
            values.sort()
        }
        self.values = values
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

/// Number field that updates its value on every keystroke. `TextField(value:format:)` only commits
/// on Return or losing focus, and the decimal pad has no Return key, so dependent numbers lagged behind.
struct LiveNumberField: View {
    let placeholder: String
    @Binding var value: Double?
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            .onAppear { text = Self.format(value) }
            .onChange(of: text) { _, newText in
                guard isFocused else { return }
                let parsed = newText.isEmpty ? nil : try? Double(newText, format: .number)
                if parsed != value { value = parsed }
            }
            .onChange(of: value) { _, newValue in
                if !isFocused { text = Self.format(newValue) }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { text = Self.format(value) }
            }
    }

    private static func format(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(0...1)).grouping(.never)) } ?? ""
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

// MARK: - Waiting Phrases

/// A playful, food-themed "working on it" line for AI waits: a spinner-free icon and phrase that
/// change every ~1.6s in random order ("Simmering…", "Checking the fridge…"). Reduce Motion swaps
/// them without the slide.
struct WaitingPhrases: View {
    /// Phrases to rotate through, each with an SF Symbol
    let phrases: [(text: String, icon: String)]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index: Int

    init(_ phrases: [(text: String, icon: String)]) {
        self.phrases = phrases
        _index = State(initialValue: Int.random(in: 0..<max(phrases.count, 1)))
    }

    /// For AI Chat: cooking up an answer
    static let chat: [(text: String, icon: String)] = [
        ("Simmering…", "flame"),
        ("Marinating on that…", "drop"),
        ("Whisking…", "cup.and.saucer"),
        ("Seasoning to taste…", "sparkles"),
        ("Preheating…", "oven"),
        ("Chopping it up…", "carrot"),
        ("Taste-testing…", "fork.knife"),
        ("Reducing the sauce…", "frying.pan"),
        ("Weighing the portions…", "scalemass"),
        ("Counting calories…", "flame.fill"),
        ("Kneading the numbers…", "birthday.cake"),
        ("Plating up…", "takeoutbag.and.cup.and.straw"),
    ]

    /// For Finish the Day: putting a snack or meal together from what's at home
    static let finishDay: [(text: String, icon: String)] = [
        ("Checking the fridge…", "refrigerator"),
        ("Raiding the pantry…", "cabinet"),
        ("Balancing the macros…", "scalemass"),
        ("Assembling something tasty…", "fork.knife"),
        ("Folding in the protein…", "dumbbell"),
        ("Skipping the sad snacks…", "hand.thumbsdown"),
        ("Mixing it up…", "frying.pan"),
        ("Tasting for balance…", "sparkles"),
        ("Plating up…", "takeoutbag.and.cup.and.straw"),
    ]

    var body: some View {
        let phrase = phrases.isEmpty ? (text: "Thinking…", icon: "sparkles") : phrases[index % phrases.count]
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: phrase.icon)
                .font(.body.weight(.medium))
                .foregroundStyle(DS.Color.protein)
                .frame(width: 30)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse)
            // Only the text is clipped (for the push transition); wide symbols like frying.pan
            // would otherwise be cut off at the edges
            Text(phrase.text)
                .font(DS.Typography.subhead)
                .foregroundStyle(DS.Color.textSecondary)
                .id(phrase.text)
                .transition(reduceMotion ? .opacity : .push(from: .bottom))
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
        }
        .accessibilityElement(children: .combine)
        .task {
            guard phrases.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                var next = Int.random(in: 0..<phrases.count)
                if next == index { next = (next + 1) % phrases.count }
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) { index = next }
            }
        }
    }
}
