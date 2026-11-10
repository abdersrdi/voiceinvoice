import XCTest
@testable import VoiceInvoice

final class InvoiceMathTests: XCTestCase {
    func testTotalsWithDiscountAndTax() {
        let totals = InvoiceMath.totals(
            lines: [(2, 20), (1, 40)],
            discountPercent: 10,
            taxRate: 20,
            currencyCode: "USD"
        )
        XCTAssertEqual(totals.subtotal, 80, accuracy: 0.001)
        XCTAssertEqual(totals.discount, 8, accuracy: 0.001)
        XCTAssertEqual(totals.taxable, 72, accuracy: 0.001)
        XCTAssertEqual(totals.tax, 14.4, accuracy: 0.001)
        XCTAssertEqual(totals.total, 86.4, accuracy: 0.001)
    }

    func testRoundingHalfUp() {
        XCTAssertEqual(InvoiceMath.round(1.005, digits: 2), 1.01, accuracy: 0.0001)
        XCTAssertEqual(InvoiceMath.round(2.675, digits: 2), 2.68, accuracy: 0.0001)
    }

    func testZeroDecimalCurrency() {
        XCTAssertEqual(InvoiceMath.fractionDigits(for: "JPY"), 0)
        let totals = InvoiceMath.totals(lines: [(3, 333.3)], discountPercent: 0, taxRate: 0, currencyCode: "JPY")
        XCTAssertEqual(totals.total, 1000, accuracy: 0.001)
    }

    func testEmptyInvoiceIsZero() {
        let totals = InvoiceMath.totals(lines: [], discountPercent: 5, taxRate: 20, currencyCode: "EUR")
        XCTAssertEqual(totals, InvoiceTotals(subtotal: 0, discount: 0, taxable: 0, tax: 0, total: 0))
    }
}

final class InvoiceNumberingTests: XCTestCase {
    func testFormat() {
        XCTAssertEqual(InvoiceNumbering.format(prefix: "INV", tag: "A7", sequence: 12), "INV-A7-0012")
    }

    func testBlankPrefixFallsBack() {
        XCTAssertEqual(InvoiceNumbering.format(prefix: "  ", tag: "ZZ", sequence: 1), "INV-ZZ-0001")
    }

    func testDeviceTagIsStable() {
        XCTAssertEqual(InvoiceNumbering.deviceTag, InvoiceNumbering.deviceTag)
        XCTAssertEqual(InvoiceNumbering.deviceTag.count, 2)
    }
}

final class PaginatorTests: XCTestCase {
    func testEmptyIsOnePage() {
        XCTAssertEqual(Paginator.pages(lineCount: 0), [0..<0])
    }

    func testFitsOnFirstPageWithFooter() {
        XCTAssertEqual(Paginator.pages(lineCount: 10), [0..<10])
    }

    func testOverflowAddsTotalsOnlyPage() {
        XCTAssertEqual(Paginator.pages(lineCount: 11), [0..<11, 11..<11])
    }

    func testMultiplePages() {
        XCTAssertEqual(Paginator.pages(lineCount: 30), [0..<18, 18..<30])
    }

    func testEveryLineAppearsExactlyOnce() {
        for count in 0...120 {
            let pages = Paginator.pages(lineCount: count)
            let covered = pages.flatMap { Array($0) }
            XCTAssertEqual(covered, Array(0..<count), "count \(count)")
        }
    }
}
