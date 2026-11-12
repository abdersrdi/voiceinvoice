import SwiftUI

/// One A4 page (595 x 842 pt) of the invoice. Always rendered in light mode for printing.
struct InvoicePageView: View {
    static let pageSize = CGSize(width: 595, height: 842)

    let document: InvoiceDocument
    let lineRange: Range<Int>
    let pageIndex: Int
    let pageCount: Int

    private var isFirst: Bool { pageIndex == 0 }
    private var isLast: Bool { pageIndex == pageCount - 1 }

    private let ink = Color(hex: 0x1C1517)
    private let muted = Color(hex: 0x7A6A6E)
    private let accent = Color(hex: 0x6B1F2E)
    private let rule = Color(hex: 0xE5DADC)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isFirst {
                header
                billTo
            } else {
                continuationHeader
            }

            tableHeader
            ForEach(lineRange.map { $0 }, id: \.self) { index in
                row(document.lines[index])
            }

            if isLast {
                totalsBlock
                amountInWordsBlock
                notesBlock
                Spacer(minLength: 12)
                signatureBlock
            } else {
                Spacer(minLength: 0)
            }

            footer
        }
        .padding(.horizontal, 40)
        .padding(.top, 40)
        .padding(.bottom, 28)
        .frame(width: Self.pageSize.width, height: Self.pageSize.height, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .environment(\.locale, document.locale)
        .environment(\.layoutDirection, DocumentLanguage.isRightToLeft(code: document.languageCode) ? .rightToLeft : .leftToRight)
        .foregroundStyle(ink)
    }

    private func money(_ value: Double) -> String {
        Money.string(value, currencyCode: document.currencyCode, locale: document.locale)
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: document.locale))
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if let logo = document.logo {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 120, maxHeight: 56, alignment: .leading)
                        .padding(.bottom, 4)
                }
                Text(verbatim: document.shopName)
                    .font(.system(size: 18, weight: .bold))
                if !document.shopAddress.isEmpty {
                    Text(verbatim: document.shopAddress).font(.system(size: 9)).foregroundStyle(muted)
                }
                if !document.shopTaxID.isEmpty {
                    (Text("Tax ID") + Text(verbatim: ": \(document.shopTaxID)"))
                        .font(.system(size: 9)).foregroundStyle(muted)
                }
                if !document.shopPhone.isEmpty || !document.shopEmail.isEmpty {
                    Text(verbatim: [document.shopPhone, document.shopEmail].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 9)).foregroundStyle(muted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("INVOICE")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(accent)
                Text(verbatim: document.number)
                    .font(.system(size: 11, weight: .semibold))
                (Text("Issued") + Text(verbatim: ": \(dateText(document.issueDate))"))
                    .font(.system(size: 9)).foregroundStyle(muted)
                if let due = document.dueDate {
                    (Text("Due") + Text(verbatim: ": \(dateText(due))"))
                        .font(.system(size: 9)).foregroundStyle(muted)
                }
            }
        }
        .padding(.bottom, 22)
    }

    private var billTo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("BILL TO")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(muted)
            Text(verbatim: document.customerName)
                .font(.system(size: 13, weight: .semibold))
            if !document.customerAddress.isEmpty {
                Text(verbatim: document.customerAddress).font(.system(size: 9)).foregroundStyle(muted)
            }
            if !document.customerEmail.isEmpty {
                Text(verbatim: document.customerEmail).font(.system(size: 9)).foregroundStyle(muted)
            }
        }
        .padding(.bottom, 22)
    }

    private var continuationHeader: some View {
        HStack {
            Text(verbatim: document.shopName).font(.system(size: 12, weight: .bold))
            Spacer()
            Text(verbatim: document.number).font(.system(size: 10)).foregroundStyle(muted)
        }
        .padding(.bottom, 18)
    }

    // MARK: Table

    private var tableHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DESCRIPTION").frame(maxWidth: .infinity, alignment: .leading)
                Text("QTY").frame(width: 50, alignment: .trailing)
                Text("PRICE").frame(width: 80, alignment: .trailing)
                Text("AMOUNT").frame(width: 90, alignment: .trailing)
            }
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(muted)
            .padding(.bottom, 6)
            Rectangle().fill(accent).frame(height: 1.5)
        }
    }

    private func row(_ line: InvoiceDocument.Line) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(verbatim: line.name)
                    .font(.system(size: 10.5))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: line.quantity.formatted())
                    .frame(width: 50, alignment: .trailing)
                Text(verbatim: money(line.unitPrice))
                    .frame(width: 80, alignment: .trailing)
                Text(verbatim: money(
                    InvoiceMath.lineAmount(quantity: line.quantity, unitPrice: line.unitPrice, currencyCode: document.currencyCode)
                ))
                .frame(width: 90, alignment: .trailing)
            }
            .font(.system(size: 10.5))
            .frame(height: 25)
            Rectangle().fill(rule).frame(height: 0.5)
        }
    }

    // MARK: Totals

    private var totalsBlock: some View {
        let totals = document.totals
        let code = document.currencyCode
        return HStack {
            Spacer()
            VStack(spacing: 6) {
                totalLine("Subtotal", money(totals.subtotal))
                if totals.discount > 0 {
                    totalLine("Discount", "-" + money(totals.discount))
                }
                if document.taxRate > 0 {
                    totalLine("Tax", money(totals.tax))
                }
                Rectangle().fill(accent).frame(height: 1.5)
                HStack {
                    Text("TOTAL").font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(verbatim: money(totals.total))
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(accent)
                }
            }
            .frame(width: 230)
        }
        .padding(.top, 16)
    }

    /// The total in words, shown for currencies and languages where invoices customarily carry it.
    private var amountInWordsBlock: some View {
        Group {
            if AmountInWords.isCustomary(currencyCode: document.currencyCode, languageCode: document.languageCode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AMOUNT IN WORDS").font(.system(size: 8, weight: .bold)).foregroundStyle(muted)
                    Text(verbatim: AmountInWords.string(document.totals.total, currencyCode: document.currencyCode, locale: document.locale))
                        .font(.system(size: 9.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            }
        }
    }

    private func totalLine(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 10)).foregroundStyle(muted)
            Spacer()
            Text(verbatim: value).font(.system(size: 10.5, weight: .medium))
        }
    }

    private var notesBlock: some View {
        Group {
            if !document.notes.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NOTES").font(.system(size: 8, weight: .bold)).foregroundStyle(muted)
                    Text(verbatim: document.notes).font(.system(size: 9.5))
                }
                .padding(.top, 20)
            }
        }
    }

    // MARK: Signature and footer

    private var signatureBlock: some View {
        HStack(alignment: .bottom) {
            if let stamp = document.stamp {
                Image(uiImage: stamp)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 110, maxHeight: 90, alignment: .leading)
            }
            Spacer()
            VStack(spacing: 4) {
                if let signature = document.signature {
                    Image(uiImage: signature)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 150, maxHeight: 56)
                } else {
                    Color.clear.frame(width: 150, height: 56)
                }
                Rectangle().fill(muted).frame(width: 150, height: 0.75)
                Text("Authorized signature")
                    .font(.system(size: 8))
                    .foregroundStyle(muted)
            }
        }
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack {
            Text(verbatim: document.footerNote)
                .font(.system(size: 8))
                .foregroundStyle(muted)
                .lineLimit(2)
            Spacer()
            Text(verbatim: "\(pageIndex + 1) / \(pageCount)")
                .font(.system(size: 8))
                .foregroundStyle(muted)
        }
        .padding(.top, 8)
    }
}
