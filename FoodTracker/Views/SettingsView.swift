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
    @Query private var allEntries: [FoodEntry]
    @FocusState private var isTargetFieldFocused: Bool
    @State private var selectedProvider = VisionProvider.selected
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

    var body: some View {
        NavigationStack {
            Form {
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
                        Text("USDA FoodData Central")
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                } header: {
                    Text("ABOUT")
                        .font(DS.Typography.labelS)
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                }
            }
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
        }
    }

    private func loadKeyForCurrentProvider() {
        apiKey = KeychainService.load(account: selectedProvider.keychainAccount) ?? ""
        showingKey = false
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
