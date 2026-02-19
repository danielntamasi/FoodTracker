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
                        Button("Save All") { saveAll() }
                            .disabled(identifiedFoods.isEmpty)
                    }
                }
            }
            .task {
                if image != nil && identifiedFoods.isEmpty {
                    analyzePhoto()
                }
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
                    .multilineTextAlignment(.trailing)
            }
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

        for food in identifiedFoods {
            let entry = FoodEntry(
                name: food.name,
                calories: food.calories,
                proteinGrams: food.proteinGrams,
                carbsGrams: food.carbsGrams,
                fatGrams: food.fatGrams,
                photoData: thumbnailData,
                mealGroupID: food.mealGroupID,
                mealName: food.mealName,
                iconName: thumbnailData == nil ? foodIconName(for: food.name) : nil
            )
            modelContext.insert(entry)
        }
        dismiss()
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
