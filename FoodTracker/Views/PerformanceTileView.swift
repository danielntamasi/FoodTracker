import SwiftUI

// MARK: - Macro Type

enum MacroType: CaseIterable {
    case calories, protein, carbs, fat

    var name: String {
        switch self {
        case .calories: return "Calories"
        case .protein: return "Protein"
        case .carbs: return "Carbs"
        case .fat: return "Fat"
        }
    }

    var unit: String { self == .calories ? "kcal" : "g" }

    var iconName: String {
        switch self {
        case .calories: return DS.Icon.calories
        case .protein: return DS.Icon.protein
        case .carbs: return DS.Icon.carbs
        case .fat: return DS.Icon.fat
        }
    }

    var color: Color {
        switch self {
        case .calories: return DS.Color.textPrimary
        case .protein: return DS.Color.protein
        case .carbs: return DS.Color.carbs
        case .fat: return DS.Color.fat
        }
    }

    var target: Int {
        switch self {
        case .calories: return DailyTarget.calories
        case .protein: return DailyTarget.protein
        case .carbs: return DailyTarget.carbs
        case .fat: return DailyTarget.fat
        }
    }
}

// MARK: - Performance Tile

/// History's performance card: average daily calories and macros over the last
/// 7/30/90/365 days, each compared against its goal's ±10% band, plus how many
/// days the averages are based on.
struct PerformanceTileView: View {
    let entries: [FoodEntry]
    @State private var window: PerformanceWindow = .week
    @State private var showingInfo = false
    @State private var showingPartialDays = false
    @State private var excludedDays = ExcludedDays.load()

    private var summary: PerformanceSummary {
        PerformanceCalculator.summary(entries: entries, window: window, excluded: excludedDays)
    }

    var body: some View {
        let summary = summary
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            header(summary)

            Picker("Period", selection: $window) {
                ForEach(PerformanceWindow.allCases) { window in
                    Text(window.shortLabel).tag(window)
                }
            }
            .pickerStyle(.segmented)

            DataCoverageRow(summary: summary) {
                showingPartialDays = true
            }

            if summary.loggedDays == 0 {
                Label("Nothing logged yet", systemImage: "tray")
                    .font(DS.Typography.subhead)
                    .foregroundStyle(DS.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.Spacing.l)
            } else {
                VStack(spacing: DS.Spacing.l) {
                    ForEach(summary.averages) { average in
                        MacroAverageRow(average: average)
                    }
                }

                if !summary.hasTargets {
                    Label("Set daily targets in Settings to compare", systemImage: "target")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }
            }
        }
        .padding(DS.Spacing.m)
        .appCard()
        .animation(.easeInOut(duration: 0.25), value: window)
        .sheet(isPresented: $showingInfo) {
            PerformanceInfoView()
        }
        .sheet(isPresented: $showingPartialDays) {
            PartialDaysView(days: summary.partialDays, excludedDays: $excludedDays)
        }
        .onChange(of: excludedDays) { _, newValue in
            ExcludedDays.save(newValue)
        }
    }

    private func header(_ summary: PerformanceSummary) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Text("Performance")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Color.textPrimary)
            Spacer()
            if summary.hasTargets && summary.loggedDays > 0 {
                let allOn = summary.onTargetCount == summary.targetedCount
                Label("\(summary.onTargetCount)/\(summary.targetedCount)", systemImage: "target")
                    .font(DS.Typography.labelL)
                    .monospacedDigit()
                    .foregroundStyle(allOn ? DS.Color.success : DS.Color.textSecondary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(summary.onTargetCount) of \(summary.targetedCount) goals on target")
            }
            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Performance info")
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Data Coverage Row

/// How many days the averages rest on: "5 of 7 days · 2 missing", with a dot per day
/// (7D, 30D) or a fill bar (90D, 1Y), colored by coverage so thin data stands out.
/// Days that look partially logged get a faded dot and a button to review them;
/// days left out of the averages get a hollow dot.
private struct DataCoverageRow: View {
    let summary: PerformanceSummary
    let onShowPartialDays: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownCoverage: Double = 0

    private var color: Color {
        switch summary.coverage {
        case 0.8...: return DS.Color.success
        case 0.5..<0.8: return DS.Color.carbs
        default: return DS.Color.danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .foregroundStyle(color)
                Text("\(summary.loggedDays) of \(summary.window.rawValue) days")
                    .foregroundStyle(DS.Color.textPrimary)
                    .contentTransition(.numericText())
                if summary.missingDays > 0 {
                    Text("· \(summary.missingDays) missing")
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
                if !summary.partialDays.isEmpty {
                    partialButton
                }
            }
            .font(DS.Typography.labelM)
            .monospacedDigit()
            .accessibilityElement(children: .combine)

            Group {
                if summary.window.rawValue <= PerformanceWindow.month.rawValue {
                    dayDots
                } else {
                    coverageBar
                }
            }
            .accessibilityHidden(true)
        }
    }

    /// "2 look partial" while flagged days still count, else "1 left out"
    private var partialButton: some View {
        let counted = summary.partialCountedCount
        let text = counted > 0
            ? "\(counted) look\(counted == 1 ? "s" : "") partial"
            : "\(summary.excludedCount) left out"
        return Button(action: onShowPartialDays) {
            HStack(spacing: 3) {
                Image(systemName: counted > 0 ? "exclamationmark.triangle.fill" : "line.3.horizontal.decrease.circle")
                Text(text)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(counted > 0 ? DS.Color.carbs : DS.Color.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Review days that look partially logged")
    }

    /// One dot per day, oldest on the left
    private var dayDots: some View {
        HStack(spacing: summary.window == .week ? 6 : 3) {
            ForEach(Array(summary.dayStatuses.enumerated()), id: \.offset) { index, status in
                dot(status)
                    .transition(.scale(scale: 0.2, anchor: .leading).combined(with: .opacity))
                    .animation(reduceMotion ? nil : .spring(duration: 0.4).delay(Double(index) * 0.015), value: summary.window)
            }
        }
    }

    @ViewBuilder
    private func dot(_ status: DayStatus) -> some View {
        switch status {
        case .empty:
            Capsule().fill(DS.Color.ringTrack).frame(height: 6)
        case .complete:
            Capsule().fill(color).frame(height: 6)
        case .partial:
            Capsule().fill(color.opacity(0.35)).frame(height: 6)
        case .excluded:
            Capsule().strokeBorder(DS.Color.textTertiary, lineWidth: 1).frame(height: 6)
        }
    }

    private var coverageBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DS.Color.ringTrack)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * shownCoverage)
            }
        }
        .frame(height: 6)
        .onAppear { animateCoverage(to: summary.coverage) }
        .onChange(of: summary.coverage) { _, newValue in animateCoverage(to: newValue) }
    }

    private func animateCoverage(to value: Double) {
        if reduceMotion {
            shownCoverage = value
        } else {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                shownCoverage = value
            }
        }
    }
}

// MARK: - Partial Days

/// Days in the window that look partially logged (or were left out), with why, and
/// a button per day to leave it out of the averages or count it again.
private struct PartialDaysView: View {
    let days: [DayLog]
    @Binding var excludedDays: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(days) { day in
                        row(day)
                    }
                } footer: {
                    Text("Days with very few calories, or no lunch or dinner logged on a light day, probably weren't fully logged. Leaving them out keeps them from pulling your averages down. Entries aren't touched.")
                }
            }
            .navigationTitle("Partial Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton(title: "Close") { dismiss() }
                }
                if days.contains(where: { $0.isPartial && !$0.isExcluded }) {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Leave All Out") {
                            for day in days where day.isPartial {
                                excludedDays.insert(ExcludedDays.key(for: day.date))
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ day: DayLog) -> some View {
        let key = ExcludedDays.key(for: day.date)
        return HStack(spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(DS.Typography.labelL)
                        .foregroundStyle(day.isExcluded ? DS.Color.textTertiary : DS.Color.textPrimary)
                    Text("\(day.calories.formatted()) kcal")
                        .font(DS.Typography.caption)
                        .monospacedDigit()
                        .foregroundStyle(DS.Color.textTertiary)
                }
                Label(day.isPartial ? day.partialReasons.joined(separator: " · ") : "Left out by you",
                      systemImage: day.isPartial ? "exclamationmark.triangle.fill" : "line.3.horizontal.decrease.circle")
                    .font(DS.Typography.caption)
                    .foregroundStyle(day.isPartial ? DS.Color.carbs : DS.Color.textSecondary)
            }
            Spacer(minLength: 0)
            Button(day.isExcluded ? "Count It" : "Leave Out") {
                if day.isExcluded {
                    excludedDays.remove(key)
                } else {
                    excludedDays.insert(key)
                }
            }
            .glassButtonStyle(prominent: !day.isExcluded)
            .controlSize(.small)
        }
    }
}

// MARK: - Macro Average Row

private struct MacroAverageRow: View {
    let average: MacroAverage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What the bar fill shows: grows from 0 on appear and slides when the period changes
    @State private var shownAverage: Double = 0

    /// The bar spans 0–150% of the goal; anything past that pins to the end
    private let scaleMax = 1.5

    var body: some View {
        let status = average.status
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                macroLabel
                Spacer(minLength: 0)
                Text(Int(average.average.rounded()).formatted())
                    .font(DS.Typography.numberM)
                    .monospacedDigit()
                    .foregroundStyle(DS.Color.textPrimary)
                    .contentTransition(.numericText())
                Text(average.macro.unit)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.textTertiary)
                if average.target > 0 {
                    statusChip(status)
                }
            }

            if average.target > 0 {
                goalBar
            }
        }
        .onAppear { animate(to: average.average) }
        .onChange(of: average.average) { _, newValue in animate(to: newValue) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(status))
    }

    /// Calories is just its flame; the macros get their icon plus name, in their P/C/F color
    @ViewBuilder
    private var macroLabel: some View {
        if average.macro == .calories {
            Image(systemName: average.macro.iconName)
                .font(.body)
                .foregroundStyle(DS.Color.textPrimary)
        } else {
            HStack(spacing: 6) {
                Image(systemName: average.macro.iconName)
                    .font(.subheadline)
                    .frame(width: 20)
                Text(average.macro.name)
                    .font(DS.Typography.labelL)
            }
            .foregroundStyle(average.macro.color)
        }
    }

    /// Track with the ±10% goal band shaded, a tick at the goal labeled with its value,
    /// and the average as a fill
    private var goalBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let target = Double(average.target)
            let x = { (value: Double) in CGFloat(min(value / (target * scaleMax), 1)) * width }

            VStack(alignment: .leading, spacing: 2) {
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.Color.ringTrack)

                    Capsule()
                        .fill(average.macro.color.opacity(0.85))
                        .frame(width: max(x(shownAverage), 8))

                    // On top of the fill so the band stays visible when the average is past it
                    Rectangle()
                        .fill(DS.Color.success.opacity(0.35))
                        .frame(width: x(target * PerformanceThresholds.onTargetHigh) - x(target * PerformanceThresholds.onTargetLow))
                        .offset(x: x(target * PerformanceThresholds.onTargetLow))

                    Rectangle()
                        .fill(DS.Color.textSecondary)
                        .frame(width: 2)
                        .offset(x: x(target) - 1)
                }
                .frame(height: 10)
                .clipShape(Capsule())

                Text(average.target.formatted())
                    .font(DS.Typography.caption2)
                    .monospacedDigit()
                    .foregroundStyle(DS.Color.textTertiary)
                    .fixedSize()
                    .frame(width: 60)
                    .offset(x: x(target) - 30)
            }
        }
        .frame(height: 26)
    }

    private func animate(to value: Double) {
        if reduceMotion {
            shownAverage = value
        } else {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                shownAverage = value
            }
        }
    }

    private func statusChip(_ status: TargetStatus) -> some View {
        HStack(spacing: 2) {
            Image(systemName: status.iconName)
                .font(.caption2.weight(.bold))
            if let text = status.shortLabel {
                Text(text)
                    .font(DS.Typography.labelS)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(status.color)
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(status.color.opacity(0.12)))
        .fixedSize()
        // Same slot width on every row so the values line up
        .frame(width: 56, alignment: .trailing)
    }

    private func accessibilityText(_ status: TargetStatus) -> String {
        let value = "\(Int(average.average.rounded())) \(average.macro.unit)"
        guard average.target > 0 else { return "\(average.macro.name), average \(value)" }
        return "\(average.macro.name), average \(value) of \(average.target) goal, \(status.label)"
    }
}
