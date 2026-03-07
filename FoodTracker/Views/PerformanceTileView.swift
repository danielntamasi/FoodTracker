import Charts
import SwiftUI

// MARK: - Performance Period

enum PerformancePeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

// MARK: - Day Record

struct DayRecord {
    let date: Date
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let hasData: Bool
}

// MARK: - Macro Type

enum MacroType: CaseIterable {
    case calories, protein, carbs, fat

    var label: String {
        switch self {
        case .calories: return "Cal"
        case .protein: return "Pro"
        case .carbs: return "Carb"
        case .fat: return "Fat"
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

    func value(from record: DayRecord) -> Double {
        switch self {
        case .calories: return Double(record.calories)
        case .protein: return record.protein
        case .carbs: return record.carbs
        case .fat: return record.fat
        }
    }
}

// MARK: - Dot Status

enum DotStatus {
    case noData
    case noTarget
    case onTarget
    case over(severe: Bool)
    case under(severe: Bool)

    var color: Color {
        switch self {
        case .noData: return DS.Color.textTertiary
        case .noTarget: return DS.Color.protein.opacity(0.3)
        case .onTarget: return DS.Color.success
        case .over(let severe), .under(let severe):
            return severe ? DS.Color.danger : DS.Color.carbs
        }
    }

    var arrowName: String? {
        switch self {
        case .over: return "chevron.up"
        case .under: return "chevron.down"
        default: return nil
        }
    }
}

// MARK: - Performance Tile

struct PerformanceTileView: View {
    let entries: [FoodEntry]
    @State private var selectedPeriod: PerformancePeriod = .week
    @State private var showingInfo = false
    @State private var useBarChart = true

    private var calc: PerformanceCalculator {
        PerformanceCalculator(
            entries: entries,
            activeMacroTypes: MacroType.allCases.filter { $0.target > 0 }
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance")
                    .font(.headline)
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                if selectedPeriod == .week && calc.hasTargets {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            useBarChart.toggle()
                        }
                    } label: {
                        Image(systemName: useBarChart ? "chart.bar.fill" : "circle.grid.3x3.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(PerformancePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            if calc.hasTargets {
                switch selectedPeriod {
                case .week: weekContent
                case .month: monthContent
                case .year: yearContent
                }
            } else {
                noTargetsContent
            }
        }
        .padding(DS.Spacing.m)
        .appCard()
        .sheet(isPresented: $showingInfo) {
            PerformanceInfoView()
        }
    }

    // MARK: - Week Content

    @ViewBuilder
    private var weekContent: some View {
        let records = calc.dailyRecords(for: .week)
        let onTarget = calc.daysOnTarget(in: records)
        let withData = calc.daysWithData(in: records)
        let pct = withData > 0 ? Int(round(Double(onTarget) / Double(withData) * 100)) : 0
        let streak = calc.globalCurrentStreak(allEntries: entries)
        let delta = calc.avgDelta(in: records)

        VStack(spacing: 10) {
            heroStat(onTarget: onTarget, total: withData, pct: pct)

            if useBarChart {
                weekBarChart(records: records)
                weekStatusDotsRow(records: records)
            } else {
                macroDotsMatrix(records: records)
            }

            HStack {
                if withData > 0 && DailyTarget.calories > 0 {
                    let sign = delta >= 0 ? "+" : ""
                    Text("Avg \(sign)\(delta.formatted()) cal/day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if streak > 0 {
                    streakLabel(count: streak, isBest: false)
                }
            }
        }
    }

    // MARK: - Week Macro Bar Chart

    private struct MacroBarEntry: Identifiable {
        let id = UUID()
        let xPos: Double
        let macro: String
        let pct: Double
        let color: Color
    }

    private func macroColor(for macro: MacroType) -> Color {
        switch macro {
        case .calories: return .gray
        case .protein: return DS.Color.protein
        case .carbs: return DS.Color.carbs
        case .fat: return DS.Color.fat
        }
    }

    private static let macroOffsets: [MacroType: Double] = [
        .calories: -0.27, .protein: -0.09, .carbs: 0.09, .fat: 0.27
    ]

    private func weekBarChart(records: [DayRecord]) -> some View {
        let calendar = Calendar.current

        let dayLabels: [Int: String] = Dictionary(
            uniqueKeysWithValues: records.enumerated().map { i, record in
                let weekday = calendar.component(.weekday, from: record.date)
                return (i, calendar.veryShortWeekdaySymbols[weekday - 1])
            }
        )

        var barEntries: [MacroBarEntry] = []
        for (i, record) in records.enumerated() {
            for macro in MacroType.allCases {
                let target = Double(macro.target)
                let pct: Double
                if target > 0 {
                    pct = record.hasData ? (macro.value(from: record) / target) * 100 : 0
                } else {
                    pct = 0
                }
                let offset = Self.macroOffsets[macro] ?? 0
                barEntries.append(MacroBarEntry(
                    xPos: Double(i) + offset,
                    macro: macro.label,
                    pct: pct,
                    color: macroColor(for: macro)
                ))
            }
        }

        let maxPct = barEntries.map(\.pct).max() ?? 100
        let yMax = max(150, maxPct * 1.1)
        let barWidth: MarkDimension = .fixed(6)

        return Chart {
            RectangleMark(
                yStart: .value("Low", 90),
                yEnd: .value("High", 110)
            )
            .foregroundStyle(.green.opacity(0.08))

            RuleMark(y: .value("Target", 100))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(.secondary.opacity(0.5))

            ForEach(barEntries) { entry in
                BarMark(
                    x: .value("Day", entry.xPos),
                    y: .value("% of Target", entry.pct),
                    width: barWidth
                )
                .foregroundStyle(entry.color)
                .cornerRadius(1.5)
            }
        }
        .chartXAxis {
            AxisMarks(values: Array(0..<records.count).map { Double($0) }) { value in
                if let dbl = value.as(Double.self), let label = dayLabels[Int(dbl)] {
                    AxisValueLabel {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXScale(domain: -0.5...6.5)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100, 150]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...yMax)
        .chartLegend(position: .bottom, spacing: 4) {
            HStack(spacing: 12) {
                ForEach(MacroType.allCases, id: \.label) { macro in
                    HStack(spacing: 4) {
                        Circle().fill(macroColor(for: macro)).frame(width: 6, height: 6)
                        Text(macro.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.clipped()
        }
        .frame(height: 140)
    }

    // MARK: - Week Status Dots Row

    private func weekStatusDotsRow(records: [DayRecord]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                let status = calc.dayOverallStatus(record)
                ZStack {
                    Circle()
                        .fill(status.color)
                        .frame(width: 10, height: 10)
                    if let arrow = status.arrowName {
                        Image(systemName: arrow)
                            .font(.system(size: 5, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month Content

    @ViewBuilder
    private var monthContent: some View {
        let records = calc.dailyRecords(for: .month)
        let onTarget = calc.daysOnTarget(in: records)
        let withData = calc.daysWithData(in: records)
        let pct = withData > 0 ? Int(round(Double(onTarget) / Double(withData) * 100)) : 0
        let avg = calc.avgCalories(in: records)
        let best = calc.bestStreak(in: records)
        let streak = calc.globalCurrentStreak(allEntries: entries)
        let trend = calc.monthTrend()

        VStack(spacing: 10) {
            heroStat(onTarget: onTarget, total: withData, pct: pct)
            weeklyDotsRow(dots: calc.monthWeeklyDotsFrom(records))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if withData > 0 && DailyTarget.calories > 0 {
                        HStack(spacing: 0) {
                            Text("Avg \(avg.formatted()) cal/day")
                            Text("  \u{00B7}  Target \(DailyTarget.calories.formatted())")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Text(trend.label)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(trend.color)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if streak > 0 {
                        streakLabel(count: streak, isBest: false)
                    }
                    if best > 0 {
                        streakLabel(count: best, isBest: true)
                    }
                }
            }
        }
    }

    // MARK: - Year Content

    @ViewBuilder
    private var yearContent: some View {
        let records = calc.dailyRecords(for: .year)
        let onTarget = calc.daysOnTarget(in: records)
        let withData = calc.daysWithData(in: records)
        let pct = withData > 0 ? Int(round(Double(onTarget) / Double(withData) * 100)) : 0
        let best = calc.bestStreak(in: records)
        let streak = calc.globalCurrentStreak(allEntries: entries)
        let dots = calc.yearMonthlyDotsFrom(records)

        VStack(spacing: 10) {
            heroStat(onTarget: onTarget, total: withData, pct: pct)
            monthDotsRow(dots: dots)

            HStack {
                if streak > 0 {
                    streakLabel(count: streak, isBest: false)
                }
                Spacer()
                if best > 0 {
                    streakLabel(count: best, isBest: true)
                }
            }
        }
    }

    // MARK: - No Targets Content

    @ViewBuilder
    private var noTargetsContent: some View {
        let records = calc.dailyRecords(for: selectedPeriod)
        let logged = calc.daysWithData(in: records)
        let avg = calc.avgCalories(in: records)

        VStack(spacing: 10) {
            HStack {
                Text("This \(selectedPeriod.rawValue)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }

            if selectedPeriod == .week {
                noTargetDayDotsRow(records: records)
            } else if selectedPeriod == .month {
                weeklyDotsRow(dots: calc.monthWeeklyDotsFrom(records))
            } else if selectedPeriod == .year {
                monthDotsRow(dots: calc.yearMonthlyDotsFrom(records))
            }

            HStack {
                if logged > 0 {
                    Text("Avg \(avg.formatted()) cal/day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(logged) \(logged == 1 ? "day" : "days") logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Shared Components

    private func heroStat(onTarget: Int, total: Int, pct: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(onTarget) of \(total) on target")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text("\(pct)%")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(calc.adherenceColor(pct))
        }
    }

    private func macroDotsMatrix(records: [DayRecord]) -> some View {
        let calendar = Calendar.current
        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 34, height: 1)
                ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                    let weekday = calendar.component(.weekday, from: record.date)
                    let symbol = calendar.veryShortWeekdaySymbols[weekday - 1]
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(MacroType.allCases, id: \.label) { macro in
                HStack(spacing: 0) {
                    Text(macro.label)
                        .font(.caption2)
                        .foregroundStyle(macro.target > 0 ? .secondary : .quaternary)
                        .frame(width: 34, alignment: .leading)
                    ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                        matrixDot(status: calc.dotStatus(for: macro, record: record))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func matrixDot(status: DotStatus) -> some View {
        ZStack {
            Circle()
                .fill(status.color)
                .frame(width: 14, height: 14)
            if let arrow = status.arrowName {
                Image(systemName: arrow)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func noTargetDayDotsRow(records: [DayRecord]) -> some View {
        let calendar = Calendar.current
        return HStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                let weekday = calendar.component(.weekday, from: record.date)
                let symbol = calendar.veryShortWeekdaySymbols[weekday - 1]
                VStack(spacing: 4) {
                    Circle()
                        .fill(record.hasData ? DS.Color.protein : DS.Color.textTertiary)
                        .frame(width: 12, height: 12)
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func weeklyDotsRow(dots: [(label: String, hasData: Bool, adherencePct: Double?)]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                VStack(spacing: 4) {
                    Circle()
                        .fill(calc.monthDotColor(hasData: dot.hasData, adherencePct: dot.adherencePct))
                        .frame(width: 14, height: 14)
                    Text(dot.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthDotsRow(dots: [(label: String, hasData: Bool, adherencePct: Double?)]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                VStack(spacing: 4) {
                    Circle()
                        .fill(calc.monthDotColor(hasData: dot.hasData, adherencePct: dot.adherencePct))
                        .frame(width: 12, height: 12)
                    Text(dot.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func streakLabel(count: Int, isBest: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(isBest ? "Best streak" : "Streak"): \(count) \(count == 1 ? "day" : "days")")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
