import Foundation
import SwiftUI
import Combine

@MainActor
class QuickAddViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isProcessing: Bool = false
    @Published var parsedExpensePreview: Expense?
    @Published var errorMessage: String?
    
    private let appViewModel: AppViewModel
    
    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }
    
    func parseInput() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        parsedExpensePreview = nil
        
        do {
            let expense = try await OllamaService.shared.parseNaturalLanguageExpense(inputText)
            parsedExpensePreview = expense
        } catch {
            errorMessage = "Failed to parse: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    func confirmAndSave() {
        guard let expense = parsedExpensePreview else { return }
        appViewModel.addExpense(expense)
        reset()
    }
    
    func reset() {
        inputText = ""
        parsedExpensePreview = nil
        errorMessage = nil
    }
}
