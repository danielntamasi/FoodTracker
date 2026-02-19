import SwiftUI
import SwiftData

struct DailySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [FoodEntry]
    @State private var showingAddEntry = false
    @State private var showingPhotoCapture = false

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
                        ForEach(todayEntries) { entry in
                            FoodEntryRow(entry: entry)
                        }
                        .onDelete(perform: deleteEntries)
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
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(todayEntries[index])
        }
    }
}

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
