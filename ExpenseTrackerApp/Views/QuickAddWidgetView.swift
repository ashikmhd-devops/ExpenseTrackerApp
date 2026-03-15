import SwiftUI

struct QuickAddWidgetView: View {
    @StateObject var viewModel: QuickAddViewModel
    @Environment(\.dismiss) var dismiss
    
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
            
            if viewModel.isProcessing {
                ProgressView("Thinking...")
            }
            
            if let preview = viewModel.parsedExpensePreview {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Parsed Expense")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: preview.category.icon)
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading) {
                            Text(preview.merchant)
                                .font(.headline)
                            Text(preview.category.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("₹\(preview.amount, specifier: "%.2f")")
                                .font(.headline)
                            Text(preview.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Button("Cancel") {
                            viewModel.reset()
                        }
                        .keyboardShortcut(.cancelAction)

                        Spacer()

                        Button("Save") {
                            viewModel.confirmAndSave()
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
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
