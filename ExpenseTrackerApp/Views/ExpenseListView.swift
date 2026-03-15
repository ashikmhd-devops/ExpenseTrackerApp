import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    let isSelected: Bool
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(expense.category.iconBackground)
                    .frame(width: 38, height: 38)
                Image(systemName: expense.category.icon)
                    .foregroundColor(expense.category.iconColor)
                    .font(.system(size: 15, weight: .regular))
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant.capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Text(expense.category.rawValue)
                    Text("·")
                    Text(expense.date, style: .date)
                }
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.6))
            }

            Spacer()

            // Price (vertically centered with title)
            Text("₹\(expense.amount, specifier: "%.2f")")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)

            // Hover-reveal delete
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.red.opacity(0.85))
            }
            .buttonStyle(.borderless)
            .opacity(isHovered || isSelected ? 1 : 0)
            .frame(width: 20)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected
                    ? Color.accentColor.opacity(0.12)
                    : Color(NSColor.controlBackgroundColor))
        )
        .onHover { isHovered = $0 }
    }
}

struct ExpenseListView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showClearConfirmation = false
    @State private var selection: Set<String> = []
    @State private var expenseToDelete: Expense?

    var body: some View {
        ZStack {
            List(selection: $selection) {
                ForEach(appViewModel.expenses) { expense in
                    ExpenseRowView(
                        expense: expense,
                        isSelected: selection.contains(expense.id),
                        onDelete: { expenseToDelete = expense }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 3, leading: 20, bottom: 3, trailing: 20))
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
        }
    }
}
