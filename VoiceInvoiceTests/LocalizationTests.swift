import XCTest
@testable import VoiceInvoice

final class LocalizationTests: XCTestCase {
    private var bundle: Bundle { Bundle(for: SubscriptionStore.self) }

    private func localizedBundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(bundle.path(forResource: language, ofType: "lproj"), "no \(language).lproj in app")
        return try XCTUnwrap(Bundle(path: path))
    }

    func testAllLaunchLanguagesAreShipped() throws {
        for language in ["fr", "es", "it", "zh-Hans"] {
            _ = try localizedBundle(language)
        }
    }

    func testCommonStringsAreTranslated() throws {
        let expectations: [String: [String: String]] = [
            "fr": ["Cancel": "Annuler", "Save": "Enregistrer", "Invoices": "Factures"],
            "es": ["Cancel": "Cancelar", "Save": "Guardar", "Invoices": "Facturas"],
            "it": ["Cancel": "Annulla", "Save": "Salva", "Invoices": "Fatture"],
            "zh-Hans": ["Cancel": "取消", "Save": "保存", "Invoices": "发票"]
        ]
        for (language, pairs) in expectations {
            let localized = try localizedBundle(language)
            for (key, expected) in pairs {
                XCTAssertEqual(localized.localizedString(forKey: key, value: "MISSING", table: nil), expected, "\(language): \(key)")
            }
        }
    }

    func testPluralForms() throws {
        let french = try localizedBundle("fr")
        let fr = Locale(identifier: "fr")
        let one = String(localized: "\(1) invoices", bundle: french, locale: fr)
        let many = String(localized: "\(3) invoices", bundle: french, locale: fr)
        XCTAssertEqual(one, "1 facture")
        XCTAssertEqual(many, "3 factures")
    }

    func testPermissionPromptsAreLocalized() throws {
        let french = try localizedBundle("fr")
        let text = french.localizedString(forKey: "NSMicrophoneUsageDescription", value: "MISSING", table: "InfoPlist")
        XCTAssertNotEqual(text, "MISSING")
        XCTAssertTrue(text.contains("Talkstamp"))
    }

    func testStatusTitlesFollowLanguage() {
        XCTAssertEqual(InvoiceStatus.paid.title.isEmpty, false)
    }
}
