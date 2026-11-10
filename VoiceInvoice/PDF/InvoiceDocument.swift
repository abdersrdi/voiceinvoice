import Foundation
import UIKit

/// A plain value snapshot of an invoice and its shop, used for PDF rendering.
struct InvoiceDocument {
    struct Line: Identifiable {
        let id = UUID()
        var name: String
        var quantity: Double
        var unitPrice: Double
    }

    var shopName = ""
    var shopAddress = ""
    var shopTaxID = ""
    var shopPhone = ""
    var shopEmail = ""
    var footerNote = ""
    var languageCode = ""
    var logo: UIImage?
    var stamp: UIImage?
    var signature: UIImage?

    var number = ""
    var issueDate = Date()
    var dueDate: Date?
    var customerName = ""
    var customerAddress = ""
    var customerEmail = ""
    var notes = ""
    var currencyCode = "USD"
    var taxRate = 0.0
    var discountPercent = 0.0
    var lines: [Line] = []

    var locale: Locale { DocumentLanguage.locale(for: languageCode) }

    var totals: InvoiceTotals {
        InvoiceMath.totals(
            lines: lines.map { ($0.quantity, $0.unitPrice) },
            discountPercent: discountPercent,
            taxRate: taxRate,
            currencyCode: currencyCode
        )
    }

    init() {}

    init(invoice: Invoice, store: StoreProfile) {
        shopName = store.name
        shopAddress = store.address
        shopTaxID = store.taxID
        shopPhone = store.phone
        shopEmail = store.email
        footerNote = store.footerNote
        languageCode = invoice.languageCode.isEmpty ? store.documentLanguage : invoice.languageCode
        logo = store.logoData.flatMap(UIImage.init(data:))
        stamp = store.stampData.flatMap(UIImage.init(data:))
        signature = store.signatureData.flatMap(UIImage.init(data:))

        number = invoice.number
        issueDate = invoice.issueDate
        dueDate = invoice.dueDate
        customerName = invoice.customerName
        customerAddress = invoice.customerAddress
        customerEmail = invoice.customerEmail
        notes = invoice.notes
        currencyCode = invoice.currencyCode
        taxRate = invoice.taxRate
        discountPercent = invoice.discountPercent
        lines = invoice.sortedLines
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty || $0.unitPrice != 0 }
            .map { Line(name: $0.name, quantity: $0.quantity, unitPrice: $0.unitPrice) }
    }
}

enum Paginator {
    static let firstPageWithFooter = 10
    static let firstPageNoFooter = 18
    static let otherPageWithFooter = 16
    static let otherPageNoFooter = 24

    /// Splits `lineCount` rows into page ranges. The last page always has room for totals and signature;
    /// if the rows alone fill the page, an extra totals-only page is added.
    static func pages(lineCount: Int) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var index = 0
        var first = true
        while true {
            let remaining = lineCount - index
            let withFooter = first ? firstPageWithFooter : otherPageWithFooter
            let noFooter = first ? firstPageNoFooter : otherPageNoFooter
            if remaining <= withFooter {
                result.append(index..<lineCount)
                break
            }
            let take = min(noFooter, remaining)
            result.append(index..<(index + take))
            index += take
            first = false
            if index >= lineCount {
                result.append(lineCount..<lineCount)
                break
            }
        }
        return result
    }
}
