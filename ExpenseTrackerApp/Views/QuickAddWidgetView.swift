import SwiftUI

struct QuickAddWidgetView: View {
    @StateObject var viewModel: QuickAddViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Quick Add")
                .font(.title2)
                .bold()

            HStack(spacing: 8) {
                TextField("e.g., Spent ₹450 at Starbucks for coffee today", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isProcessing)
                    .onSubmit {
                        Task { await viewModel.parseInput() }
                    }

                if viewModel.suggestedExpense != nil {
                    Button(action: { viewModel.applyMagicWand() }) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                            .padding(8)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Pre-fill from history")
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.suggestedExpense != nil)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Parsed Expense")
                        .font(.caption)
                        .foregroundColor(Color(red: 154/255, green: 160/255, blue: 166/255))
                    Spacer()
                    if viewModel.parsedExpensePreview != nil {
                        Button(action: { isEditing.toggle() }) {
                            Text(isEditing ? "Done" : "Edit").font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }

                if let expense = viewModel.parsedExpensePreview {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: expense.category.icon)
                                .foregroundColor(.accentColor)
                        }

                        if isEditing {
                            VStack(alignment: .leading) {
                                TextField("Merchant", text: Binding(
                                    get: { viewModel.parsedExpensePreview?.merchant ?? "" },
                                    set: { viewModel.parsedExpensePreview?.merchant = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)

                                Picker("Category", selection: Binding(
                                    get: { viewModel.parsedExpensePreview?.category ?? .miscellaneous },
                                    set: { viewModel.parsedExpensePreview?.category = $0 }
                                )) {
                                    ForEach(ExpenseCategory.allCases) { category in
                                        Text(category.rawValue).tag(category)
                                    }
                                }
                                .labelsHidden()
                            }
                        } else {
                            VStack(alignment: .leading) {
                                Text(expense.merchant)
                                    .font(.headline)
                                Text(expense.category.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(Color(red: 154/255, green: 160/255, blue: 166/255))
                            }
                        }

                        Spacer()

                        if isEditing {
                            VStack(alignment: .trailing) {
                                TextField("Amount", value: Binding(
                                    get: { viewModel.parsedExpensePreview?.amount ?? 0 },
                                    set: { viewModel.parsedExpensePreview?.amount = $0 }
                                ), format: .currency(code: "INR"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)

                                DatePicker("", selection: Binding(
                                    get: { viewModel.parsedExpensePreview?.date ?? Date() },
                                    set: { viewModel.parsedExpensePreview?.date = $0 }
                                ), displayedComponents: .date)
                                .labelsHidden()
                            }
                        } else {
                            VStack(alignment: .trailing) {
                                Text("₹\(expense.amount, specifier: "%.2f")")
                                    .font(.headline)
                                Text(expense.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(Color(red: 154/255, green: 160/255, blue: 166/255))
                            }
                        }
                    }
                } else {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "ellipsis")
                                .foregroundColor(Color(red: 154/255, green: 160/255, blue: 166/255))
                        }
                        VStack(alignment: .leading) {
                            Text(viewModel.isProcessing ? "Thinking..." : "Waiting for input...")
                                .font(.headline)
                                .foregroundColor(Color(red: 154/255, green: 160/255, blue: 166/255))
                        }
                        Spacer()
                    }
                    .frame(height: 44)
                }

                HStack {
                    Button("Cancel") {
                        if viewModel.parsedExpensePreview != nil {
                            viewModel.reset()
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Save") {
                        viewModel.confirmAndSave()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.parsedExpensePreview == nil || viewModel.isProcessing)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
        .onDisappear {
            viewModel.reset()
            isEditing = false
        }
    }
}
