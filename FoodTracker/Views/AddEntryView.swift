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
    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var pendingNutrients: (calories: Int, protein: Double, carbs: Double, fat: Double)?

    private let servingPresets: [Double] = stride(from: 0.25, through: 3.0, by: 0.25).map { $0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.sentences)
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

                Section("Servings") {
                    HStack {
                        Text("Servings")
                        Spacer()
                        Text(formatServings(servings))
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(servingPresets, id: \.self) { preset in
                                Button {
                                    servings = preset
                                } label: {
                                    Text(formatServings(preset))
                                        .font(.subheadline)
                                        .fontWeight(servings == preset ? .bold : .regular)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            servings == preset
                                                ? Color.accentColor.opacity(0.2)
                                                : Color(.systemGray5)
                                        )
                                        .foregroundStyle(
                                            servings == preset
                                                ? Color.accentColor
                                                : .primary
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        Text("Custom")
                        Spacer()
                        TextField("Servings", value: $servings, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                    }

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
                    .disabled(name.isEmpty || isLookingUp)

                    if let nutrients = pendingNutrients {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("USDA Result")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(nutrients.calories) cal")
                                    Text("P: \(nutrients.protein, specifier: "%.1f")g  C: \(nutrients.carbs, specifier: "%.1f")g  F: \(nutrients.fat, specifier: "%.1f")g")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    acceptNutrients(nutrients)
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .imageScale(.large)
                                }
                                .buttonStyle(.borderless)
                                Button {
                                    withAnimation { pendingNutrients = nil }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                        .imageScale(.large)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .transition(.opacity)
                    }

                    if let error = lookupError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Look up nutrition data from USDA based on the food name.")
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

    private func lookupNutrition() {
        isLookingUp = true
        lookupError = nil
        pendingNutrients = nil

        Task {
            do {
                let nutrients = try await USDAService.shared.lookupNutrients(for: name)
                if nutrients.calories > 0 || nutrients.protein > 0 || nutrients.carbs > 0 || nutrients.fat > 0 {
                    withAnimation {
                        pendingNutrients = (
                            calories: Int(nutrients.calories),
                            protein: (nutrients.protein * 10).rounded() / 10,
                            carbs: (nutrients.carbs * 10).rounded() / 10,
                            fat: (nutrients.fat * 10).rounded() / 10
                        )
                    }
                } else {
                    lookupError = "No nutrition data found for \"\(name)\"."
                }
            } catch {
                lookupError = error.localizedDescription
            }
            isLookingUp = false
        }
    }

    private func acceptNutrients(_ nutrients: (calories: Int, protein: Double, carbs: Double, fat: Double)) {
        caloriesText = "\(nutrients.calories)"
        proteinText = "\(nutrients.protein)"
        carbsText = "\(nutrients.carbs)"
        fatText = "\(nutrients.fat)"
        withAnimation { pendingNutrients = nil }
    }

    private func save() {
        let baseCal = Int(caloriesText) ?? 0
        let baseP = Double(proteinText) ?? 0
        let baseC = Double(carbsText) ?? 0
        let baseF = Double(fatText) ?? 0

        let entry = FoodEntry(
            name: name.titleCased(),
            calories: Int((Double(baseCal) * servings).rounded()),
            proteinGrams: (baseP * servings * 10).rounded() / 10,
            carbsGrams: (baseC * servings * 10).rounded() / 10,
            fatGrams: (baseF * servings * 10).rounded() / 10,
            notes: notes,
            iconName: foodIconName(for: name)
        )
        modelContext.insert(entry)
        dismiss()
    }

    private func formatServings(_ value: Double) -> String {
        let whole = Int(value)
        let frac = value - Double(whole)
        let fracStr: String?
        if abs(frac - 0.25) < 0.001 { fracStr = "\u{00BC}" }
        else if abs(frac - 0.5) < 0.001 { fracStr = "\u{00BD}" }
        else if abs(frac - 0.75) < 0.001 { fracStr = "\u{00BE}" }
        else if abs(frac) < 0.001 { fracStr = nil }
        else { return String(format: "%.2g", value) }

        if let f = fracStr {
            return whole > 0 ? "\(whole)\(f)" : f
        }
        return "\(whole)"
    }
}
