import SwiftUI

struct QuickAddWidgetView: View {
    @StateObject var viewModel: QuickAddViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isEditing: Bool = false
    
    private var expenseBinding: Binding<Expense>? {
        guard let _ = viewModel.parsedExpensePreview else { return nil }
        return Binding(
            get: { viewModel.parsedExpensePreview! },
            set: { viewModel.parsedExpensePreview = $0 }
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Quick Add")
                .font(.title2)
                .bold()
            
            TextField("e.g., Spent ₹450 at Starbucks for coffee today", text: $viewModel.inputText)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isProcessing)
                .onSubmit {
                    Task {
                        await viewModel.parseInput()
                    }
                }
            
            // We remove the separate ProgressView and placeholder logic to integrate it into the card directly
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Parsed Expense")
                        .font(.caption)
                        .foregroundColor(Color(red: 154/255, green: 160/255, blue: 166/255))
                    
                    Spacer()
                    
                    if viewModel.parsedExpensePreview != nil {
                        Button(action: {
                            isEditing.toggle()
                        }) {
                            Text(isEditing ? "Done" : "Edit")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }

                if let binding = expenseBinding {
                    let preview = binding.wrappedValue
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: preview.category.icon)
                                .foregroundColor(.accentColor)
                        }

                        if isEditing {
                            VStack(alignment: .leading) {
                                TextField("Merchant", text: binding.merchant)
                                    .textFieldStyle(.roundedBorder)
                                Picker("Category", selection: binding.category) {
                                    ForEach(ExpenseCategory.allCases) { category in
                                        Text(category.rawValue).tag(category)
                                    }
                                }
                                .labelsHidden()
                            }
                        } else {
                            VStack(alignment: .leading) {
                                Text(preview.merchant)
                                    .font(.headline)
                                Text(preview.category.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(Color(red: 154/255, green: 160/255, blue: 166/255))
                            }
                        }

                        Spacer()

                        if isEditing {
                            VStack(alignment: .trailing) {
                                TextField("Amount", value: binding.amount, format: .currency(code: "INR"))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 90)
                                DatePicker("", selection: binding.date, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        } else {
                            VStack(alignment: .trailing) {
                                Text("₹\(preview.amount, specifier: "%.2f")")
                                    .font(.headline)
                                Text(preview.date, style: .date)
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
    }
}
