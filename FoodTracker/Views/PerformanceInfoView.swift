import SwiftUI

/// Explains History's performance card
struct PerformanceInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Each row is your average per day over the chosen period: the last 7, 30 or 90 days, or the last year.")
                    Text("Only days you logged something count, so a missed day doesn't pull the average down. Today isn't counted until it's over.")
                } header: {
                    Text("Averages")
                }

                Section {
                    Label("The days row shows how many days the averages rest on. Each dot is a day; filled means something was logged.", systemImage: "calendar")
                    legendRow(.onTarget, "80% or more of days logged")
                    legendRow(.over(percent: 15, severe: false), "50–80% logged")
                    legendRow(.over(percent: 25, severe: true), "Under half logged: take the averages with a grain of salt")
                    iconRow("exclamationmark.triangle.fill", DS.Color.carbs, "Faded dot: the day looks partially logged (very few calories, or no lunch or dinner on a light day). Tap \"looks partial\" to review and leave it out.")
                    iconRow("line.3.horizontal.decrease.circle", DS.Color.textSecondary, "Hollow dot: you left the day out of the averages")
                } header: {
                    Text("Days Counted")
                }

                Section {
                    iconRow("checkmark", DS.Color.success, "Within 10% of your goal")
                    iconRow("arrow.up", DS.Color.carbs, "Over by 10–20% (the number is how much)")
                    iconRow("arrow.down", DS.Color.carbs, "Under by 10–20%")
                    iconRow("arrow.up", DS.Color.danger, "More than 20% over or under")
                    iconRow("target", DS.Color.textSecondary, "Goals on target, in the card's header")
                    iconRow(DS.Icon.calories, DS.Color.textPrimary, "Calories")
                    iconRow(DS.Icon.protein, DS.Color.protein, "Protein")
                    iconRow(DS.Icon.carbs, DS.Color.carbs, "Carbs")
                    iconRow(DS.Icon.fat, DS.Color.fat, "Fat")
                } header: {
                    Text("Icons and Colors")
                } footer: {
                    Text("The shaded band on each bar is the on-target range (goal ±10%), and the line under the number marks the goal itself.")
                }

                Section {
                    Text("Goals come from your daily targets in Settings. A macro with no target shows its average without a comparison.")
                } header: {
                    Text("Goals")
                }
            }
            .font(DS.Typography.subhead)
            .navigationTitle("How to Read Performance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton(title: "Close") { dismiss() }
                }
            }
        }
    }

    private func iconRow(_ icon: String, _ color: Color, _ text: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
        }
    }

    private func legendRow(_ status: TargetStatus, _ text: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            Circle()
                .fill(status.color)
                .frame(width: 12, height: 12)
            Text(text)
        }
    }
}
