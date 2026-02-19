import SwiftUI
import SwiftData
import Charts

struct DailySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [FoodEntry]
    @State private var showingAddEntry = false
    @State private var showingPhotoCapture = false
    @State private var showingBarcodeScanner = false
    @State private var editingEntry: FoodEntry?

    private var todayEntries: [FoodEntry] {
        let calendar = Calendar.current
        return allEntries
            .filter { calendar.isDateInToday($0.date) }
            .sorted {
                // Entries with sortOrder take priority; otherwise sort by date descending
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

    private func reorderItems(_ items: [EntryDisplayItem], from source: IndexSet, to destination: Int) {
        var reordered = items
        reordered.move(fromOffsets: source, toOffset: destination)

        // Assign sortOrder to all underlying entries based on new position
        var order = 0
        for item in reordered {
            switch item {
            case .standalone(let entry):
                entry.sortOrder = order
                order += 1
            case .mealGroup(_, _, let entries):
                for entry in entries {
                    entry.sortOrder = order
                }
                order += 1
            }
        }
    }

    private var hasTargets: Bool {
        DailyTarget.calories > 0 || DailyTarget.protein > 0 || DailyTarget.carbs > 0 || DailyTarget.fat > 0
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
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

                if todayEntries.isEmpty {
                    Section("Today's Food") {
                        ContentUnavailableView(
                            "No entries yet",
                            systemImage: "fork.knife",
                            description: Text("Add your first meal to start tracking.")
                        )
                    }
                } else {
                    ForEach(TimeOfDay.allCases, id: \.self) { period in
                        let periodEntries = todayEntries.filter { TimeOfDay.from($0.date) == period }
                        if !periodEntries.isEmpty {
                            let displayItems = groupedDisplayItems(from: periodEntries)
                            Section {
                                ForEach(displayItems, id: \.id) { item in
                                    switch item {
                                    case .standalone(let entry):
                                        FoodEntryRow(entry: entry)
                                            .contentShape(Rectangle())
                                            .onTapGesture { editingEntry = entry }
                                            .swipeActions {
                                                Button(role: .destructive) {
                                                    modelContext.delete(entry)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    case .mealGroup(_, let mealName, let entries):
                                        DisclosureGroup {
                                            ForEach(entries) { entry in
                                                FoodEntryRow(entry: entry)
                                                    .contentShape(Rectangle())
                                                    .onTapGesture { editingEntry = entry }
                                            }
                                        } label: {
                                            MealEntryRow(mealName: mealName, entries: entries)
                                        }
                                        .swipeActions {
                                            Button(role: .destructive) {
                                                for entry in entries {
                                                    modelContext.delete(entry)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .onMove { source, destination in
                                    reorderItems(displayItems, from: source, to: destination)
                                }
                            } header: {
                                Label(period.rawValue, systemImage: period.systemImage)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddEntry = true
                        } label: {
                            Label("Add Manually", systemImage: "pencil")
                        }

                        Button {
                            showingPhotoCapture = true
                        } label: {
                            Label("Add with Photo", systemImage: "camera")
                        }

                        Button {
                            showingBarcodeScanner = true
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView()
            }
            .sheet(isPresented: $showingPhotoCapture) {
                PhotoCaptureView()
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView()
            }
            .sheet(item: $editingEntry) { entry in
                EditEntryView(entry: entry)
            }
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
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: entries.first?.iconName ?? "fork.knife")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(mealName)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    Text("P: \(String(format: "%.0f", totalProtein))g")
                    Text("C: \(String(format: "%.0f", totalCarbs))g")
                    Text("F: \(String(format: "%.0f", totalFat))g")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("\(entries.count) items")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("\(totalCalories) cal")
                .font(.subheadline)
                .fontWeight(.medium)
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

                        // Remaining portion
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

                // Calorie overlay
                VStack(spacing: 2) {
                    Text("\(calories)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    if calorieTarget > 0 {
                        Text("/ \(calorieTarget) cal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("calories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Macro progress bars
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
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: entry.iconName ?? "fork.knife")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                HStack(spacing: 8) {
                    Text("P: \(String(format: "%.0f", entry.proteinGrams))g")
                    Text("C: \(String(format: "%.0f", entry.carbsGrams))g")
                    Text("F: \(String(format: "%.0f", entry.fatGrams))g")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.calories) cal")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
