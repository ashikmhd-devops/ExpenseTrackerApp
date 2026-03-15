import Foundation
import GRDB

struct Expense: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    var id: String
    var amount: Double
    var category: ExpenseCategory
    var merchant: String
    var date: Date
    var note: String?
    
    init(id: String = UUID().uuidString, amount: Double, category: ExpenseCategory, merchant: String, date: Date, note: String? = nil) {
        self.id = id
        self.amount = amount
        self.category = category
        self.merchant = merchant
        self.date = date
        self.note = note
    }
}
