import SwiftUI

enum InvoicePDFError: LocalizedError {
    case couldNotCreateContext

    var errorDescription: String? {
        switch self {
        case .couldNotCreateContext:
            return String(localized: "The PDF file could not be created.")
        }
    }
}

enum InvoicePDFRenderer {
    /// Renders the invoice to a vector PDF in a fresh temporary folder and returns its URL.
    @MainActor
    static func render(_ document: InvoiceDocument) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let safeNumber = document.number
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
        let fileName = safeNumber.isEmpty ? "Invoice.pdf" : "Invoice-\(safeNumber).pdf"
        let url = folder.appendingPathComponent(fileName)

        var mediaBox = CGRect(origin: .zero, size: InvoicePageView.pageSize)
        guard let pdf = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw InvoicePDFError.couldNotCreateContext
        }

        let pages = Paginator.pages(lineCount: document.lines.count)
        for (index, range) in pages.enumerated() {
            let renderer = ImageRenderer(
                content: InvoicePageView(
                    document: document,
                    lineRange: range,
                    pageIndex: index,
                    pageCount: pages.count
                )
            )
            renderer.proposedSize = ProposedViewSize(InvoicePageView.pageSize)
            pdf.beginPDFPage(nil)
            renderer.render { _, draw in
                draw(pdf)
            }
            pdf.endPDFPage()
        }
        pdf.closePDF()
        return url
    }
}
