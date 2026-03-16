import SwiftUI

struct EditExpenseView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let expense: Expense

    @State private var merchant: String
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var note: String

    init(expense: Expense) {
        self.expense = expense
        _merchant    = State(initialValue: expense.merchant)
        _amountText  = State(initialValue: String(format: "%.2f", expense.amount))
        _category    = State(initialValue: expense.category)
        _date        = State(initialValue: expense.date)
        _note        = State(initialValue: expense.note ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Expense")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Form
            VStack(spacing: 16) {
                field(label: "Merchant") {
                    TextField("e.g. Swiggy", text: $merchant)
                        .textFieldStyle(.plain)
                }

                field(label: "Amount (₹)") {
                    TextField("0.00", text: $amountText)
                        .textFieldStyle(.plain)
                }

                field(label: "Category") {
                    Picker("", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            HStack {
                                Image(systemName: cat.icon).foregroundColor(cat.iconColor)
                                Text(cat.rawValue)
                            }.tag(cat)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                field(label: "Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                field(label: "Note (optional)") {
                    TextField("Short note", text: $note)
                        .textFieldStyle(.plain)
                }
            }
            .padding(20)

            Divider()

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save Changes") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding(20)
        }
        .frame(width: 380)
    }

    private var isValid: Bool {
        !merchant.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(amountText.filter { $0.isNumber || $0 == "." }) != nil
    }

    private func saveChanges() {
        guard let amount = Double(amountText.filter { $0.isNumber || $0 == "." }), amount > 0 else { return }
        let updated = Expense(
            id: expense.id,
            amount: amount,
            category: category,
            merchant: merchant.trimmingCharacters(in: .whitespaces),
            date: date,
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
        )
        appViewModel.updateExpense(updated)
        dismiss()
    }

    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            content()
                .padding(10)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
