import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingQuickAdd = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                summaryBanner
                Divider()
                ExpenseListView()
            }
            fab
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

    // MARK: - Summary Banner

    private var summaryBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Spent This Month")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text("₹\(appViewModel.totalSpentThisMonth, specifier: "%.2f")")
                    .font(.system(size: 28, weight: .bold))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - FAB

    private var fab: some View {
        Button(action: { showingQuickAdd = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add Expense")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(red: 0.04, green: 0.14, blue: 0.22))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(red: 0.28, green: 0.86, blue: 0.76))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .padding(24)
        .help("Quick Add Expense")
        .keyboardShortcut("n", modifiers: .command)
    }
}
