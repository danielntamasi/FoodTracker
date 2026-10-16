import Foundation
import SwiftData
import UIKit

// MARK: - Feedback Models

enum FeedbackKind: String, CaseIterable, Identifiable {
    case broken, numbers, idea

    var id: String { rawValue }

    var label: String {
        switch self {
        case .broken: return "Something's broken"
        case .numbers: return "Numbers look wrong"
        case .idea: return "I wish it could…"
        }
    }

    /// Fits a three-way segmented control.
    var shortLabel: String {
        switch self {
        case .broken: return "Broken"
        case .numbers: return "Wrong numbers"
        case .idea: return "Idea"
        }
    }

    var icon: String {
        switch self {
        case .broken: return "ladybug"
        case .numbers: return "number"
        case .idea: return "lightbulb"
        }
    }

    var notePrompt: String {
        switch self {
        case .broken: return "What happened?"
        case .numbers: return "Which number looks wrong, and what should it be?"
        case .idea: return "What were you trying to do?"
        }
    }

    var isIdea: Bool { self == .idea }

    /// Most follow-up questions the assistant may ask before the report goes out.
    var maxQuestions: Int { isIdea ? 3 : 2 }
}

enum FeedbackPriority: String, CaseIterable, Identifiable {
    case niceToHave = "Nice to have"
    case bugsMeOften = "This bugs me often"
    var id: String { rawValue }
}

struct FeedbackExchange: Identifiable {
    let id = UUID()
    let question: String
    var answer: String
}

/// What the app knows at the moment feedback starts. Built on the main actor from SwiftData, then passed around as plain values.
struct FeedbackContext {
    var screenshot: UIImage?
    var recentEntries: [String] = []
    /// Short description of the food log, used for feature requests.
    var logSummary: String = ""
}

enum FeedbackStep {
    case question(String)
    /// Bug reports: nothing more to ask.
    case ready
    /// Feature requests: one-line summary for the user to confirm.
    case summary(String)
}

// MARK: - Feedback Service

enum FeedbackService {

    /// Whether an AI provider key is set; without one, feedback skips the follow-up questions.
    static var hasAIKey: Bool {
        let key = KeychainService.load(account: VisionProvider.selected.keychainAccount)
        return !(key ?? "").isEmpty
    }

    // MARK: Context

    @MainActor
    static func makeContext(screenshot: UIImage?, modelContext: ModelContext) -> FeedbackContext {
        var descriptor = FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 400
        let entries = (try? modelContext.fetch(descriptor)) ?? []

        var context = FeedbackContext(screenshot: screenshot)
        context.recentEntries = entries.prefix(10).map { entry in
            "\(entry.name) (\(entry.totalCalories) cal, \(entry.date.formatted(date: .abbreviated, time: .shortened)))"
        }
        context.logSummary = logSummary(entries)
        return context
    }

    private static func logSummary(_ entries: [FoodEntry]) -> String {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return "" }
        let month = entries.filter { $0.date >= cutoff }
        guard !month.isEmpty else { return "No food logged in the last 30 days." }

        let days = Set(month.map { Calendar.current.startOfDay(for: $0.date) }).count
        var counts: [String: Int] = [:]
        var periods = [0, 0, 0]
        for entry in month {
            counts[entry.name, default: 0] += 1
            let hour = Calendar.current.component(.hour, from: entry.date)
            periods[hour < 11 ? 0 : hour < 17 ? 1 : 2] += 1
        }
        let top = counts.sorted { $0.value > $1.value }.prefix(8).map { "\($0.key) ×\($0.value)" }
        let meals = Set(month.compactMap(\.mealGroupID)).count

        return """
        Last 30 days: \(month.count) entries on \(days) days, \(meals) logged as meals.
        Most logged: \(top.joined(separator: ", ")).
        Entries by time of day: morning \(periods[0]), afternoon \(periods[1]), evening \(periods[2]).
        """
    }

    // MARK: Past Requests

    private static let pastRequestsKey = "feedbackPastRequests"

    /// Feature requests already sent from this phone, newest first, as "date: summary".
    static var pastRequests: [String] {
        UserDefaults.standard.stringArray(forKey: pastRequestsKey) ?? []
    }

    static func rememberRequest(_ summary: String) {
        let line = "\(Date().formatted(date: .abbreviated, time: .omitted)): \(summary)"
        UserDefaults.standard.set(Array(([line] + pastRequests).prefix(30)), forKey: pastRequestsKey)
    }

    // MARK: Assistant

    /// Asks the assistant for the next step: one more question, or done.
    /// `forceFinish` tells it the question budget is used up.
    static func nextStep(
        kind: FeedbackKind,
        note: String,
        exchanges: [FeedbackExchange],
        context: FeedbackContext,
        forceFinish: Bool
    ) async throws -> FeedbackStep {
        var turns: [FoodChatTurn] = []

        var opening = "Report type: \(kind.label)\n\nTheir note: \(note)"
        if !kind.isIdea, context.screenshot == nil {
            opening += "\n\n(No screenshot attached.)"
        }
        let jpegs = kind.isIdea ? [] : (context.screenshot.flatMap { prepareImageForUpload($0) }.map { [$0] } ?? [])
        turns.append(FoodChatTurn(isUser: true, text: opening, jpegs: jpegs))

        for exchange in exchanges {
            turns.append(FoodChatTurn(isUser: false, text: exchange.question, jpegs: []))
            turns.append(FoodChatTurn(isUser: true, text: exchange.answer, jpegs: []))
        }

        if forceFinish, let last = turns.popLast() {
            let instruction = kind.isIdea
                ? "That's all the questions. Reply with only the <summary> now."
                : "That's all the questions. Reply with only <ready/> now."
            turns.append(FoodChatTurn(isUser: true, text: last.text + "\n\n(\(instruction))", jpegs: last.jpegs))
        }

        let reply = try await FoodChatService.reply(to: turns, system: systemPrompt(kind: kind, context: context))
        return parse(reply, kind: kind)
    }

    private static func parse(_ reply: String, kind: FeedbackKind) -> FeedbackStep {
        if let open = reply.range(of: "<summary>") {
            let rest = reply[open.upperBound...]
            let body = rest.range(of: "</summary>").map { rest[..<$0.lowerBound] } ?? rest
            return .summary(body.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if reply.contains("<ready") {
            return .ready
        }
        let question = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        return question.isEmpty ? (kind.isIdea ? .summary("") : .ready) : .question(question)
    }

    private static func systemPrompt(kind: FeedbackKind, context: FeedbackContext) -> String {
        let shared = """
        You are inside FoodTracker, a personal iPhone calorie and macro tracking app used by two people. The person who builds it reads every report and works from them directly, so a report is only useful if it is specific enough to act on without having to go back and ask.

        Write like a quick text message: short, friendly, plain sentences, no markdown, no greetings, no thanking, no apologizing. Ask exactly one question per reply. Never ask about something the note, earlier answers, or screenshot already make clear. Don't propose fixes or promise anything will change.

        What the app does today:
        \(appOverview)

        Their most recent log entries:
        \(context.recentEntries.isEmpty ? "(none)" : context.recentEntries.joined(separator: "\n"))
        """

        if kind.isIdea {
            let past = pastRequests.prefix(15)
            return shared + """


            This is a feature request. Your job is to fill in what the idea needs to be built well, in at most \(kind.maxQuestions) questions, aimed at whichever of these is still missing:
            - when it comes up and how often
            - what they do today instead
            - what should happen when it works (what they'd tap, what they'd see)
            If the app already does this or something close (see the overview), say where in one sentence and ask whether that covers it. If one of their past requests below looks like the same idea, ask whether it is.

            When you know enough, or when told there are no more questions, reply with only:
            <summary>One or two sentences in their own voice, starting with "I want", covering what they want, when or how often it comes up, and what they do today.</summary>

            Their food log, for context:
            \(context.logSummary)

            Feature requests they've sent before:
            \(past.isEmpty ? "(none)" : past.joined(separator: "\n"))
            """
        } else {
            return shared + """


            This is a problem report (\(kind.label.lowercased())). A screenshot of the screen they were on is usually attached. If the note plus screenshot already say what went wrong and where, reply with only <ready/>. Otherwise ask about the single most important missing piece, such as what they did just before, what they expected instead, or which number is wrong and what it should be (for example what the package label says). At most \(kind.maxQuestions) questions in total; when told there are no more, reply with only <ready/>.
            """
        }
    }

    private static let appOverview = """
    - Today tab: daily calorie ring and macro totals against targets, entries grouped into morning/afternoon/evening, swipe to delete, edit or add again, drag to reorder, meals expand into their items.
    - History tab: past days, collapsible, with totals. Performance tile: how many days were on target this week/month/year, streaks, trends.
    - The + button opens: Recent (favorites, frequent foods, recent meals, recent foods to re-add with one tap), Search (your past foods, USDA database, AI estimate, manual entry), AI Chat (describe or photograph food, go back and forth with the AI, then tap "Log it"), Build (compose a named meal from several ingredients and save it as a group), Barcode (scan a package via OpenFoodFacts, choose servings).
    - Tapping an entry opens its detail page: photo, macros, share of daily goals; Edit changes name, numbers, serving size, servings, date and time; star to favorite.
    - Settings: AI provider and model, API keys, daily calorie and macro targets, Apple Health sync, appearance, CSV import and export of the food log, estimation accuracy history, feedback.
    - Home screen widget with today's calories and macros.
    """

    // MARK: Report

    /// Where reports are emailed. Set at build time from FEEDBACK_EMAIL in the gitignored Secrets.xcconfig,
    /// so the address stays out of the repo; nil when not set.
    static let recipient: String? = {
        let value = (Bundle.main.object(forInfoDictionaryKey: "FeedbackRecipient") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
        return value.contains("@") ? value : nil
    }()

    static func subject(kind: FeedbackKind, note: String, summary: String?) -> String {
        let text = (summary?.isEmpty == false ? summary! : note)
            .replacingOccurrences(of: "\n", with: " ")
        let short = text.count > 60 ? String(text.prefix(57)) + "…" : text
        return "FoodTracker \(kind.isIdea ? "idea" : "problem"): \(short)"
    }

    static func reportText(
        kind: FeedbackKind,
        note: String,
        exchanges: [FeedbackExchange],
        summary: String?,
        priority: FeedbackPriority?,
        context: FeedbackContext
    ) -> String {
        var lines: [String] = []
        if kind.isIdea {
            lines.append("💡 FoodTracker idea" + (priority.map { " (\($0.rawValue))" } ?? ""))
            if let summary, !summary.isEmpty { lines.append(summary) }
            lines.append("")
            lines.append("Original note: \(note)")
        } else {
            lines.append("\(kind == .numbers ? "🔢" : "🐞") FoodTracker: \(kind.label)")
            lines.append(note)
        }

        let answered = exchanges.filter { !$0.answer.isEmpty }
        if !answered.isEmpty {
            lines.append("")
            for exchange in answered {
                lines.append("Q: \(exchange.question)")
                lines.append("A: \(exchange.answer)")
            }
        }

        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        lines.append("")
        lines.append("—")
        lines.append("App \(version) (\(build)) · iOS \(UIDevice.current.systemVersion) · \(Date().formatted(date: .abbreviated, time: .shortened))")
        if !context.recentEntries.isEmpty {
            lines.append("Recent entries: " + context.recentEntries.prefix(5).joined(separator: "; "))
        }
        return lines.joined(separator: "\n")
    }
}
