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
    @State private var servings: Double = 1.0
    @State private var servingDesc: String?
    @State private var servingWeight: Double?
    @State private var lookup = NutritionLookup()

    private var hasContent: Bool {
        !name.isEmpty || !caloriesText.isEmpty || !proteinText.isEmpty || !carbsText.isEmpty || !fatText.isEmpty
    }

    /// Pre-fill from a USDA result (used by SearchFoodView)
    var prefill: USDAService.USDALookupResult?
    /// Called after a successful save (before dismiss)
    var onSave: (() -> Void)?
    /// When set, saves as an IngredientItem instead of a FoodEntry (used by BuildMealView)
    var onIngredientAdded: ((IngredientItem) -> Void)?

    private var servingSizeLabel: String? {
        if let desc = servingDesc, let grams = servingWeight {
            return "\(desc) (\(Int(grams))g)"
        } else if let desc = servingDesc {
            return desc
        } else if let grams = servingWeight {
            return "\(Int(grams))g"
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    HStack {
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.sentences)
                        if !name.isEmpty {
                            if lookup.isLookingUp {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button { lookup.lookupNutrition(for: name) } label: {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .accessibilityLabel("Look up nutrition")
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    TextField("Calories", text: $caloriesText)
                        .keyboardType(.numberPad)
                }

                if !lookup.lookupResults.isEmpty {
                    Section {
                        USDAResultsList(results: lookup.lookupResults, selectedIndex: Binding(
                            get: { lookup.selectedResultIndex },
                            set: { lookup.selectedResultIndex = $0 }
                        ))
                            .onChange(of: lookup.selectedResultIndex) { _, newIndex in
                                if let index = newIndex {
                                    acceptResult(lookup.lookupResults[index])
                                }
                            }
                    } header: {
                        Text("USDA Results")
                    } footer: {
                        Text("Tap a result to fill in nutrition data.")
                    }
                }

                if let error = lookup.lookupError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(DS.Color.danger)
                    }
                }

                if let estimate = lookup.aiEstimate {
                    Section {
                        USDAResultCard(result: estimate, isSelected: true) {
                            acceptResult(estimate)
                        }
                    } header: {
                        Text("AI Estimate")
                    } footer: {
                        Text("Estimated by \(VisionProvider.selected.rawValue).")
                    }
                }

                if !name.isEmpty && !lookup.isLookingUp && !lookup.isEstimating && lookup.aiEstimate == nil {
                    Section {
                        Button {
                            lookup.runAIEstimate(for: name)
                        } label: {
                            HStack {
                                Label("AI Estimate", systemImage: "sparkles")
                                Spacer()
                                if lookup.isEstimating {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(lookup.isEstimating)
                    } footer: {
                        Text("Use AI to estimate nutrition for prepared or complex foods.")
                    }
                }

                Section("Macros (grams)") {
                    TextField("Protein", text: $proteinText)
                        .keyboardType(.decimalPad)
                    TextField("Carbs", text: $carbsText)
                        .keyboardType(.decimalPad)
                    TextField("Fat", text: $fatText)
                        .keyboardType(.decimalPad)
                }

                Section("Servings") {
                    if let servingSizeText = servingSizeLabel {
                        HStack {
                            Text("Serving Size")
                            Spacer()
                            Text(servingSizeText)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ServingPicker(servings: $servings)

                    if servings != 1.0, let cal = Int(caloriesText), cal > 0 {
                        let totalCal = Int((Double(cal) * servings).rounded())
                        let totalP = (Double(proteinText) ?? 0) * servings
                        let totalC = (Double(carbsText) ?? 0) * servings
                        let totalF = (Double(fatText) ?? 0) * servings
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Total")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(totalCal) cal")
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                            HStack {
                                Spacer()
                                coloredMacroText(protein: totalP, carbs: totalC, fat: totalF)
                                    .font(.caption)
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(onIngredientAdded != nil ? "Add Ingredient" : "Add Food")
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
            .interactiveDismissDisabled(hasContent)
            .onAppear {
                if let prefill {
                    applyPrefill(prefill)
                }
            }
            .onChange(of: lookup.aiEstimate?.description) { _, _ in
                if let estimate = lookup.aiEstimate {
                    acceptResult(estimate)
                }
            }
        }
    }

    private func applyPrefill(_ result: USDAService.USDALookupResult) {
        name = result.description.titleCased()
        let scaled = result.perServing
        caloriesText = "\(Int(scaled.calories))"
        proteinText = "\(scaled.protein)"
        carbsText = "\(scaled.carbs)"
        fatText = "\(scaled.fat)"
        servingDesc = result.servingDescription
        servingWeight = result.servingGrams
    }

    private func acceptResult(_ result: USDAService.USDALookupResult) {
        let scaled = result.perServing
        caloriesText = "\(Int(scaled.calories))"
        proteinText = "\(scaled.protein)"
        carbsText = "\(scaled.carbs)"
        fatText = "\(scaled.fat)"
        servingDesc = result.servingDescription
        servingWeight = result.servingGrams
    }

    private func save() {
        if let onIngredientAdded {
            onIngredientAdded(IngredientItem(
                name: name.titleCased(),
                calories: Int(caloriesText) ?? 0,
                proteinGrams: Double(proteinText) ?? 0,
                carbsGrams: Double(carbsText) ?? 0,
                fatGrams: Double(fatText) ?? 0,
                servings: servings,
                servingDescription: servingDesc,
                servingGrams: servingWeight
            ))
            dismiss()
            return
        }

        let entry = FoodEntry(
            name: name.titleCased(),
            calories: Int(caloriesText) ?? 0,
            proteinGrams: Double(proteinText) ?? 0,
            carbsGrams: Double(carbsText) ?? 0,
            fatGrams: Double(fatText) ?? 0,
            notes: notes,
            iconName: foodIconName(for: name),
            servings: servings,
            servingDescription: servingDesc,
            servingGrams: servingWeight
        )
        modelContext.insert(entry)
        Task { await HealthKitService.shared.syncEntry(entry) }
        onSave?()
        dismiss()
    }

}
