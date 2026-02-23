import SwiftUI
import SwiftData

struct PhotoAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let image: UIImage?

    @State private var identifiedFoods: [IdentifiedFood] = []
    @State private var isLoading: Bool
    @State private var loadingStatus = "Identifying food..."
    @State private var errorMessage: String?
    @State private var showCorrectionAlert = false
    @State private var pendingCorrections: [OpenFoodFactsService.CorrectionData] = []

    // Standard init for photo analysis
    init(image: UIImage) {
        self.image = image
        self._isLoading = State(initialValue: true)
    }

    // Init for barcode/pre-resolved results (no photo)
    init(foods: [IdentifiedFood]) {
        self.image = nil
        self._identifiedFoods = State(initialValue: foods)
        self._isLoading = State(initialValue: false)
    }

    /// Groups items by mealGroupID. Returns (groupID, mealName, indices) for groups,
    /// and (nil, nil, [index]) for standalone items — preserving original order.
    private var displayGroups: [(id: String, mealGroupID: UUID?, mealName: String?, indices: [Int])] {
        var result: [(id: String, mealGroupID: UUID?, mealName: String?, indices: [Int])] = []
        var seenGroups: Set<UUID> = []

        for (index, food) in identifiedFoods.enumerated() {
            if let groupID = food.mealGroupID {
                if seenGroups.contains(groupID) { continue }
                seenGroups.insert(groupID)
                let indices = identifiedFoods.indices.filter { identifiedFoods[$0].mealGroupID == groupID }
                result.append((id: groupID.uuidString, mealGroupID: groupID, mealName: food.mealName, indices: indices))
            } else {
                result.append((id: food.id.uuidString, mealGroupID: nil, mealName: nil, indices: [index]))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        ProgressView(loadingStatus)
                            .font(.headline)
                    }
                    .padding()
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("Analysis Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        if image != nil {
                            Button("Try Again") { analyzePhoto() }
                        }
                        Button("Cancel") { dismiss() }
                    }
                } else {
                    List {
                        if let image {
                            Section {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 150)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .listRowInsets(EdgeInsets())
                                    .padding()
                            }
                        }

                        ForEach(displayGroups, id: \.id) { group in
                            if group.mealGroupID != nil {
                                // Grouped meal
                                mealGroupSection(indices: group.indices)
                            } else {
                                // Standalone item
                                standaloneFoodSection(index: group.indices[0])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Food Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if !isLoading && errorMessage == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveAll() }
                            .disabled(identifiedFoods.isEmpty)
                    }
                }
            }
            .task {
                if image != nil && identifiedFoods.isEmpty {
                    analyzePhoto()
                }
            }
            .alert("Improve Nutrition Data?", isPresented: $showCorrectionAlert) {
                Button("Submit Correction") {
                    let corrections = pendingCorrections
                    Task { for c in corrections { await OpenFoodFactsService.shared.submitCorrection(c) } }
                    dismiss()
                }
                Button("No Thanks", role: .cancel) { dismiss() }
            } message: {
                Text("You corrected the nutrition data for a scanned product. Submit your correction to OpenFoodFacts to help other users?")
            }
        }
    }

    // MARK: - Meal Group Section

    @ViewBuilder
    private func mealGroupSection(indices: [Int]) -> some View {
        Section {
            DisclosureGroup {
                ForEach(indices, id: \.self) { index in
                    ingredientRow(index: index)
                }
            } label: {
                mealGroupHeader(indices: indices)
            }
        }
    }

    @ViewBuilder
    private func mealGroupHeader(indices: [Int]) -> some View {
        let totalCals = indices.reduce(0) { $0 + identifiedFoods[$1].calories }
        let totalProtein = indices.reduce(0.0) { $0 + identifiedFoods[$1].proteinGrams }
        let totalCarbs = indices.reduce(0.0) { $0 + identifiedFoods[$1].carbsGrams }
        let totalFat = indices.reduce(0.0) { $0 + identifiedFoods[$1].fatGrams }

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("Meal name", text: mealNameBinding(for: indices))
                    .font(.headline)
                    .textInputAutocapitalization(.sentences)
                Spacer()
                SourceBadge(source: .estimate)
            }
            HStack(spacing: 12) {
                Text("\(totalCals) cal")
                    .fontWeight(.medium)
                Text("P: \(String(format: "%.0f", totalProtein))g")
                Text("C: \(String(format: "%.0f", totalCarbs))g")
                Text("F: \(String(format: "%.0f", totalFat))g")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("\(indices.count) ingredients")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    /// Binding that updates mealName on all items in the group
    private func mealNameBinding(for indices: [Int]) -> Binding<String> {
        Binding(
            get: { identifiedFoods[indices[0]].mealName ?? "" },
            set: { newValue in
                for i in indices {
                    identifiedFoods[i].mealName = newValue
                }
            }
        )
    }

    @ViewBuilder
    private func ingredientRow(index: Int) -> some View {
        VStack(spacing: 4) {
            HStack {
                TextField("Name", text: $identifiedFoods[index].name)
                    .font(.subheadline)
                    .textInputAutocapitalization(.sentences)
                Spacer()
                TextField("Portion", text: $identifiedFoods[index].portionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
            }
            HStack(spacing: 12) {
                HStack(spacing: 2) {
                    Text("Cal").foregroundStyle(.secondary)
                    TextField("Cal", value: $identifiedFoods[index].calories, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 50)
                }
                HStack(spacing: 2) {
                    Text("P").foregroundStyle(.secondary)
                    TextField("P", value: $identifiedFoods[index].proteinGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 40)
                }
                HStack(spacing: 2) {
                    Text("C").foregroundStyle(.secondary)
                    TextField("C", value: $identifiedFoods[index].carbsGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 40)
                }
                HStack(spacing: 2) {
                    Text("F").foregroundStyle(.secondary)
                    TextField("F", value: $identifiedFoods[index].fatGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 40)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Standalone Food Section

    @ViewBuilder
    private func standaloneFoodSection(index: Int) -> some View {
        Section {
            HStack {
                Text(identifiedFoods[index].name)
                    .font(.headline)
                Spacer()
                SourceBadge(source: identifiedFoods[index].source)
            }

            HStack {
                Text("Name")
                Spacer()
                TextField("Name", text: $identifiedFoods[index].name)
                    .textInputAutocapitalization(.sentences)
                    .multilineTextAlignment(.trailing)
            }

            // Portion picker for items with per-100g data (barcode, label)
            if identifiedFoods[index].caloriesPer100g != nil {
                portionPicker(index: index)
            } else {
                HStack {
                    Text("Portion")
                    Spacer()
                    TextField("Portion", text: $identifiedFoods[index].portionDescription)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Grams")
                    Spacer()
                    TextField("Grams", value: $identifiedFoods[index].portionGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack {
                Text("Calories")
                Spacer()
                TextField("Calories", value: $identifiedFoods[index].calories, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Protein (g)")
                Spacer()
                TextField("Protein", value: $identifiedFoods[index].proteinGrams, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Carbs (g)")
                Spacer()
                TextField("Carbs", value: $identifiedFoods[index].carbsGrams, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Fat (g)")
                Spacer()
                TextField("Fat", value: $identifiedFoods[index].fatGrams, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Barcode Portion Picker

    @ViewBuilder
    private func portionPicker(index: Int) -> some View {
        let servingDesc = identifiedFoods[index].portionDescription
        let servingLabel = servingDesc.isEmpty ? "serving" : servingDesc

        HStack {
            Text("Serving Size")
            Spacer()
            Text(servingLabel)
                .foregroundStyle(.secondary)
        }

        ServingPicker(servings: Binding(
            get: { identifiedFoods[index].servings },
            set: { newValue in
                applyServings(max(0.25, newValue), at: index)
            }
        ))
    }

    private func applyServings(_ servings: Double, at index: Int) {
        guard let calPer100g = identifiedFoods[index].caloriesPer100g,
              let protPer100g = identifiedFoods[index].proteinPer100g,
              let carbsPer100g = identifiedFoods[index].carbsPer100g,
              let fatPer100g = identifiedFoods[index].fatPer100g else { return }

        let oneServingGrams = identifiedFoods[index].servingGrams ?? 100
        let totalGrams = oneServingGrams * servings
        let scaled = perServingFromPer100g(
            calPer100g: calPer100g, protPer100g: protPer100g,
            carbsPer100g: carbsPer100g, fatPer100g: fatPer100g,
            servingGrams: totalGrams
        )

        identifiedFoods[index].servings = servings
        identifiedFoods[index].portionGrams = (totalGrams * 10).rounded() / 10
        identifiedFoods[index].calories = scaled.calories
        identifiedFoods[index].proteinGrams = scaled.protein
        identifiedFoods[index].carbsGrams = scaled.carbs
        identifiedFoods[index].fatGrams = scaled.fat
    }


    // MARK: - Actions

    private func analyzePhoto() {
        guard let image else { return }
        isLoading = true
        errorMessage = nil
        loadingStatus = "Identifying food..."

        Task {
            do {
                loadingStatus = "Looking up nutrition data..."
                let foods = try await FoodAnalysisPipeline.analyzeImage(image)
                identifiedFoods = foods
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func saveAll() {
        let thumbnailData = image?.jpegData(compressionQuality: 0.5)
        var groupsWithPhoto: Set<UUID> = []
        var corrections: [OpenFoodFactsService.CorrectionData] = []

        for food in identifiedFoods {
            // Only store photo on the first entry of each meal group to avoid duplicate blob storage
            let shouldAttachPhoto: Bool
            if let groupID = food.mealGroupID {
                shouldAttachPhoto = groupsWithPhoto.insert(groupID).inserted
            } else {
                shouldAttachPhoto = true
            }
            let photoForEntry = shouldAttachPhoto ? thumbnailData : nil

            // Store per-serving values; computed total* properties handle multiplication
            let perServingCal: Int
            let perServingP: Double
            let perServingC: Double
            let perServingF: Double
            let savedServings: Double

            if let calPer100g = food.caloriesPer100g,
               let protPer100g = food.proteinPer100g,
               let carbsPer100g = food.carbsPer100g,
               let fatPer100g = food.fatPer100g {
                // Has per-100g data: check if user manually edited macros
                let oneServingGrams = food.servingGrams ?? 100
                let expectedTotalGrams = oneServingGrams * food.servings
                let expected = perServingFromPer100g(
                    calPer100g: calPer100g, protPer100g: protPer100g,
                    carbsPer100g: carbsPer100g, fatPer100g: fatPer100g,
                    servingGrams: expectedTotalGrams
                )
                let calDiff = abs(food.calories - expected.calories)
                let protDiff = abs(food.proteinGrams - expected.protein)
                let carbsDiff = abs(food.carbsGrams - expected.carbs)
                let fatDiff = abs(food.fatGrams - expected.fat)
                let userEdited = calDiff > 1 || protDiff > 0.2 || carbsDiff > 0.2 || fatDiff > 0.2

                if userEdited {
                    // User manually corrected values — back-calculate per-serving from displayed totals
                    perServingCal = food.servings > 0 ? Int((Double(food.calories) / food.servings).rounded()) : food.calories
                    perServingP = food.servings > 0 ? food.proteinGrams / food.servings : food.proteinGrams
                    perServingC = food.servings > 0 ? food.carbsGrams / food.servings : food.carbsGrams
                    perServingF = food.servings > 0 ? food.fatGrams / food.servings : food.fatGrams

                    if let barcode = food.barcode {
                        corrections.append(OpenFoodFactsService.CorrectionData(
                            barcode: barcode,
                            caloriesPerServing: perServingCal,
                            proteinPerServing: perServingP,
                            carbsPerServing: perServingC,
                            fatPerServing: perServingF
                        ))
                    }
                } else {
                    // No edits — use precise per-100g computed values
                    let scaled = perServingFromPer100g(
                        calPer100g: calPer100g, protPer100g: protPer100g,
                        carbsPer100g: carbsPer100g, fatPer100g: fatPer100g,
                        servingGrams: oneServingGrams
                    )
                    perServingCal = scaled.calories
                    perServingP = scaled.protein
                    perServingC = scaled.carbs
                    perServingF = scaled.fat
                }
                savedServings = food.servings
            } else {
                // AI-estimated: values represent the detected portion (= 1 serving)
                perServingCal = food.calories
                perServingP = food.proteinGrams
                perServingC = food.carbsGrams
                perServingF = food.fatGrams
                savedServings = food.servings
            }

            let entry = FoodEntry(
                name: food.name.titleCased(),
                calories: perServingCal,
                proteinGrams: perServingP,
                carbsGrams: perServingC,
                fatGrams: perServingF,
                photoData: photoForEntry,
                mealGroupID: food.mealGroupID,
                mealName: food.mealName,
                iconName: foodIconName(for: food.name),
                servings: savedServings,
                servingDescription: food.portionDescription.isEmpty ? nil : food.portionDescription,
                servingGrams: food.servingGrams,
                barcode: food.barcode
            )
            modelContext.insert(entry)
        }

        if corrections.isEmpty {
            dismiss()
        } else {
            pendingCorrections = corrections
            showCorrectionAlert = true
        }
    }
}

// MARK: - Source Badge

struct SourceBadge: View {
    let source: NutritionSource

    private var color: Color {
        switch source {
        case .label: return .green
        case .estimate: return .orange
        case .barcode: return .blue
        }
    }

    var body: some View {
        Text(source.displayLabel)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
