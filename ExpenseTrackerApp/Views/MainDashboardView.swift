import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingQuickAdd = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ZStack(alignment: .bottomTrailing) {
                ExpenseListView()
                fab
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddWidgetView(viewModel: QuickAddViewModel(appViewModel: appViewModel))
                .frame(width: 420, height: 340)
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

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            summaryCard
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 8)

            List {
                NavigationLink(destination: ExpenseListView()) {
                    Label("All Expenses", systemImage: "list.bullet.rectangle")
                        .font(.system(size: 13, weight: .medium))
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.accentColor.opacity(0.15))
                        .padding(.horizontal, 4)
                )
            }
            .listStyle(.sidebar)

            Spacer()
        }
        .navigationTitle("Dashboard")
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Spent This Month")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.5)
            Text("₹\(appViewModel.totalSpentThisMonth, specifier: "%.2f")")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.18, blue: 0.78), Color(red: 0.44, green: 0.18, blue: 0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - FAB

    private var fab: some View {
        Button(action: { showingQuickAdd = true }) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.25))
                .frame(width: 52, height: 52)
                .background(Color(red: 0.28, green: 0.86, blue: 0.76))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(24)
        .help("Quick Add Expense")
        .keyboardShortcut("n", modifiers: .command)
    }
}
