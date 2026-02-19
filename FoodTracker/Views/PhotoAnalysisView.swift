import SwiftUI
import SwiftData

struct PhotoAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let image: UIImage

    @State private var identifiedFoods: [IdentifiedFood] = []
    @State private var isLoading = true
    @State private var loadingStatus = "Identifying food..."
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

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
                        Button("Try Again") { analyzePhoto() }
                        Button("Cancel") { dismiss() }
                    }
                } else {
                    List {
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

                        ForEach($identifiedFoods) { $food in
                            Section(food.name) {
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
                                        .onChange(of: food.portionGrams) { _, _ in
                                            recalculateMacros(for: &food)
                                        }
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
                analyzePhoto()
            }
        }
    }

    private func analyzePhoto() {
        isLoading = true
        errorMessage = nil
        loadingStatus = "Identifying food with Gemini..."

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

    private func recalculateMacros(for food: inout IdentifiedFood) {
        // Re-lookup would be async; for now user adjusts manually after changing grams
        // The initial values are proportional, so the user can edit directly
    }

    private func saveAll() {
        let thumbnailData = image.jpegData(compressionQuality: 0.5)

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
