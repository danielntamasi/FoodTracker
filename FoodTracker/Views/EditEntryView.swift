import SwiftUI
import SwiftData

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: FoodEntry

    @State private var isLookingUp = false
    @State private var lookupError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $entry.name)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("Calories", value: $entry.calories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Macros (grams)") {
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("Protein", value: $entry.proteinGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("Carbs", value: $entry.carbsGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("Fat", value: $entry.fatGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $entry.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        lookupNutrition()
                    } label: {
                        HStack {
                            Label("AI Lookup", systemImage: "sparkles")
                            Spacer()
                            if isLookingUp {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(entry.name.isEmpty || isLookingUp)

                    if let error = lookupError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Look up nutrition data from USDA based on the food name.")
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func lookupNutrition() {
        isLookingUp = true
        lookupError = nil

        Task {
            do {
                let nutrients = try await USDAService.shared.lookupNutrients(for: entry.name)
                if nutrients.calories > 0 || nutrients.protein > 0 || nutrients.carbs > 0 || nutrients.fat > 0 {
                    // Assume 100g default portion if we don't have portion info
                    entry.calories = Int(nutrients.calories)
                    entry.proteinGrams = (nutrients.protein * 10).rounded() / 10
                    entry.carbsGrams = (nutrients.carbs * 10).rounded() / 10
                    entry.fatGrams = (nutrients.fat * 10).rounded() / 10
                } else {
                    lookupError = "No nutrition data found for \"\(entry.name)\"."
                }
            } catch {
                lookupError = error.localizedDescription
            }
            isLookingUp = false
        }
    }
}
