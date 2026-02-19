import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Calories", text: $caloriesText)
                        .keyboardType(.numberPad)
                }

                Section("Macros (grams)") {
                    TextField("Protein", text: $proteinText)
                        .keyboardType(.decimalPad)
                    TextField("Carbs", text: $carbsText)
                        .keyboardType(.decimalPad)
                    TextField("Fat", text: $fatText)
                        .keyboardType(.decimalPad)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || caloriesText.isEmpty)
                }
            }
        }
    }

    private func save() {
        let entry = FoodEntry(
            name: name,
            calories: Int(caloriesText) ?? 0,
            proteinGrams: Double(proteinText) ?? 0,
            carbsGrams: Double(carbsText) ?? 0,
            fatGrams: Double(fatText) ?? 0,
            notes: notes,
            iconName: foodIconName(for: name)
        )
        modelContext.insert(entry)
        dismiss()
    }
}
