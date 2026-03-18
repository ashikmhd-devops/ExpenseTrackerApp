import Foundation
import GRDB
import os.log

class DatabaseService {
    static let shared = DatabaseService()
    
    private var dbWriter: DatabaseWriter!
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LocalExpenseTracker", category: "Database")
    
    private init() {
        do {
            try setupDatabase()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }
    
    private func setupDatabase() throws {
        // App Support directory for storing the database locally
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        // Create an app-specific folder
        let bundleID = Bundle.main.bundleIdentifier ?? "com.local.ExpenseTracker"
        let appDirectoryURL = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        
        if !fileManager.fileExists(atPath: appDirectoryURL.path) {
            try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        let databaseURL = appDirectoryURL.appendingPathComponent("expenses.sqlite")
        
        // Connect to the database
        dbWriter = try DatabasePool(path: databaseURL.path)
        
        // Migrate schema
        try migrator.migrate(dbWriter)
        logger.info("Database initialized at \(databaseURL.path)")
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1") { db in
            try db.create(table: "expense") { t in
                t.column("id", .text).primaryKey()
                t.column("amount", .double).notNull()
                t.column("category", .text).notNull()
                t.column("merchant", .text).notNull()
                t.column("date", .datetime).notNull()
                t.column("note", .text)
            }
        }
        
        return migrator
    }
    
    // MARK: - CRUD Operations
    
    func saveExpense(_ expense: Expense) throws {
        try dbWriter.write { db in
            try expense.save(db)
        }
    }
    
    func fetchAllExpenses() throws -> [Expense] {
        try dbWriter.read { db in
            try Expense.order(Column("date").desc).fetchAll(db)
        }
    }
    
    func deleteExpense(_ expense: Expense) throws {
        try dbWriter.write { db in
            _ = try expense.delete(db)
        }
    }

    func clearAllExpenses() throws {
        try dbWriter.write { db in
            _ = try Expense.deleteAll(db)
        }
    }
    
    // MARK: - Raw SQL Execution

    enum QueryValidationError: LocalizedError {
        case notSelectStatement
        case forbiddenKeyword(String)
        case forbiddenTable(String)

        var errorDescription: String? {
            switch self {
            case .notSelectStatement:
                return "Only SELECT queries are allowed."
            case .forbiddenKeyword(let kw):
                return "Query contains forbidden keyword: \(kw)"
            case .forbiddenTable(let t):
                return "Query references forbidden table: \(t)"
            }
        }
    }

    /// Validates that a LLM-generated SQL string is a read-only SELECT against
    /// the `expense` table only. Throws `QueryValidationError` on any violation.
    private func validateSelectQuery(_ sql: String) throws {
        let normalized = sql
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        // Must start with SELECT (case-insensitive)
        guard normalized.uppercased().hasPrefix("SELECT") else {
            throw QueryValidationError.notSelectStatement
        }

        // Tokenize by splitting on non-alphanumeric boundaries for keyword matching
        let upperSQL = normalized.uppercased()

        // Block any write or schema-manipulation keyword
        let forbidden = [
            "INSERT", "UPDATE", "DELETE", "DROP", "CREATE", "ALTER",
            "ATTACH", "DETACH", "PRAGMA", "VACUUM", "REINDEX",
            "REPLACE", "TRUNCATE", "RENAME", "GRANT", "REVOKE",
            "BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT",
            "--", "/*", ";"
        ]
        for kw in forbidden {
            // Use word-boundary check: keyword must not be part of a longer token
            let pattern = "(^|[^A-Z0-9_])\(NSRegularExpression.escapedPattern(for: kw))([^A-Z0-9_]|$)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: upperSQL, range: NSRange(upperSQL.startIndex..., in: upperSQL)) != nil {
                throw QueryValidationError.forbiddenKeyword(kw)
            }
        }

        // Only allow querying the `expense` table
        let allowedTables: Set<String> = ["EXPENSE"]
        // Extract identifiers that follow FROM or JOIN
        let fromJoinPattern = "(?:FROM|JOIN)\\s+([A-Z_][A-Z0-9_]*)"
        if let regex = try? NSRegularExpression(pattern: fromJoinPattern) {
            let matches = regex.matches(in: upperSQL, range: NSRange(upperSQL.startIndex..., in: upperSQL))
            for match in matches {
                if let range = Range(match.range(at: 1), in: upperSQL) {
                    let tableName = String(upperSQL[range])
                    if !allowedTables.contains(tableName) {
                        throw QueryValidationError.forbiddenTable(tableName.lowercased())
                    }
                }
            }
        }
    }

    func executeRawQuery(_ sql: String) throws -> [[String: String]] {
        try validateSelectQuery(sql)
        return try dbWriter.read { db in
            let rows = try Row.fetchAll(db, sql: sql)
            var result: [[String: String]] = []
            
            for row in rows {
                var rowDict: [String: String] = [:]
                for (columnName, databaseValue) in row {
                    if let value = String.fromDatabaseValue(databaseValue) {
                        rowDict[columnName] = value
                    } else if let value = Double.fromDatabaseValue(databaseValue) {
                        rowDict[columnName] = String(value)
                    } else if let value = Int64.fromDatabaseValue(databaseValue) {
                        rowDict[columnName] = String(value)
                    } else {
                        // For nulls or other types, we can use an empty string or literal "null"
                        rowDict[columnName] = databaseValue.isNull ? "NULL" : String(describing: databaseValue)
                    }
                }
                result.append(rowDict)
            }
            return result
        }
    }
}
