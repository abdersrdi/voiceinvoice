import SwiftUI
import SwiftData

struct InvoiceEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var stores: [StoreProfile]

    @Bindable var invoice: Invoice
    let isNew: Bool

    private var canSave: Bool {
        let hasCustomer = !invoice.customerName.trimmingCharacters(in: .whitespaces).isEmpty
        let hasLine = invoice.sortedLines.contains {
            !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return hasCustomer && hasLine
    }

    var body: some View {
        Form {
            Section("Customer") {
                TextField("Customer name", text: $invoice.customerName)
                    .textContentType(.name)
                TextField("Address", text: $invoice.customerAddress, axis: .vertical)
                    .lineLimit(1...3)
                TextField("Email", text: $invoice.customerEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Items") {
                ForEach(invoice.sortedLines) { line in
                    LineEditorRow(line: line, currencyCode: invoice.currencyCode)
                }
                .onDelete(perform: deleteLines)

                Button {
                    Haptics.tap()
                    addLine()
                } label: {
                    Label("Add item", systemImage: "plus.circle.fill")
                }
            }

            Section("Pricing") {
                HStack {
                    Text("Discount (%)")
                    Spacer()
                    TextField("0", value: $invoice.discountPercent, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
                HStack {
                    Text("Tax (%)")
                    Spacer()
                    TextField("0", value: $invoice.taxRate, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
            }

            Section("Details") {
                DatePicker("Issue date", selection: $invoice.issueDate, displayedComponents: .date)
                Toggle("Due date", isOn: dueDateEnabled)
                if invoice.dueDate != nil {
                    DatePicker("Due", selection: dueDateValue, displayedComponents: .date)
                }
                TextField("Notes or payment terms", text: $invoice.notes, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section {
                totalsBlock
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isNew ? String(localized: "New invoice") : String(localized: "Edit invoice"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { cancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
    }

    private var totalsBlock: some View {
        let totals = invoice.totals
        let code = invoice.currencyCode
        return VStack(spacing: 8) {
            totalRow("Subtotal", totals.subtotal, code)
            if totals.discount > 0 {
                totalRow("Discount", -totals.discount, code)
            }
            if invoice.taxRate > 0 {
                totalRow("Tax", totals.tax, code)
            }
            Divider()
            HStack {
                Text("Total")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Text(Money.string(totals.total, currencyCode: code))
                    .font(Theme.amount(24, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private func totalRow(_ title: LocalizedStringKey, _ value: Double, _ code: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(Money.string(value, currencyCode: code))
                .font(Theme.amount(16, weight: .medium))
        }
    }

    private var dueDateEnabled: Binding<Bool> {
        Binding(
            get: { invoice.dueDate != nil },
            set: { enabled in
                if enabled {
                    invoice.dueDate = invoice.dueDate
                        ?? Calendar.current.date(byAdding: .day, value: 14, to: invoice.issueDate)
                } else {
                    invoice.dueDate = nil
                }
            }
        )
    }

    private var dueDateValue: Binding<Date> {
        Binding(
            get: { invoice.dueDate ?? invoice.issueDate },
            set: { invoice.dueDate = $0 }
        )
    }

    private func addLine() {
        let line = InvoiceLine()
        line.position = (invoice.sortedLines.last?.position ?? -1) + 1
        context.insert(line)
        line.invoice = invoice
    }

    private func deleteLines(at offsets: IndexSet) {
        let current = invoice.sortedLines
        for index in offsets where current.indices.contains(index) {
            context.delete(current[index])
        }
    }

    private func cancel() {
        if isNew {
            context.delete(invoice)
            try? context.save()
        }
        dismiss()
    }

    private func save() {
        for line in invoice.sortedLines
        where line.name.trimmingCharacters(in: .whitespaces).isEmpty && line.unitPrice == 0 {
            context.delete(line)
        }
        if let store = stores.first {
            if invoice.number.isEmpty {
                UsagePolicy.register(in: store)
            }
            InvoiceNumbering.assign(to: invoice, store: store)
        }
        invoice.updatedAt = Date()
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

struct LineEditorRow: View {
    @Bindable var line: InvoiceLine
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Item", text: $line.name)
                .font(.system(.body, design: .rounded, weight: .medium))
            HStack(spacing: 8) {
                TextField("Qty", value: $line.quantity, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(width: 56)
                    .textFieldStyle(.roundedBorder)
                Text("×").foregroundStyle(Theme.secondaryText)
                TextField("Price", value: $line.unitPrice, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(width: 96)
                    .textFieldStyle(.roundedBorder)
                Spacer()
                Text(Money.string(
                    InvoiceMath.lineAmount(quantity: line.quantity, unitPrice: line.unitPrice, currencyCode: currencyCode),
                    currencyCode: currencyCode
                ))
                .font(Theme.amount(16))
            }
        }
        .padding(.vertical, 4)
    }
}
