import SwiftUI

@main
struct ExpenseTrackerApp: App {
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainDashboardView()
                .environmentObject(appViewModel)
        }
        .windowStyle(.hiddenTitleBar)
        
        // This gives us the persistent menu bar extra logic!
        MenuBarExtra("Expense Tracker", systemImage: "dollarsign.circle") {
            QuickAddWidgetView(viewModel: QuickAddViewModel(appViewModel: appViewModel))
                .environmentObject(appViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
