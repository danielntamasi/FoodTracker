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
    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var lookupResults: [USDAService.USDALookupResult] = []
    @State private var selectedResultIndex: Int?
    @State private var isEstimating = false
    @State private var aiEstimate: USDAService.USDALookupResult?

    /// Pre-fill from a USDA result (used by SearchFoodView)
    var prefill: USDAService.USDALookupResult?

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
                            if isLookingUp {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button { lookupNutrition() } label: {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    TextField("Calories", text: $caloriesText)
                        .keyboardType(.numberPad)
                }

                if !lookupResults.isEmpty {
                    Section {
                        USDAResultsList(results: lookupResults, selectedIndex: $selectedResultIndex)
                            .onChange(of: selectedResultIndex) { _, newIndex in
                                if let index = newIndex {
                                    acceptResult(lookupResults[index])
                                }
                            }
                    } header: {
                        Text("USDA Results")
                    } footer: {
                        Text("Tap a result to fill in nutrition data.")
                    }
                }

                if let error = lookupError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let estimate = aiEstimate {
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

                if !name.isEmpty && !isLookingUp && !isEstimating && aiEstimate == nil {
                    Section {
                        Button {
                            runAIEstimate()
                        } label: {
                            HStack {
                                Label("AI Estimate", systemImage: "brain")
                                Spacer()
                                if isEstimating {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isEstimating)
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
                                    .foregroundStyle(.secondary)
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
            .onAppear {
                if let prefill {
                    applyPrefill(prefill)
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

    private func lookupNutrition() {
        isLookingUp = true
        lookupError = nil
        lookupResults = []
        selectedResultIndex = nil
        aiEstimate = nil

        Task {
            do {
                let results = try await USDAService.shared.lookupFoodOptions(for: name)
                withAnimation {
                    if results.isEmpty {
                        lookupError = "No nutrition data found for \"\(name)\"."
                    } else {
                        lookupResults = results
                    }
                }
            } catch {
                lookupError = error.localizedDescription
            }
            isLookingUp = false
        }
    }

    private func runAIEstimate() {
        isEstimating = true
        lookupError = nil

        Task {
            do {
                let result = try await FoodAnalysisPipeline.estimateNutrition(for: name)
                withAnimation {
                    aiEstimate = result
                    acceptResult(result)
                }
            } catch {
                lookupError = error.localizedDescription
            }
            isEstimating = false
        }
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
        dismiss()
    }

}
