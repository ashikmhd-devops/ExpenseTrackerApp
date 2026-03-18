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

struct ExpenseListView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showClearConfirmation = false
    @State private var selection: Set<UUID> = []
    @State private var expenseToDelete: Expense?
    @State private var expenseToEdit: Expense?

    var body: some View {
        List(selection: $selection) {
            ForEach(appViewModel.expenses) { expense in
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
            .onDelete(perform: appViewModel.deleteExpense)
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
