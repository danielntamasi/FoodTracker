import SwiftUI
import SwiftData

enum AppTab {
    case today, history, settings
}

enum QuickAddAction {
    case photo, barcode, manual, browse
}

struct ContentView: View {
    @State private var activeTab: AppTab = .today
    @State private var showingQuickAdd = false
    @State private var showingAddEntry = false
    @State private var showingPhotoCapture = false
    @State private var showingBarcodeScanner = false
    @State private var showingBrowse = false
    @State private var pendingQuickAction: QuickAddAction?

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch activeTab {
                case .today:
                    DailySummaryView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 110)
            }

            floatingTabBar
        }
        .sheet(isPresented: $showingQuickAdd, onDismiss: {
            guard let action = pendingQuickAction else { return }
            pendingQuickAction = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                switch action {
                case .photo: showingPhotoCapture = true
                case .barcode: showingBarcodeScanner = true
                case .manual: showingAddEntry = true
                case .browse: showingBrowse = true
                }
            }
        }) {
            QuickAddSheet(selectedAction: $pendingQuickAction)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddEntry) {
            AddEntryView()
        }
        .sheet(isPresented: $showingPhotoCapture) {
            PhotoCaptureView()
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            BarcodeScannerView()
        }
        .sheet(isPresented: $showingBrowse) {
            BrowseFoodsView()
        }
    }

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "fork.knife", label: "Today", tab: .today)
            tabItem(icon: "calendar", label: "History", tab: .history)

            Button {
                showingQuickAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())

            tabItem(icon: "gearshape", label: "Settings", tab: .settings)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func tabItem(icon: String, label: String, tab: AppTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(activeTab == tab ? .body : .callout)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Quick Add Sheet

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAction: QuickAddAction?

    var body: some View {
        VStack(spacing: 12) {
            quickAddCard(icon: "camera", label: "Add with Photo") {
                selectedAction = .photo
                dismiss()
            }
            quickAddCard(icon: "barcode.viewfinder", label: "Scan Barcode") {
                selectedAction = .barcode
                dismiss()
            }
            quickAddCard(icon: "pencil", label: "Add Manually") {
                selectedAction = .manual
                dismiss()
            }
            quickAddCard(icon: "clock.arrow.circlepath", label: "Browse Recent") {
                selectedAction = .browse
                dismiss()
            }
        }
        .padding(20)
    }

    private func quickAddCard(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32)
                Text(label)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Browse Foods View

struct BrowseFoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    private var frequentFoods: [(name: String, calories: Int, protein: Double, carbs: Double, fat: Double, count: Int, iconName: String?, photoData: Data?)] {
        var groups: [String: (name: String, calories: Int, protein: Double, carbs: Double, fat: Double, count: Int, iconName: String?, photoData: Data?, latestDate: Date)] = [:]
        for entry in allEntries {
            let key = entry.name.lowercased().trimmingCharacters(in: .whitespaces)
            if key.isEmpty { continue }
            if var existing = groups[key] {
                existing.count += 1
                if entry.date > existing.latestDate {
                    existing.latestDate = entry.date
                    if entry.photoData != nil { existing.photoData = entry.photoData }
                }
                groups[key] = existing
            } else {
                groups[key] = (name: entry.name, calories: entry.calories, protein: entry.proteinGrams, carbs: entry.carbsGrams, fat: entry.fatGrams, count: 1, iconName: entry.iconName, photoData: entry.photoData, latestDate: entry.date)
            }
        }
        return Array(
            groups.values
                .sorted {
                    if $0.count != $1.count { return $0.count > $1.count }
                    return $0.latestDate > $1.latestDate
                }
                .prefix(5)
                .map { ($0.name, $0.calories, $0.protein, $0.carbs, $0.fat, $0.count, $0.iconName, $0.photoData) }
        )
    }

    private var recentFoods: [FoodEntry] {
        let calendar = Calendar.current
        var seen: Set<String> = []
        var result: [FoodEntry] = []
        for entry in allEntries {
            if calendar.isDateInToday(entry.date) { continue }
            let key = entry.name.lowercased().trimmingCharacters(in: .whitespaces)
            if key.isEmpty { continue }
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(entry)
            if result.count >= 10 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if !frequentFoods.isEmpty {
                    Section("Frequent") {
                        ForEach(Array(frequentFoods.enumerated()), id: \.offset) { _, food in
                            Button {
                                addFood(name: food.name, calories: food.calories, protein: food.protein, carbs: food.carbs, fat: food.fat, iconName: food.iconName, photoData: food.photoData)
                            } label: {
                                HStack {
                                    Image(systemName: food.iconName ?? "fork.knife")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(food.name)
                                            .font(.body)
                                        coloredMacroText(protein: food.protein, carbs: food.carbs, fat: food.fat)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(food.calories) cal")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)
                                        Text("\u{00D7}\(food.count)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                if !recentFoods.isEmpty {
                    Section("Recent") {
                        ForEach(recentFoods) { entry in
                            Button {
                                addFood(name: entry.name, calories: entry.calories, protein: entry.proteinGrams, carbs: entry.carbsGrams, fat: entry.fatGrams, iconName: entry.iconName, photoData: entry.photoData)
                            } label: {
                                HStack {
                                    Image(systemName: entry.iconName ?? "fork.knife")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name)
                                            .font(.body)
                                        coloredMacroText(protein: entry.proteinGrams, carbs: entry.carbsGrams, fat: entry.fatGrams)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    Text("\(entry.calories) cal")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                if frequentFoods.isEmpty && recentFoods.isEmpty {
                    ContentUnavailableView(
                        "No Foods Yet",
                        systemImage: "fork.knife",
                        description: Text("Foods you've added will appear here for quick access.")
                    )
                }
            }
            .navigationTitle("Browse Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addFood(name: String, calories: Int, protein: Double, carbs: Double, fat: Double, iconName: String?, photoData: Data? = nil) {
        let entry = FoodEntry(
            name: name,
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            photoData: photoData,
            iconName: iconName ?? foodIconName(for: name)
        )
        modelContext.insert(entry)
        dismiss()
    }
}
