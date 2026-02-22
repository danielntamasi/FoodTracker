import SwiftUI

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
    @FocusState private var isTargetFieldFocused: Bool
    @State private var selectedProvider = VisionProvider.selected
    @State private var apiKey = ""
    @State private var showingKey = false
    @State private var usdaKey = ""
    @State private var showingUSDAKey = false
    @State private var savedSuccessfully = false
    @State private var calorieTarget = DailyTarget.calories
    @State private var proteinTarget = DailyTarget.protein
    @State private var carbsTarget = DailyTarget.carbs
    @State private var fatTarget = DailyTarget.fat

    var body: some View {
        NavigationStack {
            Form {
                Section("Vision Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(VisionProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: selectedProvider) { _, newValue in
                        VisionProvider.selected = newValue
                        loadKeyForCurrentProvider()
                    }
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
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Save API Key") {
                        if KeychainService.save(apiKey: apiKey, account: selectedProvider.keychainAccount) {
                            savedSuccessfully = true
                        }
                    }
                    .disabled(apiKey.isEmpty)
                } header: {
                    Text("\(selectedProvider.rawValue) API Key")
                } footer: {
                    Text("Stored securely in the Keychain. \(selectedProvider.keyInstructions).")
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
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Save USDA Key") {
                        if KeychainService.save(apiKey: usdaKey, account: USDAService.keychainAccount) {
                            savedSuccessfully = true
                        }
                    }
                    .disabled(usdaKey.isEmpty)
                } header: {
                    Text("USDA API Key (Optional)")
                } footer: {
                    Text("Free key with 1,000 requests/hour. Sign up at fdc.nal.usda.gov/api-key-signup. Without a key, the app uses DEMO_KEY (30/hour).")
                }

                Section {
                    targetRow("Calories", value: $calorieTarget, key: DailyTarget.calorieKey)
                    targetRow("Protein (g)", value: $proteinTarget, key: DailyTarget.proteinKey)
                    targetRow("Carbs (g)", value: $carbsTarget, key: DailyTarget.carbsKey)
                    targetRow("Fat (g)", value: $fatTarget, key: DailyTarget.fatKey)
                } header: {
                    Text("Daily Targets")
                } footer: {
                    Text("Set to 0 to disable a target. Targets are shown on the Today screen.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Nutrition Data")
                        Spacer()
                        Text("USDA FoodData Central")
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
