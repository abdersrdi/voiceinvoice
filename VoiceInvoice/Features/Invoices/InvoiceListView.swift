import SwiftUI
import SwiftData

struct EditorRoute: Identifiable {
    let invoice: Invoice
    var id: PersistentModelID { invoice.persistentModelID }
}

struct InvoiceListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Invoice.issueDate, order: .reverse) private var invoices: [Invoice]
    @Query private var stores: [StoreProfile]

    @State private var search = ""
    @State private var route: EditorRoute?

    private var store: StoreProfile? { stores.first }

    private var filtered: [Invoice] {
        let term = search.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return invoices }
        return invoices.filter {
            $0.number.localizedCaseInsensitiveContains(term)
                || $0.customerName.localizedCaseInsensitiveContains(term)
        }
    }

    private var monthInvoices: [Invoice] {
        invoices.filter { Calendar.current.isDate($0.issueDate, equalTo: Date(), toGranularity: .month) }
    }

    private var monthTotal: Double {
        let code = store?.currencyCode ?? "USD"
        return monthInvoices.filter { $0.currencyCode == code }.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    summaryCard

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered) { invoice in
                            NavigationLink(value: invoice) {
                                InvoiceRow(invoice: invoice)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    context.delete(invoice)
                                    try? context.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Invoices")
            .searchable(text: $search, prompt: "Search invoices")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Haptics.tap()
                        newInvoice()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("New invoice")
                }
            }
            .navigationDestination(for: Invoice.self) { invoice in
                InvoiceDetailView(invoice: invoice)
            }
            .sheet(item: $route) { route in
                NavigationStack {
                    InvoiceEditorView(invoice: route.invoice, isNew: true)
                }
                .interactiveDismissDisabled()
            }
        }
    }

    private var summaryCard: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("This month")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                Text(Money.string(monthTotal, currencyCode: store?.currencyCode ?? "USD"))
                    .font(Theme.amount(38, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(monthInvoices.count) invoices")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.glacier)
            }
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Theme.secondaryText)
            Text(search.isEmpty ? "No invoices yet" : "No results")
                .font(.system(.headline, design: .rounded))
            if search.isEmpty {
                Text("Tap + to create your first invoice.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func newInvoice() {
        guard let store else { return }
        let invoice = Invoice()
        invoice.currencyCode = store.currencyCode
        invoice.taxRate = store.defaultTaxRate
        context.insert(invoice)
        route = EditorRoute(invoice: invoice)
    }
}

struct InvoiceRow: View {
    let invoice: Invoice

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.customerName.isEmpty ? String(localized: "No customer") : invoice.customerName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(invoice.number.isEmpty ? String(localized: "Draft") : invoice.number)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                Text(invoice.issueDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
                Text(Money.string(invoice.total, currencyCode: invoice.currencyCode))
                    .font(Theme.amount(18))
                    .foregroundStyle(.primary)
                StatusPill(status: invoice.status)
            }
        }
        .cardStyle()
    }
}
