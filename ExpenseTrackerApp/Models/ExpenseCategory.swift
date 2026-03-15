import Foundation

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food = "Food"
    case fuel = "Fuel"
    case shopping = "Shopping"
    case utilities = "Utilities"
    case entertainment = "Entertainment"
    case travel = "Travel"
    case health = "Health"
    case education = "Education"
    case vehicle = "Vehicle"
    case miscellaneous = "Miscellaneous"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .fuel: return "fuelpump.fill"
        case .shopping: return "cart.fill"
        case .utilities: return "bolt.fill"
        case .entertainment: return "ticket.fill"
        case .travel: return "airplane"
        case .health: return "cross.case.fill"
        case .education: return "book.fill"
        case .vehicle: return "car.fill"
        case .miscellaneous: return "questionmark.circle.fill"
        }
    }
}
