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
    @State private var reverseChronological = UserDefaults.standard.bool(forKey: "reverseChronological")

    private var orderedPeriods: [TimeOfDay] {
        reverseChronological ? TimeOfDay.allCases.reversed() : TimeOfDay.allCases
    }

    private var flatListItems: [FlatListItem] {
        var items: [FlatListItem] = []
        for period in orderedPeriods {
            items.append(.sectionHeader(period))
            let filtered = todayEntries.filter { TimeOfDay.from($0.date) == period }
            let periodEntries = reverseChronological ? Array(filtered.reversed()) : filtered
            let displayItems = groupedDisplayItems(from: periodEntries)
            for displayItem in displayItems {
                items.append(.entry(displayItem))
                if case .mealGroup(let groupID, _, let entries) = displayItem,
                   expandedGroups.contains(groupID) {
                    for entry in entries {
                        items.append(.expandedSubItem(entry, groupID: groupID))
                    }
                }
            }
        }
        return items
    }

    private func periodHasEntries(_ period: TimeOfDay) -> Bool {
        todayEntries.contains { TimeOfDay.from($0.date) == period }
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

    private var totalCalories: Int {
        todayEntries.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Double {
        todayEntries.reduce(0) { $0 + $1.proteinGrams }
    }

    private var totalCarbs: Double {
        todayEntries.reduce(0) { $0 + $1.carbsGrams }
    }

    private var totalFat: Double {
        todayEntries.reduce(0) { $0 + $1.fatGrams }
    }

    private var hasTargets: Bool {
        DailyTarget.calories > 0 || DailyTarget.protein > 0 || DailyTarget.carbs > 0 || DailyTarget.fat > 0
    }

    private var widgetSyncID: String {
        "\(totalCalories)-\(totalProtein)-\(totalCarbs)-\(totalFat)-\(todayEntries.count)"
    }

    private func syncWidgetData() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(totalCalories, forKey: "widgetCalories")
        defaults.set(totalProtein, forKey: "widgetProtein")
        defaults.set(totalCarbs, forKey: "widgetCarbs")
        defaults.set(totalFat, forKey: "widgetFat")
        defaults.set(Date.now.timeIntervalSince1970, forKey: "widgetLastSync")
        defaults.set(DailyTarget.calories, forKey: "calorieTarget")
        defaults.set(DailyTarget.protein, forKey: "proteinTarget")
        defaults.set(DailyTarget.carbs, forKey: "carbsTarget")
        defaults.set(DailyTarget.fat, forKey: "fatTarget")
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
        switch period {
        case .morning: components.hour = 9
        case .afternoon: components.hour = 13
        case .evening: components.hour = 18
        }
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

                        case .expandedSubItem(let entry, _):
                            expandedSubItemRow(entry: entry)
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
            .background(Color(.systemGroupedBackground))
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
        Group {
            if hasTargets {
                MacroDonutCard(
                    calories: totalCalories,
                    calorieTarget: DailyTarget.calories,
                    protein: totalProtein,
                    proteinTarget: Double(DailyTarget.protein),
                    carbs: totalCarbs,
                    carbsTarget: Double(DailyTarget.carbs),
                    fat: totalFat,
                    fatTarget: Double(DailyTarget.fat)
                )
            } else {
                VStack(spacing: 12) {
                    Text("\(totalCalories)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.4), value: totalCalories)
                    Text("calories today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 24) {
                        MacroLabel(label: "Protein", value: totalProtein, color: .blue)
                        MacroLabel(label: "Carbs", value: totalCarbs, color: .orange)
                        MacroLabel(label: "Fat", value: totalFat, color: .purple)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse)
            Text("No meals logged today")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Tap + to add your first meal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Section Header

    private func sectionHeader(period: TimeOfDay) -> some View {
        HStack {
            Image(systemName: period.systemImage)
                .font(.caption)
                .foregroundStyle(period.tintColor)
                .frame(width: 26, height: 26)
                .background(period.tintColor.opacity(0.15))
                .clipShape(Circle())

            Text(period.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            if period == orderedPeriods.first(where: { p in todayEntries.contains { TimeOfDay.from($0.date) == p } }) {
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                        reverseChronological.toggle()
                        UserDefaults.standard.set(reverseChronological, forKey: "reverseChronological")
                    }
                } label: {
                    Image(systemName: reverseChronological ? "arrow.down" : "arrow.up")
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
            FoodEntryRow(entry: entry)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

        }
    }

    // MARK: - Expanded Sub-Item Row

    private func expandedSubItemRow(entry: FoodEntry) -> some View {
        FoodEntryRow(entry: entry)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture { editingEntry = entry }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 32, bottom: 2, trailing: 16))
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

// MARK: - Time of Day

enum TimeOfDay: String, CaseIterable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"

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
        if hour < 12 { return .morning }
        if hour < 17 { return .afternoon }
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
    case expandedSubItem(FoodEntry, groupID: UUID)

    var id: String {
        switch self {
        case .sectionHeader(let period): return "header-\(period.rawValue)"
        case .entry(let item): return item.id
        case .expandedSubItem(let entry, _): return "sub-\(entry.id.uuidString)"
        }
    }
}

func groupedDisplayItems(from entries: [FoodEntry]) -> [EntryDisplayItem] {
    var result: [EntryDisplayItem] = []
    var seenGroups: Set<UUID> = []

    for entry in entries {
        if let groupID = entry.mealGroupID {
            if seenGroups.contains(groupID) { continue }
            seenGroups.insert(groupID)
            let groupEntries = entries.filter { $0.mealGroupID == groupID }
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
    Text(String(format: "%.0f", protein)).foregroundColor(.blue) +
    Text("P").foregroundColor(.secondary) +
    Text(" · ").foregroundColor(Color(uiColor: .tertiaryLabel)) +
    Text(String(format: "%.0f", carbs)).foregroundColor(.orange) +
    Text("C").foregroundColor(.secondary) +
    Text(" · ").foregroundColor(Color(uiColor: .tertiaryLabel)) +
    Text(String(format: "%.0f", fat)).foregroundColor(.purple) +
    Text("F").foregroundColor(.secondary)
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
    var size: CGFloat = 52

    private var iconColor: Color { foodIconColor(for: iconName) }

    var body: some View {
        Image(systemName: iconName ?? "fork.knife")
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundStyle(iconColor)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Meal Entry Row

struct MealEntryRow: View {
    let mealName: String
    let entries: [FoodEntry]

    private var totalCalories: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Double {
        entries.reduce(0) { $0 + $1.proteinGrams }
    }

    private var totalCarbs: Double {
        entries.reduce(0) { $0 + $1.carbsGrams }
    }

    private var totalFat: Double {
        entries.reduce(0) { $0 + $1.fatGrams }
    }

    var body: some View {
        HStack {
            if let photoData = entries.first?.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                FoodIconThumbnail(iconName: entries.first?.iconName ?? "fork.knife")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(mealName)
                    .font(.body)
                    .fontWeight(.medium)
                coloredMacroText(protein: totalProtein, carbs: totalCarbs, fat: totalFat)
                    .font(.caption)
                Text("\(entries.count) items")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("\(totalCalories) cal")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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
            ("Protein", protein, proteinTarget, .blue),
            ("Carbs", carbs, carbsTarget, .orange),
            ("Fat", fat, fatTarget, .purple),
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
                .foregroundStyle(.secondary)
        }
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack {
            if let photoData = entry.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                FoodIconThumbnail(iconName: entry.iconName ?? foodIconName(for: entry.name))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                coloredMacroText(protein: entry.proteinGrams, carbs: entry.carbsGrams, fat: entry.fatGrams)
                    .font(.caption)
            }

            Spacer()

            Text("\(entry.calories) cal")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Meal Group

struct MealGroup: Identifiable {
    let id: UUID
    let name: String
    let entries: [FoodEntry]
}

// MARK: - Meal Summary View

struct MealSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let mealGroup: MealGroup

    @State private var extractedColor: Color?

    private var totalCalories: Int { mealGroup.entries.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { mealGroup.entries.reduce(0) { $0 + $1.proteinGrams } }
    private var totalCarbs: Double { mealGroup.entries.reduce(0) { $0 + $1.carbsGrams } }
    private var totalFat: Double { mealGroup.entries.reduce(0) { $0 + $1.fatGrams } }

    private var proteinCals: Double { totalProtein * 4 }
    private var carbsCals: Double { totalCarbs * 4 }
    private var fatCals: Double { totalFat * 9 }
    private var totalMacroCals: Double { proteinCals + carbsCals + fatCals }

    private var proteinPct: Int {
        guard totalMacroCals > 0 else { return 0 }
        return Int((proteinCals / totalMacroCals * 100).rounded())
    }
    private var carbsPct: Int {
        guard totalMacroCals > 0 else { return 0 }
        return Int((carbsCals / totalMacroCals * 100).rounded())
    }
    private var fatPct: Int {
        guard totalMacroCals > 0 else { return 0 }
        return Int((fatCals / totalMacroCals * 100).rounded())
    }

    private var hasTargets: Bool {
        DailyTarget.calories > 0 || DailyTarget.protein > 0 || DailyTarget.carbs > 0 || DailyTarget.fat > 0
    }

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
        // Derive from first entry's food icon category
        let iconName = mealGroup.entries.first?.iconName ?? foodIconName(for: mealGroup.name)
        return mealIconDarkColor(for: iconName)
    }

    private func mealIconDarkColor(for iconName: String) -> Color {
        switch iconName {
        case "bird": return Color(red: 0.15, green: 0.10, blue: 0.05)
        case "flame": return Color(red: 0.21, green: 0.09, blue: 0.05)
        case "fish": return Color(red: 0.05, green: 0.15, blue: 0.15)
        case "egg": return Color(red: 0.22, green: 0.19, blue: 0.08)
        case "cup.and.saucer": return Color(red: 0.14, green: 0.09, blue: 0.05)
        case "cup.and.saucer.fill": return Color(red: 0.10, green: 0.15, blue: 0.20)
        case "waterbottle": return Color(red: 0.05, green: 0.15, blue: 0.18)
        case "wineglass": return Color(red: 0.15, green: 0.05, blue: 0.10)
        case "birthday.cake": return Color(red: 0.18, green: 0.08, blue: 0.12)
        case "takeoutbag.and.cup.and.straw": return Color(red: 0.20, green: 0.12, blue: 0.05)
        case "triangle": return Color(red: 0.22, green: 0.08, blue: 0.05)
        case "leaf": return Color(red: 0.05, green: 0.15, blue: 0.05)
        case "carrot": return Color(red: 0.24, green: 0.14, blue: 0.05)
        case "leaf.circle": return Color(red: 0.12, green: 0.15, blue: 0.08)
        case "chart.bar": return Color(red: 0.10, green: 0.12, blue: 0.18)
        case "snowflake": return Color(red: 0.12, green: 0.19, blue: 0.22)
        case "bowl": return Color(red: 0.20, green: 0.14, blue: 0.06)
        default: return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
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
                            if let uiImage = mealImage {
                                ZStack(alignment: .bottom) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: fullGeo.size.width, height: fullGeo.size.height * 0.65)
                                        .clipped()

                                    LinearGradient(
                                        stops: [
                                            .init(color: .clear, location: 0.0),
                                            .init(color: bgColor.opacity(0.3), location: 0.3),
                                            .init(color: bgColor.opacity(0.85), location: 0.7),
                                            .init(color: bgColor, location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: fullGeo.size.height * 0.65 * 0.6)

                                    VStack(spacing: 12) {
                                        Text(mealGroup.name)
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.center)
                                            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

                                        HStack(spacing: 12) {
                                            metricPill(value: "\(totalCalories)", label: "cal", color: .white)
                                            metricPill(value: formatMacro(totalProtein), label: "P", color: .blue)
                                            metricPill(value: formatMacro(totalCarbs), label: "C", color: .orange)
                                            metricPill(value: formatMacro(totalFat), label: "F", color: .purple)
                                        }

                                        if totalMacroCals > 0 {
                                            macroDonut(size: 80)
                                        }
                                    }
                                    .padding(.bottom, 16)
                                    .padding(.horizontal, 16)
                                }
                                .frame(height: fullGeo.size.height * 0.65)
                            } else {
                                // No photo — icon hero with category color
                                let iconName = mealGroup.entries.first?.iconName ?? foodIconName(for: mealGroup.name)
                                let iconClr = foodIconColor(for: iconName)

                                ZStack(alignment: .bottom) {
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

                                        Text(mealGroup.name)
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.center)
                                            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

                                        HStack(spacing: 12) {
                                            metricPill(value: "\(totalCalories)", label: "cal", color: .white)
                                            metricPill(value: formatMacro(totalProtein), label: "P", color: .blue)
                                            metricPill(value: formatMacro(totalCarbs), label: "C", color: .orange)
                                            metricPill(value: formatMacro(totalFat), label: "F", color: .purple)
                                        }

                                        if totalMacroCals > 0 {
                                            macroDonut(size: 80)
                                        }
                                    }
                                    .padding(.bottom, 16)
                                    .padding(.horizontal, 16)
                                }
                                .padding(.top, 44)
                            }

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
                                                Text("\(entry.calories) cal")
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

                                if hasTargets {
                                    dailyGoalBars
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
                extractedColor = dominantColor(from: uiImage)
            }
        }
    }

    private func metricPill(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.subheadline).fontWeight(.bold)
            Text(label).font(.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private func macroDonut(size: CGFloat) -> some View {
        let segments: [(name: String, cals: Double, color: Color)] = [
            ("Protein", proteinCals, .blue),
            ("Carbs", carbsCals, .orange),
            ("Fat", fatCals, .purple),
        ].filter { $0.cals > 0 }

        return HStack(spacing: 12) {
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
                pctLabel(pct: proteinPct, name: "P", color: .blue)
                pctLabel(pct: carbsPct, name: "C", color: .orange)
                pctLabel(pct: fatPct, name: "F", color: .purple)
            }
        }
    }

    private func pctLabel(pct: Int, name: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(pct)% \(name)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var dailyGoalBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("% of Daily Goal")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6))

            VStack(spacing: 8) {
                if DailyTarget.calories > 0 {
                    goalBar(label: "Cal", value: Double(totalCalories), target: Double(DailyTarget.calories), color: .gray)
                }
                if DailyTarget.protein > 0 {
                    goalBar(label: "Protein", value: totalProtein, target: Double(DailyTarget.protein), color: .blue)
                }
                if DailyTarget.carbs > 0 {
                    goalBar(label: "Carbs", value: totalCarbs, target: Double(DailyTarget.carbs), color: .orange)
                }
                if DailyTarget.fat > 0 {
                    goalBar(label: "Fat", value: totalFat, target: Double(DailyTarget.fat), color: .purple)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func goalBar(label: String, value: Double, target: Double, color: Color) -> some View {
        let pct = target > 0 ? Int((value / target * 100).rounded()) : 0
        return HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 48, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1)).frame(height: 6)
                    Capsule().fill(color).frame(width: geo.size.width * min(value / max(target, 1), 1.0), height: 6)
                }
            }
            .frame(height: 6)
            Text("\(pct)%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func formatMacro(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    private func dominantColor(from image: UIImage) -> Color? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let sampleHeight = max(height / 5, 1)
        let yOffset = height - sampleHeight
        guard let cropped = cgImage.cropping(to: CGRect(x: 0, y: yOffset, width: width, height: sampleHeight)) else { return nil }

        let ciImage = CIImage(cgImage: cropped)
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ])
        guard let outputImage = filter?.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)

        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        let darkenFactor: Double = colorScheme == .dark ? 0.3 : 0.55
        return Color(red: r * darkenFactor, green: g * darkenFactor, blue: b * darkenFactor)
    }
}
