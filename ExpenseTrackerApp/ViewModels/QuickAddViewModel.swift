import Foundation
import SwiftUI
import Combine

@MainActor
class QuickAddViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isProcessing: Bool = false
    @Published var parsedExpensePreview: Expense?
    @Published var suggestedExpense: Expense?
    @Published var errorMessage: String?
    
    private let appViewModel: AppViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        
        $inputText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newText in
                self?.findSuggestion(for: newText)
            }
            .store(in: &cancellables)
    }
    
    private func findSuggestion(for text: String) {
        guard parsedExpensePreview == nil else { return } // Don't suggest if already parsed
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 3 else {
            suggestedExpense = nil
            return
        }
        
        // Find the first expense in history where the merchant matches the input text reasonably well
        if let match = appViewModel.expenses.first(where: { $0.merchant.lowercased().contains(trimmed) || trimmed.contains($0.merchant.lowercased()) }) {
            suggestedExpense = match
        } else {
            suggestedExpense = nil
        }
    }
    
    func applyMagicWand() {
        guard let suggestion = suggestedExpense else { return }
        // Create a new expense based on the suggestion, but with today's date and a fresh UUID
        let newExpense = Expense(
            amount: suggestion.amount,
            category: suggestion.category,
            merchant: suggestion.merchant,
            date: Date(),
            note: "Magic Wand Auto-fill"
        )
        parsedExpensePreview = newExpense
        suggestedExpense = nil // Hide wand once applied
    }
    
    func parseInput() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        parsedExpensePreview = nil
        suggestedExpense = nil
        
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
        // Don't reset here — SwiftUI still holds the Binding and will
        // call its getter one more time during the dismissal layout pass.
        // reset() is called from onDisappear in the view instead.
    }
    
    func reset() {
        inputText = ""
        parsedExpensePreview = nil
        suggestedExpense = nil
        errorMessage = nil
    }
}
