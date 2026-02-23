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
        case .noData: return Color(.systemGray4)
        case .noTarget: return Color.accentColor.opacity(0.3)
        case .onTarget: return .green
        case .over(let severe), .under(let severe):
            return severe ? .red : .yellow
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

// MARK: - Trend Direction

private enum TrendDirection {
    case improving, declining, steady

    var label: String {
        switch self {
        case .improving: return "▲ Improving vs last month"
        case .declining: return "▼ Declining vs last month"
        case .steady: return "▸ Steady vs last month"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .declining: return .red
        case .steady: return .secondary
        }
    }
}

// MARK: - Performance Thresholds

private enum PerformanceThresholds {
    /// Ratio bounds for "on target" (±10%)
    static let onTargetLow = 0.9
    static let onTargetHigh = 1.1
    /// Ratio bounds for "slightly off" (10-20% off)
    static let severeOverThreshold = 1.2
    static let severeUnderThreshold = 0.8
    /// Monthly dot adherence thresholds
    static let monthDotGood = 0.7
    static let monthDotFair = 0.5
    /// Overall adherence color thresholds (percentage)
    static let adherenceGood = 70
    static let adherenceFair = 50
    /// Trend sensitivity (5% difference)
    static let trendSensitivity = 0.05
}

// MARK: - Performance Tile

struct PerformanceTileView: View {
    let entries: [FoodEntry]
    @State private var selectedPeriod: PerformancePeriod = .week

    private var activeMacroTypes: [MacroType] {
        MacroType.allCases.filter { $0.target > 0 }
    }

    private var hasTargets: Bool { !activeMacroTypes.isEmpty }

    // MARK: - Data Builders

    private func buildDailyRecords(days: Int) -> [DayRecord] {
        let calendar = Calendar.current
        let now = Date()

        // Pre-bucket entries by day for O(n + d) instead of O(n * d)
        let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(days - 1), to: now)!)
        var buckets: [Int: [FoodEntry]] = [:]
        for entry in entries {
            let dayStart = calendar.startOfDay(for: entry.date)
            let offset = calendar.dateComponents([.day], from: startDate, to: dayStart).day ?? -1
            guard offset >= 0 && offset < days else { continue }
            buckets[offset, default: []].append(entry)
        }

        var records: [DayRecord] = []
        records.reserveCapacity(days)
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            let dayEntries = buckets[offset] ?? []
            records.append(DayRecord(
                date: date,
                calories: dayEntries.reduce(0) { $0 + $1.totalCalories },
                protein: dayEntries.reduce(0) { $0 + $1.totalProteinGrams },
                carbs: dayEntries.reduce(0) { $0 + $1.totalCarbsGrams },
                fat: dayEntries.reduce(0) { $0 + $1.totalFatGrams },
                hasData: !dayEntries.isEmpty
            ))
        }
        return records
    }

    private var yearDayCount: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return 1 }
        return (calendar.dateComponents([.day], from: yearStart, to: now).day ?? 0) + 1
    }

    private var dailyRecords: [DayRecord] {
        switch selectedPeriod {
        case .week: return buildDailyRecords(days: 7)
        case .month: return buildDailyRecords(days: 28)
        case .year: return buildDailyRecords(days: yearDayCount)
        }
    }

    // MARK: - Dot Status

    private func dotStatus(for macro: MacroType, record: DayRecord) -> DotStatus {
        guard record.hasData else { return .noData }
        let tgt = Double(macro.target)
        guard tgt > 0 else { return .noTarget }
        let val = macro.value(from: record)
        let pct = val / tgt
        if pct >= PerformanceThresholds.onTargetLow && pct <= PerformanceThresholds.onTargetHigh { return .onTarget }
        if pct > PerformanceThresholds.onTargetHigh { return pct > PerformanceThresholds.severeOverThreshold ? .over(severe: true) : .over(severe: false) }
        return pct < PerformanceThresholds.severeUnderThreshold ? .under(severe: true) : .under(severe: false)
    }

    // MARK: - All-Macro Adherence

    private func isDayFullyOnTarget(_ record: DayRecord) -> Bool {
        guard record.hasData else { return false }
        let macros = activeMacroTypes
        guard !macros.isEmpty else { return false }
        return macros.allSatisfy { macro in
            let val = macro.value(from: record)
            let tgt = Double(macro.target)
            guard tgt > 0 else { return true }
            let pct = val / tgt
            return pct >= PerformanceThresholds.onTargetLow && pct <= PerformanceThresholds.onTargetHigh
        }
    }

    private func dayOverallStatus(_ record: DayRecord) -> DotStatus {
        guard record.hasData else { return .noData }
        let macros = activeMacroTypes
        guard !macros.isEmpty else { return .noTarget }

        var worstSeverity = 0 // 0 = on target, 1 = slight, 2 = severe
        var isOver = false

        for macro in macros {
            let val = macro.value(from: record)
            let tgt = Double(macro.target)
            guard tgt > 0 else { continue }
            let pct = val / tgt
            if pct >= PerformanceThresholds.onTargetLow && pct <= PerformanceThresholds.onTargetHigh {
                continue
            }
            let severe = pct > PerformanceThresholds.severeOverThreshold || pct < PerformanceThresholds.severeUnderThreshold
            let severity = severe ? 2 : 1
            if severity > worstSeverity {
                worstSeverity = severity
                isOver = pct > PerformanceThresholds.onTargetHigh
            }
        }

        switch worstSeverity {
        case 0: return .onTarget
        case 1: return isOver ? .over(severe: false) : .under(severe: false)
        default: return isOver ? .over(severe: true) : .under(severe: true)
        }
    }

    private func daysOnTarget(in records: [DayRecord]) -> Int {
        records.filter { isDayFullyOnTarget($0) }.count
    }

    private func daysWithData(in records: [DayRecord]) -> Int {
        records.filter { $0.hasData }.count
    }

    private func currentStreak(in records: [DayRecord]) -> Int {
        var streak = 0
        var started = false
        for record in records.reversed() {
            if isDayFullyOnTarget(record) {
                streak += 1
                started = true
            } else if !record.hasData && !started {
                continue
            } else {
                break
            }
        }
        return streak
    }

    private func bestStreak(in records: [DayRecord]) -> Int {
        var best = 0
        var current = 0
        for record in records {
            if isDayFullyOnTarget(record) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    private func avgDelta(in records: [DayRecord]) -> Int {
        let calTarget = DailyTarget.calories
        guard calTarget > 0 else { return 0 }
        let withData = records.filter { $0.hasData }
        guard !withData.isEmpty else { return 0 }
        return withData.reduce(0) { $0 + ($1.calories - calTarget) } / withData.count
    }

    private func avgCalories(in records: [DayRecord]) -> Int {
        let withData = records.filter { $0.hasData }
        guard !withData.isEmpty else { return 0 }
        return withData.reduce(0) { $0 + $1.calories } / withData.count
    }

    // MARK: - Year Monthly Dots

    private func yearMonthlyDotsFrom(_ records: [DayRecord]) -> [(label: String, hasData: Bool, adherencePct: Double?)] {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)

        let grouped = Dictionary(grouping: records) { record in
            calendar.component(.month, from: record.date)
        }

        var dots: [(label: String, hasData: Bool, adherencePct: Double?)] = []
        for month in 1...12 {
            let label = calendar.veryShortMonthSymbols[month - 1]

            if month > currentMonth {
                dots.append((label: label, hasData: false, adherencePct: nil))
                continue
            }

            guard let monthRecords = grouped[month] else {
                dots.append((label: label, hasData: false, adherencePct: nil))
                continue
            }

            let withData = monthRecords.filter { $0.hasData }
            if withData.isEmpty {
                dots.append((label: label, hasData: false, adherencePct: nil))
                continue
            }

            guard hasTargets else {
                dots.append((label: label, hasData: true, adherencePct: nil))
                continue
            }

            let onTarget = withData.filter { isDayFullyOnTarget($0) }.count
            let adherence = Double(onTarget) / Double(withData.count)
            dots.append((label: label, hasData: true, adherencePct: adherence))
        }

        return dots
    }

    private func monthDotColor(hasData: Bool, adherencePct: Double?) -> Color {
        guard hasData else { return Color(.systemGray4) }
        guard let adherence = adherencePct else { return .accentColor }
        if adherence >= PerformanceThresholds.monthDotGood { return .green }
        if adherence >= PerformanceThresholds.monthDotFair { return .yellow }
        return .red
    }

    // MARK: - Month Weekly Dots

    private func monthWeeklyDotsFrom(_ records: [DayRecord]) -> [(label: String, hasData: Bool, adherencePct: Double?)] {
        // Split 28 days into 4 weeks (oldest first)
        var dots: [(label: String, hasData: Bool, adherencePct: Double?)] = []
        for week in 0..<4 {
            let start = week * 7
            let end = min(start + 7, records.count)
            guard start < records.count else {
                dots.append((label: "W\(week + 1)", hasData: false, adherencePct: nil))
                continue
            }
            let weekRecords = Array(records[start..<end])
            let withData = weekRecords.filter { $0.hasData }

            if withData.isEmpty {
                dots.append((label: "W\(week + 1)", hasData: false, adherencePct: nil))
                continue
            }

            guard hasTargets else {
                dots.append((label: "W\(week + 1)", hasData: true, adherencePct: nil))
                continue
            }

            let onTarget = withData.filter { isDayFullyOnTarget($0) }.count
            let adherence = Double(onTarget) / Double(withData.count)
            dots.append((label: "W\(week + 1)", hasData: true, adherencePct: adherence))
        }
        return dots
    }

    private func weeklyDotsRow(dots: [(label: String, hasData: Bool, adherencePct: Double?)]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                VStack(spacing: 4) {
                    Circle()
                        .fill(monthDotColor(hasData: dot.hasData, adherencePct: dot.adherencePct))
                        .frame(width: 14, height: 14)
                    Text(dot.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month Trend

    private var monthTrend: TrendDirection {
        let all56 = buildDailyRecords(days: 56)
        let previous = Array(all56.prefix(28))
        let current = Array(all56.suffix(28))

        let currentWithData = daysWithData(in: current)
        let previousWithData = daysWithData(in: previous)

        guard currentWithData > 0, previousWithData > 0 else { return .steady }

        let currentPct = Double(daysOnTarget(in: current)) / Double(currentWithData)
        let previousPct = Double(daysOnTarget(in: previous)) / Double(previousWithData)

        let diff = currentPct - previousPct
        if diff > PerformanceThresholds.trendSensitivity { return .improving }
        if diff < -PerformanceThresholds.trendSensitivity { return .declining }
        return .steady
    }

    @State private var showingInfo = false
    @State private var useBarChart = true

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
                if selectedPeriod == .week && hasTargets {
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

            if hasTargets {
                switch selectedPeriod {
                case .week: weekContent
                case .month: monthContent
                case .year: yearContent
                }
            } else {
                noTargetsContent
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingInfo) {
            PerformanceInfoView()
        }
    }

    // MARK: - Adherence Color

    private func adherenceColor(_ pct: Int) -> Color {
        if pct >= PerformanceThresholds.adherenceGood { return .green }
        if pct >= PerformanceThresholds.adherenceFair { return .yellow }
        return .red
    }

    // MARK: - Week Content

    @ViewBuilder
    private var weekContent: some View {
        let records = dailyRecords
        let onTarget = daysOnTarget(in: records)
        let withData = daysWithData(in: records)
        let pct = withData > 0 ? Int(round(Double(onTarget) / Double(withData) * 100)) : 0
        let streak = currentStreak(in: records)
        let delta = avgDelta(in: records)

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

    // MARK: - Week Bar Chart

    private func barColor(for status: DotStatus) -> Color {
        switch status {
        case .onTarget: return .green
        case .over(let severe), .under(let severe): return severe ? .red : .yellow
        case .noData, .noTarget: return Color(.systemGray4)
        }
    }

    private func weekBarChart(records: [DayRecord]) -> some View {
        let calendar = Calendar.current
        let calTarget = DailyTarget.calories

        let chartData: [(label: String, calories: Int, status: DotStatus, index: Int)] = records.enumerated().map { i, record in
            let weekday = calendar.component(.weekday, from: record.date)
            let symbol = calendar.veryShortWeekdaySymbols[weekday - 1]
            return (label: symbol, calories: record.calories, status: dayOverallStatus(record), index: i)
        }

        let maxCal = chartData.map { Double($0.calories) }.max() ?? 0
        let yMax = max(Double(calTarget > 0 ? calTarget : 2000) * 1.4, maxCal * 1.15)

        return Chart {
            if calTarget > 0 {
                RuleMark(y: .value("Target", calTarget))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary.opacity(0.6))
            }

            ForEach(chartData, id: \.index) { item in
                BarMark(
                    x: .value("Day", item.index),
                    y: .value("Calories", item.calories)
                )
                .foregroundStyle(barColor(for: item.status))
                .cornerRadius(4)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: chartData.map { $0.index }) { value in
                if let idx = value.as(Int.self), idx < chartData.count {
                    AxisValueLabel {
                        Text(chartData[idx].label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXScale(domain: -0.5...6.5)
        .chartYScale(domain: 0...yMax)
        .frame(height: 120)
    }

    // MARK: - Week Status Dots Row

    private func weekStatusDotsRow(records: [DayRecord]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                let status = dayOverallStatus(record)
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
        let records = dailyRecords
        let onTarget = daysOnTarget(in: records)
        let withData = daysWithData(in: records)
        let pct = withData > 0 ? Int(round(Double(onTarget) / Double(withData) * 100)) : 0
        let avg = avgCalories(in: records)
        let best = bestStreak(in: records)
        let trend = monthTrend

        VStack(spacing: 10) {
            heroStat(onTarget: onTarget, total: withData, pct: pct)
            weeklyDotsRow(dots: monthWeeklyDotsFrom(records))

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
                if best > 0 {
                    streakLabel(count: best, isBest: true)
                }
            }
        }
    }

    // MARK: - Year Content

    @ViewBuilder
    private var yearContent: some View {
        let records = dailyRecords
        let onTarget = daysOnTarget(in: records)
        let withData = daysWithData(in: records)
        let pct = withData > 0 ? Int(round(Double(onTarget) / Double(withData) * 100)) : 0
        let best = bestStreak(in: records)
        let dots = yearMonthlyDotsFrom(records)

        VStack(spacing: 10) {
            heroStat(onTarget: onTarget, total: withData, pct: pct)
            monthDotsRow(dots: dots)

            if best > 0 {
                HStack {
                    streakLabel(count: best, isBest: true)
                    Spacer()
                }
            }
        }
    }

    // MARK: - No Targets Content

    @ViewBuilder
    private var noTargetsContent: some View {
        let records = dailyRecords
        let logged = daysWithData(in: records)
        let avg = avgCalories(in: records)

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
                weeklyDotsRow(dots: monthWeeklyDotsFrom(records))
            } else if selectedPeriod == .year {
                monthDotsRow(dots: yearMonthlyDotsFrom(records))
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
                .foregroundStyle(adherenceColor(pct))
        }
    }

    private func macroDotsMatrix(records: [DayRecord]) -> some View {
        let calendar = Calendar.current
        return VStack(spacing: 6) {
            // Day letter header row
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

            // One row per macro type (all 4, active ones get colored dots)
            ForEach(MacroType.allCases, id: \.label) { macro in
                HStack(spacing: 0) {
                    Text(macro.label)
                        .font(.caption2)
                        .foregroundStyle(macro.target > 0 ? .secondary : .quaternary)
                        .frame(width: 34, alignment: .leading)
                    ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                        matrixDot(status: dotStatus(for: macro, record: record))
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
                        .fill(record.hasData ? Color.accentColor : Color(.systemGray4))
                        .frame(width: 12, height: 12)
                    Text(symbol)
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
                        .fill(monthDotColor(hasData: dot.hasData, adherencePct: dot.adherencePct))
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
