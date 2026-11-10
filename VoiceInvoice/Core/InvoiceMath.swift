import Foundation

struct InvoiceTotals: Equatable {
    var subtotal: Double
    var discount: Double
    var taxable: Double
    var tax: Double
    var total: Double
}

enum InvoiceMath {
    static func fractionDigits(for currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.maximumFractionDigits
    }

    static func round(_ value: Double, digits: Int) -> Double {
        let factor = pow(10.0, Double(digits))
        let nudge = value >= 0 ? 1e-9 : -1e-9
        return ((value * factor) + nudge).rounded() / factor
    }

    static func totals(
        lines: [(quantity: Double, unitPrice: Double)],
        discountPercent: Double,
        taxRate: Double,
        currencyCode: String
    ) -> InvoiceTotals {
        let digits = fractionDigits(for: currencyCode)
        let subtotal = lines.reduce(0.0) { $0 + round($1.quantity * $1.unitPrice, digits: digits) }
        let discount = round(subtotal * discountPercent / 100, digits: digits)
        let taxable = subtotal - discount
        let tax = round(taxable * taxRate / 100, digits: digits)
        return InvoiceTotals(
            subtotal: round(subtotal, digits: digits),
            discount: discount,
            taxable: round(taxable, digits: digits),
            tax: tax,
            total: round(taxable + tax, digits: digits)
        )
    }

    static func lineAmount(quantity: Double, unitPrice: Double, currencyCode: String) -> Double {
        round(quantity * unitPrice, digits: fractionDigits(for: currencyCode))
    }
}

enum Money {
    static func string(_ value: Double, currencyCode: String, locale: Locale = .current) -> String {
        value.formatted(.currency(code: currencyCode).locale(locale))
    }
}

enum InvoiceNumbering {
    private static let tagKey = "voiceinvoice.deviceTag"
    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    /// Short per-device tag so two devices numbering offline never collide.
    static var deviceTag: String {
        if let saved = UserDefaults.standard.string(forKey: tagKey), !saved.isEmpty {
            return saved
        }
        let tag = String((0..<2).map { _ in alphabet.randomElement() ?? "A" })
        UserDefaults.standard.set(tag, forKey: tagKey)
        return tag
    }

    static func format(prefix: String, tag: String, sequence: Int) -> String {
        let cleanPrefix = prefix.trimmingCharacters(in: .whitespaces)
        let head = cleanPrefix.isEmpty ? "INV" : cleanPrefix
        return "\(head)-\(tag)-\(String(format: "%04d", sequence))"
    }

    static func assign(to invoice: Invoice, store: StoreProfile) {
        guard invoice.number.isEmpty else { return }
        invoice.number = format(prefix: store.invoicePrefix, tag: deviceTag, sequence: store.nextNumber)
        store.nextNumber += 1
    }
}
