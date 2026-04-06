import SwiftUI

// Adaptive card color: #2C2C2C in dark mode, #F2F2F2 in light mode
private let cardBackground = Color(NSColor(name: nil, dynamicProvider: { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(red: 0.173, green: 0.173, blue: 0.173, alpha: 1)
        : NSColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
}))

struct ExpenseRowView: View {
    let expense: Expense
    let isSelected: Bool
    let onDelete: () -> Void
    let onEdit: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(expense.category.iconBackground)
                    .frame(width: 40, height: 40)
                Image(systemName: expense.category.icon)
                    .foregroundColor(expense.category.iconColor)
                    .font(.system(size: 16, weight: .regular))
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.merchant.capitalized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 5) {
                    Text(expense.category.rawValue)
                    Text("•")
                    Text(expense.date, style: .date)
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            // Price
            Text("₹\(expense.amount, specifier: "%.2f")")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            // Hover-reveal action buttons
            HStack(spacing: 6) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(.borderless)
                .help("Edit expense")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.red.opacity(0.85))
                }
                .buttonStyle(.borderless)
                .help("Delete expense")
            }
            .opacity(isHovered || isSelected ? 1 : 0)
            .frame(width: 44)
        }
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(
                    color: isSelected ? expense.category.iconColor.opacity(0.4) : .clear,
                    radius: isSelected ? 8 : 0,
                    x: 0,
                    y: 0
                )
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Month group model

private struct MonthGroup: Identifiable {
    let id: String        // "March 2026"
    let year: Int
    let month: Int
    var expenses: [Expense]

    var total: Double { expenses.reduce(0) { $0 + $1.amount } }
}

private func buildMonthGroups(from expenses: [Expense]) -> [MonthGroup] {
    let cal = Calendar.current
    var dict: [String: MonthGroup] = [:]
    let fmt = DateFormatter()
    fmt.dateFormat = "MMMM yyyy"

    for expense in expenses {
        let key = fmt.string(from: expense.date)
        let comps = cal.dateComponents([.year, .month], from: expense.date)
        if dict[key] == nil {
            dict[key] = MonthGroup(id: key, year: comps.year ?? 0, month: comps.month ?? 0, expenses: [])
        }
        dict[key]!.expenses.append(expense)
    }

    return dict.values.sorted {
        $0.year != $1.year ? $0.year > $1.year : $0.month > $1.month
    }
}

// MARK: - Month section header

private struct MonthSectionHeader: View {
    let group: MonthGroup
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 12)

                Text(group.id)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(group.expenses.count) expense\(group.expenses.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("₹\(group.total, specifier: "%.0f")")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ExpenseListView

struct ExpenseListView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showClearConfirmation = false
    @State private var selection: Set<UUID> = []
    @State private var expenseToDelete: Expense?
    @State private var expenseToEdit: Expense?
    @State private var expandedMonths: Set<String> = []

    private var monthGroups: [MonthGroup] {
        buildMonthGroups(from: appViewModel.expenses)
    }

    private var currentMonthKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: Date())
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(monthGroups) { group in
                Section {
                    if expandedMonths.contains(group.id) {
                        ForEach(group.expenses) { expense in
                            ExpenseRowView(
                                expense: expense,
                                isSelected: selection.contains(expense.id),
                                onDelete: { expenseToDelete = expense },
                                onEdit: { expenseToEdit = expense }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        }
                        .onDelete { offsets in
                            let toDelete = offsets.map { group.expenses[$0] }
                            appViewModel.commitDeletes(toDelete)
                        }
                    }
                } header: {
                    MonthSectionHeader(
                        group: group,
                        isExpanded: expandedMonths.contains(group.id)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedMonths.contains(group.id) {
                                expandedMonths.remove(group.id)
                            } else {
                                expandedMonths.insert(group.id)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Expenses")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label("Clear All", systemImage: "trash.fill")
                }
                .disabled(appViewModel.expenses.isEmpty)
            }
        }
        .onAppear {
            expandedMonths.insert(currentMonthKey)
        }
        .onChange(of: appViewModel.expenses) { _ in
            // If a new month appears, expand it automatically
            let keys = Set(monthGroups.map(\.id))
            let newKey = currentMonthKey
            if keys.contains(newKey) {
                expandedMonths.insert(newKey)
            }
        }
        .confirmationDialog("Clear all expenses?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                appViewModel.clearAllExpenses()
            }
        }
        .confirmationDialog(
            "Delete \"\(expenseToDelete?.merchant ?? "")\"?",
            isPresented: Binding(get: { expenseToDelete != nil }, set: { if !$0 { expenseToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    appViewModel.deleteExpenses(withIDs: [expense.id])
                    selection.remove(expense.id)
                    expenseToDelete = nil
                }
            }
        }
        .overlay {
            if appViewModel.expenses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No expenses yet")
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(item: $expenseToEdit) { expense in
            EditExpenseView(expense: expense)
                .environmentObject(appViewModel)
        }
    }
}
