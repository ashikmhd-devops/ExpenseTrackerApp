import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drop Target Overlay (shown while dragging a file over the window)

struct DropTargetOverlay: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    Color(red: 0.28, green: 0.86, blue: 0.76).opacity(0.9),
                    style: StrokeStyle(lineWidth: 3, dash: [10, 5])
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.28, green: 0.86, blue: 0.76).opacity(0.07))
                )

            VStack(spacing: 14) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(red: 0.28, green: 0.86, blue: 0.76))
                    .symbolEffect(.bounce, options: .repeating)

                Text("Drop Receipt to Scan")
                    .font(.system(size: 18, weight: .semibold))

                Text("PDF or Image · Powered by llava")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .ignoresSafeArea()
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .animation(.easeInOut(duration: 0.15), value: true)
    }
}

// MARK: - Processing Card (sparkle animation while llava reads the file)

struct ProcessingReceiptCard: View {
    let fileName: String

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<7, id: \.self) { i in
                            let symbols = ["sparkle", "sparkles", "sparkle", "star.fill", "sparkles", "sparkle", "star.fill"]
                            let sizes: [CGFloat] = [13, 17, 11, 14, 18, 12, 15]
                            let colors: [Color] = [.yellow, Color(red: 0.28, green: 0.86, blue: 0.76), .orange, .yellow, Color(red: 0.28, green: 0.86, blue: 0.76), .orange, .yellow]
                            let angle = t * 1.3 + Double(i) * (.pi * 2 / 7)
                            Image(systemName: symbols[i])
                                .font(.system(size: sizes[i]))
                                .foregroundColor(colors[i])
                                .offset(x: cos(angle) * 44, y: sin(angle) * 32)
                                .opacity(0.35 + 0.65 * abs(sin(t * 1.8 + Double(i) * 0.9)))
                                .rotationEffect(.degrees(t * 50))
                        }
                    }
                }

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.accentColor)
            }
            .frame(width: 120, height: 100)

            VStack(spacing: 6) {
                Text("Reading Receipt…")
                    .font(.system(size: 16, weight: .semibold))
                Text(fileName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 220)
            }

            ProgressView()
                .scaleEffect(0.85)

            Text("llava is extracting merchant, total & items")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 10)
    }
}

// MARK: - Scanned Receipt Confirm Sheet

struct ScannedReceiptConfirmView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let parsed: ParsedExpense

    @State private var merchant: String
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var note: String

    init(parsed: ParsedExpense) {
        self.parsed = parsed
        _merchant   = State(initialValue: parsed.merchant)
        _amountText = State(initialValue: String(format: "%.2f", parsed.amount))
        _category   = State(initialValue: ExpenseCategory(rawValue: parsed.category) ?? .miscellaneous)
        let isoFmt  = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate]
        let d = isoFmt.date(from: parsed.date) ?? Date()
        _date = State(initialValue: d)
        _note = State(initialValue: parsed.note ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Receipt Scanned")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Review and save, or edit any field")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    appViewModel.scannedExpense = nil
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Preview row
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(category.iconBackground)
                        .frame(width: 44, height: 44)
                    Image(systemName: category.icon)
                        .foregroundColor(category.iconColor)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(merchant.isEmpty ? "Unknown Merchant" : merchant.capitalized)
                        .font(.system(size: 15, weight: .semibold))
                    Text(category.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("₹\(amountText)")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(0.05))

            Divider()

            // Editable fields
            VStack(spacing: 14) {
                field("Merchant") {
                    TextField("Merchant name", text: $merchant)
                        .textFieldStyle(.plain)
                }
                field("Amount (₹)") {
                    TextField("0.00", text: $amountText)
                        .textFieldStyle(.plain)
                }
                field("Category") {
                    Picker("", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                field("Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                field("Note (optional)") {
                    TextField("What was purchased?", text: $note)
                        .textFieldStyle(.plain)
                }
            }
            .padding(20)

            Divider()

            HStack(spacing: 12) {
                Button("Discard") {
                    appViewModel.scannedExpense = nil
                    dismiss()
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Save Expense") { saveExpense() }
                    .buttonStyle(.borderedProminent)
                    .disabled(merchant.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 400)
    }

    private var isValid: Bool {
        !merchant.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0) > 0
    }

    private func saveExpense() {
        let amount = Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0
        guard amount > 0 else { return }
        appViewModel.addExpense(Expense(
            amount: amount,
            category: category,
            merchant: merchant.trimmingCharacters(in: .whitespaces),
            date: date,
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
        ))
        appViewModel.scannedExpense = nil
        dismiss()
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
