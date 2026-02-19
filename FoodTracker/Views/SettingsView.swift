import SwiftUI

struct SettingsView: View {
    @State private var selectedProvider = VisionProvider.selected
    @State private var apiKey = ""
    @State private var showingKey = false
    @State private var savedSuccessfully = false

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
}
