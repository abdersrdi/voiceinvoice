import XCTest
import SwiftData
import PDFKit
@testable import VoiceInvoice

@MainActor
final class ModelAndPDFTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try Persistence.makeInMemoryContainer()
        return ModelContext(container)
    }

    func testInvoiceTotalsFromStoredLines() throws {
        let context = try makeContext()
        let invoice = Invoice()
        invoice.currencyCode = "USD"
        invoice.taxRate = 10
        context.insert(invoice)

        for (index, item) in [("Shirt", 2.0, 20.0), ("Pants", 1.0, 40.0)].enumerated() {
            let line = InvoiceLine()
            line.position = index
            line.name = item.0
            line.quantity = item.1
            line.unitPrice = item.2
            context.insert(line)
            line.invoice = invoice
        }
        try context.save()

        XCTAssertEqual(invoice.sortedLines.map(\.name), ["Shirt", "Pants"])
        XCTAssertEqual(invoice.totals.subtotal, 80, accuracy: 0.001)
        XCTAssertEqual(invoice.total, 88, accuracy: 0.001)
    }

    func testNumberingAssignsOnceAndIncrements() throws {
        let context = try makeContext()
        let store = StoreProfile()
        store.invoicePrefix = "VI"
        context.insert(store)
        let invoice = Invoice()
        context.insert(invoice)

        InvoiceNumbering.assign(to: invoice, store: store)
        let first = invoice.number
        InvoiceNumbering.assign(to: invoice, store: store)

        XCTAssertEqual(invoice.number, first)
        XCTAssertTrue(first.hasPrefix("VI-"))
        XCTAssertEqual(store.nextNumber, 2)
    }

    func testStatusRoundTrip() throws {
        let invoice = Invoice()
        XCTAssertEqual(invoice.status, .draft)
        invoice.status = .paid
        XCTAssertEqual(invoice.statusRaw, "paid")
    }

    func testPDFRendersAllPages() throws {
        var document = InvoiceDocument()
        document.shopName = "Test Shop"
        document.number = "INV-AA-0001"
        document.customerName = "Customer"
        document.currencyCode = "EUR"
        document.taxRate = 20
        document.lines = (1...30).map {
            InvoiceDocument.Line(name: "Item \($0)", quantity: 1, unitPrice: Double($0))
        }

        let url = try InvoicePDFRenderer.render(document)
        let pdf = try XCTUnwrap(PDFDocument(url: url))

        XCTAssertEqual(pdf.pageCount, Paginator.pages(lineCount: 30).count)
        XCTAssertGreaterThan(try XCTUnwrap(try? Data(contentsOf: url)).count, 1000)
    }
}
