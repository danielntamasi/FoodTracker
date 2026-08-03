import SwiftUI

// MARK: - Trend Direction

enum TrendDirection {
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
        case .improving: return DS.Color.success
        case .declining: return DS.Color.danger
        case .steady: return DS.Color.textSecondary
        }
    }
}

// MARK: - Performance Thresholds

enum PerformanceThresholds {
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

// MARK: - Performance Calculator

struct PerformanceCalculator {
    let entries: [FoodEntry]
    let activeMacroTypes: [MacroType]

    var hasTargets: Bool { !activeMacroTypes.isEmpty }

    // MARK: - Data Builders

    func buildDailyRecords(days: Int) -> [DayRecord] {
        let calendar = Calendar.current
        let now = Date()

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

    var yearDayCount: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return 1 }
        return (calendar.dateComponents([.day], from: yearStart, to: now).day ?? 0) + 1
    }

    func dailyRecords(for period: PerformancePeriod) -> [DayRecord] {
        switch period {
        case .week: return buildDailyRecords(days: 7)
        case .month: return buildDailyRecords(days: 28)
        case .year: return buildDailyRecords(days: yearDayCount)
        }
    }

    // MARK: - Dot Status

    func dotStatus(for macro: MacroType, record: DayRecord) -> DotStatus {
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

    func isDayFullyOnTarget(_ record: DayRecord) -> Bool {
        guard record.hasData else { return false }
        guard !activeMacroTypes.isEmpty else { return false }
        return activeMacroTypes.allSatisfy { macro in
            let val = macro.value(from: record)
            let tgt = Double(macro.target)
            guard tgt > 0 else { return true }
            let pct = val / tgt
            return pct >= PerformanceThresholds.onTargetLow && pct <= PerformanceThresholds.onTargetHigh
        }
    }

    func dayOverallStatus(_ record: DayRecord) -> DotStatus {
        guard record.hasData else { return .noData }
        guard !activeMacroTypes.isEmpty else { return .noTarget }

        var worstSeverity = 0
        var isOver = false

        for macro in activeMacroTypes {
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

    func daysOnTarget(in records: [DayRecord]) -> Int {
        records.filter { isDayFullyOnTarget($0) }.count
    }

    func daysWithData(in records: [DayRecord]) -> Int {
        records.filter { $0.hasData }.count
    }

    func currentStreak(in records: [DayRecord], excludeToday: Bool = false) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var started = false
        for record in records.reversed() {
            // Skip today — the day isn't over yet so it shouldn't break a streak
            if excludeToday && calendar.isDate(record.date, inSameDayAs: today) {
                continue
            }
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

    /// Computes the current streak looking back from yesterday across ALL entries,
    /// not limited to the selected period. Today is excluded because it's still in progress.
    func globalCurrentStreak(allEntries: [FoodEntry]) -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let earliest = allEntries.map(\.date).min() else { return 0 }
        let startDay = calendar.startOfDay(for: earliest)
        let today = calendar.startOfDay(for: now)
        let totalDays = (calendar.dateComponents([.day], from: startDay, to: today).day ?? 0) + 1
        guard totalDays > 0 else { return 0 }

        let globalCalc = PerformanceCalculator(entries: allEntries, activeMacroTypes: activeMacroTypes)
        let records = globalCalc.buildDailyRecords(days: totalDays)
        return globalCalc.currentStreak(in: records, excludeToday: true)
    }

    func bestStreak(in records: [DayRecord]) -> Int {
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

    func avgDelta(in records: [DayRecord]) -> Int {
        let calTarget = DailyTarget.calories
        guard calTarget > 0 else { return 0 }
        let withData = records.filter { $0.hasData }
        guard !withData.isEmpty else { return 0 }
        return withData.reduce(0) { $0 + ($1.calories - calTarget) } / withData.count
    }

    func avgCalories(in records: [DayRecord]) -> Int {
        let withData = records.filter { $0.hasData }
        guard !withData.isEmpty else { return 0 }
        return withData.reduce(0) { $0 + $1.calories } / withData.count
    }

    // MARK: - Year Monthly Dots

    func yearMonthlyDotsFrom(_ records: [DayRecord]) -> [(label: String, hasData: Bool, adherencePct: Double?)] {
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

    func monthDotColor(hasData: Bool, adherencePct: Double?) -> Color {
        guard hasData else { return DS.Color.textTertiary }
        guard let adherence = adherencePct else { return DS.Color.brandPink }
        if adherence >= PerformanceThresholds.monthDotGood { return DS.Color.success }
        if adherence >= PerformanceThresholds.monthDotFair { return DS.Color.carbs }
        return DS.Color.danger
    }

    // MARK: - Month Weekly Dots

    func monthWeeklyDotsFrom(_ records: [DayRecord]) -> [(label: String, hasData: Bool, adherencePct: Double?)] {
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

    // MARK: - Month Trend

    func monthTrend() -> TrendDirection {
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

    // MARK: - Adherence Color

    func adherenceColor(_ pct: Int) -> Color {
        if pct >= PerformanceThresholds.adherenceGood { return DS.Color.success }
        if pct >= PerformanceThresholds.adherenceFair { return DS.Color.carbs }
        return DS.Color.danger
    }
}
