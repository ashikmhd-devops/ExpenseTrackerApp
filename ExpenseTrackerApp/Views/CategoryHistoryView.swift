import SwiftUI

// MARK: - Category History Sheet

struct CategoryHistoryView: View {
    let category: ExpenseCategory
    let monthlyData: [(label: String, total: Double)]

    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    // Bar chart animation
    @State private var animateBars: Bool = false

    private var maxValue: Double {
        monthlyData.map(\.total).max() ?? 1
    }

    var body: some View {
        ZStack {
            // ── Glassmorphic background ──────────────────────────────
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        chartSection
                        aiInsightSection
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 480, height: 520)
        .onAppear {
            // Kick off bar animation + AI fetch
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
                animateBars = true
            }
            appViewModel.generateCategoryInsight(for: category)
        }
        .onDisappear {
            // Reset so stale result isn't shown next time
            appViewModel.categoryInsight = nil
            animateBars = false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Category icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(category.iconBackground)
                    .frame(width: 38, height: 38)
                Image(systemName: category.icon)
                    .foregroundColor(category.iconColor)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(category.rawValue) Spending History")
                    .font(.system(size: 17, weight: .semibold))
                Text("Last 6 months")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Bar Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Breakdown")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            GeometryReader { geo in
                let barWidth = (geo.size.width - CGFloat(monthlyData.count - 1) * 10) / CGFloat(monthlyData.count)
                let chartHeight: CGFloat = 160

                VStack(spacing: 0) {
                    // Bars + value labels
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(Array(monthlyData.enumerated()), id: \.offset) { idx, item in
                            let ratio = maxValue > 0 ? item.total / maxValue : 0
                            let barH  = animateBars ? max(chartHeight * CGFloat(ratio), item.total > 0 ? 4 : 2) : 2

                            VStack(spacing: 4) {
                                // Amount label (only show if bar is tall enough)
                                if item.total > 0 {
                                    Text("₹\(shortAmount(item.total))")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(category.iconColor)
                                        .opacity(animateBars ? 1 : 0)
                                        .animation(.easeIn.delay(0.3 + Double(idx) * 0.05), value: animateBars)
                                } else {
                                    Text("—")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }

                                Spacer(minLength: 0)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [category.iconColor.opacity(0.9), category.iconColor.opacity(0.5)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: barWidth, height: barH)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(idx) * 0.06), value: animateBars)
                            }
                            .frame(height: chartHeight, alignment: .bottom)
                        }
                    }
                    .frame(height: chartHeight)

                    Divider()
                        .padding(.top, 4)

                    // Month labels
                    HStack(spacing: 10) {
                        ForEach(Array(monthlyData.enumerated()), id: \.offset) { _, item in
                            Text(item.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: barWidth)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .frame(height: 210)   // chart + labels combined
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func shortAmount(_ value: Double) -> String {
        if value >= 100_000 { return "\(String(format: "%.1f", value / 100_000))L" }
        if value >= 1_000   { return "\(String(format: "%.1f", value / 1_000))K" }
        return String(format: "%.0f", value)
    }

    // MARK: - AI Insight

    private var aiInsightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
                Text("AI Insight")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Group {
                if appViewModel.isGeneratingCategoryInsight {
                    HStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Analysing your \(category.rawValue.lowercased()) spending…")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                } else if let insight = appViewModel.categoryInsight {
                    Text(insight)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.35), value: appViewModel.isGeneratingCategoryInsight)
            .animation(.easeInOut(duration: 0.35), value: appViewModel.categoryInsight)
        }
    }
}
