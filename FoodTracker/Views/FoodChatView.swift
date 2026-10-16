import SwiftUI
import SwiftData
import PhotosUI

struct FoodChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [FoodChatMessage] = []
    @State private var draft = ""
    @State private var pendingImages: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var cameraImage: UIImage?
    @State private var showingCamera = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var composerFocused: Bool

    private let bottomAnchor = "chat-bottom"
    private let maxImagesPerMessage = 4

    private var canSend: Bool {
        !isSending && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingImages.isEmpty)
    }

    /// Only the newest proposal can be logged; older ones are shown dimmed for context.
    private var latestProposalID: UUID? {
        messages.last { $0.foodLog != nil }?.id
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.m) {
                        if messages.isEmpty {
                            emptyState
                        }

                        ForEach(messages) { message in
                            messageRow(message)
                        }

                        if isSending {
                            typingIndicator
                        }

                        if let errorMessage {
                            errorRow(errorMessage)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchor)
                    }
                    .padding(.horizontal, DS.Spacing.m)
                    .padding(.top, DS.Spacing.m)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { scrollToBottom(proxy) }
                .onChange(of: isSending) { scrollToBottom(proxy) }
                .onChange(of: errorMessage) { scrollToBottom(proxy) }
            }
            .background(DS.Color.backgroundPrimary)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .navigationTitle("Log with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .interactiveDismissDisabled(!messages.isEmpty)
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
    }

    // MARK: - Messages

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.s) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(DS.Color.protein)
            Text("What did you eat?")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Color.textPrimary)
            Text("Send a photo, describe it, or both. We'll work out the details together, then you log it when it looks right.")
                .font(DS.Typography.subhead)
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.xxl)
    }

    @ViewBuilder
    private func messageRow(_ message: FoodChatMessage) -> some View {
        let isUser = message.role == .user

        VStack(alignment: isUser ? .trailing : .leading, spacing: DS.Spacing.s) {
            if !message.images.isEmpty {
                HStack(spacing: DS.Spacing.s) {
                    ForEach(Array(message.images.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
                    }
                }
            }

            if !message.text.isEmpty {
                Text(message.text)
                    .font(DS.Typography.subhead)
                    .foregroundStyle(isUser ? .white : DS.Color.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                            .fill(isUser ? DS.Color.protein : DS.Color.backgroundSecondary)
                    )
                    .textSelection(.enabled)
            }

            if let foodLog = message.foodLog {
                proposalCard(foodLog, isLatest: message.id == latestProposalID)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(isUser ? .leading : .trailing, DS.Spacing.xl)
    }

    private func proposalCard(_ foodLog: ChatFoodLog, isLatest: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            if let mealName = foodLog.meal_name, !mealName.isEmpty, foodLog.items.count > 1 {
                Text(mealName.titleCased())
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Color.textPrimary)
            }

            ForEach(Array(foodLog.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name.titleCased())
                            .font(DS.Typography.labelL)
                            .foregroundStyle(DS.Color.textPrimary)
                        if let portion = portionText(for: item) {
                            Text(portion)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    Spacer()
                    Text("\(Int(item.calories.rounded())) cal")
                        .font(DS.Typography.numberM)
                        .foregroundStyle(DS.Color.textPrimary)
                }
            }

            Divider()

            HStack {
                Text("\(foodLog.totalCalories) cal")
                    .font(DS.Typography.numberL)
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer()
                HStack(spacing: DS.Spacing.s) {
                    Text("\(formatMacro(foodLog.totalProtein))g P").foregroundStyle(DS.Color.protein)
                    Text("\(formatMacro(foodLog.totalCarbs))g C").foregroundStyle(DS.Color.carbs)
                    Text("\(formatMacro(foodLog.totalFat))g F").foregroundStyle(DS.Color.fat)
                }
                .font(DS.Typography.labelM)
            }

            if isLatest {
                Button {
                    save(foodLog)
                } label: {
                    Label("Log it", systemImage: "checkmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DS.Gradient.plusButton)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(isSending)
                .padding(.top, DS.Spacing.xs)
            }
        }
        .padding(DS.Spacing.m)
        .appCard()
        .opacity(isLatest ? 1 : 0.5)
    }

    private func portionText(for item: ChatFoodItem) -> String? {
        let portion = item.portion?.trimmingCharacters(in: .whitespaces) ?? ""
        let grams = item.portion_grams.map { "\(Int($0.rounded()))g" }
        switch (portion.isEmpty, grams) {
        case (false, let grams?): return "\(portion) (\(grams))"
        case (false, nil): return portion
        case (true, let grams?): return grams
        case (true, nil): return nil
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: DS.Spacing.s) {
            ProgressView()
            Text("Thinking...")
                .font(DS.Typography.subhead)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorRow(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(DS.Typography.subhead)
                .foregroundStyle(DS.Color.danger)
            Button("Try Again") {
                Task { await requestReply() }
            }
            .font(DS.Typography.labelL)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.m)
        .appCardHighlight(DS.Color.danger)
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: DS.Spacing.s) {
            if !pendingImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.s) {
                        ForEach(Array(pendingImages.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
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

            HStack(alignment: .bottom, spacing: DS.Spacing.s) {
                Button {
                    composerFocused = false
                    showingCamera = true
                } label: {
                    Image(systemName: "camera")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Take photo")
                .disabled(pendingImages.count >= maxImagesPerMessage)

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: max(1, maxImagesPerMessage - pendingImages.count),
                    matching: .images
                ) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Choose photos")
                .disabled(pendingImages.count >= maxImagesPerMessage)

                TextField("Describe your food...", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .font(DS.Typography.subhead)
                    .textInputAutocapitalization(.sentences)
                    .focused($composerFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                            .fill(DS.Color.backgroundSubtle)
                    )

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .accessibilityLabel("Send")
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
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

    private func send() {
        guard canSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)

        var images: [UIImage] = []
        var jpegs: [Data] = []
        for image in pendingImages {
            guard let jpeg = prepareImageForUpload(image) else { continue }
            images.append(image)
            jpegs.append(jpeg)
        }
        guard !text.isEmpty || !jpegs.isEmpty else {
            errorMessage = FoodAnalysisError.invalidImage.localizedDescription
            return
        }

        messages.append(FoodChatMessage(role: .user, text: text, rawText: text, images: images, jpegs: jpegs))
        draft = ""
        pendingImages = []
        Task { await requestReply() }
    }

    private func requestReply() async {
        guard !isSending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        let turns = messages.map {
            FoodChatTurn(isUser: $0.role == .user, text: $0.rawText, jpegs: $0.jpegs)
        }
        do {
            let raw = try await FoodChatService.reply(to: turns)
            let parsed = FoodChatService.parseReply(raw)
            messages.append(FoodChatMessage(role: .assistant, text: parsed.text, rawText: raw, foodLog: parsed.foodLog))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ foodLog: ChatFoodLog) {
        let items = foodLog.items.filter {
            isValidNutrition(calories: Int($0.calories.rounded()), protein: $0.protein_grams, carbs: $0.carbs_grams, fat: $0.fat_grams)
        }
        guard !items.isEmpty else {
            errorMessage = "That estimate has invalid values. Ask the assistant to correct it."
            return
        }

        // Several items are saved as one meal group, matching the photo analysis flow.
        let mealGroupID: UUID? = items.count > 1 ? UUID() : nil
        let trimmedMealName = foodLog.meal_name?.trimmingCharacters(in: .whitespaces) ?? ""
        let mealName: String? = mealGroupID == nil ? nil : (trimmedMealName.isEmpty ? "Meal" : trimmedMealName.titleCased())
        let photoData = messages.last { !$0.jpegs.isEmpty }?.jpegs.first
        let source: EntrySource = messages.contains { !$0.jpegs.isEmpty } ? .aiChatPhoto : .aiChatText
        let model = currentAIModelID()
        recordInChatCorrections(final: items, source: source, model: model)

        for (index, item) in items.enumerated() {
            let portion = item.portion?.trimmingCharacters(in: .whitespaces) ?? ""
            let entry = FoodEntry(
                name: item.name.titleCased(),
                calories: Int(item.calories.rounded()),
                proteinGrams: item.protein_grams,
                carbsGrams: item.carbs_grams,
                fatGrams: item.fat_grams,
                // Only store the photo on the first entry to avoid duplicate blob storage
                photoData: index == 0 ? photoData : nil,
                mealGroupID: mealGroupID,
                mealName: mealName,
                iconName: foodIconName(for: item.name),
                servingDescription: portion.isEmpty ? nil : portion,
                servingGrams: item.portion_grams,
                entrySource: source,
                aiModel: model
            )
            modelContext.insert(entry)
            Task { await HealthKitService.shared.syncEntry(entry) }
        }
        dismiss()
    }

    /// Records how the assistant's first estimate for each item differs from what was logged,
    /// i.e. what the conversation corrected. Items are matched by name; added or renamed items are skipped.
    private func recordInChatCorrections(final items: [ChatFoodItem], source: EntrySource, model: String) {
        guard let first = messages.first(where: { $0.foodLog != nil })?.foodLog else { return }
        let initial = Dictionary(first.items.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

        for item in items {
            guard let original = initial[item.name.lowercased()] else { continue }
            Task {
                await AccuracyTracker.shared.recordCorrection(
                    foodName: item.name,
                    source: .estimate,
                    originalCalories: Int(original.calories.rounded()),
                    originalProtein: original.protein_grams,
                    originalCarbs: original.carbs_grams,
                    originalFat: original.fat_grams,
                    correctedCalories: Int(item.calories.rounded()),
                    correctedProtein: item.protein_grams,
                    correctedCarbs: item.carbs_grams,
                    correctedFat: item.fat_grams,
                    entrySource: source,
                    model: model,
                    stage: "chat"
                )
            }
        }
    }
}
