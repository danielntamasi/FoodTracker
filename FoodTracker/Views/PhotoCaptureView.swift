import SwiftUI
import UIKit

struct PhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var showingAnalysis = false
    var onIngredientsAdded: (([IngredientItem]) -> Void)?

    var body: some View {
        NavigationStack {
            ImagePicker(image: $capturedImage)
                .ignoresSafeArea()
                .navigationTitle("Take Photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .onChange(of: capturedImage) { _, newImage in
                    if newImage != nil {
                        showingAnalysis = true
                    }
                }
                .fullScreenCover(isPresented: $showingAnalysis, onDismiss: {
                    dismiss()
                }) {
                    if let image = capturedImage {
                        PhotoAnalysisView(image: image, onIngredientsAdded: onIngredientsAdded)
                    }
                }
        }
    }
}

struct PrecisionPhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImages: [UIImage] = []
    @State private var showingCamera = true
    @State private var showingAnalysis = false
    var onIngredientsAdded: (([IngredientItem]) -> Void)?

    @State private var currentImage: UIImage?

    private var promptText: String {
        switch capturedImages.count {
        case 0: return "Take a top-down photo of your food"
        case 1: return "Now take a side-angle photo for better portion estimation"
        default: return "Add another angle, or continue to analysis"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Photo capture area
                if showingCamera {
                    ImagePicker(image: $currentImage)
                        .ignoresSafeArea()
                } else {
                    // Review captured images
                    VStack(spacing: DS.Spacing.m) {
                        Text(promptText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, DS.Spacing.m)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Spacing.s) {
                                ForEach(capturedImages.indices, id: \.self) { index in
                                    Image(uiImage: capturedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
                                        .overlay(
                                            Text(index == 0 ? "Top" : "Side \(index)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.ultraThinMaterial)
                                                .clipShape(Capsule())
                                                .padding(4),
                                            alignment: .topLeading
                                        )
                                }
                            }
                            .padding(.horizontal, DS.Spacing.screenEdge)
                        }

                        HStack(spacing: DS.Spacing.m) {
                            if capturedImages.count < 3 {
                                Button {
                                    showingCamera = true
                                } label: {
                                    Label("Add Angle", systemImage: "camera.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, DS.Spacing.m)
                                        .padding(.vertical, DS.Spacing.s)
                                        .background(DS.Color.backgroundElevated)
                                        .foregroundStyle(DS.Color.textPrimary)
                                        .clipShape(Capsule())
                                }
                            }

                            Button {
                                showingAnalysis = true
                            } label: {
                                Label("Analyze \(capturedImages.count) Photos", systemImage: "sparkles")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, DS.Spacing.m)
                                    .padding(.vertical, DS.Spacing.s)
                                    .background(DS.Color.protein)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, DS.Spacing.l)
                    }
                }
            }
            .navigationTitle("Precision Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: currentImage) { _, newImage in
                if let newImage {
                    capturedImages.append(newImage)
                    currentImage = nil
                    showingCamera = false
                }
            }
            .fullScreenCover(isPresented: $showingAnalysis, onDismiss: {
                dismiss()
            }) {
                MultiAngleAnalysisView(images: capturedImages, onIngredientsAdded: onIngredientsAdded)
            }
        }
    }
}

/// Wraps PhotoAnalysisView with multi-image pipeline support.
struct MultiAngleAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let images: [UIImage]
    var onIngredientsAdded: (([IngredientItem]) -> Void)?

    @State private var identifiedFoods: [IdentifiedFood] = []
    @State private var isLoading = true
    @State private var loadingStatus = "Analyzing multiple angles..."
    @State private var errorMessage: String?
    @State private var selectedPlateSize: PlateSize = .medium
    @State private var selectedCookingMethod: CookingMethod?
    @State private var pipelineTrace: PipelineTrace?

    var body: some View {
        if !identifiedFoods.isEmpty || errorMessage != nil {
            // Pass first image so PhotoAnalysisView shows the photo and preparation context pickers
            if let firstImage = images.first {
                PhotoAnalysisView(
                    image: firstImage,
                    prefilled: identifiedFoods,
                    trace: pipelineTrace,
                    onIngredientsAdded: onIngredientsAdded
                )
            } else {
                PhotoAnalysisView(
                    foods: identifiedFoods,
                    onIngredientsAdded: onIngredientsAdded
                )
            }
        } else {
            NavigationStack {
                VStack(spacing: 16) {
                    // Show thumbnails of all angles
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            Image(uiImage: images[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    ProgressView(loadingStatus)
                        .font(.headline)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .padding()
                .navigationTitle("Precision Analysis")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .task {
                    await analyzeMultiAngle()
                }
            }
        }
    }

    private func analyzeMultiAngle() async {
        do {
            loadingStatus = "Analyzing \(images.count) angles for better accuracy..."
            let (foods, trace) = try await FoodAnalysisPipeline.analyzeImagesWithTrace(
                images,
                cookingMethod: selectedCookingMethod,
                plateSize: selectedPlateSize
            )
            identifiedFoods = foods
            pipelineTrace = trace
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

struct PhotoUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var showingAnalysis = false
    var onIngredientsAdded: (([IngredientItem]) -> Void)?

    var body: some View {
        NavigationStack {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
                .ignoresSafeArea()
                .navigationTitle("Choose Photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .onChange(of: selectedImage) { _, newImage in
                    if newImage != nil {
                        showingAnalysis = true
                    }
                }
                .fullScreenCover(isPresented: $showingAnalysis, onDismiss: {
                    dismiss()
                }) {
                    if let image = selectedImage {
                        PhotoAnalysisView(image: image, onIngredientsAdded: onIngredientsAdded)
                    }
                }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .camera
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        // Use requested source type, falling back to photo library (Simulator)
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
