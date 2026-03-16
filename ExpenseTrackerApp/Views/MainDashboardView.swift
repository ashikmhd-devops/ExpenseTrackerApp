import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingQuickAdd = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 50000.0

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationTitle("Main Menu")
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
        } detail: {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    NLQueryView()
                    ExpenseListView()
                }
                fab
            }
            .navigationTitle("Expenses")
        }
        .background(VisualEffectBackground().ignoresSafeArea())
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddWidgetView(viewModel: QuickAddViewModel(appViewModel: appViewModel))
                .frame(width: 420, height: 340)
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

    // MARK: - Sidebar Content
    
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

    private var summaryBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Spent This Month")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text("₹\(appViewModel.totalSpentThisMonth, specifier: "%.2f")")
                .font(.system(size: 32, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    // MARK: - Spending Gauge
    
    private var spendingGauge: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Usage")
                .font(.headline)
                .padding(.horizontal, 20)
            
            Gauge(value: appViewModel.totalSpentThisMonth, in: 0...monthlyBudget) {
                Text("Monthly Limit")
            } currentValueLabel: {
                Text("₹\(appViewModel.totalSpentThisMonth, specifier: "%.0f")")
            } minimumValueLabel: {
                Text("₹0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } maximumValueLabel: {
                Text("₹\(monthlyBudget, specifier: "%.0f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            Button(action: {
                appViewModel.generateInsights()
            }) {
                HStack(spacing: 6) {
                    if appViewModel.isGeneratingInsights {
                        ProgressView()
                            .scaleEffect(0.7)
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
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
