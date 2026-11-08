import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onIngredientsAdded: (([IngredientItem]) -> Void)?

    @State private var scannedBarcode: String?
    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var showingResults = false
    @State private var scannedFoods: [IdentifiedFood] = []
    @State private var resetCounter = 0
    /// Barcode OFF doesn't have, offered to "Add It".
    @State private var notFoundBarcode: String?
    @State private var addingBarcode: String?

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
                                if let barcode = notFoundBarcode {
                                    Button("Add It") { addingBarcode = barcode }
                                        .glassButtonStyle(prominent: true)
                                    Button("Scan Again") { scanAgain() }
                                        .glassButtonStyle()
                                } else {
                                    Button("Scan Again") { scanAgain() }
                                        .glassButtonStyle(prominent: true)
                                }
                            }
                        }
                    } else {
                        // Scanning guide
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
                    CloseButton { dismiss() }
                        .tint(DS.Color.overlayText)
                }
            }
            .sheet(isPresented: $showingResults, onDismiss: {
                dismiss()
            }) {
                PhotoAnalysisView(foods: scannedFoods, onIngredientsAdded: onIngredientsAdded)
            }
            .sheet(item: Binding(get: { addingBarcode.map(ScannedCode.init) }, set: { addingBarcode = $0?.code })) { scanned in
                AddBarcodeProductView(barcode: scanned.code, onIngredientsAdded: onIngredientsAdded) {
                    dismiss()
                }
            }
        }
    }

    private struct ScannedCode: Identifiable {
        let code: String
        var id: String { code }
    }

    private func scanAgain() {
        lookupError = nil
        notFoundBarcode = nil
        scannedBarcode = nil
        resetCounter += 1
    }

    private func handleBarcode(_ barcode: String) {
        guard scannedBarcode == nil, !isLookingUp else { return }
        scannedBarcode = barcode

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        isLookingUp = true
        lookupError = nil

        Task {
            do {
                let product = try await OpenFoodFactsService.shared.lookup(barcode: barcode)
                let food = IdentifiedFood(
                    name: product.name,
                    calories: product.calories,
                    proteinGrams: product.proteinGrams,
                    carbsGrams: product.carbsGrams,
                    fatGrams: product.fatGrams,
                    portionGrams: product.portionGrams,
                    portionDescription: product.servingSize,
                    source: .barcode,
                    caloriesPer100g: product.caloriesPer100g,
                    proteinPer100g: product.proteinPer100g,
                    carbsPer100g: product.carbsPer100g,
                    fatPer100g: product.fatPer100g,
                    servingGrams: product.portionGrams,
                    barcode: barcode,
                    scannedServingDescription: product.servingSize,
                    scannedServingGrams: product.portionGrams
                )
                scannedFoods = [food]
                isLookingUp = false
                showingResults = true
            } catch OpenFoodFactsService.LookupError.productNotFound {
                // Added products go to OFF, so a later scan finds them there
                notFoundBarcode = barcode
                lookupError = "This product isn't in the database yet."
                isLookingUp = false
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
            .glassControl(in: RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous), interactive: false)
            .padding(.horizontal)
    }
}

// MARK: - Add Barcode Product

/// Adds a product OFF doesn't have: the user types the label in, or takes photos of the package and the AI fills
/// the form. Saving logs it (or returns it as a Build Meal ingredient) and adds it to OpenFoodFacts.
struct AddBarcodeProductView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let barcode: String
    var onIngredientsAdded: (([IngredientItem]) -> Void)?
    let onSaved: () -> Void

    @State private var name = ""
    @State private var brand = ""
    @State private var servingDescription = ""
    @State private var servingGrams: Double?
    @State private var calories: Int?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var servings: Double = 1.0
    @State private var photos: [UIImage] = []
    @State private var cameraImage: UIImage?
    @State private var showingCamera = false
    @State private var isReading = false
    @State private var readError: String?
    @State private var isSubmitting = false
    /// OpenFoodFacts outcome shown after saving; the sheet closes when it's dismissed.
    @State private var submitResult: Bool?

    private let maxPhotos = 3

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var canSave: Bool {
        guard !trimmedName.isEmpty, let calories else { return false }
        return isValidNutrition(calories: calories, protein: protein ?? 0, carbs: carbs ?? 0, fat: fat ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection

                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.sentences)
                    TextField("Brand (optional)", text: $brand)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Product")
                } footer: {
                    Text("Barcode \(barcode)")
                }

                Section {
                    TextField("Serving size, e.g. 1 bar", text: $servingDescription)
                    HStack {
                        Text("Serving weight (g)")
                        Spacer()
                        LiveNumberField(placeholder: "0", value: $servingGrams)
                    }
                } header: {
                    Text("Serving (from the label)")
                }

                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", value: $calories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    numberRow("Protein (g)", value: $protein)
                    numberRow("Carbs (g)", value: $carbs)
                    numberRow("Fat (g)", value: $fat)
                } header: {
                    Text("Nutrition per serving")
                }

                Section("Servings eaten") {
                    if let grams = servingGrams, grams > 0 {
                        // Typing the grams eaten sets the servings count (grams / serving weight)
                        HStack {
                            Text("Amount eaten (g)")
                            Spacer()
                            LiveNumberField(placeholder: "\(Int(grams))", value: Binding(
                                get: { (grams * servings).roundedTo(1) },
                                set: { newValue in
                                    guard let eaten = newValue, eaten > 0 else { return }
                                    servings = (eaten / grams * 1000).rounded() / 1000
                                }
                            ))
                        }
                    }
                    ServingPicker(servings: $servings)
                }

                Section {
                } footer: {
                    Text(OpenFoodFactsService.hasCredentials
                         ? "Saving also adds this product to OpenFoodFacts, so the next scan finds it."
                         : "Add your OpenFoodFacts login in Settings so products you add are saved to the database and found next time.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Color.backgroundPrimary)
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        ConfirmButton("Save", action: save)
                            .disabled(!canSave || isReading || submitResult != nil)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(image: $cameraImage)
                    .ignoresSafeArea()
            }
            .alert(submitResult == true ? "Added to OpenFoodFacts" : "Not added to OpenFoodFacts",
                   isPresented: Binding(get: { submitResult != nil }, set: { if !$0 { finish() } })) {
                Button("OK") { finish() }
            } message: {
                Text(submitResult == true
                     ? "Thanks! It can take a few minutes before scans find it. Your entry is logged."
                     : "OpenFoodFacts didn't accept it. Check your login in Settings. Your entry is still logged.")
            }
            .interactiveDismissDisabled(isSubmitting)
            .onChange(of: cameraImage) { _, image in
                guard let image else { return }
                cameraImage = nil
                showingCamera = false
                photos.append(image)
                Task { await readLabel() }
            }
        }
    }

    private var photoSection: some View {
        Section {
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.s) {
                        ForEach(photos.indices, id: \.self) { index in
                            Image(uiImage: photos[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
                        }
                    }
                }
            }
            if isReading {
                HStack(spacing: DS.Spacing.s) {
                    ProgressView()
                    Text("Reading the package...")
                        .foregroundStyle(DS.Color.textSecondary)
                }
            } else if photos.count < maxPhotos {
                Button {
                    showingCamera = true
                } label: {
                    Label(photos.isEmpty ? "Take Photo of Package" : "Add Another Photo", systemImage: "camera")
                }
            }
            if let readError {
                Text(readError)
                    .font(.caption)
                    .foregroundStyle(DS.Color.danger)
            }
        } header: {
            Text("Fill from photos")
        } footer: {
            Text("Photograph the front and the nutrition facts. AI fills in the form below; check it before saving.")
        }
    }

    /// Sends every photo so far and fills in whatever the AI could read. Fields it couldn't read keep their values.
    private func readLabel() async {
        let jpegs = photos.compactMap { prepareImageForUpload($0) }
        guard !jpegs.isEmpty else { return }
        isReading = true
        readError = nil
        defer { isReading = false }
        do {
            let label = try await FoodChatService.readProductLabel(jpegs)
            if let value = label.name, !value.isEmpty { name = value }
            if let value = label.brand, !value.isEmpty { brand = value }
            if let value = label.serving_size, !value.isEmpty { servingDescription = value }
            if let value = label.serving_grams { servingGrams = value }
            if let value = label.calories { calories = Int(value.rounded()) }
            if let value = label.protein_grams { protein = value }
            if let value = label.carbs_grams { carbs = value }
            if let value = label.fat_grams { fat = value }
        } catch {
            readError = (error as? LocalizedError)?.errorDescription ?? "Couldn't read the package. Try another photo or type it in."
        }
    }

    private func numberRow(_ label: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private func save() {
        guard canSave, let calories else { return }
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)
        let displayName = (trimmedBrand.isEmpty ? trimmedName : "\(trimmedBrand) \(trimmedName)").titleCased()
        let serving = servingDescription.trimmingCharacters(in: .whitespaces)
        let grams = servingGrams.flatMap { $0 > 0 ? $0 : nil }

        if let onIngredientsAdded {
            onIngredientsAdded([IngredientItem(
                name: displayName,
                calories: calories,
                proteinGrams: protein ?? 0,
                carbsGrams: carbs ?? 0,
                fatGrams: fat ?? 0,
                servings: servings,
                servingDescription: serving.isEmpty ? nil : serving,
                servingGrams: grams,
                barcode: barcode,
                entrySource: .barcode
            )])
        } else {
            let entry = FoodEntry(
                name: displayName,
                calories: calories,
                proteinGrams: protein ?? 0,
                carbsGrams: carbs ?? 0,
                fatGrams: fat ?? 0,
                iconName: foodIconName(for: displayName),
                servings: servings,
                servingDescription: serving.isEmpty ? nil : serving,
                servingGrams: grams,
                barcode: barcode,
                entrySource: .barcode
            )
            modelContext.insert(entry)
            Task { await HealthKitService.shared.syncEntry(entry) }
        }

        // Always added to OFF; the alert reports whether it worked
        let product = OpenFoodFactsService.CorrectionData(
            barcode: barcode,
            caloriesPerServing: calories,
            proteinPerServing: protein ?? 0,
            carbsPerServing: carbs ?? 0,
            fatPerServing: fat ?? 0,
            servingDescription: serving.isEmpty ? nil : serving,
            servingGrams: grams,
            productName: trimmedName.titleCased(),
            brand: trimmedBrand.isEmpty ? nil : trimmedBrand
        )
        guard OpenFoodFactsService.hasCredentials else {
            finish()
            return
        }
        isSubmitting = true
        Task {
            submitResult = await OpenFoodFactsService.shared.submitCorrection(product)
            isSubmitting = false
        }
    }

    private func finish() {
        dismiss()
        onSaved()
    }
}

// MARK: - AVFoundation Camera View

struct BarcodeCameraView: UIViewControllerRepresentable {
    let onBarcodeScanned: (String) -> Void
    var resetCounter: Int

    func makeUIViewController(context: Context) -> BarcodeScannerController {
        let controller = BarcodeScannerController()
        controller.onBarcodeScanned = onBarcodeScanned
        context.coordinator.lastResetCounter = resetCounter
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerController, context: Context) {
        if resetCounter != context.coordinator.lastResetCounter {
            context.coordinator.lastResetCounter = resetCounter
            uiViewController.resetScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var lastResetCounter = 0
    }
}

class BarcodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcodeScanned: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [
                .ean8,
                .ean13,
                .upce,
                .code128,
                .code39
            ]
        }

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = object.stringValue else {
            return
        }

        hasScanned = true
        onBarcodeScanned?(barcode)
    }

    func resetScanning() {
        hasScanned = false
    }
}
