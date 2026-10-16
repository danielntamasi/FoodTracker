import SwiftUI
import SwiftData

struct PhotoAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let image: UIImage?
    /// When set, saves as IngredientItems instead of FoodEntries (used by BuildMealView)
    var onIngredientsAdded: (([IngredientItem]) -> Void)?

    @State private var identifiedFoods: [IdentifiedFood] = []
    @State private var isLoading: Bool
    @State private var loadingStatus = "Identifying food..."
    @State private var errorMessage: String?
    @State private var showCorrectionAlert = false
    @State private var pendingCorrections: [OpenFoodFactsService.CorrectionData] = []
    @State private var selectedCookingMethod: CookingMethod?
    @State private var selectedPlateSize: PlateSize = .medium
    @State private var isReEstimating = false
    @State private var pipelineTrace: PipelineTrace?
    @State private var showingBugReport = false

    // Standard init for photo analysis
    init(image: UIImage, onIngredientsAdded: (([IngredientItem]) -> Void)? = nil) {
        self.image = image
        self.onIngredientsAdded = onIngredientsAdded
        self._isLoading = State(initialValue: true)
    }

    // Init for barcode/pre-resolved results (no photo)
    init(foods: [IdentifiedFood], onIngredientsAdded: (([IngredientItem]) -> Void)? = nil) {
        self.image = nil
        self.onIngredientsAdded = onIngredientsAdded
        self._identifiedFoods = State(initialValue: foods)
        self._isLoading = State(initialValue: false)
    }

    // Init for multi-angle: has image for display + pre-filled results (no re-analysis needed)
    init(image: UIImage, prefilled foods: [IdentifiedFood], trace: PipelineTrace? = nil, onIngredientsAdded: (([IngredientItem]) -> Void)? = nil) {
        self.image = image
        self.onIngredientsAdded = onIngredientsAdded
        self._identifiedFoods = State(initialValue: foods)
        self._isLoading = State(initialValue: false)
        self._pipelineTrace = State(initialValue: trace)
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
                            .font(DS.Typography.headline)
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

                        // Cooking method & plate size controls (only for photo analysis)
                        if image != nil {
                            Section {
                                cookingMethodPicker
                                plateSizePicker
                            } header: {
                                Text("Preparation Context")
                            } footer: {
                                Text("Adjusting these will re-estimate nutrition using better-matched data.")
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

                        if pipelineTrace != nil || image != nil {
                            Section {
                                Button {
                                    showingBugReport = true
                                } label: {
                                    Label("Report an Issue", systemImage: "flag")
                                        .font(.subheadline)
                                        .foregroundStyle(DS.Color.textSecondary)
                                }
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
                        if isReEstimating {
                            ProgressView()
                        } else {
                            Button("Save") { saveAll() }
                                .disabled(identifiedFoods.isEmpty || identifiedFoods.contains {
                                    !isValidNutrition(calories: $0.calories, protein: $0.proteinGrams, carbs: $0.carbsGrams, fat: $0.fatGrams)
                                })
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .task {
                if image != nil && identifiedFoods.isEmpty {
                    analyzePhoto()
                }
            }
            .sheet(isPresented: $showingBugReport) {
                BugReportView(
                    trace: pipelineTrace,
                    photos: image.map { [$0] } ?? [],
                    identifiedFoods: identifiedFoods
                )
            }
            .alert("Submit Correction to OpenFoodFacts?", isPresented: $showCorrectionAlert) {
                Button("Submit Correction") {
                    let corrections = pendingCorrections
                    Task { for c in corrections { await OpenFoodFactsService.shared.submitCorrection(c) } }
                    dismiss()
                }
                Button("No Thanks", role: .cancel) { dismiss() }
            } message: {
                Text("You corrected a scanned product. This will be sent to the public database:\n\n" + pendingCorrections.map(\.summary).joined(separator: "\n\n"))
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
                    .font(DS.Typography.headline)
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
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Color.textSecondary)
            Text("\(indices.count) ingredients")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Color.textTertiary)
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
                    .font(DS.Typography.subhead)
                    .textInputAutocapitalization(.sentences)
                Spacer()
                confidenceBadge(score: identifiedFoods[index].confidenceScore)
                TextField("Portion", text: $identifiedFoods[index].portionDescription)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
            }
            // Hidden calories info
            if let hiddenCals = identifiedFoods[index].hiddenCaloriesEstimate, hiddenCals > 0,
               let source = identifiedFoods[index].hiddenCaloriesSource {
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Color.carbs)
                    Text("+\(hiddenCals) hidden")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Color.carbs)
                    Text("(\(source))")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Color.textTertiary)
                    Spacer()
                }
            }
            HStack(spacing: 12) {
                HStack(spacing: 2) {
                    Text("Cal").foregroundStyle(DS.Color.textSecondary)
                    TextField("Cal", value: $identifiedFoods[index].calories, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 50)
                }
                HStack(spacing: 2) {
                    Text("P").foregroundStyle(DS.Color.textSecondary)
                    TextField("P", value: $identifiedFoods[index].proteinGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 40)
                }
                HStack(spacing: 2) {
                    Text("C").foregroundStyle(DS.Color.textSecondary)
                    TextField("C", value: $identifiedFoods[index].carbsGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 40)
                }
                HStack(spacing: 2) {
                    Text("F").foregroundStyle(DS.Color.textSecondary)
                    TextField("F", value: $identifiedFoods[index].fatGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 40)
                }
            }
            .font(DS.Typography.caption)
        }
        .padding(.vertical, 2)
        .overlay(
            // Low confidence visual indicator
            identifiedFoods[index].confidenceScore.map { score in
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        score <= 2 ? DS.Color.danger.opacity(0.4) : .clear,
                        lineWidth: 1
                    )
            }
        )
    }

    // MARK: - Standalone Food Section

    @ViewBuilder
    private func standaloneFoodSection(index: Int) -> some View {
        Section {
            HStack {
                Text(identifiedFoods[index].name)
                    .font(DS.Typography.headline)
                Spacer()
                confidenceBadge(score: identifiedFoods[index].confidenceScore)
                SourceBadge(source: identifiedFoods[index].source)
            }

            // Hidden calories info
            if let hiddenCals = identifiedFoods[index].hiddenCaloriesEstimate, hiddenCals > 0,
               let source = identifiedFoods[index].hiddenCaloriesSource {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.carbs)
                    Text("+\(hiddenCals) hidden cal")
                        .font(DS.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Color.carbs)
                    Text("(\(source))")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                }
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

    // MARK: - Cooking Method Picker

    @ViewBuilder
    private var cookingMethodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How was this prepared?")
                .font(DS.Typography.subhead)
                .foregroundStyle(DS.Color.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "None" option to clear selection
                    cookingMethodPill(nil, label: "Auto")

                    ForEach(CookingMethod.allCases) { method in
                        cookingMethodPill(method, label: method.rawValue)
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    @ViewBuilder
    private func cookingMethodPill(_ method: CookingMethod?, label: String) -> some View {
        let isSelected = selectedCookingMethod == method
        Button {
            if selectedCookingMethod != method {
                selectedCookingMethod = method
                reEstimateWithContext()
            }
        } label: {
            HStack(spacing: 4) {
                if let method {
                    Image(systemName: method.iconName)
                        .font(DS.Typography.caption2)
                }
                Text(label)
                    .font(DS.Typography.labelM)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? DS.Color.protein.opacity(0.2) : DS.Color.backgroundElevated)
            .foregroundStyle(isSelected ? DS.Color.protein : DS.Color.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? DS.Color.protein.opacity(0.5) : DS.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plate Size Picker

    @ViewBuilder
    private var plateSizePicker: some View {
        HStack {
            Text("Plate size")
                .font(DS.Typography.subhead)
            Spacer()
            Picker("Plate size", selection: $selectedPlateSize) {
                ForEach(PlateSize.allCases) { size in
                    Text(size.rawValue).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .onChange(of: selectedPlateSize) { _, _ in
                reEstimateWithContext()
            }
        }
    }

    // MARK: - Confidence Badge

    @ViewBuilder
    private func confidenceBadge(score: Int?) -> some View {
        if let score {
            let (color, label): (Color, String) = {
                switch score {
                case 4...5: return (DS.Color.success, "High")
                case 3: return (DS.Color.carbs, "Medium")
                default: return (DS.Color.danger, "Low")
                }
            }()
            HStack(spacing: 3) {
                Image(systemName: score >= 4 ? "checkmark.circle.fill" : score == 3 ? "questionmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(DS.Typography.caption2)
                Text(label)
                    .font(DS.Typography.labelS)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    // MARK: - Barcode Portion Picker

    @ViewBuilder
    private func portionPicker(index: Int) -> some View {
        HStack {
            Text("Serving Size")
            Spacer()
            TextField("1 serving", text: $identifiedFoods[index].portionDescription)
                .multilineTextAlignment(.trailing)
        }
        HStack {
            Text("Serving Weight (g)")
            Spacer()
            TextField("Grams", value: Binding(
                get: { identifiedFoods[index].servingGrams },
                set: { setServingGrams($0, at: index) }
            ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }

        ServingPicker(servings: Binding(
            get: { identifiedFoods[index].servings },
            set: { newValue in
                applyServings(max(0.25, newValue), at: index)
            }
        ))
    }

    /// Whether the item's nutrition is still what its per-100g data gives for the current serving,
    /// i.e. the user hasn't typed over it.
    private func nutritionMatchesPer100g(_ food: IdentifiedFood) -> Bool {
        guard let calPer100g = food.caloriesPer100g,
              let protPer100g = food.proteinPer100g,
              let carbsPer100g = food.carbsPer100g,
              let fatPer100g = food.fatPer100g else { return false }

        let expected = perServingFromPer100g(
            calPer100g: calPer100g, protPer100g: protPer100g,
            carbsPer100g: carbsPer100g, fatPer100g: fatPer100g,
            servingGrams: (food.servingGrams ?? 100) * food.servings
        )
        return abs(food.calories - expected.calories) <= 1
            && abs(food.proteinGrams - expected.protein) <= 0.2
            && abs(food.carbsGrams - expected.carbs) <= 0.2
            && abs(food.fatGrams - expected.fat) <= 0.2
    }

    /// Changes the weight of one serving. Untouched nutrition is recalculated for the new weight;
    /// values the user typed (e.g. from the label) are kept and now describe the new serving.
    private func setServingGrams(_ grams: Double?, at index: Int) {
        guard let grams, grams > 0, grams != identifiedFoods[index].servingGrams else { return }

        let recalculate = nutritionMatchesPer100g(identifiedFoods[index])
        identifiedFoods[index].servingGrams = grams
        identifiedFoods[index].portionDescription = strippingServingWeight(identifiedFoods[index].portionDescription)
        if recalculate {
            applyServings(identifiedFoods[index].servings, at: index)
        } else {
            identifiedFoods[index].portionGrams = (grams * identifiedFoods[index].servings).roundedTo(1)
        }
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
        identifiedFoods[index].portionGrams = totalGrams.roundedTo(1)
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
                loadingStatus = "Analyzing photo..."
                let (foods, trace) = try await FoodAnalysisPipeline.analyzeImageWithTrace(
                    image,
                    cookingMethod: selectedCookingMethod,
                    plateSize: selectedPlateSize
                )
                pipelineTrace = trace
                loadingStatus = "Looking up nutrition data..."
                identifiedFoods = foods
                if selectedCookingMethod == nil, let detected = foods.first(where: { $0.cookingMethod != nil })?.cookingMethod {
                    selectedCookingMethod = CookingMethod.from(detected)
                }
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// Re-runs USDA/FNDDS lookups with updated cooking method or plate size context.
    /// Reuses the cached vision response to avoid re-sending the image to the API.
    private func reEstimateWithContext() {
        guard !identifiedFoods.isEmpty,
              let trace = pipelineTrace,
              let rawText = trace.rawVisionResponseText,
              let response = try? decodeVisionResponse(from: rawText) else { return }
        isReEstimating = true

        Task {
            do {
                let (foods, foodTraces) = try await FoodAnalysisPipeline.processVisionResponseWithTrace(
                    response,
                    cookingMethod: selectedCookingMethod,
                    plateSize: selectedPlateSize
                )
                identifiedFoods = foods
                if var trace = pipelineTrace {
                    trace.foodTraces = foodTraces
                    trace.plateSize = selectedPlateSize.rawValue
                    trace.cookingMethodSelection = selectedCookingMethod?.rawValue
                    trace.finalResults = foods.map { PipelineTrace.traceIdentifiedFood($0) }
                    pipelineTrace = trace
                }
            } catch {
                // Silently fail — keep existing results
            }
            isReEstimating = false
        }
    }

    private func saveAll() {
        // Ingredient mode: return IngredientItems instead of saving to SwiftData
        if let onIngredientsAdded {
            let items = identifiedFoods.map { food in
                // Convert total-portion values to per-serving before passing to ingredient
                let perServingCal: Int
                let perServingP: Double
                let perServingC: Double
                let perServingF: Double
                if food.servings > 0 && abs(food.servings - 1.0) > 0.001 {
                    perServingCal = Int((Double(food.calories) / food.servings).rounded())
                    perServingP = food.proteinGrams / food.servings
                    perServingC = food.carbsGrams / food.servings
                    perServingF = food.fatGrams / food.servings
                } else {
                    perServingCal = food.calories
                    perServingP = food.proteinGrams
                    perServingC = food.carbsGrams
                    perServingF = food.fatGrams
                }
                return IngredientItem(
                    name: food.name.titleCased(),
                    calories: perServingCal,
                    proteinGrams: perServingP,
                    carbsGrams: perServingC,
                    fatGrams: perServingF,
                    servings: food.servings,
                    servingDescription: food.portionDescription.isEmpty ? nil : food.portionDescription,
                    servingGrams: food.servingGrams
                )
            }
            onIngredientsAdded(items)
            dismiss()
            return
        }

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
                let userEdited = !nutritionMatchesPer100g(food)

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
                            fatPerServing: perServingF,
                            servingDescription: food.portionDescription.isEmpty ? nil : food.portionDescription,
                            servingGrams: food.servingGrams
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

                    // Serving corrected but nutrition untouched: send the new serving, keep per-100g as it was
                    let description = food.portionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    let servingChanged = food.servingGrams != food.scannedServingGrams
                        || description != (food.scannedServingDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if let barcode = food.barcode, servingChanged, let grams = food.servingGrams, grams > 0 {
                        corrections.append(OpenFoodFactsService.CorrectionData(
                            barcode: barcode,
                            caloriesPerServing: perServingCal,
                            proteinPerServing: perServingP,
                            carbsPerServing: perServingC,
                            fatPerServing: perServingF,
                            servingDescription: description.isEmpty ? nil : description,
                            servingGrams: grams,
                            per100g: .init(calories: calPer100g, protein: protPer100g, carbs: carbsPer100g, fat: fatPer100g)
                        ))
                    }
                }
                savedServings = food.servings
            } else {
                // AI-estimated: values may represent the total detected portion
                // Divide by servings to get true per-serving values
                if food.servings > 0 && abs(food.servings - 1.0) > 0.001 {
                    perServingCal = Int((Double(food.calories) / food.servings).rounded())
                    perServingP = food.proteinGrams / food.servings
                    perServingC = food.carbsGrams / food.servings
                    perServingF = food.fatGrams / food.servings
                } else {
                    perServingCal = food.calories
                    perServingP = food.proteinGrams
                    perServingC = food.carbsGrams
                    perServingF = food.fatGrams
                }
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
            Task { await HealthKitService.shared.syncEntry(entry) }
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
        case .label: return DS.Color.success
        case .estimate: return DS.Color.carbs
        case .barcode: return DS.Color.protein
        case .usda: return DS.Color.success
        }
    }

    var body: some View {
        Text(source.displayLabel)
            .font(DS.Typography.labelS)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
