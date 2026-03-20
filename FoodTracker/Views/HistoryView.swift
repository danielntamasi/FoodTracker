import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @State private var editingEntry: FoodEntry?
    @State private var editingMealGroup: MealGroup?
    @State private var expandedGroups: Set<UUID> = []
    @State private var expandedDays: Set<String> = []

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
                                        Button { editingEntry = entry } label: {
                                            FoodEntryRow(entry: entry)
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
                                                    .foregroundStyle(DS.Color.textTertiary)
                                                    .frame(width: 44, height: 44)
                                                    .contentShape(Rectangle())
                                            }
                                            .accessibilityLabel(expandedGroups.contains(groupID) ? "Collapse meal" : "Expand meal")
                                            .buttonStyle(.plain)
                                        }
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

                                        if expandedGroups.contains(groupID) {
                                            let groupPhoto = entries.first(where: { $0.photoData != nil })?.photoData
                                            ForEach(entries) { entry in
                                                Button { editingEntry = entry } label: {
                                                    FoodEntryRow(entry: entry, groupPhotoData: groupPhoto)
                                                        .contentShape(Rectangle())
                                                }
                                                .buttonStyle(PressableButtonStyle())
                                                    .padding(.leading, 16)
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
                                        .foregroundStyle(DS.Color.textTertiary)
                                        .frame(width: 16)
                                    Text(dateString)
                                        .font(DS.Typography.labelS)
                                        .foregroundStyle(DS.Color.textSecondary)
                                    Spacer()
                                    let dayCals = dayEntries.reduce(0) { $0 + $1.totalCalories }
                                    let dayP = dayEntries.reduce(0.0) { $0 + $1.totalProteinGrams }
                                    let dayC = dayEntries.reduce(0.0) { $0 + $1.totalCarbsGrams }
                                    let dayF = dayEntries.reduce(0.0) { $0 + $1.totalFatGrams }
                                    Text("\(dayCals) cal")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Color.textSecondary)
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
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DS.Color.backgroundPrimary)
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
