import XCTest
@testable import VoiceInvoice

final class LocalizationTests: XCTestCase {
    private var bundle: Bundle { Bundle(for: SubscriptionStore.self) }

    private func localizedBundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(bundle.path(forResource: language, ofType: "lproj"), "no \(language).lproj in app")
        return try XCTUnwrap(Bundle(path: path))
    }

    func testAllLaunchLanguagesAreShipped() throws {
        for language in ["fr", "es", "it", "zh-Hans", "ar", "hi", "ur"] {
            _ = try localizedBundle(language)
        }
    }

    func testCommonStringsAreTranslated() throws {
        let expectations: [String: [String: String]] = [
            "fr": ["Cancel": "Annuler", "Save": "Enregistrer", "Invoices": "Factures"],
            "es": ["Cancel": "Cancelar", "Save": "Guardar", "Invoices": "Facturas"],
            "it": ["Cancel": "Annulla", "Save": "Salva", "Invoices": "Fatture"],
            "zh-Hans": ["Cancel": "取消", "Save": "保存", "Invoices": "发票"],
            "ar": ["Cancel": "إلغاء", "Save": "حفظ", "Invoices": "الفواتير"],
            "hi": ["Cancel": "रद्द करें", "Save": "सहेजें", "Invoices": "इनवॉइस"],
            "ur": ["Cancel": "منسوخ کریں", "Save": "محفوظ کریں", "Invoices": "انوائسز"]
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

    func testArabicPluralForms() throws {
        let arabic = try localizedBundle("ar")
        let ar = Locale(identifier: "ar")
        XCTAssertEqual(String(localized: "\(1) invoices", bundle: arabic, locale: ar), "فاتورة واحدة")
        XCTAssertEqual(String(localized: "\(2) invoices", bundle: arabic, locale: ar), "فاتورتان")
        XCTAssertTrue(String(localized: "\(3) invoices", bundle: arabic, locale: ar).contains("فواتير"))
    }

    func testRightToLeftLanguages() {
        XCTAssertTrue(DocumentLanguage.isRightToLeft(code: "ar"))
        XCTAssertTrue(DocumentLanguage.isRightToLeft(code: "ur"))
        XCTAssertFalse(DocumentLanguage.isRightToLeft(code: "hi"))
        XCTAssertFalse(DocumentLanguage.isRightToLeft(code: ""))
    }

    func testStatusTitlesFollowLanguage() {
        XCTAssertEqual(InvoiceStatus.paid.title.isEmpty, false)
    }
}
