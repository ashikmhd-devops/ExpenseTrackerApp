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
    private let modelName = "llama3.2:3b"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LocalExpenseTracker", category: "Ollama")
    
    func parseNaturalLanguageExpense(_ input: String) async throws -> Expense {
        let systemPrompt = """
        You are a highly accurate expense parsing assistant. Extract the transaction details from the user's input.
        Output MUST be in strictly valid JSON matching this schema:
        {
          "amount": float, (numeric only, no currency symbols)
          "category": string, (Must be one of: Food, Fuel, Shopping, Utilities, Entertainment, Travel, Health, Education, Miscellaneous)
          "merchant": string, (The name of the store or service)
          "date": string, (ISO8601 format, infer from context if possible, otherwise use today's date),
          "note": string (Optional short description or context, leave null if not applicable)
        }
        Today's date is \(ISO8601DateFormatter().string(from: Date())). Do not output markdown, ONLY JSON.
        """
        
        let fullPrompt = "\(systemPrompt)\n\nUser Input: \(input)"
        
        let reqBody = OllamaParseRequest(model: modelName, prompt: fullPrompt, stream: false, format: "json")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(reqBody)
        
        logger.info("Sending request to Ollama: \\(input)")
        
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
        
        // Try exact ISO8601 first, fallback to today if parsing fails
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: parsed.date) ?? Date()
        
        return Expense(amount: parsed.amount, category: category, merchant: parsed.merchant, date: date, note: parsed.note)
    }
}
