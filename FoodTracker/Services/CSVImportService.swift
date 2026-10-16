import Foundation
import SwiftData

enum CSVImportService {

    struct ParsedEntry {
        var name: String
        var calories: Int
        var proteinGrams: Double
        var carbsGrams: Double
        var fatGrams: Double
        var date: Date
        var servingDescription: String?
    }

    struct ImportResult {
        var entries: [ParsedEntry]
        var skippedRows: Int
    }

    static func parse(csvURL: URL) throws -> ImportResult {
        guard csvURL.startAccessingSecurityScopedResource() else {
            throw ImportError.accessDenied
        }
        defer { csvURL.stopAccessingSecurityScopedResource() }

        let content = try String(contentsOf: csvURL, encoding: .utf8)
        return parse(csvString: content)
    }

    static func parse(csvString: String) -> ImportResult {
        let rows = csvString.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard rows.count > 1 else { return ImportResult(entries: [], skippedRows: 0) }

        let headers = parseCSVRow(rows[0]).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        let nameIdx = headers.firstIndex { ["name", "food name", "food", "item", "description"].contains($0) }
        let calIdx = headers.firstIndex { ["calories", "cal", "cals", "energy", "kcal"].contains($0) }
        let protIdx = headers.firstIndex { ["protein (g)", "protein", "protein_grams"].contains($0) }
        let fatIdx = headers.firstIndex { ["fat (g)", "fat", "total fat", "fat_grams"].contains($0) }
        let carbIdx = headers.firstIndex { ["carbs (g)", "carbs", "carbohydrates", "carbohydrates (g)", "carbs_grams"].contains($0) }
        let dateIdx = headers.firstIndex { ["date", "day", "entry date"].contains($0) }
        let servingIdx = headers.firstIndex { ["serving size", "serving", "portion"].contains($0) }

        guard let nameIdx else { return ImportResult(entries: [], skippedRows: rows.count - 1) }

        var entries: [ParsedEntry] = []
        var skipped = 0

        let dateFormatters: [DateFormatter] = [
            { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "MM/dd/yyyy"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "M/d/yyyy"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; f.locale = Locale(identifier: "en_US"); return f }(),
        ]

        for i in 1..<rows.count {
            let fields = parseCSVRow(rows[i])
            guard fields.count > nameIdx else { skipped += 1; continue }

            let name = fields[nameIdx].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { skipped += 1; continue }

            let cal = calIdx.flatMap { $0 < fields.count ? Int(fields[$0].trimmingCharacters(in: .whitespaces)) : nil } ?? 0
            let prot = protIdx.flatMap { $0 < fields.count ? Double(fields[$0].trimmingCharacters(in: .whitespaces)) : nil } ?? 0
            let fat = fatIdx.flatMap { $0 < fields.count ? Double(fields[$0].trimmingCharacters(in: .whitespaces)) : nil } ?? 0
            let carbs = carbIdx.flatMap { $0 < fields.count ? Double(fields[$0].trimmingCharacters(in: .whitespaces)) : nil } ?? 0

            var date = Date()
            if let dateIdx, dateIdx < fields.count {
                let dateStr = fields[dateIdx].trimmingCharacters(in: .whitespaces)
                for formatter in dateFormatters {
                    if let d = formatter.date(from: dateStr) { date = d; break }
                }
            }

            let serving = servingIdx.flatMap { $0 < fields.count ? fields[$0].trimmingCharacters(in: .whitespaces) : nil }

            entries.append(ParsedEntry(
                name: name,
                calories: cal,
                proteinGrams: prot,
                carbsGrams: carbs,
                fatGrams: fat,
                date: date,
                servingDescription: serving?.isEmpty == true ? nil : serving
            ))
        }

        return ImportResult(entries: entries, skippedRows: skipped)
    }

    static func importEntries(_ parsed: [ParsedEntry], into context: ModelContext) -> Int {
        var count = 0
        for entry in parsed {
            let food = FoodEntry(
                name: entry.name.titleCased(),
                calories: entry.calories,
                proteinGrams: entry.proteinGrams,
                carbsGrams: entry.carbsGrams,
                fatGrams: entry.fatGrams,
                date: entry.date,
                iconName: foodIconName(for: entry.name),
                servings: 1.0,
                servingDescription: entry.servingDescription
            )
            context.insert(food)
            count += 1
        }
        return count
    }

    // MARK: - Export

    /// Writes every entry to a CSV in the same layout the importer reads, so an export can be imported again.
    /// Values are totals for what was eaten (servings already applied). Time and Meal are extra columns the importer ignores.
    static func exportCSV(_ entries: [FoodEntry]) -> URL? {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        func field(_ text: String) -> String {
            guard text.contains(where: { ",\"\n".contains($0) }) else { return text }
            return "\"" + text.replacingOccurrences(of: "\"", with: "'") + "\""
        }
        func num(_ value: Double) -> String {
            value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
        }

        var lines = ["Name,Calories,Protein,Fat,Carbs,Date,Serving Size,Time,Meal"]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            var serving = entry.servingDescription ?? ""
            if entry.servings != 1 {
                serving = "\(formatServings(entry.servings)) × \(serving.isEmpty ? "serving" : serving)"
            }
            lines.append([
                field(entry.name),
                "\(entry.totalCalories)",
                num(entry.totalProteinGrams),
                num(entry.totalFatGrams),
                num(entry.totalCarbsGrams),
                dayFormatter.string(from: entry.date),
                field(serving),
                timeFormatter.string(from: entry.date),
                field(entry.mealName ?? "")
            ].joined(separator: ","))
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FoodTracker_Export_\(dayFormatter.string(from: Date())).csv")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - CSV Parsing (handles quoted fields with commas)

    private static func parseCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    enum ImportError: LocalizedError {
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Could not access the selected file."
            }
        }
    }
}
