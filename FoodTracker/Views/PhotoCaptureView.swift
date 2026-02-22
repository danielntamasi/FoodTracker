import SwiftUI
import UIKit

struct PhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var showingAnalysis = false

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
                        PhotoAnalysisView(image: image)
                    }
                }
        }
    }
}

struct PhotoUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var showingAnalysis = false

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
                        PhotoAnalysisView(image: image)
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
