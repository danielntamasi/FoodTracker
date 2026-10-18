import SwiftUI
import PencilKit
import MessageUI

// MARK: - Shake to Report

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

/// Presents the feedback sheet over whatever is on screen, including other sheets,
/// which a SwiftUI `.sheet` on the root view can't do.
@MainActor
enum FeedbackPresenter {
    private final class HostingController: UIHostingController<AnyView> {}

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
    }

    static func screenshot() -> UIImage? {
        guard let window = keyWindow else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }

    static func present(context: FeedbackContext) {
        guard var top = keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController {
            if presented is HostingController { return } // already open
            top = presented
        }

        let host = HostingController(rootView: AnyView(EmptyView()))
        host.rootView = AnyView(
            FeedbackView(context: context) { [weak host] in host?.dismiss(animated: true) }
                .tint(DS.Color.protein)
        )
        top.present(host, animated: true)
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    let context: FeedbackContext
    let onClose: () -> Void

    private enum Stage { case compose, asking, confirm, done }

    @State private var kind: FeedbackKind
    @State private var screenshot: UIImage?
    @State private var includeScreenshot: Bool
    @State private var note = ""
    @State private var exchanges: [FeedbackExchange] = []
    @State private var answer = ""
    @State private var summary = ""
    @State private var priority: FeedbackPriority = .niceToHave
    @State private var stage: Stage = .compose
    @State private var isThinking = false
    @State private var showingMarkup = false
    @State private var showingShare = false
    @State private var showingMail = false
    @State private var reportText = ""
    /// The idea summary the user confirmed, if they reached that step.
    @State private var confirmedSummary: String?
    @FocusState private var fieldFocused: Bool

    init(context: FeedbackContext, onClose: @escaping () -> Void) {
        self.context = context
        self.onClose = onClose
        let startKind: FeedbackKind = context.screenshot == nil ? .idea : .broken
        _kind = State(initialValue: startKind)
        _screenshot = State(initialValue: context.screenshot)
        _includeScreenshot = State(initialValue: context.screenshot != nil && !startKind.isIdea)
    }

    private var useAI: Bool { FeedbackService.hasAIKey }

    /// The context as the assistant and report should see it, with the screenshot only if it's included.
    private var effectiveContext: FeedbackContext {
        var copy = context
        copy.screenshot = includeScreenshot ? screenshot : nil
        return copy
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch stage {
                    case .compose: composeContent
                    case .asking: askingContent
                    case .confirm: confirmContent
                    case .done: doneContent
                    }
                }
                .padding(DS.Spacing.screenEdge)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DS.Color.backgroundPrimary)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationTitle(kind.isIdea ? "Suggest a Feature" : "Report a Problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                }
            }
            .fullScreenCover(isPresented: $showingMarkup) {
                if let screenshot {
                    ScreenshotMarkupView(image: screenshot) { marked in
                        self.screenshot = marked
                        includeScreenshot = true
                    }
                }
            }
            .sheet(isPresented: $showingShare) {
                FeedbackShareSheet(items: shareItems) { completed in
                    if completed { markSent() }
                }
            }
            .sheet(isPresented: $showingMail) {
                FeedbackMailComposer(
                    subject: FeedbackService.subject(kind: kind, note: note, summary: confirmedSummary),
                    body: reportText,
                    screenshot: effectiveContext.screenshot
                ) { sent in
                    showingMail = false
                    if sent { markSent() }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: Stages

    @ViewBuilder
    private var composeContent: some View {
        Picker("Type", selection: $kind) {
            ForEach(FeedbackKind.allCases) { option in
                Text(option.shortLabel).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: kind) { _, newKind in
            if screenshot != nil { includeScreenshot = !newKind.isIdea }
        }

        if let screenshot {
            HStack(alignment: .top, spacing: 16) {
                Button { showingMarkup = true } label: {
                    Image(uiImage: screenshot)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
                        .opacity(includeScreenshot ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark up screenshot")

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Include screenshot", isOn: $includeScreenshot)
                        .font(.subheadline)
                    Button {
                        showingMarkup = true
                    } label: {
                        Label("Mark up", systemImage: "pencil.tip.crop.circle")
                            .font(.subheadline)
                    }
                }
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text(kind.notePrompt)
                .font(.headline)
            inputField("Type here", text: $note)
        }
    }

    @ViewBuilder
    private var askingContent: some View {
        Text(note)
            .font(.subheadline)
            .foregroundStyle(DS.Color.textSecondary)

        ForEach(exchanges.dropLast()) { exchange in
            VStack(alignment: .leading, spacing: 4) {
                Text(exchange.question)
                    .font(.subheadline.weight(.medium))
                Text(exchange.answer.isEmpty ? "(skipped)" : exchange.answer)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }

        if let current = exchanges.last {
            VStack(alignment: .leading, spacing: 8) {
                Label(current.question, systemImage: "sparkles")
                    .font(.headline)
                inputField("Your answer", text: $answer)
            }
        }
    }

    @ViewBuilder
    private var confirmContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Does this sum it up?")
                .font(.headline)
            inputField("Your idea in a sentence or two", text: $summary)
            Text("Edit anything that's off.")
                .font(.caption)
                .foregroundStyle(DS.Color.textTertiary)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("How much does it matter?")
                .font(.headline)
            Picker("Priority", selection: $priority) {
                ForEach(FeedbackPriority.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var doneContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("OK, I have everything I need.", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(DS.Color.success)
            Text("Please send this to Daniel. Tap the button below and hit Send in the email.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }

        VStack(alignment: .leading, spacing: 12) {
            Text(reportText)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let shot = effectiveContext.screenshot {
                Image(uiImage: shot)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
            }
        }
        .padding(12)
        .background(DS.Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
    }

    private func inputField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .lineLimit(3...10)
            .textInputAutocapitalization(.sentences)
            .focused($fieldFocused)
            .padding(12)
            .background(DS.Color.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
            .onAppear { fieldFocused = true }
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if isThinking {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                Button(action: primaryAction) {
                    Text(primaryTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!primaryEnabled)

                if stage == .asking {
                    Button("Skip and send now", action: send)
                        .font(.subheadline)
                } else if stage == .done, FeedbackService.recipient != nil {
                    Button("Other ways to send") { showingShare = true }
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.screenEdge)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var primaryTitle: String {
        switch stage {
        case .compose: return useAI ? "Next" : (kind.isIdea ? "Next" : "Send")
        case .asking: return "Next"
        case .confirm: return "Done"
        case .done: return FeedbackService.recipient == nil ? "Send" : "Email to Daniel"
        }
    }

    private var primaryEnabled: Bool {
        switch stage {
        case .compose: return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .asking: return !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .confirm: return !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .done: return true
        }
    }

    // MARK: Actions

    private func primaryAction() {
        switch stage {
        case .compose:
            if useAI {
                advance()
            } else {
                finish()
            }
        case .asking:
            exchanges[exchanges.count - 1].answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            answer = ""
            advance()
        case .confirm:
            send()
        case .done:
            email()
        }
    }

    /// Asks the assistant what's next; any failure just moves on, so feedback can always be sent.
    private func advance() {
        let used = exchanges.count >= kind.maxQuestions
        isThinking = true
        Task {
            let step = try? await FeedbackService.nextStep(
                kind: kind,
                note: note,
                exchanges: exchanges,
                context: effectiveContext,
                forceFinish: used
            )
            isThinking = false
            switch step {
            case .question(let question) where !used:
                exchanges.append(FeedbackExchange(question: question, answer: ""))
                stage = .asking
                fieldFocused = true
            case .summary(let text) where kind.isIdea && !text.isEmpty:
                summary = text
                stage = .confirm
            default:
                finish()
            }
        }
    }

    /// Ideas go to the confirm step (with their own note as the summary if the assistant didn't write one); problems go straight out.
    private func finish() {
        if kind.isIdea {
            if summary.isEmpty { summary = note }
            stage = .confirm
        } else {
            send()
        }
    }

    private var shareItems: [Any] {
        var items: [Any] = [reportText]
        if let shot = effectiveContext.screenshot { items.append(shot) }
        return items
    }

    private func send() {
        if let last = exchanges.indices.last, exchanges[last].answer.isEmpty, !answer.isEmpty {
            exchanges[last].answer = answer
        }
        fieldFocused = false
        let confirmed = kind.isIdea && stage == .confirm
        confirmedSummary = confirmed ? summary : nil
        reportText = FeedbackService.reportText(
            kind: kind,
            note: note,
            exchanges: exchanges,
            summary: confirmedSummary,
            priority: confirmed ? priority : nil,
            context: effectiveContext
        )
        withAnimation { stage = .done }
    }

    /// Opens a prefilled email to the developer. Without a Mail account, falls back to a mailto link
    /// (the default mail app, no screenshot attached).
    private func email() {
        guard let recipient = FeedbackService.recipient else {
            showingShare = true
            return
        }
        if MFMailComposeViewController.canSendMail() {
            showingMail = true
            return
        }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: FeedbackService.subject(kind: kind, note: note, summary: confirmedSummary)),
            URLQueryItem(name: "body", value: reportText)
        ]
        if let url = components.url {
            UIApplication.shared.open(url) { opened in
                if opened { markSent() } else { showingShare = true }
            }
        } else {
            showingShare = true
        }
    }

    private func markSent() {
        if kind.isIdea {
            FeedbackService.rememberRequest(confirmedSummary ?? note)
        }
        onClose()
    }
}

// MARK: - Mail Composer

private struct FeedbackMailComposer: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let screenshot: UIImage?
    let onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(FeedbackService.recipient.map { [$0] } ?? [])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        if let jpeg = screenshot?.jpegData(compressionQuality: 0.8) {
            controller.addAttachmentData(jpeg, mimeType: "image/jpeg", fileName: "screenshot.jpg")
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish(result == .sent)
        }
    }
}

// MARK: - Share Sheet

private struct FeedbackShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onComplete(completed) }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Screenshot Markup

private struct ScreenshotMarkupView: View {
    let image: UIImage
    let onDone: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canvas = PKCanvasView()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let size = fittedSize(in: geo.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                    MarkupCanvas(canvas: canvas)
                        .frame(width: size.width, height: size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black)
            .navigationTitle("Circle the problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Button("Clear") { canvas.drawing = PKDrawing() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(merged())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func fittedSize(in container: CGSize) -> CGSize {
        let scale = min(container.width / image.size.width, container.height / image.size.height)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    /// Draws the markup onto the screenshot at the screenshot's own resolution.
    private func merged() -> UIImage {
        let bounds = canvas.bounds
        guard bounds.width > 0, !canvas.drawing.strokes.isEmpty else { return image }
        let rect = CGRect(origin: .zero, size: image.size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: rect)
            canvas.drawing
                .image(from: bounds, scale: image.scale * image.size.width / bounds.width)
                .draw(in: rect)
        }
    }
}

private struct MarkupCanvas: UIViewRepresentable {
    let canvas: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .systemRed, width: 6)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
