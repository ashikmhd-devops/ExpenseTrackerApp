import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingQuickAdd = false
    
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink(destination: ExpenseListView()) {
                    Label("All Expenses", systemImage: "list.bullet.rectangle")
                }
                
                Section("Summary") {
                    HStack {
                        Text("Spent This Month")
                        Spacer()
                        Text("$\(appViewModel.totalSpentThisMonth, specifier: "%.2f")")
                            .bold()
                    }
                }
            }
            .navigationTitle("Dashboard")
        } detail: {
            ExpenseListView()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingQuickAdd.toggle() }) {
                    Image(systemName: "plus")
                }
                .help("Quick Add Expense")
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddWidgetView(viewModel: QuickAddViewModel(appViewModel: appViewModel))
                .frame(width: 400, height: 300)
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { appViewModel.errorMessage != nil },
            set: { _ in appViewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appViewModel.errorMessage ?? "")
        }
    }
}
