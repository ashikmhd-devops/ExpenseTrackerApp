import SwiftUI
import UniformTypeIdentifiers

struct MainDashboardView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingQuickAdd = false
    @State private var showingBudgetEditor = false
    @State private var selectedTab: Int = 0
    @State private var isDropTargeted: Bool = false
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 50000.0
    @AppStorage("categoryBudgetsJSON") private var categoryBudgetsJSON: String = "{}"

    private var categoryBudgets: [String: Double] {
        get {
            guard let data = categoryBudgetsJSON.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                categoryBudgetsJSON = str
            }
        }
    }

    // Spending per category for current month
    private var categorySpentThisMonth: [String: Double] {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let year  = cal.component(.year, from: now)
        var totals: [String: Double] = [:]
        for expense in appViewModel.expenses {
            guard cal.component(.month, from: expense.date) == month,
                  cal.component(.year,  from: expense.date) == year else { continue }
            totals[expense.category.rawValue, default: 0] += expense.amount
        }
        return totals
    }

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
            BudgetEditorView(monthlyBudget: $monthlyBudget, categoryBudgetsJSON: $categoryBudgetsJSON)
        }
        .sheet(isPresented: Binding(
            get: { appViewModel.scannedExpense != nil },
            set: { if !$0 { appViewModel.scannedExpense = nil } }
        )) {
            if let parsed = appViewModel.scannedExpense {
                ScannedReceiptConfirmView(parsed: parsed)
                    .environmentObject(appViewModel)
            }
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
        HStack(spacing: 0) {
            // Sidebar — always visible, no toggle button
            sidebarContent
                .frame(width: 270)

            Divider()

            // Detail pane
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    NLQueryView(selectedTab: $selectedTab)
                    ExpenseListView()
                }
                fab

                // Drop target visual hint
                if isDropTargeted {
                    DropTargetOverlay()
                        .allowsHitTesting(false)
                }

                // Processing overlay while llava reads the receipt
                if appViewModel.isProcessingReceipt {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .allowsHitTesting(true)
                    ProcessingReceiptCard(fileName: appViewModel.receiptFileName)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.3), value: appViewModel.isProcessingReceipt)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    let tmpURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: tmpURL)
                    DispatchQueue.main.async {
                        appViewModel.processDroppedFile(url: tmpURL)
                    }
                }
                return true
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryBanner
                spendingGauge
                categoryBudgetsSection
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

    // MARK: - Category Budgets Section

    @ViewBuilder
    private var categoryBudgetsSection: some View {
        let budgets = categoryBudgets
        let spent   = categorySpentThisMonth
        let tracked = ExpenseCategory.allCases.filter { budgets[$0.rawValue] != nil }

        if !tracked.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Category Budgets")
                    .font(.headline)
                    .padding(.horizontal, 20)

                ForEach(tracked, id: \.self) { category in
                    let limit   = budgets[category.rawValue] ?? 0
                    let used    = spent[category.rawValue] ?? 0
                    let ratio   = limit > 0 ? min(used / limit, 1.0) : 0
                    let barTint: Color = ratio > 0.85 ? .red : ratio > 0.65 ? .orange : .green

                    VStack(spacing: 5) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(category.iconBackground)
                                    .frame(width: 28, height: 28)
                                Image(systemName: category.icon)
                                    .foregroundColor(category.iconColor)
                                    .font(.system(size: 12))
                            }
                            Text(category.rawValue)
                                .font(.system(size: 13))
                            Spacer()
                            Text("₹\(used, specifier: "%.0f") / ₹\(limit, specifier: "%.0f")")
                                .font(.system(size: 11))
                                .foregroundColor(ratio > 0.85 ? .red : .secondary)
                        }
                        ProgressView(value: ratio)
                            .tint(barTint)
                            .scaleEffect(y: 0.8, anchor: .center)
                    }
                    .padding(.horizontal, 20)
                }
            }
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
    @Binding var categoryBudgetsJSON: String
    @Environment(\.dismiss) private var dismiss

    @State private var draftMonthly: String = ""
    @State private var draftCategory: [String: String] = [:]

    private var savedCategoryBudgets: [String: Double] {
        guard let data = categoryBudgetsJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return dict
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Budget Settings")
                    .font(.system(size: 18, weight: .semibold))
                Text("Set spending limits for this month")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Monthly total
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Monthly Total Limit", systemImage: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.4)

                        HStack {
                            Text("₹")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("e.g. 50000", text: $draftMonthly)
                                .textFieldStyle(.plain)
                                .font(.system(size: 22, weight: .bold))
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Divider()

                    // Per-category budgets
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Category Limits", systemImage: "tag")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.4)
                            Spacer()
                            Text("Leave blank for no limit")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(category.iconBackground)
                                        .frame(width: 30, height: 30)
                                    Image(systemName: category.icon)
                                        .foregroundColor(category.iconColor)
                                        .font(.system(size: 12))
                                }

                                Text(category.rawValue)
                                    .font(.system(size: 13))
                                    .frame(width: 100, alignment: .leading)

                                HStack(spacing: 4) {
                                    Text("₹").font(.system(size: 12)).foregroundColor(.secondary)
                                    TextField("No limit", text: Binding(
                                        get: { draftCategory[category.rawValue] ?? "" },
                                        set: { draftCategory[category.rawValue] = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 7))

                                // Clear button — fixed width to avoid layout shift
                                Button(action: { draftCategory[category.rawValue] = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 13))
                                }
                                .buttonStyle(.plain)
                                .opacity((draftCategory[category.rawValue] ?? "").isEmpty ? 0 : 1)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save") { saveAndDismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 420, height: 580)
        .onAppear {
            draftMonthly = String(format: "%.0f", monthlyBudget)
            let existing = savedCategoryBudgets
            for category in ExpenseCategory.allCases {
                if let budget = existing[category.rawValue], budget > 0 {
                    draftCategory[category.rawValue] = String(format: "%.0f", budget)
                }
            }
        }
    }

    private func saveAndDismiss() {
        if let value = Double(draftMonthly.filter { $0.isNumber || $0 == "." }), value > 0 {
            monthlyBudget = value
        }
        var updated: [String: Double] = [:]
        for (key, str) in draftCategory {
            if let value = Double(str.filter { $0.isNumber || $0 == "." }), value > 0 {
                updated[key] = value
            }
        }
        if let data = try? JSONEncoder().encode(updated),
           let str = String(data: data, encoding: .utf8) {
            categoryBudgetsJSON = str
        }
        dismiss()
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
