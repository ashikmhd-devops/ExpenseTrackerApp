import Foundation
import SwiftUI
import Combine

@MainActor
class AppViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var errorMessage: String?
    @Published var insights: String?
    @Published var isGeneratingInsights: Bool = false
    
    // Derived statistics
    var totalSpentThisMonth: Double {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        return expenses.filter {
            let month = calendar.component(.month, from: $0.date)
            let year = calendar.component(.year, from: $0.date)
            return month == currentMonth && year == currentYear
        }.reduce(0) { $0 + $1.amount }
    }
    
    init() {
        fetchExpenses()
    }
    
    func fetchExpenses() {
        do {
            expenses = try DatabaseService.shared.fetchAllExpenses()
        } catch {
            errorMessage = "Failed to load expenses: \(error.localizedDescription)"
        }
    }
    
    func addExpense(_ expense: Expense) {
        do {
            try DatabaseService.shared.saveExpense(expense)
            fetchExpenses()
        } catch {
            errorMessage = "Failed to save expense: \(error.localizedDescription)"
        }
    }
    
    func deleteExpense(at offsets: IndexSet) {
        offsets.forEach { index in
            let expense = expenses[index]
            do {
                try DatabaseService.shared.deleteExpense(expense)
            } catch {
                errorMessage = "Failed to delete expense: \(error.localizedDescription)"
            }
        }
        fetchExpenses()
    }

    func deleteExpenses(withIDs ids: Set<String>) {
        expenses.filter { ids.contains($0.id) }.forEach { expense in
            do {
                try DatabaseService.shared.deleteExpense(expense)
            } catch {
                errorMessage = "Failed to delete expense: \(error.localizedDescription)"
            }
        }
        fetchExpenses()
    }

    func clearAllExpenses() {
        do {
            try DatabaseService.shared.clearAllExpenses()
            fetchExpenses()
        } catch {
            errorMessage = "Failed to clear expenses: \(error.localizedDescription)"
        }
    }
    
    func generateInsights() {
        guard !expenses.isEmpty else {
            insights = "No expenses to analyze yet. Add some expenses to get insights!"
            return
        }
        
        isGeneratingInsights = true
        insights = nil
        errorMessage = nil
        
        Task {
            do {
                let newInsights = try await OllamaService.shared.generateInsights(for: expenses)
                self.insights = newInsights
            } catch {
                self.errorMessage = "Failed to generate insights: \(error.localizedDescription)"
            }
            self.isGeneratingInsights = false
        }
    }
}
