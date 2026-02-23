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
    @State private var reverseChronological = sharedDefaults.bool(forKey: "reverseChronological")
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var orderedPeriods: [TimeOfDay] {
        reverseChronological ? TimeOfDay.allCases.reversed() : TimeOfDay.allCases
    }

    private var todayEntries: [FoodEntry] {
        let calendar = Calendar.current
        return allEntries
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted {
                if let a = $0.sortOrder, let b = $1.sortOrder { return a < b }
                if $0.sortOrder != nil { return true }
                if $1.sortOrder != nil { return false }
                return $0.date > $1.date
            }
    }

    /// Always today's entries — used exclusively for widget sync
    private var actualTodayEntries: [FoodEntry] {
        let calendar = Calendar.current
        return allEntries.filter { calendar.isDateInToday($0.date) }
    }

    private var totals: (cal: Int, protein: Double, carbs: Double, fat: Double) {
        var cal = 0; var p = 0.0; var c = 0.0; var f = 0.0
        for e in todayEntries { cal += e.totalCalories; p += e.totalProteinGrams; c += e.totalCarbsGrams; f += e.totalFatGrams }
        return (cal, p, c, f)
    }

    private var totalCalories: Int { totals.cal }
    private var totalProtein: Double { totals.protein }
    private var totalCarbs: Double { totals.carbs }
    private var totalFat: Double { totals.fat }

    /// Pre-computed set of day keys (yyyy-MM-dd) that have entries — used by date strip dot indicators
    private var entryDateSet: Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(allEntries.map { formatter.string(from: $0.date) })
    }

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
        var cal = 0; var p = 0.0; var c = 0.0; var f = 0.0
        for e in actualTodayEntries { cal += e.totalCalories; p += e.totalProteinGrams; c += e.totalCarbsGrams; f += e.totalFatGrams }
        return "\(cal)-\(p)-\(c)-\(f)-\(actualTodayEntries.count)"
    }

    private func syncWidgetData() {
        var cal = 0; var p = 0.0; var c = 0.0; var f = 0.0
        for e in actualTodayEntries { cal += e.totalCalories; p += e.totalProteinGrams; c += e.totalCarbsGrams; f += e.totalFatGrams }
        sharedDefaults.set(cal, forKey: "widgetCalories")
        sharedDefaults.set(p, forKey: "widgetProtein")
        sharedDefaults.set(c, forKey: "widgetCarbs")
        sharedDefaults.set(f, forKey: "widgetFat")
        sharedDefaults.set(Date.now.timeIntervalSince1970, forKey: "widgetLastSync")
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
                // Date navigation strip
                WeekDateStripView(selectedDate: $selectedDate, entryDates: entryDateSet)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))

                // Summary card
                summaryCard
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))

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
                                .listRowBackground(Color.appBackground)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

                        case .entry(let displayItem):
                            entryCard(for: displayItem)
                                .listRowBackground(Color.appBackground)
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
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
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
        .background(
            VStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        .init(color: .headerGradientStart, location: 0.0),
                        .init(color: .headerGradientEnd, location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 300)
                Color.appBackground
            }
            .ignoresSafeArea()
        )
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        Group {
            if DailyTarget.hasTargets {
                TripleRingCard(
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
                        MacroLabel(label: "Protein", value: totalProtein, color: .macroProtein)
                        MacroLabel(label: "Carbs", value: totalCarbs, color: .macroCarbs)
                        MacroLabel(label: "Fat", value: totalFat, color: .macroFat)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.10), radius: 16, y: 6)
            }
        }
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
            Text(period.rawValue.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.8)

            Spacer()

            if period == orderedPeriods.first(where: { p in todayEntries.contains { TimeOfDay.from($0.date) == p } }) {
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                        reverseChronological.toggle()
                        sharedDefaults.set(reverseChronological, forKey: "reverseChronological")
                    }
                } label: {
                    Image(systemName: reverseChronological ? "arrow.down" : "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    Button { quickAddEntry(entry, into: modelContext) } label: {
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                Button { quickAddMealGroup(entries, mealName: mealName, into: modelContext) } label: {
                    Label("Add Again", systemImage: "plus.circle")
                }
                .tint(.green)
            }
        }
    }

    // MARK: - Expanded Sub-Item Row

    private func expandedSubItemRow(entry: FoodEntry, groupPhotoData: Data? = nil) -> some View {
        FoodEntryRow(entry: entry, groupPhotoData: groupPhotoData)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.cardBackground)
            .contentShape(Rectangle())
            .onTapGesture { editingEntry = entry }
            .listRowBackground(Color.appBackground)
            .listRowSeparator(.visible)
            .listRowSeparatorTint(Color(.separator).opacity(0.4))
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 16))
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
                Button { quickAddEntry(entry, into: modelContext) } label: {
                    Label("Add Again", systemImage: "plus.circle")
                }
                .tint(.green)
            }
    }
}

// MARK: - Week Date Strip

struct WeekDateStripView: View {
    @Binding var selectedDate: Date
    let entryDates: Set<String>

    private let calendar = Calendar.current
    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    private var weekDays: [Date] {
        // Monday-anchored week containing selectedDate
        let weekday = calendar.component(.weekday, from: selectedDate)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: selectedDate)!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var navigationTitle: String {
        if calendar.isDateInToday(selectedDate) { return "Today" }
        if calendar.isDateInYesterday(selectedDate) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f.string(from: selectedDate)
    }

    private var canGoForward: Bool {
        guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) else { return false }
        return calendar.startOfDay(for: nextWeek) <= calendar.startOfDay(for: Date())
    }

    var body: some View {
        VStack(spacing: 10) {
            // Navigation row
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(navigationTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let next = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                        if calendar.startOfDay(for: next) <= calendar.startOfDay(for: Date()) {
                            selectedDate = next
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(canGoForward ? .white : .white.opacity(0.3))
                        .frame(width: 44, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
            }
            .padding(.horizontal, 8)

            // Day strip
            HStack(spacing: 0) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                    dayCellView(day: day, letter: dayLetters[index])
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.bottom, 8)
    }

    private func dayCellView(day: Date, letter: String) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let isFuture = calendar.startOfDay(for: day) > calendar.startOfDay(for: Date())
        let dayNum = calendar.component(.day, from: day)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: day)
        let hasEntries = entryDates.contains(dateKey)

        return Button {
            guard !isFuture else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = day
            }
        } label: {
            VStack(spacing: 4) {
                Text(letter)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isFuture ? .white.opacity(0.3) : .white.opacity(0.75))

                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 34, height: 34)
                    } else if isToday {
                        Circle()
                            .strokeBorder(.white, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                    }

                    Text("\(dayNum)")
                        .font(.system(size: 14, weight: isSelected ? .bold : .regular, design: .rounded))
                        .foregroundStyle(
                            isSelected ? Color.headerGradientEnd :
                            isFuture ? .white.opacity(0.3) : .white
                        )
                }

                // Entry presence dot
                Circle()
                    .fill(hasEntries && !isSelected ? Color.white.opacity(0.7) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }
}

// MARK: - Triple Ring Card

struct TripleRingCard: View {
    let calories: Int
    let calorieTarget: Int
    let protein: Double
    let proteinTarget: Double
    let carbs: Double
    let carbsTarget: Double
    let fat: Double
    let fatTarget: Double

    var body: some View {
        VStack(spacing: 0) {
            if calorieTarget > 0 {
                let remaining = calorieTarget - calories
                HStack {
                    Text(remaining >= 0 ? "\(remaining) kcal remaining" : "\(abs(remaining)) kcal over")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
                    Spacer()
                    Text("\(calories) / \(calorieTarget) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
            }

            HStack(spacing: 0) {
                MacroRingColumn(label: "Protein", value: protein, target: proteinTarget, color: .macroProtein)

                Divider()
                    .frame(height: 60)
                    .padding(.vertical, 16)

                MacroRingColumn(label: "Fats", value: fat, target: fatTarget, color: .macroFat)

                Divider()
                    .frame(height: 60)
                    .padding(.vertical, 16)

                MacroRingColumn(label: "Carbs", value: carbs, target: carbsTarget, color: .macroCarbs)
            }
            .padding(.vertical, calorieTarget > 0 ? 12 : 20)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.10), radius: 16, y: 6)
    }
}

struct MacroRingColumn: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color

    private var progress: Double {
        target > 0 ? min(value / target, 1.0) : 0
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.5), value: value)

                Text(String(format: "%.0f", value))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4), value: value)
            }
            .frame(width: 60, height: 60)

            if target > 0 {
                Text("\(String(format: "%.0f", value))/\(String(format: "%.0f", target))")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4), value: value)
            } else {
                Text(String(format: "%.0fg", value))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
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
    Text(String(format: "%.0f", protein)).foregroundColor(.macroProtein) +
    Text("P").foregroundColor(.secondary) +
    Text(" · ").foregroundColor(Color(uiColor: .tertiaryLabel)) +
    Text(String(format: "%.0f", carbs)).foregroundColor(.macroCarbs) +
    Text("C").foregroundColor(.secondary) +
    Text(" · ").foregroundColor(Color(uiColor: .tertiaryLabel)) +
    Text(String(format: "%.0f", fat)).foregroundColor(.macroFat) +
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

    private var totalCalories: Int    { entries.reduce(0) { $0 + $1.totalCalories } }
    private var totalProtein: Double  { entries.reduce(0) { $0 + $1.totalProteinGrams } }
    private var totalCarbs: Double    { entries.reduce(0) { $0 + $1.totalCarbsGrams } }
    private var totalFat: Double      { entries.reduce(0) { $0 + $1.totalFatGrams } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(mealName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(totalCalories) kcal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 6) {
                mealMacroPill(letter: "P", value: totalProtein, target: Double(DailyTarget.protein), color: .macroProtein)
                mealMacroPill(letter: "F", value: totalFat,     target: Double(DailyTarget.fat),     color: .macroFat)
                mealMacroPill(letter: "C", value: totalCarbs,   target: Double(DailyTarget.carbs),   color: .macroCarbs)
                Spacer()
                Text("\(entries.count) items")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func mealMacroPill(letter: String, value: Double, target: Double, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(letter)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            if target > 0 {
                Text("\(String(format: "%.0f", value))/\(String(format: "%.0f", target))")
                    .font(.caption2)
                    .foregroundStyle(Color(.secondaryLabel))
            } else {
                Text(String(format: "%.0fg", value))
                    .font(.caption2)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }
}

// MARK: - Macro Donut Card (legacy — kept for reference)

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
            ("Protein", protein, proteinTarget, Color.macroProtein),
            ("Carbs", carbs, carbsTarget, Color.macroCarbs),
            ("Fat", fat, fatTarget, Color.macroFat),
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
    var groupPhotoData: Data? = nil

    private var effectivePhotoData: Data? {
        entry.photoData ?? groupPhotoData
    }

    private var weightLabel: String? {
        guard let sg = entry.servingGrams else { return nil }
        let totalGrams = sg * entry.servings
        if totalGrams == totalGrams.rounded() {
            return String(format: "%.0f g", totalGrams)
        }
        return String(format: "%.1f g", totalGrams)
    }

    var body: some View {
        HStack(spacing: 12) {
            if effectivePhotoData != nil {
                CachedThumbnailImage(photoData: effectivePhotoData, size: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let weight = weightLabel {
                    Text(weight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if entry.servings != 1.0 {
                    Text(formatServings(entry.servings) + (entry.servings == 1.0 ? " serving" : " servings"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(entry.totalCalories) kcal")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
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
