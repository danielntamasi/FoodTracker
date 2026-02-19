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

                        ForEach($identifiedFoods) { $food in
                            Section {
                                HStack {
                                    Text(food.name)
                                        .font(.headline)
                                    Spacer()
                                    SourceBadge(source: food.source)
                                }

                                HStack {
                                    Text("Name")
                                    Spacer()
                                    TextField("Name", text: $food.name)
                                        .multilineTextAlignment(.trailing)
                                }
                                HStack {
                                    Text("Portion")
                                    Spacer()
                                    TextField("Portion", text: $food.portionDescription)
                                        .multilineTextAlignment(.trailing)
                                }
                                HStack {
                                    Text("Grams")
                                    Spacer()
                                    TextField("Grams", value: $food.portionGrams, format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                }
                                HStack {
                                    Text("Calories")
                                    Spacer()
                                    TextField("Calories", value: $food.calories, format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                }
                                HStack {
                                    Text("Protein (g)")
                                    Spacer()
                                    TextField("Protein", value: $food.proteinGrams, format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                }
                                HStack {
                                    Text("Carbs (g)")
                                    Spacer()
                                    TextField("Carbs", value: $food.carbsGrams, format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                }
                                HStack {
                                    Text("Fat (g)")
                                    Spacer()
                                    TextField("Fat", value: $food.fatGrams, format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
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
                photoData: thumbnailData
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
