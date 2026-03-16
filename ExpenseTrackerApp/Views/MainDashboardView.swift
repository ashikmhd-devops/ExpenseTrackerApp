import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingQuickAdd = false
    @State private var showingBudgetEditor = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selectedTab: Int = 0
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 50000.0

    var body: some View {
        TabView(selection: $selectedTab) {
            // ── Tab 1: Expenses ──────────────────────────────────────
            expensesTab
                .tabItem { Label("Expenses", systemImage: "list.bullet.rectangle") }
                .tag(0)

            // ── Tab 2: AI Chat ───────────────────────────────────────
            AIChatView()
                .tabItem { Label("AI Advisor", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)
        }
        .background(VisualEffectBackground().ignoresSafeArea())
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddWidgetView(viewModel: QuickAddViewModel(appViewModel: appViewModel))
                .frame(width: 420, height: 340)
        }
        .sheet(isPresented: $showingBudgetEditor) {
            BudgetEditorView(monthlyBudget: $monthlyBudget)
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { appViewModel.errorMessage != nil },
            set: { _ in appViewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appViewModel.errorMessage ?? "")
        }
    }

    // MARK: - Expenses Tab

    private var expensesTab: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationTitle("Summary")
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
        } detail: {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    NLQueryView(selectedTab: $selectedTab)
                    ExpenseListView()
                }
                fab
            }
            .navigationTitle("Expenses")
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryBanner
                spendingGauge
                insightsSection
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Summary Banner

    private var spendRatio: Double {
        guard monthlyBudget > 0 else { return 0 }
        return min(appViewModel.totalSpentThisMonth / monthlyBudget, 1.0)
    }

    private var amountColor: Color {
        switch spendRatio {
        case 0..<0.4:  return .green
        case 0.4..<0.65: return Color(red: 0.9, green: 0.75, blue: 0.0)   // yellow
        case 0.65..<0.85: return .orange
        default:       return .red
        }
    }

    private var summaryBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Spent This Month")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text("₹\(appViewModel.totalSpentThisMonth, specifier: "%.2f")")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(amountColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    // MARK: - Spending Gauge

    private var spendingGauge: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Budget Usage")
                    .font(.headline)
                Spacer()
                Button(action: { showingBudgetEditor = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11))
                        Text("Set Budget")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Gauge(value: appViewModel.totalSpentThisMonth, in: 0...monthlyBudget) {
                Text("Monthly Limit")
            } currentValueLabel: {
                Text("₹\(appViewModel.totalSpentThisMonth, specifier: "%.0f")")
            } minimumValueLabel: {
                Text("₹0").font(.caption).foregroundColor(.secondary)
            } maximumValueLabel: {
                Text("₹\(monthlyBudget, specifier: "%.0f")").font(.caption).foregroundColor(.secondary)
            }
            .gaugeStyle(.accessoryLinear)
            .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Insights Section

    @ViewBuilder
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { appViewModel.generateInsights() }) {
                HStack(spacing: 6) {
                    if appViewModel.isGeneratingInsights {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("Generate Insights")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(appViewModel.isGeneratingInsights || appViewModel.expenses.isEmpty)
            .padding(.horizontal, 20)

            if let insights = appViewModel.insights {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .foregroundColor(.accentColor)
                        Text("AI Insights")
                            .font(.headline)
                        Spacer()
                        Button(action: { appViewModel.insights = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(insights)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                }
                .padding(16)
                .background(Color.accentColor.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut, value: appViewModel.insights)
            }
        }
    }

    // MARK: - FAB

    private var fab: some View {
        Button(action: { showingQuickAdd = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add Expense")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(red: 0.04, green: 0.14, blue: 0.22))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(red: 0.28, green: 0.86, blue: 0.76))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .padding(24)
        .help("Quick Add Expense")
        .keyboardShortcut("n", modifiers: .command)
    }
}

// MARK: - Budget Editor Sheet

struct BudgetEditorView: View {
    @Binding var monthlyBudget: Double
    @Environment(\.dismiss) private var dismiss
    @State private var draftBudget: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Set Monthly Budget")
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly limit (₹)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                HStack {
                    Text("₹")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("e.g. 50000", text: $draftBudget)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .bold))
                }
                .padding(14)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Save") {
                    if let value = Double(draftBudget.filter { $0.isNumber || $0 == "." }), value > 0 {
                        monthlyBudget = value
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(Double(draftBudget.filter { $0.isNumber || $0 == "." }) == nil)
            }
        }
        .padding(28)
        .frame(width: 320)
        .onAppear {
            draftBudget = String(format: "%.0f", monthlyBudget)
        }
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
    }
}
