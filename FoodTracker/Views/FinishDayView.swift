import SwiftUI
import SwiftData
import PhotosUI

/// "Finish the Day Strong": the assistant looks at what's been eaten today, the goals and the user's
/// usual foods, and suggests a few different snacks or small meals for the rest of the day. The user
/// picks single items or whole options, sees where each goal would land in the pinned tracker, and can
/// ask for options for what's left after their picks, or reply for other ideas. Photos of food they
/// have on hand (fridge, pantry, a package) can be sent too, and the assistant plans with them.
struct FinishDayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var recentEntries: [FoodEntry]

    /// Today's totals so far
    let current: Nutrients
    private let goals = Nutrients.goals

    private struct Message: Identifiable {
        let id = UUID()
        let isUser: Bool
        let text: String
        var images: [UIImage] = []
        var options: [FinishDayOption] = []
    }

    @State private var context: FinishDayContext?
    /// What's sent to the provider: the context message first, then the conversation
    @State private var turns: [FoodChatTurn] = []
    @State private var messages: [Message] = []
    /// Picked items, in the order picked. They stay picked across replies, so items from different
    /// suggestions can be combined.
    @State private var picks: [FinishDayPick] = []
    /// How many picks the last "Recalculate" covered, so the button only shows when there's something new
    @State private var recalculatedPickIDs: Set<UUID> = []
    @State private var input = ""
    /// Photos waiting to go with the next message
    @State private var pendingImages: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var cameraImage: UIImage?
    @State private var showingCamera = false
    /// Whether any photo was sent, so new items logged from the options count as AI Chat (photo)
    @State private var sentPhotos = false
    private let maxImagesPerMessage = 4
    @State private var isThinking = false
    @State private var errorMessage: String?
    @FocusState private var inputFocused: Bool

    init(current: Nutrients) {
        self.current = current
        let start = Calendar.current.date(byAdding: .day, value: -FinishDayHistory.lookbackDays, to: Calendar.current.startOfDay(for: Date())) ?? .distantPast
        _recentEntries = Query(filter: #Predicate<FoodEntry> { $0.date >= start })
    }

    private var pickedIDs: Set<UUID> { Set(picks.map(\.id)) }
    private var planned: Nutrients { picks.reduce(Nutrients()) { $0 + $1.item.totals } }
    private var canRecalculate: Bool { !picks.isEmpty && pickedIDs != recalculatedPickIDs && !isThinking }
    private var canSend: Bool {
        (!input.trimmingCharacters(in: .whitespaces).isEmpty || !pendingImages.isEmpty) && !isThinking && context != nil
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: DS.Spacing.l) {
                        ForEach(messages) { message in
                            Group {
                                if message.isUser {
                                    userBubble(message)
                                } else {
                                    assistantMessage(message)
                                }
                            }
                            .id(message.id)
                        }
                        if isThinking { WaitingPhrases(WaitingPhrases.finishDay) }
                        if let errorMessage { errorView(errorMessage) }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, DS.Spacing.screenEdge)
                    .padding(.vertical, DS.Spacing.m)
                }
                .scrollDismissesKeyboard(.interactively)
                .hardBottomEdge()
                .onChange(of: messages.count) { _, _ in
                    // A reply is shown from its top (the options are long); scrolling to the bottom
                    // left the scroll view at a stale offset that jumped on the next touch.
                    // Scrolls after the new message is laid out, so the target offset isn't computed
                    // from the old content size (which also left a stale offset that jumped on touch).
                    guard let last = messages.last else { return }
                    Task { @MainActor in
                        await Task.yield()
                        withAnimation(.smooth) {
                            if last.isUser {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            } else {
                                proxy.scrollTo(last.id, anchor: .top)
                            }
                        }
                    }
                }
                .onChange(of: isThinking) { _, thinking in
                    if thinking { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { MacroTracker(current: current, planned: planned, goals: goals) }
            .background(DS.Color.backgroundPrimary)
            .navigationTitle("Finish the Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { CloseButton { dismiss() } }
            }
            .bottomBar { bottomControls }
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(image: $cameraImage)
                    .ignoresSafeArea()
            }
            .onChange(of: cameraImage) { _, newImage in
                guard let newImage else { return }
                attach(newImage)
                cameraImage = nil
                showingCamera = false
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                pickerItems = []
                Task { await loadPickedPhotos(items) }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await start() }
    }

    // MARK: Messages

    private func userBubble(_ message: Message) -> some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
            if !message.images.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(Array(message.images.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
                    }
                }
            }
            if !message.text.isEmpty {
                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(DS.Color.protein, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(.leading, 60)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func assistantMessage(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            if !message.text.isEmpty {
                Text(message.text)
                    .foregroundStyle(DS.Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(message.options) { optionCard($0) }
        }
    }

    private func optionCard(_ option: FinishDayOption) -> some View {
        let pickedCount = option.items.filter { pickedIDs.contains($0.id) }.count
        let allPicked = pickedCount == option.items.count
        let totals = option.totals
        return VStack(alignment: .leading, spacing: 0) {
            // Header: picks or unpicks the whole option
            Button {
                withAnimation(.snappy) {
                    if allPicked {
                        let ids = Set(option.items.map(\.id))
                        picks.removeAll { ids.contains($0.id) }
                    } else {
                        picks += option.items.filter { !pickedIDs.contains($0.id) }
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: DS.Spacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.title)
                            .font(.headline)
                            .foregroundStyle(DS.Color.textPrimary)
                        if !option.note.isEmpty {
                            Text(option.note)
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                        macroLine(totals)
                            .font(.footnote.weight(.medium))
                    }
                    Spacer(minLength: 0)
                    checkmark(allPicked ? .all : pickedCount > 0 ? .some : .none)
                }
                .padding(DS.Spacing.m)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(option.title), whole option")
            .accessibilityAddTraits(allPicked ? .isSelected : [])

            ForEach(option.items) { pick in
                Divider().padding(.leading, DS.Spacing.m + 36)
                itemRow(pick)
            }
        }
        .background(DS.Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(pickedCount > 0 ? DS.Color.protein.opacity(0.6) : .clear, lineWidth: 1.5)
        )
    }

    private func itemRow(_ pick: FinishDayPick) -> some View {
        let isOn = pickedIDs.contains(pick.id)
        let item = pick.item
        let totals = item.totals
        return Button {
            withAnimation(.snappy) {
                if isOn { picks.removeAll { $0.id == pick.id } } else { picks.append(pick) }
            }
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.s) {
                FoodIconThumbnail(iconName: iconName(for: item), size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    let detail = [item.amount, "\(Int(totals.calories.rounded())) cal", "\(Int(totals.protein.rounded()))g protein", item.isEstimate ? "est." : nil]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                checkmark(isOn ? .all : .none)
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private enum CheckState { case none, some, all }

    private func checkmark(_ state: CheckState) -> some View {
        Image(systemName: state == .all ? "checkmark.circle.fill" : state == .some ? "minus.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(state == .none ? DS.Color.textTertiary : DS.Color.protein)
            .contentTransition(.symbolEffect(.replace))
    }

    private func macroLine(_ n: Nutrients) -> Text {
        Text("\(Int(n.calories.rounded()).formatted()) cal · ").foregroundStyle(DS.Color.textSecondary)
        + Text("\(Int(n.protein.rounded()))P ").foregroundStyle(DS.Color.protein)
        + Text("\(Int(n.carbs.rounded()))C ").foregroundStyle(DS.Color.carbs)
        + Text("\(Int(n.fat.rounded()))F").foregroundStyle(DS.Color.fat)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(message)
                .foregroundStyle(DS.Color.danger)
            Button("Try Again") { Task { await send(nil) } }
                .glassButtonStyle(prominent: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Bottom

    private var bottomControls: some View {
        VStack(spacing: DS.Spacing.s) {
            if !picks.isEmpty {
                HStack(spacing: DS.Spacing.s) {
                    if canRecalculate {
                        Button(action: recalculate) {
                            Label("Recalculate", systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .glassButtonStyle(prominent: false)
                        .accessibilityLabel("Recalculate for what's left")
                    }
                    Button(action: addPicks) {
                        Text("Add \(picks.count) · \(Int(planned.calories.rounded()).formatted()) cal")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .glassButtonStyle(prominent: true)
                }
            }
            if !pendingImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.s) {
                        ForEach(Array(pendingImages.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        pendingImages.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                    }
                                    .accessibilityLabel("Remove photo")
                                    .padding(2)
                                }
                        }
                    }
                }
            }
            HStack(spacing: DS.Spacing.s) {
                Menu {
                    Button {
                        inputFocused = false
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: max(1, maxImagesPerMessage - pendingImages.count),
                        matching: .images
                    ) {
                        Label("Choose Photos", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "camera")
                        .font(.body.weight(.semibold))
                        .frame(width: 22, height: 22)
                }
                .glassButtonStyle(prominent: false)
                .buttonBorderShape(.circle)
                .disabled(pendingImages.count >= maxImagesPerMessage || isThinking)
                .accessibilityLabel("Add photos of food you have")

                TextField(pendingImages.isEmpty ? "Something else? e.g. no bars, warm" : "Add a note (optional)", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassControl(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .submitLabel(.send)
                    // A vertical field puts Return into the text instead of reliably calling onSubmit
                    // (clearing it there left the text behind), so a newline sends instead
                    .onChange(of: input) { _, newValue in
                        if newValue.contains("\n") {
                            input = newValue.replacingOccurrences(of: "\n", with: " ")
                            sendInput()
                        }
                    }
                Button(action: sendInput) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .frame(width: 22, height: 22)
                }
                .glassButtonStyle(prominent: true)
                .buttonBorderShape(.circle)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, DS.Spacing.screenEdge)
        .padding(.vertical, DS.Spacing.s)
        .animation(.snappy, value: picks.isEmpty)
        .animation(.snappy, value: canRecalculate)
        .animation(.snappy, value: pendingImages.count)
    }

    private func iconName(for item: FinishDayItem) -> String {
        switch item {
        case .usual(let food, _): return food.template.iconName ?? foodIconName(for: food.name)
        case .meal(let meal): return meal.entries.first?.iconName ?? "fork.knife"
        case .new(let name, _, _): return foodIconName(for: name)
        }
    }

    // MARK: Conversation

    private func start() async {
        guard context == nil else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let history = recentEntries.filter { $0.date < today }
        let context = FinishDayContext(
            now: Date(),
            goals: goals,
            current: current,
            eatenToday: recentEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: today) },
            foods: FinishDayHistory.usualFoods(entries: history),
            meals: FinishDayHistory.usualMeals(entries: history)
        )
        self.context = context
        turns = [FoodChatTurn(isUser: true, text: FinishDayService.contextMessage(context), jpegs: [])]
        await send(nil)
    }

    /// Clears the field now and again on the next run loop: the keyboard can write back a pending
    /// autocorrection or predictive word after the binding is cleared, leaving the sent text in place.
    private func clearInput() {
        input = ""
        DispatchQueue.main.async { input = "" }
    }

    private func sendInput() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        var images: [UIImage] = []
        var jpegs: [Data] = []
        for image in pendingImages {
            guard let jpeg = prepareImageForUpload(image) else { continue }
            images.append(image)
            jpegs.append(jpeg)
        }
        guard !text.isEmpty || !jpegs.isEmpty else { return }
        clearInput()
        pendingImages = []
        if !jpegs.isEmpty { sentPhotos = true }
        // Photos alone still need words for the assistant; the bubble shows just the photos
        let detail = jpegs.isEmpty ? nil : (text.isEmpty ? FinishDayService.photosMessage : text + "\n\n" + FinishDayService.photosMessage)
        Task { await send(text, detail: detail, images: images, jpegs: jpegs) }
    }

    private func attach(_ image: UIImage) {
        guard pendingImages.count < maxImagesPerMessage else { return }
        pendingImages.append(image)
    }

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                attach(image)
            }
        }
    }

    /// Tells the assistant what's been picked and asks for options for the rest
    private func recalculate() {
        guard canRecalculate else { return }
        recalculatedPickIDs = pickedIDs
        let detail = FinishDayService.recalculateMessage(picks: picks, current: current, goals: goals)
        Task { await send("What's left after my \(picks.count) pick\(picks.count == 1 ? "" : "s")?", detail: detail) }
    }

    /// Sends `text` (shown as the user's bubble; `detail` is what the assistant gets instead, if set).
    /// nil re-asks with the conversation as it is, for the first request or a retry.
    private func send(_ text: String?, detail: String? = nil, images: [UIImage] = [], jpegs: [Data] = []) async {
        guard let context else { return }
        if let text {
            messages.append(Message(isUser: true, text: text, images: images))
            turns.append(FoodChatTurn(isUser: true, text: detail ?? text, jpegs: jpegs))
        }
        errorMessage = nil
        isThinking = true
        do {
            let reply = try await FinishDayService.reply(to: turns, context: context)
            isThinking = false
            // The assistant's own turn, with its options summarized so a follow-up can refer to them
            let summary = reply.options.isEmpty ? "" : "\n(Options: \(reply.options.map(\.title).joined(separator: "; ")))"
            turns.append(FoodChatTurn(isUser: false, text: reply.text + summary, jpegs: []))
            messages.append(Message(isUser: false, text: reply.text, options: reply.options))
        } catch {
            isThinking = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Saving

    /// Logs the picks now. Picks from the same option with several entries become a meal group named
    /// after it; usual foods and meals are copies of the user's own entries, new items the assistant's estimate.
    private func addPicks() {
        let now = Date()
        let model = currentAIModelID()
        // Group by option, keeping the order picked
        var order: [String] = []
        var byOption: [String: [FinishDayItem]] = [:]
        for pick in picks {
            if byOption[pick.optionTitle] == nil { order.append(pick.optionTitle) }
            byOption[pick.optionTitle, default: []].append(pick.item)
        }
        for title in order {
            let items = byOption[title] ?? []
            if items.count == 1, case .meal(let meal) = items[0] {
                quickAddMealGroup(meal.entries, mealName: meal.name, into: modelContext, date: now)
                continue
            }
            let entryCount = items.reduce(0) { count, item in
                if case .meal(let meal) = item { return count + meal.entries.count }
                return count + 1
            }
            let groupID: UUID? = entryCount > 1 ? UUID() : nil
            let mealName: String? = groupID == nil ? nil : title.titleCased()
            var entries: [FoodEntry] = []
            for item in items {
                switch item {
                case .usual(let food, let servings):
                    entries.append(copy(food.template, servings: servings, groupID: groupID, mealName: mealName, date: now))
                case .meal(let meal):
                    entries += meal.entries.map { copy($0, servings: $0.servings, groupID: groupID, mealName: mealName, date: now) }
                case .new(let name, let portion, let nutrients):
                    entries.append(FoodEntry(
                        name: name.titleCased(),
                        calories: Int(nutrients.calories.rounded()),
                        proteinGrams: nutrients.protein,
                        carbsGrams: nutrients.carbs,
                        fatGrams: nutrients.fat,
                        date: now,
                        mealGroupID: groupID,
                        mealName: mealName,
                        iconName: foodIconName(for: name),
                        servingDescription: portion,
                        entrySource: sentPhotos ? .aiChatPhoto : .aiChatText,
                        aiModel: model
                    ))
                }
            }
            for (index, entry) in entries.enumerated() {
                entry.sortOrder = index
                modelContext.insert(entry)
                Task { await HealthKitService.shared.syncEntry(entry) }
            }
        }
        dismiss()
    }

    /// A new entry with the same food as `entry` (like `quickAddEntry`), in this option's meal group
    private func copy(_ entry: FoodEntry, servings: Double, groupID: UUID?, mealName: String?, date: Date) -> FoodEntry {
        FoodEntry(
            name: entry.name,
            calories: entry.calories,
            proteinGrams: entry.proteinGrams,
            carbsGrams: entry.carbsGrams,
            fatGrams: entry.fatGrams,
            date: date,
            photoData: entry.isGeneratedImage ? nil : entry.photoData,
            mealGroupID: groupID,
            mealName: mealName,
            iconName: entry.iconName ?? foodIconName(for: entry.name),
            servings: servings,
            servingDescription: entry.servingDescription,
            servingGrams: entry.servingGrams,
            barcode: entry.barcode,
            entrySource: entry.entrySource.flatMap(EntrySource.init(rawValue:)),
            aiModel: entry.aiModel
        )
    }
}

/// Pinned under the title: each goal with today's amount (solid) and the picks so far in a lighter
/// shade of the same color, so it's always clear what the picks would do.
private struct MacroTracker: View {
    let current: Nutrients
    let planned: Nutrients
    let goals: Nutrients

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            column(DS.Icon.calories, DS.Color.textPrimary, current.calories, planned.calories, goals.calories, "")
            column(DS.Icon.protein, DS.Color.protein, current.protein, planned.protein, goals.protein, "g")
            column(DS.Icon.carbs, DS.Color.carbs, current.carbs, planned.carbs, goals.carbs, "g")
            column(DS.Icon.fat, DS.Color.fat, current.fat, planned.fat, goals.fat, "g")
        }
        .padding(.horizontal, DS.Spacing.screenEdge)
        .padding(.vertical, DS.Spacing.s)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private func column(_ icon: String, _ color: Color, _ now: Double, _ add: Double, _ goal: Double, _ unit: String) -> some View {
        if goal > 0 {
            let after = now + add
            let tone = GoalTone(current: after, goal: goal)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(color)
                    Text("\(Int(after.rounded()).formatted())")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(tone == .inProgress ? DS.Color.textPrimary : tone.color(normal: color))
                        .contentTransition(.numericText())
                    Text("/\(Int(goal).formatted())\(unit)")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textTertiary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                ProjectionBar(now: now, after: after, goal: goal, color: color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.spring(duration: 0.3), value: after)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Int(after.rounded())) of \(Int(goal))\(unit)")
        }
    }
}

/// Today's amount (solid) and the picks (a lighter shade) against the goal, with the ±10% band shaded.
private struct ProjectionBar: View {
    let now: Double
    let after: Double
    let goal: Double
    let color: Color

    /// The bar spans 0–130% of the goal
    private let span = 1.3

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = { (v: Double) in CGFloat(min(v / (goal * span), 1)) * w }
            ZStack(alignment: .leading) {
                Capsule().fill(DS.Color.ringTrack)
                Rectangle()
                    .fill(DS.Color.success.opacity(0.18))
                    .frame(width: x(goal * PerformanceThresholds.onTargetHigh) - x(goal * PerformanceThresholds.onTargetLow))
                    .offset(x: x(goal * PerformanceThresholds.onTargetLow))
                Capsule().fill(color.opacity(0.35)).frame(width: x(max(after, now)))
                Capsule().fill(color).frame(width: x(now))
                Rectangle()
                    .fill(DS.Color.textPrimary.opacity(0.6))
                    .frame(width: 2)
                    .offset(x: x(goal) - 1)
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }
}
