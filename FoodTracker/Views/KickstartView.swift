import SwiftUI
import SwiftData

/// A greeting plus the foods and meals usually had by this time that aren't logged yet, ready to add.
/// Whatever isn't added (unticked, "Not Today", or swiped away) isn't offered again today.
struct KickstartView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let suggestions: [KickstartSuggestion]
    /// Off for the Settings preview, which shouldn't use up today's suggestions
    var remembersDismissals = true
    @State private var selected: Set<String>
    @State private var now = Date()
    @State private var didAdd = false

    init(suggestions: [KickstartSuggestion], remembersDismissals: Bool = true) {
        self.suggestions = suggestions
        self.remembersDismissals = remembersDismissals
        _selected = State(initialValue: Set(suggestions.map(\.id)))
    }

    private var greeting: (text: String, icon: String, colors: [Color]) {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12: return ("Good morning", "sunrise.fill", [DS.Color.carbs, DS.Color.danger])
        case 12..<17: return ("Good afternoon", "sun.max.fill", [DS.Color.carbs, DS.Color.carbs.opacity(0.7)])
        default: return ("Good evening", "moon.stars.fill", [DS.Color.fat, DS.Color.protein])
        }
    }

    private var selectedCalories: Int {
        suggestions.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    ForEach(suggestions) { suggestion in
                        row(suggestion)
                    }
                } header: {
                    Text("Usually by now")
                } footer: {
                    Text("Foods and meals you've logged on most days since you started having them (looking back four weeks), usually around this time or earlier. Anything you don't add won't be offered again today.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Color.backgroundPrimary)
            .contentMargins(.top, 0, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .bottomBar {
                VStack(spacing: DS.Spacing.xs) {
                    Button(action: addSelected) {
                        Text(selected.isEmpty ? "Add to Today" : "Add \(selected.count) to Today · \(selectedCalories.formatted()) cal")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .glassButtonStyle(prominent: true)
                    .disabled(selected.isEmpty)
                    Button("Not Today") { dismiss() }
                        .font(.body.weight(.medium))
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding(.vertical, DS.Spacing.xs)
                }
                .padding(.horizontal, DS.Spacing.screenEdge)
                .padding(.vertical, DS.Spacing.s)
            }
        }
        .presentationDetents([.fraction(0.75), .large])
        .onDisappear {
            // Not Today or swiped away: none of these come back today
            if remembersDismissals, !didAdd { KickstartSuggestions.dismiss(suggestions.map(\.id)) }
        }
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.s) {
            Image(systemName: greeting.icon)
                .font(.system(size: 44))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(LinearGradient(colors: greeting.colors, startPoint: .top, endPoint: .bottom))
                .symbolEffect(.bounce, options: .nonRepeating)
            Text(greeting.text)
                .font(DS.Typography.displayM)
                .foregroundStyle(DS.Color.textPrimary)
            Text(suggestions.count == 1
                 ? "By this time you've usually had this. Add it to today?"
                 : "By this time you've usually had these. Add them to today?")
                .font(DS.Typography.subhead)
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.s)
    }

    private func row(_ suggestion: KickstartSuggestion) -> some View {
        let isOn = selected.contains(suggestion.id)
        return Button {
            if isOn { selected.remove(suggestion.id) } else { selected.insert(suggestion.id) }
        } label: {
            HStack(spacing: DS.Spacing.m) {
                FoodIconThumbnail(iconName: suggestion.iconName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.name)
                        .font(.body)
                        .foregroundStyle(DS.Color.textPrimary)
                    Text(detail(suggestion))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }
                Spacer()
                Text("\(suggestion.calories) cal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? DS.Color.protein : DS.Color.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func detail(_ suggestion: KickstartSuggestion) -> String {
        let day = Calendar.current.startOfDay(for: now)
        let early = day.addingTimeInterval(TimeInterval(suggestion.earlyMinute * 60))
        let usual = day.addingTimeInterval(TimeInterval(suggestion.usualMinute * 60))
        let time = suggestion.usualMinute - suggestion.earlyMinute < 15
            ? "Usually around \(usual.formatted(date: .omitted, time: .shortened))"
            : "Usually \((early..<usual).formatted(.interval.hour().minute()))"
        var parts = [time]
        if suggestion.slot > 1 {
            parts.insert("\(suggestion.slot)\(ordinalSuffix(suggestion.slot)) today", at: 0)
        }
        if suggestion.mealName != nil {
            parts.append("\(suggestion.template.count) item\(suggestion.template.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    private func ordinalSuffix(_ n: Int) -> String {
        switch n { case 2: "nd"; case 3: "rd"; default: "th" }
    }

    /// Copies each picked food or meal into today at its usual time (or now, if that's later).
    /// Unticked ones aren't offered again today.
    private func addSelected() {
        didAdd = true
        if remembersDismissals {
            KickstartSuggestions.dismiss(suggestions.map(\.id).filter { !selected.contains($0) })
        }
        for suggestion in suggestions where selected.contains(suggestion.id) {
            let date = suggestion.dateToday(now: now)
            if let mealName = suggestion.mealName {
                quickAddMealGroup(suggestion.template, mealName: mealName, into: modelContext, date: date)
            } else if let entry = suggestion.template.first {
                quickAddEntry(entry, into: modelContext, date: date)
            }
        }
        dismiss()
    }
}
