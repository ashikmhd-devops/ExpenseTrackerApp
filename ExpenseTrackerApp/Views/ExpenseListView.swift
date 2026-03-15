import SwiftUI

struct ExpenseListView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showClearConfirmation = false

    var body: some View {
        List {
            ForEach(appViewModel.expenses) { expense in
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: expense.category.icon)
                            .foregroundColor(.accentColor)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(expense.merchant)
                            .font(.headline)
                        Text(expense.category.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("₹\(expense.amount, specifier: "%.2f")")
                            .font(.headline)
                        Text(expense.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: appViewModel.deleteExpense)
        }
        .navigationTitle("Expenses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(appViewModel.expenses.isEmpty)
            }
        }
        .confirmationDialog("Clear all expenses?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                appViewModel.clearAllExpenses()
            }
        }
        .overlay {
            if appViewModel.expenses.isEmpty {
                VStack {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No expenses yet")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
        }
    }
}
