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
        let todayWeekday = calendar.component(.weekday, from: today)

        var lastWeekdays: [(String, Date)] = []
        for (index, name) in weekdayNames.enumerated() {
            let targetWeekday = index + 1
            var daysBack = todayWeekday - targetWeekday
            if daysBack <= 0 { daysBack += 7 }
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

    /// If the LLM returns a future date (more than 1 day from now), roll it back one year.
    /// This handles "Feb 28th" being mapped to next year instead of the most recent past occurrence.
    private func mostRecentPast(_ date: Date) -> Date {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: 1, to: Date())!
        guard date > cutoff else { return date }
        return calendar.date(byAdding: .year, value: -1, to: date) ?? date
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
          "date": string, (ISO8601 date format YYYY-MM-DD. Reference: \(resolvedDateContext()). For month/day without a year (e.g. "Feb 28th", "March 5"): if that date has already passed this year use this year, if it has not yet occurred this year use last year. NEVER output a future date unless the user explicitly says "next".),
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
        let rawDate = dateOnlyFormatter.date(from: parsed.date) ?? fullFormatter.date(from: parsed.date) ?? Date()
        let date = mostRecentPast(rawDate)
        
        return Expense(amount: parsed.amount, category: category, merchant: parsed.merchant, date: date, note: parsed.note)
    }
    
    func generateInsights(for expenses: [Expense]) async throws -> String {
        guard !expenses.isEmpty else { return "No expenses to analyze." }
        
        // Summarize by category
        var categoryTotals: [String: Double] = [:]
        for expense in expenses {
            categoryTotals[expense.category.rawValue, default: 0] += expense.amount
        }
        
        let summaryLines = categoryTotals.map { "\($0.key): ₹\(String(format: "%.2f", $0.value))" }
        let summaryString = summaryLines.joined(separator: "\n")
        
        let systemPrompt = """
        You are an insightful financial advisor. Analyze the user's spending category summary and provide 2-3 short, actionable, and encouraging sentences of advice or observation. Keep it concise.
        """
        
        let fullPrompt = "\(systemPrompt)\n\nSpending Summary:\n\(summaryString)"
        
        let reqBody = OllamaParseRequest(model: modelName, prompt: fullPrompt, stream: false, format: "")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(reqBody)
        
        logger.info("Sending insights request to Ollama")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaParseResponse.self, from: data)
        return ollamaResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func generateSQLQuery(from input: String) async throws -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        let systemPrompt = """
        You are a highly accurate SQLite data extraction assistant.
        Convert the user's natural language question into a valid SQLite query.
        
        The database contains a single table named `expense` with the following schema:
        - `id` (TEXT, Primary Key)
        - `amount` (REAL, not null)
        - `category` (TEXT, not null - e.g., 'Food', 'Fuel', 'Shopping')
        - `merchant` (TEXT, not null)
        - `date` (DATETIME, not null, format: 'YYYY-MM-DD HH:MM:SS.SSS')
        - `note` (TEXT)
        
        Today's date is \(todayStr).
        
        Rules:
        1. Output ONLY the raw SQL query. Do NOT wrap it in markdown blockquotes like ` ```sql `. Do NOT provide any explanation.
        2. Use aggregate functions (SUM, AVG, COUNT) if the user asks for totals, averages, or counts. ALWAYS wrap SUM with COALESCE to return 0 instead of NULL, e.g., `COALESCE(SUM(amount), 0)`.
        3. Use simple, standard SQLite syntax.
        4. When comparing dates, DO NOT use `LIKE '%/%/1%'`. Use `strftime('%m', date) = '01'` or strict date boundaries `date >= '2023-01-01' AND date < '2023-02-01'`.
        5. Return exactly the query, starting with SELECT.
        
        Example Input: "How much did I spend on Food this month?"
        Example Output: SELECT COALESCE(SUM(amount), 0) FROM expense WHERE category = 'Food' AND date >= date('now', 'start of month');
        """
        
        let fullPrompt = "\(systemPrompt)\n\nUser Question: \(input)"
        let reqBody = OllamaParseRequest(model: modelName, prompt: fullPrompt, stream: false, format: "")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(reqBody)
        
        logger.info("Sending SQL generation request to Ollama: \(input)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaParseResponse.self, from: data)
        
        // Strip out any markdown code blocks the LLM might have stubbornly added anyway
        var sql = ollamaResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)
        if sql.hasPrefix("```sql") { sql.removeFirst(6) }
        if sql.hasPrefix("```") { sql.removeFirst(3) }
        if sql.hasSuffix("```") { sql.removeLast(3) }
        
        return sql.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
