import Foundation
import SwiftUI
import Combine

@MainActor
class AppViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var errorMessage: String?
    @Published var insights: String?
    @Published var isGeneratingInsights: Bool = false

    // Category History
    @Published var categoryInsight: String? = nil
    @Published var isGeneratingCategoryInsight: Bool = false
    
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

    func updateExpense(_ expense: Expense) {
        do {
            try DatabaseService.shared.saveExpense(expense)
            fetchExpenses()
        } catch {
            errorMessage = "Failed to update expense: \(error.localizedDescription)"
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

    // MARK: - Category History

    /// Returns the last `months` calendar months of spending for a given category,
    /// ordered oldest → newest, with a 3-letter month label (e.g. "Jan").
    func monthlyTotals(for category: ExpenseCategory, months: Int = 6) -> [(label: String, total: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let shortMonthSymbols = calendar.shortMonthSymbols   // ["Jan", "Feb", ...]

        // Build the last `months` (year, month) tuples — oldest first
        var buckets: [(year: Int, month: Int)] = []
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let y = calendar.component(.year,  from: date)
            let m = calendar.component(.month, from: date)
            buckets.append((y, m))
        }

        // Sum amounts for each bucket
        var totals: [String: Double] = [:]
        for expense in expenses where expense.category == category {
            let y = calendar.component(.year,  from: expense.date)
            let m = calendar.component(.month, from: expense.date)
            let key = "\(y)-\(m)"
            totals[key, default: 0] += expense.amount
        }

        return buckets.map { (year, month) in
            let key   = "\(year)-\(month)"
            let label = shortMonthSymbols[month - 1]
            return (label: label, total: totals[key] ?? 0)
        }
    }

    func generateCategoryInsight(for category: ExpenseCategory) {
        isGeneratingCategoryInsight = true
        categoryInsight = nil
        let data = monthlyTotals(for: category)
        Task {
            do {
                let insight = try await OllamaService.shared.generateCategoryInsight(
                    category: category.rawValue,
                    monthlyTotals: data
                )
                self.categoryInsight = insight
            } catch {
                self.categoryInsight = "Couldn't reach Ollama. Make sure it's running (`ollama serve`)."
            }
            self.isGeneratingCategoryInsight = false
        }
    }

    // MARK: - AI Chat

    @Published var chatMessages: [ChatMessage] = []
    @Published var isChatLoading: Bool = false

    // MARK: - Receipt Scanning
    @Published var isProcessingReceipt: Bool = false
    @Published var scannedExpense: ParsedExpense? = nil
    @Published var receiptFileName: String = ""

    func sendChatMessage(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        chatMessages.append(ChatMessage(role: .user, content: trimmed))
        isChatLoading = true

        Task {
            do {
                let reply = try await OllamaService.shared.chat(messages: chatMessages, expenses: expenses)
                self.chatMessages.append(ChatMessage(role: .assistant, content: reply))
            } catch {
                self.chatMessages.append(ChatMessage(role: .assistant,
                    content: "Sorry, I couldn't connect to Ollama. Make sure it's running (`ollama serve`)."))
            }
            self.isChatLoading = false
        }
    }

    func startProactiveChat() {
        guard chatMessages.isEmpty else { return }
        isChatLoading = true
        Task {
            do {
                let greeting = try await OllamaService.shared.chat(
                    messages: [ChatMessage(role: .user, content: "Review my spending and give me 2–3 proactive observations or suggestions.")],
                    expenses: expenses
                )
                self.chatMessages.append(ChatMessage(role: .user,
                    content: "Review my spending and give me 2–3 proactive observations or suggestions."))
                self.chatMessages.append(ChatMessage(role: .assistant, content: greeting))
            } catch {
                self.chatMessages.append(ChatMessage(role: .assistant,
                    content: "Couldn't connect to Ollama. Make sure it's running (`ollama serve`)."))
            }
            self.isChatLoading = false
        }
    }

    func sendToChatFromSearch(_ text: String) {
        sendChatMessage(text)
    }

    func processDroppedFile(url: URL) {
        let ext = url.pathExtension.lowercased()
        guard ["pdf", "jpg", "jpeg", "png", "heic", "tiff"].contains(ext) else {
            errorMessage = "Unsupported file. Drop a PDF or image (JPG, PNG, HEIC)."
            return
        }
        isProcessingReceipt = true
        receiptFileName = url.lastPathComponent

        Task {
            do {
                let base64: String
                if ext == "pdf" {
                    guard let image = ReceiptImageHelper.pdfToImage(url: url),
                          let b64 = ReceiptImageHelper.imageToBase64(image) else {
                        throw NSError(domain: "Receipt", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "Could not render PDF page"])
                    }
                    base64 = b64
                } else {
                    guard let image = NSImage(contentsOf: url),
                          let b64 = ReceiptImageHelper.imageToBase64(image) else {
                        throw NSError(domain: "Receipt", code: 2,
                                      userInfo: [NSLocalizedDescriptionKey: "Could not read image file"])
                    }
                    base64 = b64
                }
                let parsed = try await OllamaService.shared.extractExpenseFromReceipt(imageBase64: base64)
                self.scannedExpense = parsed
            } catch {
                self.errorMessage = "Receipt scan failed: \(error.localizedDescription)"
            }
            self.isProcessingReceipt = false
        }
    }

    // MARK: - Natural Language Query
    
    @Published var queryInput: String = ""
    @Published var queryResult: String?
    @Published var isRunningQuery: Bool = false
    
    func runNLQuery(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isRunningQuery = true
        queryResult = nil
        errorMessage = nil
        
        Task {
            do {
                // 1. Convert natural language to SQL via Ollama
                let sql = try await OllamaService.shared.generateSQLQuery(from: query)
                print("Generated SQL: \(sql)") // useful for debugging
                
                // 2. Execute SQL against local SQLite database
                let rows = try DatabaseService.shared.executeRawQuery(sql)
                
                // 3. Format the result
                var formattedResult = "Query: \(sql)\n\n"
                
                if rows.isEmpty {
                    formattedResult += "No results found."
                } else {
                    for (index, row) in rows.enumerated() {
                        formattedResult += "Row \(index + 1):\n"
                        for (key, value) in row {
                            formattedResult += "  \(key): \(value)\n"
                        }
                        formattedResult += "\n"
                    }
                }
                self.queryResult = formattedResult.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                self.errorMessage = "Query failed: \(error.localizedDescription)"
                self.queryResult = "Error executing query."
            }
            self.isRunningQuery = false
        }
    }
}
