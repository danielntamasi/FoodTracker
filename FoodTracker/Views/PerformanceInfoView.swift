import SwiftUI

struct PerformanceInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dotColorsSection
                    weeklyMatrixSection
                    statsSection
                }
                .padding(16)
            }
            .background(DS.Color.backgroundPrimary)
            .navigationTitle("How to Read Performance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Dot Colors Section

    private var dotColorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dot Colors")
                .font(.headline)

            VStack(spacing: 8) {
                dotLegendRow(status: .onTarget, label: "On target", description: "within ±10% of goal")
                dotLegendRow(status: .over(severe: false), label: "Slightly over", description: "10–20% above")
                dotLegendRow(status: .under(severe: false), label: "Slightly under", description: "10–20% below")
                dotLegendRow(status: .over(severe: true), label: "Way over", description: "more than 20% above")
                dotLegendRow(status: .under(severe: true), label: "Way under", description: "more than 20% below")
                dotLegendRow(status: .noData, label: "No data", description: "nothing logged")
            }
            .padding(12)
            .background(DS.Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func dotLegendRow(status: DotStatus, label: String, description: String) -> some View {
        HStack(spacing: 10) {
            infoDot(status: status)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .frame(width: 100, alignment: .leading)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func infoDot(status: DotStatus) -> some View {
        ZStack {
            Circle()
                .fill(status.color)
                .frame(width: 14, height: 14)
            if let arrow = status.arrowName {
                Image(systemName: arrow)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Weekly Matrix Section

    private var weeklyMatrixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Matrix")
                .font(.headline)

            VStack(spacing: 0) {
                exampleMatrix
                    .padding(12)

                Text("Rows = macros you're tracking. Columns = days. A day is \"on target\" when every row is green.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .background(DS.Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var exampleMatrix: some View {
        let days = ["M", "T", "W", "T", "F"]
        let rows: [(String, [DotStatus])] = [
            ("Cal",  [.onTarget, .onTarget, .onTarget, .over(severe: false), .onTarget]),
            ("Pro",  [.onTarget, .under(severe: false), .onTarget, .onTarget, .onTarget]),
            ("Carb", [.onTarget, .onTarget, .over(severe: false), .onTarget, .under(severe: true)]),
            ("Fat",  [.onTarget, .onTarget, .onTarget, .onTarget, .onTarget]),
        ]

        return VStack(spacing: 6) {
            // Day headers
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 34, alignment: .leading)
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Macro rows
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    Text(row.0)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .leading)
                    ForEach(Array(row.1.enumerated()), id: \.offset) { _, status in
                        infoDot(status: status)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats Explained")
                .font(.headline)

            VStack(spacing: 0) {
                statRow(
                    label: "X of Y on target",
                    description: "Days where every tracked macro was within ±10%. Days with no food logged are excluded.",
                    isFirst: true
                )
                statRow(
                    label: "Streak",
                    description: "Consecutive on-target days ending today.",
                    isFirst: false
                )
                statRow(
                    label: "Best streak",
                    description: "Longest run of on-target days in the selected period.",
                    isFirst: false
                )
                statRow(
                    label: "Avg ±X cal/day",
                    description: "How much you averaged over or under your calorie target.",
                    isFirst: false
                )
                statRow(
                    label: "▲ / ▼ / ▸ Trend",
                    description: "Compares your adherence to the previous period of the same length.",
                    isFirst: false
                )
            }
            .background(DS.Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func statRow(label: String, description: String, isFirst: Bool) -> some View {
        VStack(spacing: 0) {
            if !isFirst {
                Divider()
                    .padding(.leading, 12)
            }
            HStack(alignment: .top, spacing: 10) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 110, alignment: .leading)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
        }
    }
}
