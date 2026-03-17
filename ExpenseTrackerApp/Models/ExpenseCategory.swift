import Foundation
import SwiftUI

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
    case investment = "Investment"
    case creditCardBill = "Credit Card Bill"
    case miscellaneous = "Miscellaneous"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .food:          return "fork.knife"
        case .fuel:          return "fuelpump"
        case .shopping:      return "bag"
        case .utilities:     return "bolt"
        case .entertainment: return "ticket"
        case .travel:        return "airplane"
        case .health:        return "stethoscope"
        case .education:     return "graduationcap"
        case .vehicle:       return "car"
        case .investment:    return "chart.line.uptrend.xyaxis"
        case .creditCardBill: return "creditcard"
        case .miscellaneous: return "questionmark.circle"
        }
    }

    var iconColor: Color {
        switch self {
        case .food:          return Color(red: 0.80, green: 0.38, blue: 0.08)
        case .fuel:          return Color(red: 0.68, green: 0.48, blue: 0.05)
        case .shopping:      return Color(red: 0.72, green: 0.10, blue: 0.42)
        case .utilities:     return Color(red: 0.46, green: 0.10, blue: 0.68)
        case .entertainment: return Color(red: 0.68, green: 0.08, blue: 0.18)
        case .travel:        return Color(red: 0.08, green: 0.30, blue: 0.72)
        case .health:        return Color(red: 0.68, green: 0.08, blue: 0.30)
        case .education:     return Color(red: 0.08, green: 0.48, blue: 0.18)
        case .vehicle:       return Color(red: 0.18, green: 0.28, blue: 0.50)
        case .investment:    return Color(red: 0.05, green: 0.50, blue: 0.32)
        case .creditCardBill: return Color(red: 0.10, green: 0.20, blue: 0.70)
        case .miscellaneous: return Color(red: 0.28, green: 0.28, blue: 0.32)
        }
    }

    var iconBackground: Color {
        switch self {
        case .food:          return Color(red: 1.00, green: 0.88, blue: 0.72)
        case .fuel:          return Color(red: 1.00, green: 0.94, blue: 0.72)
        case .shopping:      return Color(red: 1.00, green: 0.80, blue: 0.88)
        case .utilities:     return Color(red: 0.88, green: 0.74, blue: 1.00)
        case .entertainment: return Color(red: 1.00, green: 0.76, blue: 0.78)
        case .travel:        return Color(red: 0.72, green: 0.88, blue: 1.00)
        case .health:        return Color(red: 1.00, green: 0.76, blue: 0.84)
        case .education:     return Color(red: 0.74, green: 0.94, blue: 0.78)
        case .vehicle:       return Color(red: 0.78, green: 0.86, blue: 0.94)
        case .investment:    return Color(red: 0.72, green: 0.96, blue: 0.84)
        case .creditCardBill: return Color(red: 0.74, green: 0.80, blue: 1.00)
        case .miscellaneous: return Color(red: 0.86, green: 0.86, blue: 0.88)
        }
    }
}
