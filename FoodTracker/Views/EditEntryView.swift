import SwiftUI
import SwiftData
import Charts
import AVFoundation

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var entry: FoodEntry

    @State private var isEditing = false
    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var lookupDescription: String?
    @State private var extractedColor: Color?
    @State private var showingBarcodeScanner = false

    // Snapshot of original values for Cancel support
    @State private var originalName = ""
    @State private var originalCalories = 0
    @State private var originalProtein = 0.0
    @State private var originalCarbs = 0.0
    @State private var originalFat = 0.0
    @State private var originalDate = Date()
    @State private var originalServings: Double = 1.0
    @State private var servings: Double = 1.0

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mainBody
                floatingButtons
            }
        }
        .onAppear {
            if let uiImage = entryImage {
                extractedColor = dominantColor(from: uiImage, colorScheme: colorScheme)
            }
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            EditBarcodeScannerView { product in
                entry.name = product.name
                entry.calories = product.calories
                entry.proteinGrams = product.proteinGrams
                entry.carbsGrams = product.carbsGrams
                entry.fatGrams = product.fatGrams
                entry.iconName = foodIconName(for: product.name)
                entry.servings = 1.0
                servings = 1.0
            }
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
        servings = originalServings
        lookupError = nil
        lookupDescription = nil
        withAnimation(.easeInOut(duration: 0.25)) { isEditing = false }
    }

    private func finishEditing() {
        entry.servings = servings
        entry.name = entry.name.titleCased()
        entry.iconName = foodIconName(for: entry.name)
        lookupError = nil
        lookupDescription = nil
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
                        totalCalories: entry.totalCalories,
                        totalProtein: entry.totalProteinGrams,
                        totalCarbs: entry.totalCarbsGrams,
                        totalFat: entry.totalFatGrams,
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
        .background(bgColor)
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
                            if isLookingUp {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Button { lookupNutrition() } label: {
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
                if let error = lookupError {
                    groupedDivider
                    groupedRow {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                if let desc = lookupDescription {
                    groupedDivider
                    groupedRow {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                groupedDivider
                groupedRow {
                    Text("Calories")
                    Spacer()
                    TextField("Calories", value: $entry.calories, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            groupedSection(header: "Macros (grams)") {
                groupedRow {
                    Text("Protein")
                    Spacer()
                    TextField("Protein", value: $entry.proteinGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                groupedDivider
                groupedRow {
                    Text("Carbs")
                    Spacer()
                    TextField("Carbs", value: $entry.carbsGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                groupedDivider
                groupedRow {
                    Text("Fat")
                    Spacer()
                    TextField("Fat", value: $entry.fatGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            groupedSection(header: "Servings") {
                groupedRow {
                    Text("Servings")
                    Spacer()
                    Text(formatServings(servings))
                        .foregroundStyle(.white.opacity(0.6))
                }
                groupedDivider
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
                                            ? Color.accentColor.opacity(0.3)
                                            : .white.opacity(0.1)
                                    )
                                    .foregroundStyle(
                                        servings == preset
                                            ? Color.accentColor
                                            : .white.opacity(0.7)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                groupedDivider
                groupedRow {
                    Text("Custom")
                    Spacer()
                    TextField("Servings", value: $servings, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                }
                if servings != 1.0 && entry.calories > 0 {
                    groupedDivider
                    groupedRow {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Total")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int((Double(entry.calories) * servings).rounded())) cal")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            HStack {
                                Spacer()
                                coloredMacroText(
                                    protein: entry.proteinGrams * servings,
                                    carbs: entry.carbsGrams * servings,
                                    fat: entry.fatGrams * servings
                                )
                                .font(.caption)
                            }
                        }
                    }
                }
            }

            groupedSection(header: "Date & Time") {
                groupedRow {
                    DatePicker("", selection: $entry.date, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
        }
        .padding(.top, -20)
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
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 36)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
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

    private func lookupNutrition() {
        isLookingUp = true
        lookupError = nil
        lookupDescription = nil

        Task {
            do {
                let result = try await USDAService.shared.lookupFood(for: entry.name)
                let per100g = result.nutrientsPer100g
                if per100g.calories > 0 || per100g.protein > 0 || per100g.carbs > 0 || per100g.fat > 0 {
                    let scaled = result.perServing
                    entry.calories = Int(scaled.calories)
                    entry.proteinGrams = scaled.protein
                    entry.carbsGrams = scaled.carbs
                    entry.fatGrams = scaled.fat
                    servings = 1.0
                    // Build description for user verification
                    if let servingDesc = result.servingDescription {
                        let gramsNote = result.servingGrams.map { " (\(Int($0))g)" } ?? ""
                        lookupDescription = "\(result.description.titleCased()) — \(servingDesc)\(gramsNote)"
                    } else {
                        lookupDescription = "\(result.description.titleCased()) — per 100g"
                    }
                } else {
                    lookupError = "No nutrition data found for \"\(entry.name)\"."
                }
            } catch {
                lookupError = error.localizedDescription
            }
            isLookingUp = false
        }
    }
}

// MARK: - Barcode Scanner for Edit Screen

struct EditBarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onProductScanned: (OpenFoodFactsService.Product) -> Void

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
                onProductScanned(product)
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
