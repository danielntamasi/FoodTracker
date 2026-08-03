import SwiftUI
import SwiftData
import Charts
import WidgetKit

struct DailySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [FoodEntry]
    @State private var editingEntry: FoodEntry?
    @State private var editingMealGroup: MealGroup?
    @State private var expandedGroups: Set<UUID> = []
    @State private var reverseChronological = sharedDefaults.bool(forKey: AppConstants.Defaults.reverseChronological)

    private var orderedPeriods: [TimeOfDay] {
        reverseChronological ? TimeOfDay.allCases.reversed() : TimeOfDay.allCases
    }

    private var todayEntries: [FoodEntry] {
        let calendar = Calendar.current
        return allEntries
            .filter { calendar.isDateInToday($0.date) }
            .sorted {
                if let a = $0.sortOrder, let b = $1.sortOrder { return a < b }
                if $0.sortOrder != nil { return true }
                if $1.sortOrder != nil { return false }
                return $0.date > $1.date
            }
    }

    private var totals: (cal: Int, protein: Double, carbs: Double, fat: Double) {
        todayEntries.reduce((0, 0.0, 0.0, 0.0)) {
            ($0.0 + $1.totalCalories, $0.1 + $1.totalProteinGrams, $0.2 + $1.totalCarbsGrams, $0.3 + $1.totalFatGrams)
        }
    }

    private var totalCalories: Int { totals.cal }
    private var totalProtein: Double { totals.protein }
    private var totalCarbs: Double { totals.carbs }
    private var totalFat: Double { totals.fat }

    // Bucket entries by time-of-day in a single pass
    private var entriesByPeriod: [TimeOfDay: [FoodEntry]] {
        Dictionary(grouping: todayEntries) { TimeOfDay.from($0.date) }
    }

    private var flatListItems: [FlatListItem] {
        let buckets = entriesByPeriod
        var items: [FlatListItem] = []
        for period in orderedPeriods {
            items.append(.sectionHeader(period))
            let periodEntries = buckets[period] ?? []
            let ordered = reverseChronological ? Array(periodEntries.reversed()) : periodEntries
            let displayItems = groupedDisplayItems(from: ordered)
            for displayItem in displayItems {
                items.append(.entry(displayItem))
                if case .mealGroup(let groupID, _, let entries) = displayItem,
                   expandedGroups.contains(groupID) {
                    let groupPhoto = entries.first(where: { $0.photoData != nil })?.photoData
                    for entry in entries {
                        items.append(.expandedSubItem(entry, groupID: groupID, groupPhotoData: groupPhoto))
                    }
                }
            }
        }
        return items
    }

    private func periodHasEntries(_ period: TimeOfDay) -> Bool {
        !(entriesByPeriod[period]?.isEmpty ?? true)
    }

    private var widgetSyncID: String {
        "\(totalCalories)-\(totalProtein)-\(totalCarbs)-\(totalFat)-\(todayEntries.count)"
    }

    private func syncWidgetData() {
        sharedDefaults.set(totalCalories, forKey: AppConstants.Defaults.widgetCalories)
        sharedDefaults.set(totalProtein, forKey: AppConstants.Defaults.widgetProtein)
        sharedDefaults.set(totalCarbs, forKey: AppConstants.Defaults.widgetCarbs)
        sharedDefaults.set(totalFat, forKey: AppConstants.Defaults.widgetFat)
        sharedDefaults.set(Date.now.timeIntervalSince1970, forKey: AppConstants.Defaults.widgetLastSync)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = flatListItems
        items.move(fromOffsets: source, toOffset: destination)

        // Walk each entry backwards to find its nearest preceding section header
        var currentPeriod: TimeOfDay = orderedPeriods.first ?? .morning
        for item in items {
            switch item {
            case .sectionHeader(let period):
                currentPeriod = period
            case .entry(let displayItem):
                switch displayItem {
                case .standalone(let entry):
                    if TimeOfDay.from(entry.date) != currentPeriod {
                        entry.date = adjustedDate(for: entry.date, movingTo: currentPeriod)
                    }
                case .mealGroup(_, _, let entries):
                    for entry in entries {
                        if TimeOfDay.from(entry.date) != currentPeriod {
                            entry.date = adjustedDate(for: entry.date, movingTo: currentPeriod)
                        }
                    }
                }
            case .expandedSubItem:
                break
            }
        }

        // Reassign global sort orders
        var orderedEntries: [FoodEntry] = []
        for item in items {
            if case .entry(let displayItem) = item {
                switch displayItem {
                case .standalone(let entry): orderedEntries.append(entry)
                case .mealGroup(_, _, let entries): orderedEntries.append(contentsOf: entries)
                }
            }
        }
        if reverseChronological {
            orderedEntries.reverse()
        }
        for (i, entry) in orderedEntries.enumerated() {
            entry.sortOrder = i
        }
    }

    private func adjustedDate(for date: Date, movingTo period: TimeOfDay) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .minute, .second], from: date)
        components.hour = period.defaultHour
        return calendar.date(from: components) ?? date
    }

    /// Ensure every entry has a sortOrder so drag-to-reorder is stable
    private func assignInitialSortOrders() {
        let needsAssignment = todayEntries.contains { $0.sortOrder == nil }
        guard needsAssignment else { return }
        for (index, entry) in todayEntries.enumerated() {
            if entry.sortOrder == nil {
                entry.sortOrder = index
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary card
                summaryCard
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                if todayEntries.isEmpty {
                    emptyStateView
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(flatListItems) { item in
                        switch item {
                        case .sectionHeader(let period):
                            sectionHeader(period: period)
                                .opacity(periodHasEntries(period) ? 1.0 : 0.5)
                                .moveDisabled(true)
                                .deleteDisabled(true)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

                        case .entry(let displayItem):
                            entryCard(for: displayItem)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                        case .expandedSubItem(let entry, _, let groupPhotoData):
                            expandedSubItemRow(entry: entry, groupPhotoData: groupPhotoData)
                                .moveDisabled(true)
                        }
                    }
                    .onMove { source, destination in
                        moveItems(from: source, to: destination)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 88, for: .scrollContent)
            .background(DS.Color.backgroundPrimary)
            .navigationTitle("Today")
            .sheet(item: $editingEntry) { entry in
                EditEntryView(entry: entry)
            }
            .sheet(item: $editingMealGroup) { group in
                MealSummaryView(mealGroup: group)
            }
            .task(id: widgetSyncID) {
                syncWidgetData()
            }
            .onAppear {
                assignInitialSortOrders()
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: DS.Spacing.l) {
            CalorieRing(
                consumed: totalCalories,
                goal: DailyTarget.calories
            )
            .animation(.spring(duration: 0.4), value: totalCalories)

            if DailyTarget.hasTargets {
                HStack(spacing: DS.Spacing.xl) {
                    MacroArc(label: "Protein", current: totalProtein, goal: Double(DailyTarget.protein), color: DS.Color.protein)
                    MacroArc(label: "Carbs", current: totalCarbs, goal: Double(DailyTarget.carbs), color: DS.Color.carbs)
                    MacroArc(label: "Fat", current: totalFat, goal: Double(DailyTarget.fat), color: DS.Color.fat)
                }
            } else {
                HStack(spacing: DS.Spacing.l) {
                    MacroLabel(label: "Protein", value: totalProtein, color: DS.Color.protein)
                    MacroLabel(label: "Carbs", value: totalCarbs, color: DS.Color.carbs)
                    MacroLabel(label: "Fat", value: totalFat, color: DS.Color.fat)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.l)
        .frame(maxWidth: .infinity)
        .background(DS.Gradient.cardShimmer)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(DS.Color.border, lineWidth: DS.Border.hairline)
        )
        .padding(.horizontal, DS.Spacing.m)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(DS.Color.brandPink)
                .symbolEffect(.pulse)
            Text("No meals logged today")
                .font(.headline)
                .foregroundStyle(DS.Color.textPrimary)
            Text("Tap + to add your first meal")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Section Header

    private func sectionHeader(period: TimeOfDay) -> some View {
        let periodEntries = entriesByPeriod[period] ?? []
        let sectionCals = periodEntries.reduce(0) { $0 + $1.totalCalories }

        return HStack {
            HStack(spacing: 6) {
                Image(systemName: period.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                Text(period.rawValue.uppercased())
                    .font(DS.Typography.sectionLabel)
                    .foregroundStyle(DS.Color.textSecondary)
                    .tracking(1.5)
            }

            Spacer()

            if sectionCals > 0 {
                Text("\(sectionCals) cal")
                    .font(DS.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(DS.Color.textTertiary)
            }

            if period == orderedPeriods.first(where: { p in todayEntries.contains { TimeOfDay.from($0.date) == p } }) {
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                        reverseChronological.toggle()
                        sharedDefaults.set(reverseChronological, forKey: AppConstants.Defaults.reverseChronological)
                    }
                } label: {
                    Image(systemName: reverseChronological ? "arrow.down" : "arrow.up")
                        .foregroundStyle(DS.Color.textTertiary)
                        .contentTransition(.symbolEffect(.replace.offUp))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reverseChronological ? "Show oldest first" : "Show newest first")
            }
        }
    }

    // MARK: - Entry Card

    @ViewBuilder
    private func entryCard(for item: EntryDisplayItem) -> some View {
        switch item {
        case .standalone(let entry):
            Button { editingEntry = entry } label: {
                FoodEntryRow(entry: entry)
                    .padding(12)
                    .background(DS.Color.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        let entryID = entry.id
                        let entryDate = entry.date
                        Task { await HealthKitService.shared.deleteEntry(id: entryID, date: entryDate) }
                        withAnimation { modelContext.delete(entry) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button { editingEntry = entry } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                    Button { quickAddEntry(entry, into: modelContext) } label: {
                        Label("Add Again", systemImage: "plus.circle")
                    }
                    .tint(.green)
                }

        case .mealGroup(let groupID, let mealName, let entries):
            HStack {
                Button {
                    editingMealGroup = MealGroup(id: groupID, name: mealName, entries: entries)
                } label: {
                    MealEntryRow(mealName: mealName, entries: entries)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
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
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(expandedGroups.contains(groupID) ? "Collapse meal" : "Expand meal")
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(DS.Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    for entry in entries {
                        let entryID = entry.id
                        let entryDate = entry.date
                        Task { await HealthKitService.shared.deleteEntry(id: entryID, date: entryDate) }
                    }
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
                Button { quickAddMealGroup(entries, mealName: mealName, into: modelContext) } label: {
                    Label("Add Again", systemImage: "plus.circle")
                }
                .tint(.green)
            }

        }
    }

    // MARK: - Expanded Sub-Item Row

    private func expandedSubItemRow(entry: FoodEntry, groupPhotoData: Data? = nil) -> some View {
        Button { editingEntry = entry } label: {
            FoodEntryRow(entry: entry, groupPhotoData: groupPhotoData)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(DS.Color.backgroundSecondary.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 32, bottom: 2, trailing: 16))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    let entryID = entry.id
                    let entryDate = entry.date
                    Task { await HealthKitService.shared.deleteEntry(id: entryID, date: entryDate) }
                    withAnimation { modelContext.delete(entry) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button { editingEntry = entry } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
                Button { quickAddEntry(entry, into: modelContext) } label: {
                    Label("Add Again", systemImage: "plus.circle")
                }
                .tint(.green)
            }
    }
}

// MARK: - Time of Day

enum TimeOfDay: String, CaseIterable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"

    /// Hour boundary where this period starts (morning=0, afternoon=12, evening=17)
    var startHour: Int {
        switch self {
        case .morning: return 0
        case .afternoon: return 12
        case .evening: return 17
        }
    }

    /// Default hour assigned when an entry is moved into this period
    var defaultHour: Int {
        switch self {
        case .morning: return 9
        case .afternoon: return 13
        case .evening: return 18
        }
    }

    var systemImage: String {
        switch self {
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "moon.stars"
        }
    }

    var tintColor: Color {
        switch self {
        case .morning: return .orange
        case .afternoon: return .yellow
        case .evening: return .indigo
        }
    }

    static func from(_ date: Date) -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        if hour < Self.afternoon.startHour { return .morning }
        if hour < Self.evening.startHour { return .afternoon }
        return .evening
    }
}

// MARK: - Display Item Grouping

enum EntryDisplayItem: Identifiable {
    case standalone(FoodEntry)
    case mealGroup(groupID: UUID, mealName: String, entries: [FoodEntry])

    var id: String {
        switch self {
        case .standalone(let entry): return entry.id.uuidString
        case .mealGroup(let groupID, _, _): return groupID.uuidString
        }
    }
}

enum FlatListItem: Identifiable {
    case sectionHeader(TimeOfDay)
    case entry(EntryDisplayItem)
    case expandedSubItem(FoodEntry, groupID: UUID, groupPhotoData: Data?)

    var id: String {
        switch self {
        case .sectionHeader(let period): return "header-\(period.rawValue)"
        case .entry(let item): return item.id
        case .expandedSubItem(let entry, _, _): return "sub-\(entry.id.uuidString)"
        }
    }
}

func groupedDisplayItems(from entries: [FoodEntry]) -> [EntryDisplayItem] {
    // First pass: collect meal group entries by ID
    var groupsByID: [UUID: [FoodEntry]] = [:]
    for entry in entries {
        if let groupID = entry.mealGroupID {
            groupsByID[groupID, default: []].append(entry)
        }
    }

    // Second pass: build result maintaining original order
    var result: [EntryDisplayItem] = []
    var seenGroups: Set<UUID> = []
    for entry in entries {
        if let groupID = entry.mealGroupID {
            if seenGroups.contains(groupID) { continue }
            seenGroups.insert(groupID)
            let groupEntries = groupsByID[groupID] ?? [entry]
            let mealName = groupEntries.first?.mealName ?? "Meal"
            result.append(.mealGroup(groupID: groupID, mealName: mealName, entries: groupEntries))
        } else {
            result.append(.standalone(entry))
        }
    }
    return result
}

// MARK: - Colored Macro Text

func coloredMacroText(protein: Double, carbs: Double, fat: Double) -> Text {
    Text(String(format: "%.0f", protein)).foregroundColor(DS.Color.protein) +
    Text("P").foregroundColor(DS.Color.textSecondary) +
    Text(" · ").foregroundColor(DS.Color.textTertiary) +
    Text(String(format: "%.0f", carbs)).foregroundColor(DS.Color.carbs) +
    Text("C").foregroundColor(DS.Color.textSecondary) +
    Text(" · ").foregroundColor(DS.Color.textTertiary) +
    Text(String(format: "%.0f", fat)).foregroundColor(DS.Color.fat) +
    Text("F").foregroundColor(DS.Color.textSecondary)
}

// MARK: - Food Icon Color

func foodIconColor(for iconName: String?) -> Color {
    switch iconName {
    case "bird": return Color(red: 0.6, green: 0.4, blue: 0.2)
    case "flame": return Color(red: 0.85, green: 0.35, blue: 0.2)
    case "fish": return .teal
    case "egg": return Color(red: 0.9, green: 0.75, blue: 0.3)
    case "cup.and.saucer": return Color(red: 0.55, green: 0.35, blue: 0.2)
    case "cup.and.saucer.fill": return Color(red: 0.4, green: 0.6, blue: 0.8)
    case "waterbottle": return .cyan
    case "wineglass": return Color(red: 0.6, green: 0.2, blue: 0.4)
    case "birthday.cake": return .pink
    case "takeoutbag.and.cup.and.straw": return .orange
    case "triangle": return Color(red: 0.9, green: 0.3, blue: 0.2)
    case "leaf": return .green
    case "carrot": return Color(red: 0.95, green: 0.55, blue: 0.2)
    case "leaf.circle": return Color(red: 0.5, green: 0.6, blue: 0.3)
    case "chart.bar": return Color(red: 0.4, green: 0.5, blue: 0.7)
    case "snowflake": return Color(red: 0.5, green: 0.75, blue: 0.9)
    case "bowl": return Color(red: 0.8, green: 0.55, blue: 0.25)
    default: return .secondary
    }
}

// MARK: - Food Icon Thumbnail

struct FoodIconThumbnail: View {
    let iconName: String?
    var size: CGFloat = 44

    private var iconColor: Color { foodIconColor(for: iconName) }

    var body: some View {
        Image(systemName: iconName ?? "fork.knife")
            .font(.system(size: size * 0.35, weight: .medium))
            .foregroundStyle(iconColor)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                    .fill(DS.Color.iconThumbnailBg)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
    }
}

// MARK: - Meal Entry Row

struct MealEntryRow: View {
    let mealName: String
    let entries: [FoodEntry]

    private var totalCalories: Int {
        entries.reduce(0) { $0 + $1.totalCalories }
    }

    private var totalProtein: Double {
        entries.reduce(0) { $0 + $1.totalProteinGrams }
    }

    private var totalCarbs: Double {
        entries.reduce(0) { $0 + $1.totalCarbsGrams }
    }

    private var totalFat: Double {
        entries.reduce(0) { $0 + $1.totalFatGrams }
    }

    var body: some View {
        HStack(spacing: 12) {
            if entries.first?.photoData != nil {
                CachedThumbnailImage(photoData: entries.first?.photoData, size: 44)
            } else {
                FoodIconThumbnail(iconName: entries.first?.iconName ?? "fork.knife", size: 44)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(mealName)
                        .font(DS.Typography.labelL)
                        .foregroundStyle(DS.Color.textPrimary)
                        .lineLimit(1)
                    Text("\(entries.count) items")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }

                HStack(spacing: 4) {
                    MacroPill(value: formatMacro(totalProtein), unit: "P", color: DS.Color.protein)
                    MacroPill(value: formatMacro(totalCarbs), unit: "C", color: DS.Color.carbs)
                    MacroPill(value: formatMacro(totalFat), unit: "F", color: DS.Color.fat)
                }
            }

            Spacer()

            Text("\(totalCalories)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DS.Color.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Macro Donut Card

struct MacroDonutCard: View {
    let calories: Int
    let calorieTarget: Int
    let protein: Double
    let proteinTarget: Double
    let carbs: Double
    let carbsTarget: Double
    let fat: Double
    let fatTarget: Double

    private var macroSegments: [(name: String, value: Double, target: Double, color: Color)] {
        [
            ("Protein", protein, proteinTarget, DS.Color.protein),
            ("Carbs", carbs, carbsTarget, DS.Color.carbs),
            ("Fat", fat, fatTarget, DS.Color.fat),
        ].filter { $0.target > 0 }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if !macroSegments.isEmpty {
                    Chart(macroSegments, id: \.name) { segment in
                        SectorMark(
                            angle: .value(segment.name, min(segment.value, segment.target)),
                            innerRadius: .ratio(0.7),
                            angularInset: 2
                        )
                        .foregroundStyle(segment.color)

                        let remaining = max(0, segment.target - segment.value)
                        if remaining > 0 {
                            SectorMark(
                                angle: .value("\(segment.name) Remaining", remaining),
                                innerRadius: .ratio(0.7),
                                angularInset: 2
                            )
                            .foregroundStyle(segment.color.opacity(0.15))
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 160)
                }

                VStack(spacing: 2) {
                    Text("\(calories)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.4), value: calories)
                    if calorieTarget > 0 {
                        Text("/ \(calorieTarget) cal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let remaining = calorieTarget - calories
                        Text("\(abs(remaining)) \(remaining >= 0 ? "left" : "over")")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.4), value: calories)
                    } else {
                        Text("calories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 16) {
                ForEach(macroSegments, id: \.name) { segment in
                    MacroProgressLabel(
                        label: segment.name,
                        value: segment.value,
                        target: segment.target,
                        color: segment.color
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct MacroProgressLabel: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(String(format: "%.0f", value))/\(String(format: "%.0f", target))g")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.4), value: value)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * min(value / max(target, 1), 1.0), height: 4)
                        .animation(.spring(duration: 0.4), value: value)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Shared Views

struct MacroLabel: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0fg", value))
                .font(.headline)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.4), value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry
    var groupPhotoData: Data? = nil

    private var effectivePhotoData: Data? {
        entry.photoData ?? groupPhotoData
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon zone
            if effectivePhotoData != nil {
                CachedThumbnailImage(photoData: effectivePhotoData, size: 44)
            } else {
                FoodIconThumbnail(iconName: entry.iconName ?? foodIconName(for: entry.name), size: 44)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.name)
                    .font(DS.Typography.labelL)
                    .foregroundStyle(DS.Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    MacroPill(value: formatMacro(entry.totalProteinGrams), unit: "P", color: DS.Color.protein)
                    MacroPill(value: formatMacro(entry.totalCarbsGrams), unit: "C", color: DS.Color.carbs)
                    MacroPill(value: formatMacro(entry.totalFatGrams), unit: "F", color: DS.Color.fat)
                }
            }

            Spacer()

            Text("\(entry.totalCalories)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DS.Color.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Meal Group

struct MealGroup: Identifiable {
    let id: UUID
    let name: String
    let entries: [FoodEntry]
}

