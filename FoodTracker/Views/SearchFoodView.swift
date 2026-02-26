import SwiftUI
import SwiftData

struct SearchFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    @State private var searchText = ""
    @State private var lookupResults: [USDAService.USDALookupResult] = []
    @State private var selectedResultIndex: Int?
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var showingAddEntry = false
    @State private var prefillResult: USDAService.USDALookupResult?
    @State private var isEstimating = false
    @State private var aiEstimate: USDAService.USDALookupResult?

    private var recentMatches: [FoodEntry] {
        let calendar = Calendar.current
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        var seen: Set<String> = []
        var result: [FoodEntry] = []
        for entry in allEntries {
            if calendar.isDateInToday(entry.date) { continue }
            let key = entry.name.lowercased().trimmingCharacters(in: .whitespaces)
            if key.isEmpty { continue }
            if seen.contains(key) { continue }
            if !query.isEmpty && !key.contains(query) { continue }
            seen.insert(key)
            result.append(entry)
            if result.count >= 10 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if !recentMatches.isEmpty {
                    Section("Recent Foods") {
                        ForEach(recentMatches) { entry in
                            Button {
                                quickAdd(entry)
                            } label: {
                                HStack {
                                    Image(systemName: entry.iconName ?? "fork.knife")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name)
                                            .font(.body)
                                        coloredMacroText(protein: entry.totalProteinGrams, carbs: entry.totalCarbsGrams, fat: entry.totalFatGrams)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    Text("\(entry.totalCalories) cal")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                if isSearching {
                    Section("USDA Database") {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if !lookupResults.isEmpty {
                    Section("USDA Database") {
                        ForEach(Array(lookupResults.enumerated()), id: \.offset) { index, result in
                            Button {
                                prefillResult = result
                                showingAddEntry = true
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.description.titleCased())
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        if let servingDesc = result.servingDescription {
                                            let gramsNote = result.servingGrams.map { " (\(Int($0))g)" } ?? ""
                                            Text("\(servingDesc)\(gramsNote)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        let scaled = result.perServing
                                        Text("\(Int(scaled.calories)) cal")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)
                                        coloredMacroText(protein: scaled.protein, carbs: scaled.carbs, fat: scaled.fat)
                                            .font(.caption)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    }
                } else if let error = searchError {
                    Section("USDA Database") {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let estimate = aiEstimate {
                    Section("AI Estimate") {
                        Button {
                            prefillResult = estimate
                            showingAddEntry = true
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(estimate.description.titleCased())
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    if let servingDesc = estimate.servingDescription {
                                        let gramsNote = estimate.servingGrams.map { " (\(Int($0))g)" } ?? ""
                                        Text("\(servingDesc)\(gramsNote)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    let scaled = estimate.perServing
                                    Text("\(Int(scaled.calories)) cal")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    coloredMacroText(protein: scaled.protein, carbs: scaled.carbs, fat: scaled.fat)
                                        .font(.caption)
                                }
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .imageScale(.large)
                            }
                        }
                        .tint(.primary)
                    }
                } else if !searchText.trimmingCharacters(in: .whitespaces).isEmpty && !isSearching && !isEstimating {
                    Section {
                        Button {
                            runAIEstimate()
                        } label: {
                            HStack {
                                Label("AI Estimate", systemImage: "brain")
                                Spacer()
                                if isEstimating {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isEstimating)
                    } footer: {
                        Text("Use AI to estimate nutrition for prepared or complex foods.")
                    }
                }

                Section {
                    Button {
                        prefillResult = nil
                        showingAddEntry = true
                    } label: {
                        Label("Add manually", systemImage: "pencil")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .onChange(of: searchText) { _, newValue in
                debouncedSearch(query: newValue)
            }
            .navigationTitle("Search Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView(prefill: prefillResult)
            }
        }
    }

    private func quickAdd(_ entry: FoodEntry) {
        let newEntry = FoodEntry(
            name: entry.name,
            calories: entry.calories,
            proteinGrams: entry.proteinGrams,
            carbsGrams: entry.carbsGrams,
            fatGrams: entry.fatGrams,
            photoData: entry.photoData,
            iconName: entry.iconName ?? foodIconName(for: entry.name),
            servings: 1.0,
            servingDescription: entry.servingDescription,
            servingGrams: entry.servingGrams
        )
        modelContext.insert(newEntry)
        dismiss()
    }

    private func debouncedSearch(query: String) {
        searchTask?.cancel()
        aiEstimate = nil
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            lookupResults = []
            searchError = nil
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                let results = try await USDAService.shared.lookupFoodOptions(for: trimmed)
                guard !Task.isCancelled else { return }
                lookupResults = results
                searchError = results.isEmpty ? "No USDA results for \"\(trimmed)\"." : nil
            } catch {
                guard !Task.isCancelled else { return }
                searchError = error.localizedDescription
                lookupResults = []
            }
            isSearching = false
        }
    }

    private func runAIEstimate() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isEstimating = true

        Task {
            do {
                let result = try await FoodAnalysisPipeline.estimateNutrition(for: query)
                withAnimation {
                    aiEstimate = result
                }
            } catch {
                searchError = error.localizedDescription
            }
            isEstimating = false
        }
    }
}
