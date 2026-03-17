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

// MARK: - Chat API (Ollama /api/chat)

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
}

struct OllamaChatResponse: Codable {
    let message: OllamaChatMessage
}

// MARK: - Vision API

struct OllamaVisionRequest: Codable {
    let model: String
    let prompt: String
    let images: [String]
    let stream: Bool
    let format: String
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

        let hour = calendar.component(.hour, from: today)
        let timeOfDay: String
        switch hour {
        case 5..<12:  timeOfDay = "morning (\(hour):00)"
        case 12..<17: timeOfDay = "afternoon (\(hour):00)"
        case 17..<21: timeOfDay = "evening (\(hour):00)"
        default:      timeOfDay = "night (\(hour):00)"
        }

        var lines = [
            "today = \(isoFormatter.string(from: today))",
            "time_of_day = \(timeOfDay)",
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
          "category": string, (Must be exactly one of: Food (meals/groceries/restaurants), Fuel (petrol/diesel/EV charging — use amount and time_of_day for ambiguous merchants: e.g. "Shell"/"BP"/"HPCL" at ₹800–3000 during morning is likely Groceries/Food, but at ₹1500+ afternoon/evening is likely Fuel; "Indian Oil"/"Bharat Petroleum" is almost always Fuel), Shopping (clothes/electronics/general retail), Utilities (electricity/water/internet/phone bills), Entertainment (movies/games/subscriptions), Travel (flights/hotels/cabs), Health (doctor/medicine/hospital), Education (school/courses/books), Vehicle (car service/repair/maintenance/insurance), Investment (mutual funds/SIP/stocks/shares/bonds/crypto/demat/trading), Credit Card Bill (credit card payment/bill/outstanding/due), Miscellaneous (anything that doesn't fit above))
          "merchant": string, (The name of the store or service)
          "date": string, (ISO8601 date format YYYY-MM-DD. Reference: \(resolvedDateContext()). YEAR RULE: if the user does not mention a year, ALWAYS assume the most recent past occurrence. For month/day (e.g. "Feb 28th", "March 5"): if that date has already passed this year use this year; if it has not yet occurred this year use last year. NEVER output a future date unless the user explicitly says "next" or "upcoming".),
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
        
        // Normalize: capitalize first letter so "investment" matches "Investment"
        let normalizedCategory = parsed.category.prefix(1).uppercased() + parsed.category.dropFirst()
        guard let category = ExpenseCategory(rawValue: normalizedCategory)
                          ?? ExpenseCategory.allCases.first(where: { $0.rawValue.lowercased() == parsed.category.lowercased() }) else {
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

    // MARK: - Contextual Chat

    func chat(messages: [ChatMessage], expenses: [Expense]) async throws -> String {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear  = calendar.component(.year, from: now)

        let monthExpenses = expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year,  from: $0.date) == currentYear
        }

        var categoryTotals: [String: Double] = [:]
        for expense in monthExpenses {
            categoryTotals[expense.category.rawValue, default: 0] += expense.amount
        }
        let totalThisMonth = monthExpenses.reduce(0) { $0 + $1.amount }

        let monthName = DateFormatter().monthSymbols[currentMonth - 1]
        let breakdown = categoryTotals
            .sorted { $0.value > $1.value }
            .map { "  \($0.key): ₹\(String(format: "%.0f", $0.value))" }
            .joined(separator: "\n")

        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate]
        let recentLines = expenses.prefix(15).map {
            "  \($0.merchant) (\($0.category.rawValue)) ₹\(String(format: "%.0f", $0.amount)) on \(isoFmt.string(from: $0.date))"
        }.joined(separator: "\n")

        let systemContent = """
        You are a smart personal finance assistant built into an expense tracker app. \
        You have full access to the user's actual spending data. Be conversational, insightful, \
        and proactive. When relevant, suggest specific budget limits based on their real data. \
        Use context to interpret ambiguous items — for example "Shell" could be Fuel or Groceries \
        depending on the amount and time of day. Keep replies concise (2–4 sentences unless more \
        detail is asked). Always use ₹ for currency.

        === Spending this month (\(monthName) \(currentYear)) ===
        Total: ₹\(String(format: "%.0f", totalThisMonth))
        \(breakdown.isEmpty ? "  No expenses yet." : breakdown)

        === Recent expenses (up to 15) ===
        \(recentLines.isEmpty ? "  None." : recentLines)
        """

        var apiMessages: [OllamaChatMessage] = [
            OllamaChatMessage(role: "system", content: systemContent)
        ]
        for msg in messages {
            apiMessages.append(OllamaChatMessage(
                role: msg.role == .user ? "user" : "assistant",
                content: msg.content
            ))
        }

        let chatEndpoint = URL(string: "http://127.0.0.1:11434/api/chat")!
        let reqBody = OllamaChatRequest(model: modelName, messages: apiMessages, stream: false)
        var request = URLRequest(url: chatEndpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(reqBody)

        logger.info("Sending chat request to Ollama (\(messages.count) messages)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return chatResponse.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Category Spending Insight

    /// Generates a 1–2 sentence AI insight for a specific category based on its last N months of spending.
    /// - Parameters:
    ///   - category: The expense category name (e.g. "Food").
    ///   - monthlyTotals: Array of (label: "Mar", total: 4200.0) sorted oldest → newest.
    func generateCategoryInsight(category: String, monthlyTotals: [(label: String, total: Double)]) async throws -> String {
        guard !monthlyTotals.isEmpty else { return "No data available for \(category) yet." }

        let breakdown = monthlyTotals
            .map { "  \($0.label): ₹\(String(format: "%.0f", $0.total))" }
            .joined(separator: "\n")

        let currentMonth = monthlyTotals.last?.label ?? ""
        let currentTotal = monthlyTotals.last?.total ?? 0
        let prevTotal    = monthlyTotals.dropLast().last?.total ?? 0

        var trend = ""
        if prevTotal > 0 {
            let pct = ((currentTotal - prevTotal) / prevTotal) * 100
            if abs(pct) < 2 {
                trend = "Spending is roughly the same as last month."
            } else if pct > 0 {
                trend = "Spending is up \(String(format: "%.0f", pct))% compared to last month."
            } else {
                trend = "Spending is down \(String(format: "%.0f", abs(pct)))% compared to last month."
            }
        }

        let prompt = """
        You are a friendly personal finance assistant. The user just opened their \(category) spending history.
        Here is their spending for the last few months:
        \(breakdown)

        Current month (\(currentMonth)): ₹\(String(format: "%.0f", currentTotal)). \(trend)

        Write exactly 1–2 encouraging, specific sentences summarising the trend and giving a brief actionable tip. \
        Do NOT repeat the raw numbers back verbatim. Respond in plain text only (no markdown, no bullet points).
        """

        let reqBody = OllamaParseRequest(model: modelName, prompt: prompt, stream: false, format: "")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(reqBody)
        request.timeoutInterval = 60

        logger.info("Sending category insight request for \(category)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let ollamaResponse = try JSONDecoder().decode(OllamaParseResponse.self, from: data)
        return ollamaResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Receipt Vision Scanning

    func extractExpenseFromReceipt(imageBase64: String) async throws -> ParsedExpense {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        let todayStr = isoFormatter.string(from: Date())

        let prompt = """
        You are a transaction extraction assistant. The image may be ANY of:
        - A physical or digital receipt
        - A bank SMS or email notification
        - A UPI/IMPS/NEFT debit alert (e.g. from HDFC, SBI, ICICI, Paytm, PhonePe)
        - A credit card statement row or screenshot

        INSTRUCTIONS — READ EVERY WORD IN THE IMAGE CAREFULLY. Do NOT guess or invent values.

        1. AMOUNT: Look for "Rs.", "₹", "INR", "debited", "amount", "total", "paid". Extract the numeric value only (e.g. 199.00).
        2. MERCHANT:
           - For a UPI VPA like "netflixupi.payu@hdfcbank" → extract "Netflix"
           - For "SWIGGY.COM", "ZOMATO", "AMAZON PAY" → use the brand name
           - For a shop receipt → use the store name at the top
           - Clean up: strip .COM, PAY, UPI, bank suffixes; capitalize properly
        3. DATE: Common Indian bank formats → convert to YYYY-MM-DD:
           - "16-03-26" or "16/03/26" = DD-MM-YY → 2026-03-16
           - "16-03-2026" = DD-MM-YYYY → 2026-03-16
           - "Mar 16, 2026" → 2026-03-16
           - Use \(todayStr) only if no date is visible at all
        4. CATEGORY — pick the single best match:
           - Food: restaurants, food delivery, grocery, Swiggy, Zomato, BigBasket
           - Fuel: petrol, diesel, HPCL, BPCL, IndianOil, Shell fuel
           - Shopping: Amazon, Flipkart, Myntra, clothing, electronics
           - Utilities: electricity, water, gas, internet, mobile recharge, JIO, Airtel, BSNL
           - Entertainment: Netflix, Spotify, YouTube Premium, OTT, movies, games
           - Travel: flights, hotels, Uber, Ola, MakeMyTrip, IRCTC, train, cab
           - Health: pharmacy, hospital, doctor, MedPlus, Apollo
           - Education: courses, school fees, books
           - Vehicle: car service, insurance, RTO, repair
           - Investment: mutual funds, SIP, stocks, shares, bonds, crypto, demat
           - Credit Card Bill: credit card payment, bill payment, outstanding due, HDFC card, ICICI card, SBI card, Axis card
           - Miscellaneous: anything else
        5. NOTE: One sentence describing what it is (e.g. "Monthly Netflix Premium subscription").

        Output ONLY valid JSON, no other text:
        {
          "amount": <number>,
          "category": "<category>",
          "merchant": "<clean merchant name>",
          "date": "<YYYY-MM-DD>",
          "note": "<description or null>"
        }
        """

        let reqBody = OllamaVisionRequest(model: "llava:latest", prompt: prompt, images: [imageBase64], stream: false, format: "json")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(reqBody)
        request.timeoutInterval = 120

        logger.info("Sending vision request to Ollama (llava)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaService", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Vision model unavailable. Run: ollama pull llava"])
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaParseResponse.self, from: data)
        guard let jsonData = ollamaResponse.response.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }

        do {
            return try JSONDecoder().decode(ParsedExpense.self, from: jsonData)
        } catch {
            logger.error("Vision: failed to decode. Raw: \(ollamaResponse.response)")
            throw NSError(domain: "OllamaService", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "Could not parse receipt scan result. Try a clearer image."])
        }
    }
}
