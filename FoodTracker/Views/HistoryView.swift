import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @State private var editingEntry: FoodEntry?

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
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "calendar",
                        description: Text("Your food entries will appear here.")
                    )
                } else {
                    ForEach(groupedEntries, id: \.0) { dateString, dayEntries in
                        Section {
                            ForEach(groupedDisplayItems(from: dayEntries), id: \.id) { item in
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
                        } header: {
                            HStack {
                                Text(dateString)
                                Spacer()
                                let dayCals = dayEntries.reduce(0) { $0 + $1.calories }
                                Text("\(dayCals) cal")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(item: $editingEntry) { entry in
                EditEntryView(entry: entry)
            }
        }
    }
}
