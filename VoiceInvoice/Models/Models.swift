import Foundation
import SwiftData

// All stored properties have defaults or are optional, and relationships are optional,
// so the schema is valid for CloudKit sync.

enum InvoiceStatus: String, CaseIterable, Identifiable {
    case draft, sent, paid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft: return String(localized: "Draft")
        case .sent: return String(localized: "Sent")
        case .paid: return String(localized: "Paid")
        }
    }

    var symbol: String {
        switch self {
        case .draft: return "pencil.circle.fill"
        case .sent: return "paperplane.circle.fill"
        case .paid: return "checkmark.circle.fill"
        }
    }
}

@Model
final class StoreProfile {
    var name: String = ""
    var address: String = ""
    var taxID: String = ""
    var phone: String = ""
    var email: String = ""
    var currencyCode: String = "USD"
    var defaultTaxRate: Double = 0
    var invoicePrefix: String = "INV"
    var nextNumber: Int = 1
    var footerNote: String = ""
    /// Free-tier counter ("2026-11") so deleting an invoice never gives the slot back.
    var usageMonth: String = ""
    var usageCount: Int = 0
    @Attribute(.externalStorage) var logoData: Data?
    @Attribute(.externalStorage) var stampData: Data?
    @Attribute(.externalStorage) var signatureData: Data?
    var createdAt: Date = Date()

    init() {}
}

@Model
final class Employee {
    var uid: String = ""
    var name: String = ""
    var createdAt: Date = Date()
    @Attribute(.externalStorage) var voiceprint: Data?
    var voiceSyncEnabled: Bool = true
    var voiceConsentAt: Date?

    init() {
        uid = UUID().uuidString
    }
}

@Model
final class Invoice {
    var number: String = ""
    var issueDate: Date = Date()
    var dueDate: Date?
    var statusRaw: String = "draft"
    var customerName: String = ""
    var customerAddress: String = ""
    var customerEmail: String = ""
    var currencyCode: String = "USD"
    var taxRate: Double = 0
    var discountPercent: Double = 0
    var notes: String = ""
    var createdByName: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \InvoiceLine.invoice)
    var lines: [InvoiceLine]? = []

    init() {}
}

@Model
final class InvoiceLine {
    var position: Int = 0
    var name: String = ""
    var quantity: Double = 1
    var unitPrice: Double = 0
    var dictatedByName: String = ""
    var rawTranscript: String = ""
    var invoice: Invoice?

    init() {}
}

extension Invoice {
    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var sortedLines: [InvoiceLine] {
        (lines ?? []).sorted { $0.position < $1.position }
    }

    var totals: InvoiceTotals {
        InvoiceMath.totals(
            lines: sortedLines.map { ($0.quantity, $0.unitPrice) },
            discountPercent: discountPercent,
            taxRate: taxRate,
            currencyCode: currencyCode
        )
    }

    var total: Double { totals.total }
}
