import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var showingKey = false
    @State private var savedSuccessfully = false

    var body: some View {
        NavigationStack {
            Form {
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
                        if KeychainService.save(apiKey: apiKey) {
                            savedSuccessfully = true
                        }
                    }
                    .disabled(apiKey.isEmpty)
                } header: {
                    Text("Gemini API Key")
                } footer: {
                    Text("Your API key is stored securely in the Keychain. Get a free key from aistudio.google.com.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Vision")
                        Spacer()
                        Text("Gemini 2.0 Flash")
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
                if let key = KeychainService.load() {
                    apiKey = key
                }
            }
            .alert("API Key Saved", isPresented: $savedSuccessfully) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your Gemini API key has been securely saved to the Keychain.")
            }
        }
    }
}
