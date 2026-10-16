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
                                    scannedBarcode = nil
                                    resetCounter += 1
                                }
                                .buttonStyle(.borderedProminent)
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
                    Button("Cancel") { dismiss() }
                        .tint(DS.Color.overlayText)
                }
            }
            .sheet(isPresented: $showingResults, onDismiss: {
                dismiss()
            }) {
                PhotoAnalysisView(foods: scannedFoods, onIngredientsAdded: onIngredientsAdded)
            }
        }
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
