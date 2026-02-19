import SwiftUI

// MARK: - Daily Targets (UserDefaults)

enum DailyTarget {
    static let calorieKey = "calorieTarget"
    static let proteinKey = "proteinTarget"
    static let carbsKey = "carbsTarget"
    static let fatKey = "fatTarget"

    static var calories: Int {
        get { UserDefaults.standard.integer(forKey: calorieKey) }
        set { UserDefaults.standard.set(newValue, forKey: calorieKey) }
    }
    static var protein: Int {
        get { UserDefaults.standard.integer(forKey: proteinKey) }
        set { UserDefaults.standard.set(newValue, forKey: proteinKey) }
    }
    static var carbs: Int {
        get { UserDefaults.standard.integer(forKey: carbsKey) }
        set { UserDefaults.standard.set(newValue, forKey: carbsKey) }
    }
    static var fat: Int {
        get { UserDefaults.standard.integer(forKey: fatKey) }
        set { UserDefaults.standard.set(newValue, forKey: fatKey) }
    }
}

struct SettingsView: View {
    @State private var selectedProvider = VisionProvider.selected
    @State private var apiKey = ""
    @State private var showingKey = false
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
            .navigationTitle("Settings")
            .onAppear {
                loadKeyForCurrentProvider()
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
                .onChange(of: value.wrappedValue) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: key)
                }
        }
    }
}
