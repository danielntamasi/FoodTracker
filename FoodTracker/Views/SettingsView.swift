import SwiftUI
import SwiftData

// MARK: - Daily Targets (UserDefaults)

enum DailyTarget {
    static let calorieKey = "calorieTarget"
    static let proteinKey = "proteinTarget"
    static let carbsKey = "carbsTarget"
    static let fatKey = "fatTarget"

    static var calories: Int {
        get { sharedDefaults.integer(forKey: calorieKey) }
        set { sharedDefaults.set(newValue, forKey: calorieKey) }
    }
    static var protein: Int {
        get { sharedDefaults.integer(forKey: proteinKey) }
        set { sharedDefaults.set(newValue, forKey: proteinKey) }
    }
    static var carbs: Int {
        get { sharedDefaults.integer(forKey: carbsKey) }
        set { sharedDefaults.set(newValue, forKey: carbsKey) }
    }
    static var fat: Int {
        get { sharedDefaults.integer(forKey: fatKey) }
        set { sharedDefaults.set(newValue, forKey: fatKey) }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [FoodEntry]
    @FocusState private var isTargetFieldFocused: Bool
    @State private var selectedProvider = VisionProvider.selected
    @State private var selectedClaudeModel = ClaudeModel.selected
    @State private var claudeModels = ClaudeModel.available
    @State private var apiKey = ""
    @State private var showingKey = false
    @State private var usdaKey = ""
    @State private var showingUSDAKey = false
    @State private var offUserID = ""
    @State private var offPassword = ""
    @State private var showingOFFPassword = false
    @State private var savedSuccessfully = false
    @State private var calorieTarget = DailyTarget.calories
    @State private var proteinTarget = DailyTarget.protein
    @State private var carbsTarget = DailyTarget.carbs
    @State private var fatTarget = DailyTarget.fat
    @State private var healthSyncEnabled = HealthKitService.isEnabled
    @State private var imagePlaygroundEnabled = ImagePlaygroundService.isEnabled
    @AppStorage(AppConstants.Defaults.appearanceMode, store: sharedDefaults)
    private var appearanceMode: String = "system"
    @State private var showImportPicker = false
    @State private var isImporting = false
    @State private var importSummary: String?
    @State private var exportFile: ExportFile?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("APPEARANCE")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                }

                Section {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(VisionProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: selectedProvider) { _, newValue in
                        VisionProvider.selected = newValue
                        loadKeyForCurrentProvider()
                    }
                    if selectedProvider == .claude {
                        Picker("Model", selection: $selectedClaudeModel) {
                            ForEach(claudeModels) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                        .onChange(of: selectedClaudeModel) { _, newValue in
                            ClaudeModel.selected = newValue
                        }
                        .task {
                            await refreshClaudeModels()
                        }
                    }
                } header: {
                    Text("VISION PROVIDER")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                }

                Section {
                    HStack {
                        if showingKey {
                            TextField("API Key", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("API Key", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Button {
                            showingKey.toggle()
                        } label: {
                            Image(systemName: showingKey ? "eye.slash" : "eye")
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Save API Key") {
                        if KeychainService.save(apiKey: apiKey, account: selectedProvider.keychainAccount) {
                            savedSuccessfully = true
                            if selectedProvider == .claude {
                                Task { await refreshClaudeModels() }
                            }
                        }
                    }
                    .foregroundStyle(DS.Color.protein)
                    .disabled(apiKey.isEmpty)
                } header: {
                    Text("\(selectedProvider.rawValue) API Key".uppercased())
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                } footer: {
                    Text("Stored securely in the Keychain. \(selectedProvider.keyInstructions).")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }

                Section {
                    HStack {
                        if showingUSDAKey {
                            TextField("API Key", text: $usdaKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("API Key", text: $usdaKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Button {
                            showingUSDAKey.toggle()
                        } label: {
                            Image(systemName: showingUSDAKey ? "eye.slash" : "eye")
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Save USDA Key") {
                        if KeychainService.save(apiKey: usdaKey, account: USDAService.keychainAccount) {
                            Task { await USDAService.shared.invalidateAPIKeyCache() }
                            savedSuccessfully = true
                        }
                    }
                    .foregroundStyle(DS.Color.protein)
                    .disabled(usdaKey.isEmpty)
                } header: {
                    Text("USDA API KEY (OPTIONAL)")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                } footer: {
                    Text("Free key with 1,000 requests/hour. Sign up at fdc.nal.usda.gov/api-key-signup. Without a key, the app uses DEMO_KEY (30/hour).")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }

                Section {
                    TextField("Username", text: $offUserID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        if showingOFFPassword {
                            TextField("Password", text: $offPassword)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Password", text: $offPassword)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Button {
                            showingOFFPassword.toggle()
                        } label: {
                            Image(systemName: showingOFFPassword ? "eye.slash" : "eye")
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Save OFF Credentials") {
                        let u = KeychainService.save(apiKey: offUserID, account: OpenFoodFactsService.keychainAccountUserID)
                        let p = KeychainService.save(apiKey: offPassword, account: OpenFoodFactsService.keychainAccountPassword)
                        if u && p { savedSuccessfully = true }
                    }
                    .foregroundStyle(DS.Color.protein)
                    .disabled(offUserID.isEmpty || offPassword.isEmpty)
                } header: {
                    Text("OPENFOODFACTS ACCOUNT (OPTIONAL)")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                } footer: {
                    Text("When you correct nutrition data on a scanned product, the app can submit corrections to OpenFoodFacts. Register free at world.openfoodfacts.org.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }

                Section {
                    targetRow("Calories", value: $calorieTarget, key: DailyTarget.calorieKey)
                    targetRow("Protein (g)", value: $proteinTarget, key: DailyTarget.proteinKey)
                    targetRow("Carbs (g)", value: $carbsTarget, key: DailyTarget.carbsKey)
                    targetRow("Fat (g)", value: $fatTarget, key: DailyTarget.fatKey)
                } header: {
                    Text("DAILY TARGETS")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                } footer: {
                    Text("Set to 0 to disable a target. Targets are shown on the Today screen.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }

                Section {
                    Toggle("Sync to Apple Health", isOn: $healthSyncEnabled)
                        .onChange(of: healthSyncEnabled) { _, newValue in
                            HealthKitService.isEnabled = newValue
                            if newValue {
                                let entries = allEntries
                                Task {
                                    let authorized = await HealthKitService.shared.requestAuthorization()
                                    if authorized {
                                        await HealthKitService.shared.syncAllEntries(entries)
                                    } else {
                                        healthSyncEnabled = false
                                        HealthKitService.isEnabled = false
                                    }
                                }
                            }
                        }
                } header: {
                    Text("APPLE HEALTH")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                } footer: {
                    Text("When enabled, food entries are written to Apple Health as nutrition data.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }

                if ImagePlaygroundService.isAvailable {
                    Section {
                        Toggle("Generate food images", isOn: $imagePlaygroundEnabled)
                            .onChange(of: imagePlaygroundEnabled) { _, newValue in
                                ImagePlaygroundService.isEnabled = newValue
                            }
                    } header: {
                        Text("IMAGE PLAYGROUND")
                            .font(DS.Typography.labelS)
                            .foregroundStyle(DS.Color.textTertiary)
                            .tracking(0.8)
                    } footer: {
                        Text("Automatically generate food images for entries without photos using Apple Intelligence.")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                }

                accuracySection

                Section {
                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import Food Entries (CSV)", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        exportEntries()
                    } label: {
                        Label("Export Food Entries (CSV)", systemImage: "square.and.arrow.up")
                    }
                    if let importSummary {
                        Text(importSummary)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.success)
                    }
                } header: {
                    Text("DATA")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                } footer: {
                    Text("Import food entries from a CSV file. Expected columns: Name, Calories, Protein, Fat, Carbs. Optional: Date, Serving Size. Export writes your whole log in the same format.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }

                Section {
                    Button {
                        FeedbackPresenter.present(context: FeedbackService.makeContext(screenshot: nil, modelContext: modelContext))
                    } label: {
                        Label("Send Feedback", systemImage: "bubble.left.and.text.bubble.right")
                    }
                } header: {
                    Text("FEEDBACK")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                } footer: {
                    Text("Report a problem or suggest a feature. Tip: shake your phone on any screen to report what's on it, with a screenshot.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    HStack {
                        Text("Nutrition Data")
                        Spacer()
                        Text("USDA FoodData Central + FNDDS")
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                } header: {
                    Text("ABOUT")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                }
            }
            .contentMargins(.bottom, 88, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background(DS.Color.backgroundPrimary)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isTargetFieldFocused = false }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadKeyForCurrentProvider()
                usdaKey = KeychainService.load(account: USDAService.keychainAccount) ?? ""
                offUserID = KeychainService.load(account: OpenFoodFactsService.keychainAccountUserID) ?? ""
                offPassword = KeychainService.load(account: OpenFoodFactsService.keychainAccountPassword) ?? ""
            }
            .alert("API Key Saved", isPresented: $savedSuccessfully) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your API key has been securely saved.")
            }
            .sheet(item: $exportFile) { file in
                ShareSheet(activityItems: [file.url])
            }
            .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url):
                    importCSV(from: url)
                case .failure(let error):
                    importSummary = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func exportEntries() {
        let entries = (try? modelContext.fetch(FetchDescriptor<FoodEntry>())) ?? []
        guard !entries.isEmpty else {
            importSummary = "Nothing to export yet"
            return
        }
        if let url = CSVImportService.exportCSV(entries) {
            exportFile = ExportFile(url: url)
        } else {
            importSummary = "Export failed"
        }
    }

    private func importCSV(from url: URL) {
        isImporting = true
        importSummary = nil
        Task {
            do {
                let parsed = try CSVImportService.parse(csvURL: url)
                let count = CSVImportService.importEntries(parsed.entries, into: modelContext)
                importSummary = "Imported \(count) entries" + (parsed.skippedRows > 0 ? " (\(parsed.skippedRows) skipped)" : "")
            } catch {
                importSummary = "Failed: \(error.localizedDescription)"
            }
            isImporting = false
        }
    }

    private func refreshClaudeModels() async {
        if let models = await ClaudeModel.refreshAvailable() {
            claudeModels = models
        }
    }

    private func loadKeyForCurrentProvider() {
        apiKey = KeychainService.load(account: selectedProvider.keychainAccount) ?? ""
        showingKey = false
    }

    @ViewBuilder
    private var accuracySection: some View {
        Section {
            NavigationLink {
                AccuracyDetailView()
            } label: {
                HStack {
                    Label("Estimation Accuracy", systemImage: "chart.line.uptrend.xyaxis")
                    Spacer()
                    Text(accuracySummaryText)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
        } header: {
            Text("ACCURACY")
                .font(DS.Typography.labelS)
                .foregroundStyle(DS.Color.textTertiary)
                .tracking(0.8)
        }
    }

    private var accuracySummaryText: String {
        // Synchronous placeholder — actual data loaded in detail view
        "View Details"
    }

    @ViewBuilder
    private func targetRow(_ label: String, value: Binding<Int>, key: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 80)
                .focused($isTargetFieldFocused)
                .onChange(of: value.wrappedValue) { _, newValue in
                    sharedDefaults.set(newValue, forKey: key)
                }
        }
    }
}

// MARK: - Accuracy Detail View

private struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

struct AccuracyDetailView: View {
    @State private var summary: AccuracyTracker.AccuracySummary?
    @State private var recentCorrections: [AccuracyTracker.CorrectionRecord] = []
    @State private var showClearAlert = false
    @State private var exportURL: URL?

    var body: some View {
        List {
            if let summary, summary.totalCorrections > 0 {
                Section {
                    HStack {
                        Text("Total Corrections")
                        Spacer()
                        Text("\(summary.totalCorrections)")
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    HStack {
                        Text("Avg Calorie Error")
                        Spacer()
                        Text(String(format: "%+.0f cal (%.0f%%)", summary.averageCalorieError, summary.averageCalorieErrorPercent))
                            .foregroundStyle(abs(summary.averageCalorieErrorPercent) > 15 ? DS.Color.danger : DS.Color.textSecondary)
                    }
                    HStack {
                        Text("Systematic Bias")
                        Spacer()
                        Text(summary.systematicBias.capitalized)
                            .foregroundStyle(summary.systematicBias == "balanced" ? DS.Color.success : DS.Color.carbs)
                    }
                } header: {
                    Text("OVERVIEW")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                }

                if !summary.bySource.isEmpty {
                    Section {
                        ForEach(summary.bySource) { stats in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stats.label)
                                    Text("\(stats.count) correction\(stats.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(DS.Color.textSecondary)
                                }
                                Spacer()
                                Text(String(format: "%+.0f%%", stats.averageCalorieErrorPercent))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(abs(stats.averageCalorieErrorPercent) > 15 ? DS.Color.danger : DS.Color.textSecondary)
                            }
                        }
                    } header: {
                        Text("BY SOURCE")
                            .font(DS.Typography.labelS)
                            .foregroundStyle(DS.Color.textTertiary)
                            .tracking(0.8)
                    } footer: {
                        Text("Average calorie change from the AI's estimate to what you corrected it to. Negative means the AI guessed too high.")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                }

                if !summary.mostCorrectedFoods.isEmpty {
                    Section {
                        ForEach(summary.mostCorrectedFoods, id: \.name) { food in
                            HStack {
                                Text(food.name.capitalized)
                                Spacer()
                                Text("\(food.count) corrections")
                                    .font(.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                        }
                    } header: {
                        Text("MOST CORRECTED FOODS")
                            .font(DS.Typography.labelS)
                            .foregroundStyle(DS.Color.textTertiary)
                            .tracking(0.8)
                    }
                }

                if !recentCorrections.isEmpty {
                    Section {
                        ForEach(recentCorrections) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(record.foodName.capitalized)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(record.date, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(DS.Color.textTertiary)
                                }
                                Text(record.sourceLabel)
                                    .font(.caption2)
                                    .foregroundStyle(DS.Color.textTertiary)
                                HStack(spacing: 12) {
                                    Text("\(record.originalCalories) → \(record.correctedCalories) cal")
                                        .font(.caption)
                                        .foregroundStyle(record.calorieDelta > 0 ? DS.Color.danger : DS.Color.protein)
                                    Text(String(format: "%+.0f%%", record.calorieErrorPercent))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(abs(record.calorieErrorPercent) > 20 ? DS.Color.danger : DS.Color.textSecondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("RECENT CORRECTIONS")
                            .font(DS.Typography.labelS)
                            .foregroundStyle(DS.Color.textTertiary)
                            .tracking(0.8)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showClearAlert = true
                    } label: {
                        Text("Clear Correction History")
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No Corrections Yet", systemImage: "checkmark.circle")
                } description: {
                    Text("When you correct the AI, in the AI Chat before logging or by editing an entry afterwards, it's tracked here to show how far off its estimates are.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Color.backgroundPrimary)
        .navigationTitle("Estimation Accuracy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let exportURL {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: exportURL) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            summary = await AccuracyTracker.shared.summary()
            recentCorrections = await AccuracyTracker.shared.recentCorrections()
            exportURL = await AccuracyTracker.shared.exportCSV()
        }
        .alert("Clear History?", isPresented: $showClearAlert) {
            Button("Clear", role: .destructive) {
                Task {
                    await AccuracyTracker.shared.clearHistory()
                    summary = await AccuracyTracker.shared.summary()
                    recentCorrections = []
                    exportURL = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all correction history. This action cannot be undone.")
        }
    }
}
