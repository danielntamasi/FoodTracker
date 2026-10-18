import SwiftUI
import SwiftData

struct SearchFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    /// When set, saves as an IngredientItem instead of a FoodEntry (used by BuildMealView)
    var onIngredientAdded: ((IngredientItem) -> Void)?

    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showingAddManual = false
    @State private var prefillResult: USDAService.USDALookupResult?
    @State private var lookup = NutritionLookup()
    @State private var resultsVisible = false
    @State private var isSearchActive = false

    private var recentMatches: [FoodEntry] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        let queryWords = query.split(separator: " ").map(String.init)
        var seen: Set<String> = []
        var result: [FoodEntry] = []
        for entry in allEntries {
            let key = entry.name.lowercased().trimmingCharacters(in: .whitespaces)
            if key.isEmpty { continue }
            if seen.contains(key) { continue }
            let matches = queryWords.allSatisfy { key.contains($0) }
            if !matches { continue }
            seen.insert(key)
            result.append(entry)
            if result.count >= 10 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                recentFoodsSection
                usdaSection
                aiEstimateSection
                manualEntrySection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DS.Color.backgroundPrimary)
            .searchable(text: $searchText, isPresented: $isSearchActive, prompt: "Search foods")
            // Open straight into the search field with the keyboard up
            .onAppear { isSearchActive = true }
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
            .sheet(item: $prefillResult) { result in
                AddEntryView(prefill: result, onSave: { dismiss() }, onIngredientAdded: onIngredientAdded.map { callback in
                    { item in callback(item); dismiss() }
                })
            }
            .sheet(isPresented: $showingAddManual) {
                AddEntryView(onSave: { dismiss() }, onIngredientAdded: onIngredientAdded.map { callback in
                    { item in callback(item); dismiss() }
                })
            }
        }
    }

    // MARK: - Recent Foods

    @ViewBuilder
    private var recentFoodsSection: some View {
        if !recentMatches.isEmpty {
            Section("Your Foods") {
                ForEach(recentMatches) { entry in
                    Button {
                        quickAdd(entry)
                    } label: {
                        HStack(spacing: 12) {
                            FoodIconThumbnail(iconName: entry.iconName ?? "fork.knife", size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .font(.body)
                                if let desc = entry.servingDescription {
                                    Text(desc)
                                        .font(.caption2)
                                        .foregroundStyle(DS.Color.textTertiary)
                                }
                                coloredMacroText(protein: entry.totalProteinGrams, carbs: entry.totalCarbsGrams, fat: entry.totalFatGrams)
                                    .font(.caption)
                            }
                            Spacer()
                            Text("\(entry.totalCalories) cal")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    .tint(.primary)
                }
            }
        }
    }

    // MARK: - USDA Section

    @ViewBuilder
    private var usdaSection: some View {
        if lookup.isLookingUp {
            Section("USDA Database") {
                SearchSkeletonRows()
            }
        } else if !lookup.lookupResults.isEmpty {
            Section("USDA Database") {
                ForEach(Array(lookup.lookupResults.enumerated()), id: \.offset) { index, result in
                    USDAResultButton(result: result, index: index, resultsVisible: resultsVisible) {
                        prefillResult = result
                    }
                }
            }
        } else if lookup.lookupError != nil {
            Section("USDA Database") {
                SearchEmptyState()
            }
        }
    }

    // MARK: - AI Estimate

    @ViewBuilder
    private var aiEstimateSection: some View {
        if let estimate = lookup.aiEstimate {
            Section("AI Estimate") {
                AIEstimateCard(estimate: estimate) {
                    prefillResult = estimate
                }
            }
        } else if !searchText.trimmingCharacters(in: .whitespaces).isEmpty && !lookup.isLookingUp && !lookup.isEstimating {
            Section {
                Button {
                    lookup.runAIEstimate(for: searchText.trimmingCharacters(in: .whitespaces))
                } label: {
                    HStack {
                        Label("AI Estimate", systemImage: "sparkles")
                            .foregroundStyle(DS.Color.fat)
                        Spacer()
                        if lookup.isEstimating {
                            ProgressView()
                        }
                    }
                }
                .disabled(lookup.isEstimating)
            } footer: {
                Text("Use AI to estimate nutrition for prepared or complex foods.")
            }
        }
    }

    // MARK: - Manual Entry

    private var manualEntrySection: some View {
        Section {
            Button {
                showingAddManual = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.body)
                        .foregroundStyle(DS.Color.textSecondary)
                        .frame(width: 32)
                    Text("Add manually")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }
            }
        }
    }

    // MARK: - Actions

    private func quickAdd(_ entry: FoodEntry) {
        if let onIngredientAdded {
            onIngredientAdded(IngredientItem(
                name: entry.name,
                calories: entry.calories,
                proteinGrams: entry.proteinGrams,
                carbsGrams: entry.carbsGrams,
                fatGrams: entry.fatGrams,
                servings: 1.0,
                servingDescription: entry.servingDescription,
                servingGrams: entry.servingGrams
            ))
            dismiss()
            return
        }
        let newEntry = FoodEntry(
            name: entry.name,
            calories: entry.calories,
            proteinGrams: entry.proteinGrams,
            carbsGrams: entry.carbsGrams,
            fatGrams: entry.fatGrams,
            photoData: entry.isGeneratedImage ? nil : entry.photoData,
            iconName: entry.iconName ?? foodIconName(for: entry.name),
            servings: 1.0,
            servingDescription: entry.servingDescription,
            servingGrams: entry.servingGrams
        )
        modelContext.insert(newEntry)
        Task { await HealthKitService.shared.syncEntry(newEntry) }
        dismiss()
    }

    private func debouncedSearch(query: String) {
        searchTask?.cancel()
        lookup.aiEstimate = nil
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            lookup.lookupResults = []
            lookup.lookupError = nil
            lookup.isLookingUp = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            lookup.isLookingUp = true
            do {
                let results = try await USDAService.shared.lookupFoodOptions(for: trimmed)
                guard !Task.isCancelled else { return }
                lookup.lookupResults = results
                lookup.lookupError = results.isEmpty ? "No USDA results for \"\(trimmed)\"." : nil
                if !results.isEmpty {
                    resultsVisible = false
                    withAnimation { resultsVisible = true }
                }
            } catch {
                guard !Task.isCancelled else { return }
                lookup.lookupError = error.localizedDescription
                lookup.lookupResults = []
            }
            lookup.isLookingUp = false
        }
    }
}

// MARK: - Extracted Subviews

private struct SearchSkeletonRows: View {
    var body: some View {
        ForEach(0..<3, id: \.self) { _ in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DS.Color.backgroundSubtle)
                        .frame(width: 140, height: 14)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DS.Color.backgroundElevated)
                        .frame(width: 80, height: 10)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DS.Color.backgroundSubtle)
                        .frame(width: 60, height: 14)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DS.Color.backgroundElevated)
                        .frame(width: 90, height: 10)
                }
            }
            .redacted(reason: .placeholder)
        }
        .phaseAnimator([false, true]) { content, phase in
            content.opacity(phase ? 0.4 : 1.0)
        } animation: { _ in
            .easeInOut(duration: 0.8)
        }
    }
}

private struct USDAResultButton: View {
    let result: USDAService.USDALookupResult
    let index: Int
    let resultsVisible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    let scaled = result.perServing
                    Text("\(Int(scaled.calories)) cal")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.textSecondary)
                    coloredMacroText(protein: scaled.protein, carbs: scaled.carbs, fat: scaled.fat)
                        .font(.caption)
                }
            }
        }
        .tint(.primary)
        .opacity(resultsVisible ? 1 : 0)
        .offset(y: resultsVisible ? 0 : 10)
        .animation(
            .spring(duration: 0.35, bounce: 0.15).delay(Double(index) * 0.05),
            value: resultsVisible
        )
    }
}

private struct AIEstimateCard: View {
    let estimate: USDAService.USDALookupResult
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(DS.Color.fat)
                        Text(estimate.description.titleCased())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(DS.Color.textPrimary)
                    }
                    if let servingDesc = estimate.servingDescription {
                        let gramsNote = estimate.servingGrams.map { " (\(Int($0))g)" } ?? ""
                        Text("\(servingDesc)\(gramsNote)")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    let scaled = estimate.perServing
                    Text("\(Int(scaled.calories)) cal")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.fat)
                    coloredMacroText(protein: scaled.protein, carbs: scaled.carbs, fat: scaled.fat)
                        .font(.caption)
                }
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DS.Color.fat)
                    .imageScale(.large)
            }
        }
        .tint(.primary)
    }
}

private struct SearchEmptyState: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(DS.Color.textSecondary)
                .symbolEffect(.pulse)
            VStack(alignment: .leading, spacing: 2) {
                Text("No results found")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Try a different search term or use AI Estimate below.")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
