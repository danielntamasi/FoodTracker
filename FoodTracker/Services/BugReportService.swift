import Foundation
import UIKit

enum BugReportService {

    struct ReportContext {
        var trace: PipelineTrace?
        var photos: [UIImage]
        var userComplaint: String
        var identifiedFoods: [IdentifiedFood]
        var entryName: String?
        var originalValues: CorrectionValues?
        var correctedValues: CorrectionValues?
    }

    struct CorrectionValues {
        var calories: Int
        var protein: Double
        var carbs: Double
        var fat: Double
    }

    static func generateReport(_ context: ReportContext) throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let dirName = "FoodTracker_BugReport_\(timestamp.replacingOccurrences(of: ":", with: "-"))"
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(dirName)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        for (index, photo) in context.photos.enumerated() {
            let photoURL = tempDir.appendingPathComponent("photo_\(index + 1).jpg")
            if let data = photo.jpegData(compressionQuality: 0.85) {
                try data.write(to: photoURL)
            }
        }

        if let trace = context.trace {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(trace)
            try jsonData.write(to: tempDir.appendingPathComponent("pipeline_trace.json"))
        }

        let markdown = generateMarkdown(context)
        try markdown.write(to: tempDir.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)

        return try zipDirectory(tempDir)
    }

    // MARK: - Zip

    private static func zipDirectory(_ directoryURL: URL) throws -> URL {
        let zipName = directoryURL.lastPathComponent + ".zip"
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent(zipName)
        try? FileManager.default.removeItem(at: zipURL)

        let coordinator = NSFileCoordinator()
        var error: NSError?
        var resultURL: URL?

        coordinator.coordinate(readingItemAt: directoryURL, options: .forUploading, error: &error) { tempZipURL in
            try? FileManager.default.copyItem(at: tempZipURL, to: zipURL)
            resultURL = zipURL
        }

        if let error { throw error }
        guard let result = resultURL else {
            throw NSError(domain: "BugReport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create zip"])
        }

        try? FileManager.default.removeItem(at: directoryURL)
        return result
    }

    // MARK: - Markdown Generation

    private static func generateMarkdown(_ context: ReportContext) -> String {
        var md = """
        # FoodTracker Vision Pipeline Bug Report
        Generated: \(ISO8601DateFormatter().string(from: Date()))

        ## User's Complaint
        \(context.userComplaint.isEmpty ? "(No description provided)" : context.userComplaint)

        """

        if !context.photos.isEmpty {
            md += "## Photos\n"
            for i in 1...context.photos.count {
                md += "- photo_\(i).jpg (attached)\n"
            }
            md += "\n"
        }

        if let trace = context.trace {
            md += generateTraceMarkdown(trace)
        } else if let name = context.entryName {
            md += "## Entry\n**Name:** \(name)\n\n"
            md += "*No pipeline trace available — this report was created from an edited entry.*\n\n"
        }

        if let orig = context.originalValues, let corr = context.correctedValues {
            md += """
            ## User Corrections
            | Field | Original | Corrected | Delta |
            |-------|----------|-----------|-------|
            | Calories | \(orig.calories) | \(corr.calories) | \(corr.calories - orig.calories) |
            | Protein | \(fmt(orig.protein))g | \(fmt(corr.protein))g | \(fmt(corr.protein - orig.protein))g |
            | Carbs | \(fmt(orig.carbs))g | \(fmt(corr.carbs))g | \(fmt(corr.carbs - orig.carbs))g |
            | Fat | \(fmt(orig.fat))g | \(fmt(corr.fat))g | \(fmt(corr.fat - orig.fat))g |

            """
        }

        if !context.identifiedFoods.isEmpty {
            md += "## Final Results Shown to User\n"
            md += "| Food | Cal | Protein | Carbs | Fat | Portion | Source |\n"
            md += "|------|-----|---------|-------|-----|---------|--------|\n"
            for food in context.identifiedFoods {
                md += "| \(food.name) | \(food.calories) | \(fmt(food.proteinGrams))g | \(fmt(food.carbsGrams))g | \(fmt(food.fatGrams))g | \(food.portionDescription) (\(fmt(food.portionGrams))g) | \(food.source.rawValue) |\n"
            }
            md += "\n"
        }

        return md
    }

    private static func generateTraceMarkdown(_ trace: PipelineTrace) -> String {
        var md = """
        ## Pipeline Configuration
        - **Vision Provider:** \(trace.visionProvider)
        - **Plate Size:** \(trace.plateSize)
        - **Cooking Method:** \(trace.cookingMethodSelection ?? "Auto")

        """

        if let rawText = trace.rawVisionResponseText {
            md += "## Vision API Response (Raw)\n```\n\(rawText)\n```\n\n"
        }

        if !trace.parsedVisionFoods.isEmpty {
            md += "## Foods Identified by Vision\n"
            md += "| # | Name | Portion | Grams | Confidence | Cooking Method | Hidden Cal |\n"
            md += "|---|------|---------|-------|------------|----------------|------------|\n"
            for (i, item) in trace.parsedVisionFoods.enumerated() {
                let conf = item.confidence.map { "\($0)/5" } ?? "—"
                let method = item.cookingMethod ?? "—"
                let hidden = item.hiddenCaloriesEstimate.map { "\(Int($0))" } ?? "0"
                let meal = item.mealName.map { " (\($0))" } ?? ""
                md += "| \(i + 1) | \(item.name)\(meal) | \(item.portion) | \(fmt(item.portionGrams)) | \(conf) | \(method) | \(hidden) |\n"
            }
            md += "\n"
        }

        if !trace.foodTraces.isEmpty {
            md += "## Per-Food Pipeline Trace\n\n"
            for (i, ft) in trace.foodTraces.enumerated() {
                md += "### Food \(i + 1): \(ft.foodNameFromVision)\n"
                md += "- **Vision portion:** \(ft.portionFromVision) (\(fmt(ft.portionGramsFromVision))g)\n"
                md += "- **Scaled portion:** \(fmt(ft.scaledPortionGrams))g (plate: \(trace.plateSize))\n"
                if let method = ft.effectiveCookingMethod {
                    md += "- **Effective cooking method:** \(method)\n"
                }
                if let hidden = ft.hiddenCaloriesEstimate, hidden > 0 {
                    md += "- **Hidden calories:** \(Int(hidden)) (\(ft.hiddenCaloriesSource ?? "unknown source"))\n"
                }
                md += "\n"

                let allQueries = ft.fnddsQueries + ft.fdcQueries
                if !allQueries.isEmpty {
                    md += "#### USDA Queries\n"
                    md += "| Query | Database | Results | Top Match |\n"
                    md += "|-------|----------|---------|----------|\n"
                    for q in allQueries {
                        let top = q.topResults.first?.description ?? "—"
                        md += "| \(q.query) | \(q.dataType) | \(q.resultCount) | \(top) |\n"
                    }
                    md += "\n"
                }

                md += "- **FNDDS attempted:** \(ft.fnddsAttempted ? "yes" : "no")"
                if let r = ft.fnddsResult { md += " → \(r.description) (\(fmt(r.caloriesPer100g)) cal/100g)" }
                md += "\n"
                md += "- **FDC attempted:** \(ft.fdcAttempted ? "yes" : "no")"
                if let r = ft.fdcResult { md += " → \(r.description) (\(fmt(r.caloriesPer100g)) cal/100g)" }
                md += "\n"

                if ft.aiEstimateFallbackUsed, let ai = ft.aiEstimateResult {
                    md += "- **AI fallback used:** yes → \(ai.calories) cal, \(fmt(ai.proteinGrams))P / \(fmt(ai.carbsGrams))C / \(fmt(ai.fatGrams))F"
                    if let sg = ai.servingGrams { md += " for \(ai.servingDescription ?? "1 serving") (\(fmt(sg))g)" }
                    md += "\n"
                }
                if ft.visionInlineEstimatesUsed {
                    md += "- **Vision inline estimates used as last resort:** yes\n"
                }
                md += "- **Final source:** \(ft.finalSource)\n\n"

                if let input = ft.sanitizationInput, let output = ft.sanitizationOutput {
                    md += "#### Sanitization\n"
                    md += "| Metric | Before | After |\n"
                    md += "|--------|--------|-------|\n"
                    md += "| Calories | \(fmt(input.calories)) | \(fmt(output.calories)) |\n"
                    md += "| Protein | \(fmt(input.protein))g | \(fmt(output.protein))g |\n"
                    md += "| Carbs | \(fmt(input.carbs))g | \(fmt(output.carbs))g |\n"
                    md += "| Fat | \(fmt(input.fat))g | \(fmt(output.fat))g |\n"
                    if !ft.sanitizationHeuristicsFired.isEmpty {
                        md += "\n**Heuristics fired:** \(ft.sanitizationHeuristicsFired.joined(separator: ", "))\n"
                    } else {
                        md += "\n**Heuristics fired:** none\n"
                    }
                    md += "\n"
                }
            }
        }

        return md
    }

    private static func fmt(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : String(format: "%.1f", value)
    }
}
