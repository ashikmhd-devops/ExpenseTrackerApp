import SwiftUI

struct ExpenseListView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
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
                        Text("$\(expense.amount, specifier: "%.2f")")
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
