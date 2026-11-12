import SwiftUI
import SwiftData

/// Launch with `-UITestSeed` to start with a realistic in-memory shop instead of the real store.
/// Used by the automated screenshot tests; never active in normal use.
enum DemoMode {
    static var isActive: Bool {
        CommandLine.arguments.contains("-UITestSeed")
    }
}

enum DemoData {
    static func container() -> ModelContainer {
        guard let container = try? Persistence.makeInMemoryContainer() else {
            return Persistence.makeContainer()
        }
        let context = ModelContext(container)
        populate(context)
        return container
    }

    static func populate(_ context: ModelContext) {
        let store = StoreProfile()
        store.name = "Maison Dupont"
        store.address = "12 Rue des Lilas, 75011 Paris"
        store.taxID = "FR 12 345 678 901"
        store.phone = "+33 1 23 45 67 89"
        store.email = "contact@maison-dupont.example"
        store.currencyCode = "EUR"
        store.defaultTaxRate = 20
        store.footerNote = "Thank you for your business. Payment due within 14 days."
        store.logoData = logoPNG()
        store.stampData = stampPNG()
        store.signatureData = signaturePNG()
        store.usageMonth = UsagePolicy.monthKey(Date())
        store.usageCount = 3
        store.nextNumber = 7
        context.insert(store)

        let camille = Employee()
        camille.name = "Camille"
        camille.voiceprint = Voiceprint(centroid: [Float](repeating: 1, count: 24), radius: 1, sampleCount: 3).data
        camille.voiceConsentAt = Date()
        context.insert(camille)
        let hugo = Employee()
        hugo.name = "Hugo"
        context.insert(hugo)

        let samples: [(String, String, Int, InvoiceStatus, [(String, Double, Double)], Double)] = [
            ("INV-A7-0006", "Boulangerie Martin", 0, .draft,
             [("Linen shirt", 2, 45), ("Wool scarf", 1, 38.5)], 0),
            ("INV-A7-0005", "Café du Coin", 1, .sent,
             [("Espresso machine service", 1, 120), ("Descaler", 3, 9.9)], 5),
            ("INV-A7-0004", "Studio Léa", 2, .paid,
             [("Photo prints A3", 12, 6.5), ("Framing", 4, 22)], 0),
            ("INV-A7-0003", "Hôtel Beaumont", 4, .paid,
             [("Bed linen set", 10, 64), ("Towels", 20, 11.5), ("Delivery", 1, 25)], 10),
            ("INV-A7-0002", "Marché Bio", 6, .sent,
             [("Organic tote bag", 50, 3.2)], 0),
            ("INV-A7-0001", "Atelier Noor", 21, .paid,
             [("Silk dress", 1, 189), ("Alterations", 1, 35)], 0)
        ]
        for (number, customer, daysAgo, status, lines, discount) in samples {
            let invoice = Invoice()
            invoice.number = number
            invoice.customerName = customer
            invoice.customerAddress = "Paris, France"
            invoice.customerEmail = "accounts@\(customer.lowercased().filter { $0.isLetter }).example"
            invoice.currencyCode = "EUR"
            invoice.taxRate = 20
            invoice.discountPercent = discount
            invoice.status = status
            invoice.issueDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            invoice.dueDate = Calendar.current.date(byAdding: .day, value: 14, to: invoice.issueDate)
            invoice.createdByName = daysAgo % 2 == 0 ? "Camille" : "Hugo"
            invoice.notes = "Bank transfer to the account on file."
            context.insert(invoice)
            for (index, line) in lines.enumerated() {
                let item = InvoiceLine()
                item.position = index
                item.name = line.0
                item.quantity = line.1
                item.unitPrice = line.2
                context.insert(item)
                item.invoice = invoice
            }
        }
        try? context.save()
    }

    // MARK: Generated artwork

    static func logoPNG() -> Data {
        let size = CGSize(width: 240, height: 240)
        return UIGraphicsImageRenderer(size: size).pngData { context in
            UIColor(red: 0.42, green: 0.12, blue: 0.18, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            let text = "MD" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 110, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }

    static func stampPNG() -> Data {
        let size = CGSize(width: 260, height: 260)
        let ink = UIColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 0.9)
        return UIGraphicsImageRenderer(size: size).pngData { context in
            let cg = context.cgContext
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: -0.26)
            cg.translateBy(x: -size.width / 2, y: -size.height / 2)
            cg.setStrokeColor(ink.cgColor)
            cg.setLineWidth(8)
            cg.strokeEllipse(in: CGRect(x: 10, y: 10, width: 240, height: 240))
            cg.setLineWidth(3)
            cg.strokeEllipse(in: CGRect(x: 26, y: 26, width: 208, height: 208))
            let text = "MAISON\nDUPONT" as NSString
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .heavy),
                .foregroundColor: ink,
                .paragraphStyle: paragraph
            ]
            text.draw(in: CGRect(x: 30, y: 88, width: 200, height: 100), withAttributes: attributes)
        }
    }

    static func signaturePNG() -> Data {
        let size = CGSize(width: 300, height: 140)
        return UIGraphicsImageRenderer(size: size).pngData { _ in
            UIColor.black.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 10, y: 100))
            path.addCurve(to: CGPoint(x: 150, y: 60), controlPoint1: CGPoint(x: 40, y: 10), controlPoint2: CGPoint(x: 90, y: 120))
            path.addCurve(to: CGPoint(x: 290, y: 80), controlPoint1: CGPoint(x: 200, y: 20), controlPoint2: CGPoint(x: 240, y: 130))
            path.lineWidth = 5
            path.lineCapStyle = .round
            path.stroke()
        }
    }
}
