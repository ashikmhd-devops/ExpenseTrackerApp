import SwiftUI

struct QuickAddWidgetView: View {
    @StateObject var viewModel: QuickAddViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Quick Add")
                .font(.title2)
                .bold()
            
            TextField("e.g., Spent $45.50 at Starbucks for coffee today", text: $viewModel.inputText)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Parsing Result:")
                        .font(.headline)
                    Text("Amount: $\(preview.amount, specifier: "%.2f")")
                    Text("Merchant: \(preview.merchant)")
                    Text("Category: \(preview.category.rawValue)")
                    Text("Date: \(preview.date, style: .date)")
                    
                    HStack {
                        Button("Cancel") {
                            viewModel.reset()
                        }
                        .keyboardShortcut(.cancelAction)
                        
                        Button("Save") {
                            viewModel.confirmAndSave()
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.top)
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
