import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct ExtractedInvoiceItem {
    @Guide(description: "Product or service name in the language spoken, without quantity, price or currency words")
    var name: String
    @Guide(description: "Number of units, 1 if none was said")
    var quantity: Double
    @Guide(description: "Price of ONE unit as a plain number. If only a total was given for several units, divide it by the quantity. 0 if no price was said")
    var unitPrice: Double
}

@available(iOS 26.0, *)
@Generable
struct ExtractedInvoice {
    @Guide(description: "Every distinct item sold, in the order spoken")
    var items: [ExtractedInvoiceItem]
}
#endif

/// Optional second engine: Apple's on-device language model, used only to help when the
/// rule-based parser could not read a price. It never runs on devices without Apple Intelligence.
enum AppleIntelligenceParser {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return false
    }

    static func parse(_ text: String, language: ParserLanguage) async -> [ParsedItem]? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            let instructions = """
            You turn a short spoken sentence from a shop owner into invoice line items. \
            The sentence is in \(language.displayName). \
            Spoken numbers must become plain numbers. Never invent items, quantities or prices. \
            If the speaker says a price for several units together, divide it by the quantity.
            """
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: text, generating: ExtractedInvoice.self)
                let items: [ParsedItem] = response.content.items.compactMap { extracted in
                    let name = extracted.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty,
                          extracted.quantity.isFinite, extracted.quantity > 0,
                          extracted.unitPrice.isFinite, extracted.unitPrice >= 0 else { return nil }
                    return ParsedItem(name: name, quantity: extracted.quantity, unitPrice: extracted.unitPrice, rawText: text)
                }
                return items.isEmpty ? nil : items
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}
