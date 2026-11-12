import XCTest
import SwiftUI
@testable import VoiceInvoice

/// Renders complete sample invoices in Arabic, Hindi and Urdu to PNG files, so the right-to-left layout, the
/// scripts and the amount in words can be checked by eye. The "Localized screenshots" GitHub workflow uploads them.
@MainActor
final class LocalizedInvoiceImagesTests: XCTestCase {
    private struct Sample {
        let name: String
        let languageCode: String
        let currency: String
        let taxRate: Double
        let shop: String
        let address: String
        let taxID: String
        let phone: String
        let customer: String
        let customerAddress: String
        let lines: [(String, Double, Double)]
        let notes: String
        let footer: String
    }

    private let samples: [Sample] = [
        Sample(name: "arabic-sar", languageCode: "ar", currency: "SAR", taxRate: 15,
               shop: "مؤسسة النور للتجارة", address: "شارع الملك فهد، الرياض", taxID: "300012345600003",
               phone: "+966 11 123 4567", customer: "شركة الأفق للمقاولات", customerAddress: "حي العليا، الرياض",
               lines: [("كابلات كهربائية", 10, 45.5), ("مفاتيح إنارة", 25, 12), ("لوحة توزيع", 2, 380)],
               notes: "الدفع خلال ١٤ يومًا من تاريخ الفاتورة.", footer: "شكرًا لتعاملكم معنا"),
        Sample(name: "arabic-aed", languageCode: "ar", currency: "AED", taxRate: 5,
               shop: "مؤسسة الخليج للأدوات", address: "شارع الشيخ زايد، دبي", taxID: "100234567800003",
               phone: "+971 4 123 4567", customer: "ورشة الماهر", customerAddress: "الشارقة",
               lines: [("مثقاب كهربائي", 3, 250), ("علبة براغي", 40, 8.75)],
               notes: "", footer: "شكرًا لتعاملكم معنا"),
        Sample(name: "hindi-inr", languageCode: "hi", currency: "INR", taxRate: 18,
               shop: "शर्मा ट्रेडर्स", address: "12, गांधी रोड, जयपुर, राजस्थान", taxID: "08ABCDE1234F1Z5",
               phone: "+91 141 234 5678", customer: "वर्मा इलेक्ट्रिकल्स", customerAddress: "मालवीय नगर, जयपुर",
               lines: [("एलईडी बल्ब", 50, 120), ("तार का बंडल", 10, 850), ("स्विच बोर्ड", 8, 430.5)],
               notes: "भुगतान 15 दिनों के भीतर करें।", footer: "आपके व्यापार के लिए धन्यवाद"),
        Sample(name: "urdu-pkr", languageCode: "ur", currency: "PKR", taxRate: 17,
               shop: "رحمان ٹریڈرز", address: "مین بازار، لاہور", taxID: "1234567-8",
               phone: "+92 42 123 4567", customer: "علی الیکٹرونکس", customerAddress: "گلبرگ، لاہور",
               lines: [("بجلی کا تار", 12, 950), ("سوئچ بورڈ", 8, 430), ("ایل ای ڈی بلب", 30, 275.5)],
               notes: "ادائیگی 15 دن کے اندر کریں۔", footer: "آپ کے اعتماد کا شکریہ")
    ]

    private func outputFolder() -> URL {
        let host = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? NSHomeDirectory()
        let url = URL(fileURLWithPath: host).appendingPathComponent("ui-screenshots/invoices", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func document(for sample: Sample) -> InvoiceDocument {
        var doc = InvoiceDocument()
        doc.shopName = sample.shop
        doc.shopAddress = sample.address
        doc.shopTaxID = sample.taxID
        doc.shopPhone = sample.phone
        doc.shopEmail = "info@example.com"
        doc.footerNote = sample.footer
        doc.languageCode = sample.languageCode
        doc.logo = UIImage(data: DemoData.logoPNG())
        doc.stamp = UIImage(data: DemoData.stampPNG())
        doc.signature = UIImage(data: DemoData.signaturePNG())
        doc.number = "INV-0042"
        doc.issueDate = Date(timeIntervalSince1970: 1_794_000_000)
        doc.dueDate = Date(timeIntervalSince1970: 1_795_200_000)
        doc.customerName = sample.customer
        doc.customerAddress = sample.customerAddress
        doc.customerEmail = "accounts@example.com"
        doc.notes = sample.notes
        doc.currencyCode = sample.currency
        doc.taxRate = sample.taxRate
        doc.lines = sample.lines.map { InvoiceDocument.Line(name: $0.0, quantity: $0.1, unitPrice: $0.2) }
        return doc
    }

    func testRenderSampleInvoices() throws {
        let folder = outputFolder()
        for sample in samples {
            let doc = document(for: sample)
            let pages = Paginator.pages(lineCount: doc.lines.count)
            for (index, range) in pages.enumerated() {
                let renderer = ImageRenderer(
                    content: InvoicePageView(document: doc, lineRange: range, pageIndex: index, pageCount: pages.count)
                )
                renderer.proposedSize = ProposedViewSize(InvoicePageView.pageSize)
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.uiImage, "\(sample.name) did not render")
                let png = try XCTUnwrap(image.pngData())
                XCTAssertGreaterThan(png.count, 20_000, "\(sample.name) looks empty")
                try png.write(to: folder.appendingPathComponent("\(sample.name)-page\(index + 1).png"))
            }
            // the same invoice as a real PDF, to make sure the vector path also works
            let pdf = try InvoicePDFRenderer.render(doc)
            XCTAssertTrue(FileManager.default.fileExists(atPath: pdf.path))
        }
    }
}
