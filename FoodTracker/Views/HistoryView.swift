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

                                        if expandedGroups.contains(groupID) {
                                            let groupPhoto = entries.first(where: { $0.photoData != nil })?.photoData
                                            ForEach(entries) { entry in
                                                FoodEntryRow(entry: entry, groupPhotoData: groupPhoto)
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
                                        .foregroundStyle(.secondary)
                                        .frame(width: 12)
                                    Text(dateString)
                                    Spacer()
                                    let dayCals = dayEntries.reduce(0) { $0 + $1.totalCalories }
                                    let dayP = dayEntries.reduce(0.0) { $0 + $1.totalProteinGrams }
                                    let dayC = dayEntries.reduce(0.0) { $0 + $1.totalCarbsGrams }
                                    let dayF = dayEntries.reduce(0.0) { $0 + $1.totalFatGrams }
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
