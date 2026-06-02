import SwiftUI
import UIKit

struct BugReportView: View {
    let trace: PipelineTrace?
    let photos: [UIImage]
    let identifiedFoods: [IdentifiedFood]
    var entryName: String?
    var originalValues: BugReportService.CorrectionValues?
    var correctedValues: BugReportService.CorrectionValues?

    @State private var userComplaint = ""
    @State private var isGenerating = false
    @State private var reportURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let photo = photos.first {
                    Section {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
                    }
                }

                if let trace {
                    Section("Pipeline Summary") {
                        LabeledContent("Provider", value: trace.visionProvider)
                        LabeledContent("Plate Size", value: trace.plateSize)
                        LabeledContent("Cooking Method", value: trace.cookingMethodSelection ?? "Auto")
                        LabeledContent("Foods Identified", value: "\(identifiedFoods.count)")
                    }
                }

                if !identifiedFoods.isEmpty {
                    Section("Results") {
                        ForEach(identifiedFoods) { food in
                            HStack {
                                Text(food.name)
                                Spacer()
                                Text("\(food.calories) cal")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }

                if let orig = originalValues, let corr = correctedValues {
                    Section("Your Corrections") {
                        correctionRow("Calories", original: "\(orig.calories)", corrected: "\(corr.calories)")
                        correctionRow("Protein", original: String(format: "%.1fg", orig.protein), corrected: String(format: "%.1fg", corr.protein))
                        correctionRow("Carbs", original: String(format: "%.1fg", orig.carbs), corrected: String(format: "%.1fg", corr.carbs))
                        correctionRow("Fat", original: String(format: "%.1fg", orig.fat), corrected: String(format: "%.1fg", corr.fat))
                    }
                }

                Section {
                    TextField("Describe what seems wrong...", text: $userComplaint, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("What's the issue?")
                } footer: {
                    Text("This report will be packaged with the photo, pipeline trace, and nutrition data for debugging.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(DS.Color.danger)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Button("Export") { generateAndShare() }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = reportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    @ViewBuilder
    private func correctionRow(_ label: String, original: String, corrected: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(original)
                .foregroundStyle(.secondary)
                .strikethrough()
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(corrected)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func generateAndShare() {
        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let context = BugReportService.ReportContext(
                    trace: trace,
                    photos: photos,
                    userComplaint: userComplaint,
                    identifiedFoods: identifiedFoods,
                    entryName: entryName,
                    originalValues: originalValues,
                    correctedValues: correctedValues
                )
                let url = try BugReportService.generateReport(context)
                reportURL = url
                showShareSheet = true
            } catch {
                errorMessage = "Failed to generate report: \(error.localizedDescription)"
            }
            isGenerating = false
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
