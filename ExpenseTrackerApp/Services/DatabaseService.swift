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
            logger.error("Failed to initialize database: \(error.localizedDescription)")
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
}
