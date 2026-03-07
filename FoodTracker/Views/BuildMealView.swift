import SwiftUI
import SwiftData

struct IngredientItem: Identifiable {
    let id = UUID()
    var name: String
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var servings: Double = 1.0
    var servingDescription: String?
    var servingGrams: Double?
}

enum IngredientSource: Identifiable {
    case manual, search, recent, photo, upload, barcode
    var id: Self { self }
}

struct BuildMealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var mealName = ""
    @State private var ingredients: [IngredientItem] = []
    @State private var activeSource: IngredientSource?

    private var ingredientCallback: (IngredientItem) -> Void {
        { item in ingredients.append(item) }
    }

    private var ingredientsCallback: ([IngredientItem]) -> Void {
        { items in ingredients.append(contentsOf: items) }
    }

    // Computed totals
    private var totalCalories: Int { ingredients.reduce(0) { $0 + Int((Double($1.calories) * $1.servings).rounded()) } }
    private var totalProtein: Double { ingredients.reduce(0) { $0 + $1.proteinGrams * $1.servings } }
    private var totalCarbs: Double { ingredients.reduce(0) { $0 + $1.carbsGrams * $1.servings } }
    private var totalFat: Double { ingredients.reduce(0) { $0 + $1.fatGrams * $1.servings } }

    var body: some View {
        NavigationStack {
            List {
                Section("Meal Name") {
                    TextField("e.g., Protein Shake", text: $mealName)
                        .textInputAutocapitalization(.sentences)
                }

                Section {
                    if ingredients.isEmpty {
                        Text("No ingredients yet")
                            .foregroundStyle(DS.Color.textSecondary)
                    } else {
                        ForEach(ingredients) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.body)
                                    if item.servings != 1.0 {
                                        Text("\(formatServings(item.servings)) servings")
                                            .font(.caption)
                                            .foregroundStyle(DS.Color.textTertiary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(Int((Double(item.calories) * item.servings).rounded())) cal")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(DS.Color.textSecondary)
                                    coloredMacroText(
                                        protein: item.proteinGrams * item.servings,
                                        carbs: item.carbsGrams * item.servings,
                                        fat: item.fatGrams * item.servings
                                    )
                                    .font(.caption)
                                }
                            }
                        }
                        .onDelete { indices in ingredients.remove(atOffsets: indices) }
                    }

                    addIngredientMenu
                } header: {
                    Text("Ingredients")
                } footer: {
                    if !ingredients.isEmpty {
                        HStack {
                            Text("Total: \(totalCalories) cal")
                                .fontWeight(.medium)
                            Spacer()
                            coloredMacroText(protein: totalProtein, carbs: totalCarbs, fat: totalFat)
                        }
                    }
                }
            }
            .navigationTitle("Build Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveMeal() }
                        .disabled(mealName.isEmpty || ingredients.isEmpty)
                }
            }
            .sheet(item: $activeSource) { source in
                switch source {
                case .manual:
                    AddEntryView(onIngredientAdded: ingredientCallback)
                case .search:
                    SearchFoodView(onIngredientAdded: ingredientCallback)
                case .recent:
                    BrowseFoodsView(onIngredientAdded: ingredientCallback)
                case .photo:
                    PhotoCaptureView(onIngredientsAdded: ingredientsCallback)
                case .upload:
                    PhotoUploadView(onIngredientsAdded: ingredientsCallback)
                case .barcode:
                    BarcodeScannerView(onIngredientsAdded: ingredientsCallback)
                }
            }
        }
    }

    private var addIngredientMenu: some View {
        Menu {
            Button { activeSource = .search } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            Button { activeSource = .recent } label: {
                Label("Recent Foods", systemImage: "clock.arrow.circlepath")
            }
            Button { activeSource = .photo } label: {
                Label("Take Photo", systemImage: "camera")
            }
            Button { activeSource = .upload } label: {
                Label("Upload Photo", systemImage: "photo.on.rectangle")
            }
            Button { activeSource = .barcode } label: {
                Label("Scan Barcode", systemImage: "barcode.viewfinder")
            }
            Divider()
            Button { activeSource = .manual } label: {
                Label("Enter Manually", systemImage: "pencil")
            }
        } label: {
            Label("Add Ingredient", systemImage: "plus.circle")
        }
    }

    private func saveMeal() {
        let groupID = UUID()
        let titleCasedName = mealName.titleCased()
        for ingredient in ingredients {
            let entry = FoodEntry(
                name: ingredient.name.titleCased(),
                calories: ingredient.calories,
                proteinGrams: ingredient.proteinGrams,
                carbsGrams: ingredient.carbsGrams,
                fatGrams: ingredient.fatGrams,
                mealGroupID: groupID,
                mealName: titleCasedName,
                iconName: foodIconName(for: ingredient.name),
                servings: ingredient.servings,
                servingDescription: ingredient.servingDescription,
                servingGrams: ingredient.servingGrams
            )
            modelContext.insert(entry)
            Task { await HealthKitService.shared.syncEntry(entry) }
        }
        dismiss()
    }
}
