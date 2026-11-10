import SwiftUI
import SwiftData

struct EditorRoute: Identifiable {
    let invoice: Invoice
    var id: PersistentIdentifier { invoice.persistentModelID }
}

struct InvoiceListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Invoice.issueDate, order: .reverse) private var invoices: [Invoice]
    @Query private var stores: [StoreProfile]
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(AppRouter.self) private var router

    @State private var showPaywall = false
    @State private var search = ""
    @State private var route: EditorRoute?
    @State private var showDictation = false
    @State private var showCounter = false
    @State private var statusFilter: InvoiceStatus?
    @State private var pendingRoute: EditorRoute?
    @State private var invoiceToDelete: Invoice?

    private var store: StoreProfile? { stores.first }

    private var filtered: [Invoice] {
        let term = search.trimmingCharacters(in: .whitespaces)
        return invoices.filter { invoice in
            if let statusFilter, invoice.status != statusFilter { return false }
            guard !term.isEmpty else { return true }
            return invoice.number.localizedCaseInsensitiveContains(term)
                || invoice.customerName.localizedCaseInsensitiveContains(term)
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

                    statusFilterBar

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered) { invoice in
                            NavigationLink(value: invoice) {
                                InvoiceRow(invoice: invoice)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    duplicate(invoice)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                Button(role: .destructive) {
                                    invoiceToDelete = invoice
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
            .overlay(alignment: .bottomTrailing) { dictateButton }
            .navigationTitle("Invoices")
            .searchable(text: $search, prompt: "Search invoices")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.tap()
                        guard allowCreation() else { return }
                        showCounter = true
                    } label: {
                        Image(systemName: "ear.badge.waveform")
                    }
                    .accessibilityLabel("Counter mode")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Haptics.tap()
                        guard allowCreation() else { return }
                        newInvoice()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("New invoice")
                }
            }
            .onAppear { consumeDictationRequest() }
            .onChange(of: router.dictationRequested) { _, _ in consumeDictationRequest() }
            .onChange(of: snapshotToken, initial: true) { _, _ in
                SnapshotWriter.update(invoices: invoices, store: store, isPro: subscriptions.isPro)
            }
            .navigationDestination(for: Invoice.self) { invoice in
                InvoiceDetailView(invoice: invoice)
            }
            .sheet(isPresented: $showDictation, onDismiss: {
                if let pending = pendingRoute {
                    route = pending
                    pendingRoute = nil
                }
            }) {
                DictationView(currencyCode: store?.currencyCode ?? "USD") { items, speaker in
                    pendingRoute = makeRoute(from: items, speaker: speaker)
                }
            }
            .confirmationDialog(
                "Delete this invoice?",
                isPresented: Binding(get: { invoiceToDelete != nil }, set: { if !$0 { invoiceToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let invoice = invoiceToDelete {
                        context.delete(invoice)
                        try? context.save()
                    }
                    invoiceToDelete = nil
                }
                Button("Cancel", role: .cancel) { invoiceToDelete = nil }
            } message: {
                Text("This can't be undone.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(limitReached: !UsagePolicy.canCreate(store: store, isPro: subscriptions.isPro))
            }
            .fullScreenCover(isPresented: $showCounter, onDismiss: presentPendingRoute) {
                CounterModeView(currencyCode: store?.currencyCode ?? "USD") { items, speaker in
                    pendingRoute = makeRoute(from: items, speaker: speaker)
                }
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
                if !subscriptions.isPro, let store {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("\(UsagePolicy.remaining(in: store)) of \(UsagePolicy.freeMonthlyLimit) free invoices left", systemImage: "crown.fill")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.16), in: Capsule())
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Theme.secondaryText)
            Text(search.isEmpty ? String(localized: "No invoices yet") : String(localized: "No results"))
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

    private var dictateButton: some View {
        Button {
            Haptics.tap()
            guard allowCreation() else { return }
            showDictation = true
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Theme.heroGradient, in: Circle())
                .shadow(color: Theme.burgundy.opacity(0.45), radius: 14, x: 0, y: 8)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel("Dictate an invoice")
    }

    /// Changes whenever something the widget shows changes.
    private var snapshotToken: Int {
        var hasher = Hasher()
        for invoice in invoices {
            hasher.combine(invoice.updatedAt)
            hasher.combine(invoice.number)
        }
        hasher.combine(subscriptions.isPro)
        hasher.combine(store?.usageCount ?? 0)
        hasher.combine(store?.currencyCode ?? "")
        return hasher.finalize()
    }

    private func consumeDictationRequest() {
        guard router.dictationRequested, store != nil else { return }
        router.dictationRequested = false
        if allowCreation() { showDictation = true }
    }

    private var statusFilterBar: some View {
        Picker("Status", selection: $statusFilter) {
            Text("All").tag(InvoiceStatus?.none)
            ForEach(InvoiceStatus.allCases) { status in
                Text(status.title).tag(Optional(status))
            }
        }
        .pickerStyle(.segmented)
    }

    private func presentPendingRoute() {
        if let pending = pendingRoute {
            route = pending
            pendingRoute = nil
        }
    }

    private func allowCreation() -> Bool {
        if UsagePolicy.canCreate(store: store, isPro: subscriptions.isPro) { return true }
        showPaywall = true
        return false
    }

    private func makeInvoice() -> Invoice? {
        guard let store else { return nil }
        let invoice = Invoice()
        invoice.currencyCode = store.currencyCode
        invoice.taxRate = store.defaultTaxRate
        context.insert(invoice)
        return invoice
    }

    private func duplicate(_ source: Invoice) {
        guard allowCreation(), let copy = makeInvoice() else { return }
        copy.customerName = source.customerName
        copy.customerAddress = source.customerAddress
        copy.customerEmail = source.customerEmail
        copy.currencyCode = source.currencyCode
        copy.taxRate = source.taxRate
        copy.discountPercent = source.discountPercent
        copy.notes = source.notes
        for (index, original) in source.sortedLines.enumerated() {
            let line = InvoiceLine()
            line.position = index
            line.name = original.name
            line.quantity = original.quantity
            line.unitPrice = original.unitPrice
            context.insert(line)
            line.invoice = copy
        }
        route = EditorRoute(invoice: copy)
    }

    private func newInvoice() {
        guard let invoice = makeInvoice() else { return }
        route = EditorRoute(invoice: invoice)
    }

    private func makeRoute(from items: [ParsedItem], speaker: String) -> EditorRoute? {
        guard let invoice = makeInvoice() else { return nil }
        invoice.createdByName = speaker
        for (index, item) in items.enumerated() {
            let line = InvoiceLine()
            line.position = index
            line.name = item.name
            line.quantity = item.quantity
            line.unitPrice = item.unitPrice
            line.rawTranscript = item.rawText
            line.dictatedByName = speaker
            context.insert(line)
            line.invoice = invoice
        }
        return EditorRoute(invoice: invoice)
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
