import SwiftUI
import SwiftData
import Charts
import AVFoundation

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var entry: FoodEntry

    @State private var isEditing = false
    @State private var lookup = NutritionLookup()
    @State private var extractedColor: Color?
    @State private var showingBarcodeScanner = false
    @State private var showCorrectionAlert = false
    @State private var pendingCorrection: OpenFoodFactsService.CorrectionData?

    // Snapshot of original values for Cancel support
    @State private var originalName = ""
    @State private var originalCalories = 0
    @State private var originalProtein = 0.0
    @State private var originalCarbs = 0.0
    @State private var originalFat = 0.0
    @State private var originalDate = Date()
    @State private var originalServings: Double = 1.0
    @State private var originalPhotoData: Data?
    @State private var servings: Double = 1.0
    @State private var isFavorite = false

    private var entryImage: UIImage? {
        guard let data = entry.photoData else { return nil }
        return UIImage(data: data)
    }

    /// Background color: extracted from photo bottom edge, or derived from food icon category
    private var bgColor: Color {
        extractedColor ?? iconDerivedBgColor
    }

    private var iconDerivedBgColor: Color {
        iconDarkColor(for: entry.iconName ?? foodIconName(for: entry.name))
    }

    private var formattedTimestamp: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(entry.date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInYesterday(entry.date) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }
        return formatter.string(from: entry.date)
    }

    private var nameChanged: Bool {
        isEditing && entry.name != originalName && !entry.name.isEmpty
    }

    private var servingSizeLabel: String? {
        let desc = entry.servingDescription
        let grams = entry.servingGrams
        if let desc, let grams {
            return "\(desc) (\(Int(grams))g)"
        } else if let desc {
            return desc
        } else if let grams {
            return "\(Int(grams))g"
        }
        return nil
    }

    // Total-value bindings: display total (per-serving × servings), back-calculate per-serving on edit
    private var totalCaloriesBinding: Binding<Int> {
        Binding(
            get: { Int((Double(entry.calories) * servings).rounded()) },
            set: { entry.calories = servings > 0 ? Int((Double($0) / servings).rounded()) : $0 }
        )
    }
    private var totalProteinBinding: Binding<Double> {
        Binding(
            get: { (entry.proteinGrams * servings).roundedTo(1) },
            set: { entry.proteinGrams = servings > 0 ? $0 / servings : $0 }
        )
    }
    private var totalCarbsBinding: Binding<Double> {
        Binding(
            get: { (entry.carbsGrams * servings).roundedTo(1) },
            set: { entry.carbsGrams = servings > 0 ? $0 / servings : $0 }
        )
    }
    private var totalFatBinding: Binding<Double> {
        Binding(
            get: { (entry.fatGrams * servings).roundedTo(1) },
            set: { entry.fatGrams = servings > 0 ? $0 / servings : $0 }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mainBody
                floatingButtons
                if !isEditing {
                    VStack {
                        Button {
                            isFavorite = FavoriteFoods.toggle(entry.name)
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(isFavorite ? DS.Color.carbs : .white)
                                .frame(height: 20)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial.opacity(0.6))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 12)
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            if let uiImage = entryImage {
                extractedColor = dominantColor(from: uiImage, colorScheme: colorScheme)
            }
            isFavorite = FavoriteFoods.isFavorite(entry.name)
        }
        .onChange(of: lookup.aiEstimate?.description) { _, _ in
            if let estimate = lookup.aiEstimate {
                applyLookupResult(estimate)
            }
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            EditBarcodeScannerView { product, barcode in
                entry.name = product.name
                entry.calories = product.calories
                entry.proteinGrams = product.proteinGrams
                entry.carbsGrams = product.carbsGrams
                entry.fatGrams = product.fatGrams
                entry.iconName = foodIconName(for: product.name)
                entry.servings = 1.0
                servings = 1.0
                entry.servingDescription = product.servingSize
                entry.servingGrams = product.portionGrams > 0 ? product.portionGrams : nil
                entry.barcode = barcode
            }
        }
        .alert("Improve Nutrition Data?", isPresented: $showCorrectionAlert) {
            Button("Submit Correction") {
                if let correction = pendingCorrection {
                    Task { await OpenFoodFactsService.shared.submitCorrection(correction) }
                }
            }
            Button("No Thanks", role: .cancel) { }
        } message: {
            Text("You corrected the nutrition data for a scanned product. Submit your correction to OpenFoodFacts to help other users?")
        }
    }

    // MARK: - Floating Buttons

    private var floatingButtons: some View {
        HStack {
            if isEditing {
                Button {
                    cancelEditing()
                } label: {
                    floatingButtonLabel("Cancel")
                }
                Spacer()
                Button {
                    finishEditing()
                } label: {
                    floatingButtonLabel("Done")
                }
            } else {
                Button {
                    startEditing()
                } label: {
                    floatingButtonLabel("Edit")
                }
                Spacer()
                Button { dismiss() } label: {
                    floatingButtonLabel("Done")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func startEditing() {
        originalName = entry.name
        originalCalories = entry.calories
        originalProtein = entry.proteinGrams
        originalCarbs = entry.carbsGrams
        originalFat = entry.fatGrams
        originalDate = entry.date
        originalServings = entry.servings
        originalPhotoData = entry.photoData
        servings = entry.servings
        withAnimation(.easeInOut(duration: 0.25)) { isEditing = true }
    }

    private func cancelEditing() {
        entry.name = originalName
        entry.calories = originalCalories
        entry.proteinGrams = originalProtein
        entry.carbsGrams = originalCarbs
        entry.fatGrams = originalFat
        entry.date = originalDate
        entry.servings = originalServings
        entry.photoData = originalPhotoData
        servings = originalServings
        if let photoData = originalPhotoData, let uiImage = UIImage(data: photoData) {
            extractedColor = dominantColor(from: uiImage, colorScheme: colorScheme)
        } else if originalPhotoData == nil {
            extractedColor = nil
        }
        lookup.reset()
        withAnimation(.easeInOut(duration: 0.25)) { isEditing = false }
    }

    private func finishEditing() {
        entry.servings = servings
        entry.name = entry.name.titleCased()
        entry.iconName = foodIconName(for: entry.name)
        // Round macro values to 1 decimal to clean up any unrounded stored data
        entry.proteinGrams = entry.proteinGrams.roundedTo(1)
        entry.carbsGrams = entry.carbsGrams.roundedTo(1)
        entry.fatGrams = entry.fatGrams.roundedTo(1)
        lookup.reset()

        // Correction detection for barcode entries
        if let barcode = entry.barcode {
            let calChanged = entry.calories != originalCalories
            let protChanged = abs(entry.proteinGrams - originalProtein) > 0.01
            let carbsChanged = abs(entry.carbsGrams - originalCarbs) > 0.01
            let fatChanged = abs(entry.fatGrams - originalFat) > 0.01

            if calChanged || protChanged || carbsChanged || fatChanged {
                pendingCorrection = OpenFoodFactsService.CorrectionData(
                    barcode: barcode,
                    caloriesPerServing: entry.calories,
                    proteinPerServing: entry.proteinGrams,
                    carbsPerServing: entry.carbsGrams,
                    fatPerServing: entry.fatGrams,
                    servingDescription: entry.servingDescription,
                    servingGrams: entry.servingGrams
                )
                withAnimation(.easeInOut(duration: 0.25)) { isEditing = false }
                showCorrectionAlert = true
                return
            }
        }

        Task { await HealthKitService.shared.updateEntry(entry) }
        withAnimation(.easeInOut(duration: 0.25)) { isEditing = false }
    }

    private func floatingButtonLabel(_ title: String) -> some View {
        Text(title)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.6))
            .clipShape(Capsule())
    }

    // MARK: - Main Body (Immersive Hero)

    private var mainBody: some View {
        GeometryReader { fullGeo in
            ScrollView {
                VStack(spacing: 0) {
                    HeroPhotoSection(
                        image: entryImage,
                        title: entry.name,
                        iconName: entry.iconName ?? foodIconName(for: entry.name),
                        bgColor: bgColor,
                        totalCalories: isEditing ? Int((Double(entry.calories) * servings).rounded()) : entry.totalCalories,
                        totalProtein: isEditing ? (entry.proteinGrams * servings).roundedTo(1) : entry.totalProteinGrams,
                        totalCarbs: isEditing ? (entry.carbsGrams * servings).roundedTo(1) : entry.totalCarbsGrams,
                        totalFat: isEditing ? (entry.fatGrams * servings).roundedTo(1) : entry.totalFatGrams,
                        geoWidth: fullGeo.size.width,
                        geoHeight: fullGeo.size.height
                    )

                    if isEditing {
                        editContent
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        VStack(spacing: 20) {
                            if DailyTarget.hasTargets {
                                DailyGoalBarsView(
                                    calories: Double(entry.totalCalories),
                                    protein: entry.totalProteinGrams,
                                    carbs: entry.totalCarbsGrams,
                                    fat: entry.totalFatGrams
                                )
                            }

                            if let servingSizeText = servingSizeLabel {
                                HStack(spacing: 4) {
                                    Text(formatServings(entry.servings))
                                        .fontWeight(.medium)
                                    Text("× \(servingSizeText)")
                                }
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            }

                            Text(formattedTimestamp)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 4)
                        }
                        .padding(.top, 12)
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(DS.Color.backgroundSecondary)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Edit Content

    private var editContent: some View {
        VStack(spacing: 20) {
            groupedSection(header: "Food") {
                groupedRow {
                    Text("Name")
                    Spacer()
                    TextField("Name", text: $entry.name)
                        .textInputAutocapitalization(.sentences)
                        .multilineTextAlignment(.trailing)
                    if nameChanged {
                        HStack(spacing: 8) {
                            if lookup.isLookingUp {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Button { lookup.lookupNutrition(for: entry.name) } label: {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                            Button { showingBarcodeScanner = true } label: {
                                Image(systemName: "barcode.viewfinder")
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: nameChanged)
                if let error = lookup.lookupError {
                    groupedDivider
                    groupedRow {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                groupedDivider
                groupedRow {
                    Text("Calories")
                    Spacer()
                    TextField("Calories", value: totalCaloriesBinding, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            if !lookup.lookupResults.isEmpty {
                groupedSection(header: "USDA Results") {
                    groupedRow {
                        USDAResultsList(results: lookup.lookupResults, selectedIndex: Binding(
                            get: { lookup.selectedResultIndex },
                            set: { lookup.selectedResultIndex = $0 }
                        ))
                            .onChange(of: lookup.selectedResultIndex) { _, newIndex in
                                if let index = newIndex {
                                    applyLookupResult(lookup.lookupResults[index])
                                }
                            }
                    }
                }
            }

            if let estimate = lookup.aiEstimate {
                groupedSection(header: "AI Estimate") {
                    groupedRow {
                        USDAResultCard(result: estimate, isSelected: true) {
                            applyLookupResult(estimate)
                        }
                    }
                }
            }

            if nameChanged && !lookup.isLookingUp && !lookup.isEstimating && lookup.aiEstimate == nil {
                groupedSection {
                    groupedRow {
                        Button { lookup.runAIEstimate(for: entry.name) } label: {
                            HStack {
                                Label("AI Estimate", systemImage: "sparkles")
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                if lookup.isEstimating {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(lookup.isEstimating)
                    }
                }
            }

            groupedSection(header: "Macros") {
                groupedRow {
                    Text("Protein")
                    Spacer()
                    TextField("Protein", value: totalProteinBinding, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                groupedDivider
                groupedRow {
                    Text("Carbs")
                    Spacer()
                    TextField("Carbs", value: totalCarbsBinding, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                groupedDivider
                groupedRow {
                    Text("Fat")
                    Spacer()
                    TextField("Fat", value: totalFatBinding, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            groupedSection(header: "Servings") {
                if let servingSizeText = servingSizeLabel {
                    groupedRow {
                        Text("Serving Size")
                        Spacer()
                        Text(servingSizeText)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    groupedDivider
                }
                groupedRow {
                    ServingPicker(servings: $servings)
                }
            }

            groupedSection(header: "Date & Time") {
                groupedRow {
                    DatePicker("", selection: $entry.date, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }

            if entry.photoData != nil {
                groupedSection {
                    Button(role: .destructive) {
                        entry.photoData = nil
                        extractedColor = nil
                    } label: {
                        groupedRow {
                            Spacer()
                            Label("Remove Photo", systemImage: "trash")
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, -20)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Grouped Section Helpers

    @ViewBuilder
    private func groupedSection<Content: View>(
        header: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let header {
                Text(header.uppercased())
                    .font(DS.Typography.labelS)
                    .foregroundStyle(DS.Color.textTertiary)
                    .tracking(0.8)
                    .padding(.horizontal, 36)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(DS.Color.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
            .padding(.horizontal, 20)
            if let footer {
                Text(footer)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.textTertiary)
                    .padding(.horizontal, 36)
            }
        }
    }

    @ViewBuilder
    private func groupedRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var groupedDivider: some View {
        Divider().padding(.leading, 16)
    }

    // MARK: - USDA Lookup

    private func applyLookupResult(_ result: USDAService.USDALookupResult) {
        let scaled = result.perServing
        entry.calories = Int(scaled.calories)
        entry.proteinGrams = scaled.protein
        entry.carbsGrams = scaled.carbs
        entry.fatGrams = scaled.fat
        entry.servingDescription = result.servingDescription
        entry.servingGrams = result.servingGrams
        servings = 1.0
    }

}

// MARK: - Barcode Scanner for Edit Screen

struct EditBarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onProductScanned: (OpenFoodFactsService.Product, String) -> Void

    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var resetCounter = 0

    var body: some View {
        NavigationStack {
            ZStack {
                BarcodeCameraView(onBarcodeScanned: handleBarcode, resetCounter: resetCounter)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    if isLookingUp {
                        lookupOverlay {
                            ProgressView("Looking up product...")
                                .font(.headline)
                        }
                    } else if let error = lookupError {
                        lookupOverlay {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                Button("Scan Again") {
                                    lookupError = nil
                                    resetCounter += 1
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    } else {
                        lookupOverlay {
                            Label("Point camera at a barcode", systemImage: "barcode.viewfinder")
                                .font(.headline)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.white)
                }
            }
        }
    }

    private func handleBarcode(_ barcode: String) {
        guard !isLookingUp else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        isLookingUp = true
        lookupError = nil

        Task {
            do {
                let product = try await OpenFoodFactsService.shared.lookup(barcode: barcode)
                onProductScanned(product, barcode)
                dismiss()
            } catch {
                lookupError = error.localizedDescription
                isLookingUp = false
            }
        }
    }

    @ViewBuilder
    private func lookupOverlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
    }
}
