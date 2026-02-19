import SwiftUI
import SwiftData

struct DailySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [FoodEntry]
    @State private var showingAddEntry = false
    @State private var showingPhotoCapture = false
    @State private var showingBarcodeScanner = false

    private var todayEntries: [FoodEntry] {
        let calendar = Calendar.current
        return allEntries.filter { calendar.isDateInToday($0.date) }
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

    var body: some View {
        NavigationStack {
            List {
                Section {
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

                Section("Today's Food") {
                    if todayEntries.isEmpty {
                        ContentUnavailableView(
                            "No entries yet",
                            systemImage: "fork.knife",
                            description: Text("Add your first meal to start tracking.")
                        )
                    } else {
                        ForEach(groupedDisplayItems(from: todayEntries), id: \.id) { item in
                            switch item {
                            case .standalone(let entry):
                                FoodEntryRow(entry: entry)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            modelContext.delete(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            case .mealGroup(let groupID, let mealName, let entries):
                                DisclosureGroup {
                                    ForEach(entries) { entry in
                                        FoodEntryRow(entry: entry)
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
        }
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
