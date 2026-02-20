import SwiftUI
import SwiftData

// MARK: - Performance Period

enum PerformancePeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

// MARK: - Day Record

private struct DayRecord {
    let date: Date
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let hasData: Bool
}

// MARK: - Macro Type

private enum MacroType: CaseIterable {
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

private enum DotStatus {
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

// MARK: - History View

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @State private var editingEntry: FoodEntry?
    @State private var editingMealGroup: MealGroup?
    @State private var expandedGroups: Set<UUID> = []
    @State private var expandedDays: Set<String> = []
    @State private var didInitExpandedDays = false

    private var groupedEntries: [(String, [FoodEntry])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let grouped = Dictionary(grouping: entries) { entry in
            formatter.string(from: entry.date)
        }

        return grouped.sorted { lhs, rhs in
            guard let lhsDate = lhs.value.first?.date, let rhsDate = rhs.value.first?.date else {
                return false
            }
            return lhsDate > rhsDate
        }
    }

    private func quickAddEntry(_ entry: FoodEntry) {
        let newEntry = FoodEntry(
            name: entry.name,
            calories: entry.calories,
            proteinGrams: entry.proteinGrams,
            carbsGrams: entry.carbsGrams,
            fatGrams: entry.fatGrams,
            photoData: entry.photoData,
            iconName: entry.iconName ?? foodIconName(for: entry.name)
        )
        modelContext.insert(newEntry)
    }

    private func quickAddMealGroup(_ entries: [FoodEntry], mealName: String?) {
        let newGroupID = UUID()
        for entry in entries {
            let newEntry = FoodEntry(
                name: entry.name,
                calories: entry.calories,
                proteinGrams: entry.proteinGrams,
                carbsGrams: entry.carbsGrams,
                fatGrams: entry.fatGrams,
                photoData: entry.photoData,
                mealGroupID: newGroupID,
                mealName: mealName,
                iconName: entry.iconName ?? foodIconName(for: entry.name)
            )
            modelContext.insert(newEntry)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !entries.isEmpty {
                    Section {
                        PerformanceTileView(entries: entries)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                if entries.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "calendar",
                        description: Text("Your food entries will appear here.")
                    )
                } else {
                    ForEach(groupedEntries, id: \.0) { dateString, dayEntries in
                        Section {
                            if expandedDays.contains(dateString) {
                                ForEach(groupedDisplayItems(from: dayEntries), id: \.id) { item in
                                    switch item {
                                    case .standalone(let entry):
                                        FoodEntryRow(entry: entry)
                                            .contentShape(Rectangle())
                                            .onTapGesture { editingEntry = entry }
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button(role: .destructive) {
                                                    withAnimation { modelContext.delete(entry) }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                                Button { editingEntry = entry } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                }
                                                .tint(.blue)
                                                Button { quickAddEntry(entry) } label: {
                                                    Label("Add Again", systemImage: "plus.circle")
                                                }
                                                .tint(.green)
                                            }

                                    case .mealGroup(let groupID, let mealName, let entries):
                                        HStack {
                                            MealEntryRow(mealName: mealName, entries: entries)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    editingMealGroup = MealGroup(id: groupID, name: mealName, entries: entries)
                                                }
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    if expandedGroups.contains(groupID) {
                                                        expandedGroups.remove(groupID)
                                                    } else {
                                                        expandedGroups.insert(groupID)
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: expandedGroups.contains(groupID) ? "chevron.up" : "chevron.down")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .frame(width: 32, height: 32)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    for entry in entries { modelContext.delete(entry) }
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                editingMealGroup = MealGroup(id: groupID, name: mealName, entries: entries)
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                            Button { quickAddMealGroup(entries, mealName: mealName) } label: {
                                                Label("Add Again", systemImage: "plus.circle")
                                            }
                                            .tint(.green)
                                        }

                                        if expandedGroups.contains(groupID) {
                                            ForEach(entries) { entry in
                                                FoodEntryRow(entry: entry)
                                                    .contentShape(Rectangle())
                                                    .onTapGesture { editingEntry = entry }
                                                    .padding(.leading, 16)
                                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                        Button(role: .destructive) {
                                                            withAnimation { modelContext.delete(entry) }
                                                        } label: {
                                                            Label("Delete", systemImage: "trash")
                                                        }
                                                        Button { editingEntry = entry } label: {
                                                            Label("Edit", systemImage: "pencil")
                                                        }
                                                        .tint(.blue)
                                                        Button { quickAddEntry(entry) } label: {
                                                            Label("Add Again", systemImage: "plus.circle")
                                                        }
                                                        .tint(.green)
                                                    }
                                            }
                                        }
                                    }
                                }
                            }
                        } header: {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedDays.contains(dateString) {
                                        expandedDays.remove(dateString)
                                    } else {
                                        expandedDays.insert(dateString)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: expandedDays.contains(dateString) ? "chevron.down" : "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 12)
                                    Text(dateString)
                                    Spacer()
                                    let dayCals = dayEntries.reduce(0) { $0 + $1.calories }
                                    let dayP = dayEntries.reduce(0.0) { $0 + $1.proteinGrams }
                                    let dayC = dayEntries.reduce(0.0) { $0 + $1.carbsGrams }
                                    let dayF = dayEntries.reduce(0.0) { $0 + $1.fatGrams }
                                    Text("\(dayCals) cal")
                                        .foregroundStyle(.secondary)
                                    coloredMacroText(protein: dayP, carbs: dayC, fat: dayF)
                                        .font(.caption2)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .contentMargins(.bottom, 88, for: .scrollContent)
            .task {
                guard !didInitExpandedDays else { return }
                didInitExpandedDays = true
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
                    expandedDays.insert(formatter.string(from: yesterday))
                }
            }
            .navigationTitle("History")
            .sheet(item: $editingEntry) { entry in
                EditEntryView(entry: entry)
            }
            .sheet(item: $editingMealGroup) { group in
                MealSummaryView(mealGroup: group)
            }
        }
    }
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
        var records: [DayRecord] = []
        for offset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let dayEntries = entries.filter { $0.date >= dayStart && $0.date < dayEnd }
            records.append(DayRecord(
                date: date,
                calories: dayEntries.reduce(0) { $0 + $1.calories },
                protein: dayEntries.reduce(0) { $0 + $1.proteinGrams },
                carbs: dayEntries.reduce(0) { $0 + $1.carbsGrams },
                fat: dayEntries.reduce(0) { $0 + $1.fatGrams },
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
        if pct >= 0.9 && pct <= 1.1 { return .onTarget }
        if pct > 1.1 { return pct > 1.2 ? .over(severe: true) : .over(severe: false) }
        return pct < 0.8 ? .under(severe: true) : .under(severe: false)
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
            return pct >= 0.9 && pct <= 1.1
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
        if adherence >= 0.7 { return .green }
        if adherence >= 0.5 { return .yellow }
        return .red
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
        if diff > 0.05 { return .improving }
        if diff < -0.05 { return .declining }
        return .steady
    }

    @State private var showingInfo = false

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
        if pct >= 70 { return .green }
        if pct >= 50 { return .yellow }
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
            macroDotsMatrix(records: records)

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

        VStack(alignment: .leading, spacing: 8) {
            heroStat(onTarget: onTarget, total: withData, pct: pct)

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

            if best > 0 {
                streakLabel(count: best, isBest: true)
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

// MARK: - Performance Info View

private struct PerformanceInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dotColorsSection
                    weeklyMatrixSection
                    statsSection
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("How to Read Performance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Dot Colors Section

    private var dotColorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dot Colors")
                .font(.headline)

            VStack(spacing: 8) {
                dotLegendRow(status: .onTarget, label: "On target", description: "within ±10% of goal")
                dotLegendRow(status: .over(severe: false), label: "Slightly over", description: "10–20% above")
                dotLegendRow(status: .under(severe: false), label: "Slightly under", description: "10–20% below")
                dotLegendRow(status: .over(severe: true), label: "Way over", description: "more than 20% above")
                dotLegendRow(status: .under(severe: true), label: "Way under", description: "more than 20% below")
                dotLegendRow(status: .noData, label: "No data", description: "nothing logged")
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func dotLegendRow(status: DotStatus, label: String, description: String) -> some View {
        HStack(spacing: 10) {
            infoDot(status: status)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .frame(width: 100, alignment: .leading)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func infoDot(status: DotStatus) -> some View {
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

    // MARK: - Weekly Matrix Section

    private var weeklyMatrixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Matrix")
                .font(.headline)

            VStack(spacing: 0) {
                exampleMatrix
                    .padding(12)

                Text("Rows = macros you're tracking. Columns = days. A day is \"on target\" when every row is green.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var exampleMatrix: some View {
        let days = ["M", "T", "W", "T", "F"]
        let rows: [(String, [DotStatus])] = [
            ("Cal",  [.onTarget, .onTarget, .onTarget, .over(severe: false), .onTarget]),
            ("Pro",  [.onTarget, .under(severe: false), .onTarget, .onTarget, .onTarget]),
            ("Carb", [.onTarget, .onTarget, .over(severe: false), .onTarget, .under(severe: true)]),
            ("Fat",  [.onTarget, .onTarget, .onTarget, .onTarget, .onTarget]),
        ]

        return VStack(spacing: 6) {
            // Day headers
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 34, alignment: .leading)
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Macro rows
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    Text(row.0)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .leading)
                    ForEach(Array(row.1.enumerated()), id: \.offset) { _, status in
                        infoDot(status: status)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats Explained")
                .font(.headline)

            VStack(spacing: 0) {
                statRow(
                    label: "X of Y on target",
                    description: "Days where every tracked macro was within ±10%. Days with no food logged are excluded.",
                    isFirst: true
                )
                statRow(
                    label: "Streak",
                    description: "Consecutive on-target days ending today.",
                    isFirst: false
                )
                statRow(
                    label: "Best streak",
                    description: "Longest run of on-target days in the selected period.",
                    isFirst: false
                )
                statRow(
                    label: "Avg ±X cal/day",
                    description: "How much you averaged over or under your calorie target.",
                    isFirst: false
                )
                statRow(
                    label: "▲ / ▼ / ▸ Trend",
                    description: "Compares your adherence to the previous period of the same length.",
                    isFirst: false
                )
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func statRow(label: String, description: String, isFirst: Bool) -> some View {
        VStack(spacing: 0) {
            if !isFirst {
                Divider()
                    .padding(.leading, 12)
            }
            HStack(alignment: .top, spacing: 10) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 110, alignment: .leading)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
        }
    }
}
