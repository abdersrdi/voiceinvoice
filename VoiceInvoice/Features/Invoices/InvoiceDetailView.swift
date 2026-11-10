import SwiftUI
import SwiftData
import PDFKit

struct InvoiceDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var stores: [StoreProfile]

    @Bindable var invoice: Invoice

    @State private var pdfURL: URL?
    @State private var showingEditor = false
    @State private var renderError: String?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let pdfURL {
                    PDFPreview(url: pdfURL)
                } else if let renderError {
                    ContentUnavailableView(
                        "Could not build the PDF",
                        systemImage: "exclamationmark.triangle",
                        description: Text(renderError)
                    )
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)

            statusBar
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(invoice.number.isEmpty ? String(localized: "Invoice") : invoice.number)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share invoice")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .task(id: invoice.updatedAt) { render() }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                InvoiceEditorView(invoice: invoice, isNew: false)
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Menu {
                ForEach(InvoiceStatus.allCases) { status in
                    Button {
                        invoice.status = status
                        invoice.updatedAt = Date()
                        try? context.save()
                        Haptics.tap()
                    } label: {
                        Label(status.title, systemImage: status.symbol)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    StatusPill(status: invoice.status)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer()
            Text(Money.string(invoice.total, currencyCode: invoice.currencyCode))
                .font(Theme.amount(22, weight: .bold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
    }

    @MainActor
    private func render() {
        guard let store = stores.first else { return }
        do {
            let document = InvoiceDocument(invoice: invoice, store: store)
            pdfURL = try InvoicePDFRenderer.render(document)
            renderError = nil
        } catch {
            pdfURL = nil
            renderError = error.localizedDescription
        }
    }
}

struct PDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
