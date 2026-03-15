import Foundation
import os.log

struct OllamaParseRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let format: String
}

struct OllamaParseResponse: Codable {
    let response: String
}

struct ParsedExpense: Codable {
    let amount: Double
    let category: String
    let merchant: String
    let date: String // ISO8601 string
    let note: String?
}

class OllamaService {
    static let shared = OllamaService()
    
    private let endpoint = URL(string: "http://127.0.0.1:11434/api/generate")!
    private let modelName = "llama3.2:latest"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LocalExpenseTracker", category: "Ollama")
    
    private func resolvedDateContext() -> String {
        let calendar = Calendar.current
        let today = Date()

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Pre-compute "last <weekday>" for all 7 days
        let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let todayWeekday = calendar.component(.weekday, from: today) // 1=Sun, 7=Sat

        var lastWeekdays: [(String, Date)] = []
        for (index, name) in weekdayNames.enumerated() {
            let targetWeekday = index + 1
            var daysBack = todayWeekday - targetWeekday
            if daysBack <= 0 { daysBack += 7 } // always go back, never use today
            let date = calendar.date(byAdding: .day, value: -daysBack, to: today)!
            lastWeekdays.append((name, date))
        }

        var lines = [
            "today = \(isoFormatter.string(from: today))",
            "yesterday = \(isoFormatter.string(from: yesterday))"
        ]
        for (name, date) in lastWeekdays {
            lines.append("last \(name) = \(isoFormatter.string(from: date))")
        }
        return lines.joined(separator: ", ")
    }

    func parseNaturalLanguageExpense(_ input: String) async throws -> Expense {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        let systemPrompt = """
        You are a highly accurate expense parsing assistant. Extract the transaction details from the user's input.
        Output MUST be in strictly valid JSON matching this schema:
        {
          "amount": float, (numeric only, no currency symbols)
          "category": string, (Must be exactly one of: Food (meals/groceries/restaurants), Fuel (petrol/diesel/EV charging), Shopping (clothes/electronics/general retail), Utilities (electricity/water/internet/phone bills), Entertainment (movies/games/subscriptions), Travel (flights/hotels/cabs), Health (doctor/medicine/hospital), Education (school/courses/books), Vehicle (car service/repair/maintenance/insurance), Miscellaneous (anything that doesn't fit above))
          "merchant": string, (The name of the store or service)
          "date": string, (ISO8601 date format YYYY-MM-DD, use this reference to resolve relative dates: \(resolvedDateContext())),
          "note": string (Optional short description or context, leave null if not applicable)
        }
        Do not output markdown, ONLY JSON.
        """
        
        let fullPrompt = "\(systemPrompt)\n\nUser Input: \(input)"
        
        let reqBody = OllamaParseRequest(model: modelName, prompt: fullPrompt, stream: false, format: "json")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(reqBody)
        
        logger.info("Sending request to Ollama: \(input)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaParseResponse.self, from: data)
        let jsonString = ollamaResponse.response
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        
        let parsed: ParsedExpense
        do {
            parsed = try JSONDecoder().decode(ParsedExpense.self, from: jsonData)
        } catch {
            logger.error("Failed to decode JSON. Raw string: \(jsonString)")
            throw NSError(domain: "OllamaService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Ollama JSON: \(jsonString)"])
        }
        
        guard let category = ExpenseCategory(rawValue: parsed.category) else {
            throw NSError(domain: "OllamaService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Category returned from Ollama: \(parsed.category)"])
        }
        
        // Try ISO8601 date-only (YYYY-MM-DD), then full datetime, fallback to today
        let dateOnlyFormatter = ISO8601DateFormatter()
        dateOnlyFormatter.formatOptions = [.withFullDate]
        let fullFormatter = ISO8601DateFormatter()
        let date = dateOnlyFormatter.date(from: parsed.date) ?? fullFormatter.date(from: parsed.date) ?? Date()
        
        return Expense(amount: parsed.amount, category: category, merchant: parsed.merchant, date: date, note: parsed.note)
    }
}
