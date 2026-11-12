import XCTest
@testable import VoiceInvoice

final class AmountInWordsTests: XCTestCase {
    private let en = Locale(identifier: "en")

    func testEnglishRupeesWithPaise() {
        let text = AmountInWords.string(1250.50, currencyCode: "INR", locale: en).lowercased()
        XCTAssertTrue(text.contains("one thousand two hundred"), text)
        XCTAssertTrue(text.contains("rupees"), text)
        XCTAssertTrue(text.contains("paise"), text)
        XCTAssertTrue(text.hasSuffix("only"), text)
    }

    func testEnglishWholeAmountHasNoMinorPart() {
        let text = AmountInWords.string(500, currencyCode: "AED", locale: en).lowercased()
        XCTAssertTrue(text.contains("five hundred"), text)
        XCTAssertTrue(text.contains("dirhams"), text)
        XCTAssertFalse(text.contains("fils"), text)
    }

    func testFirstLetterIsCapitalisedInEnglish() {
        let text = AmountInWords.string(7, currencyCode: "USD", locale: en)
        XCTAssertEqual(text.first?.isUppercase, true, text)
    }

    func testArabicAndHindiProduceTextWithCurrencyName() {
        let arabic = AmountInWords.string(120, currencyCode: "SAR", locale: Locale(identifier: "ar"))
        XCTAssertTrue(arabic.contains("ريال"), arabic)
        XCTAssertTrue(arabic.contains("فقط"), arabic)
        let hindi = AmountInWords.string(120, currencyCode: "INR", locale: Locale(identifier: "hi"))
        XCTAssertTrue(hindi.contains("रुपये"), hindi)
        XCTAssertTrue(hindi.contains("मात्र"), hindi)
    }

    func testUnknownCurrencyFallsBackToCode() {
        let text = AmountInWords.string(3, currencyCode: "JPY", locale: en)
        XCTAssertTrue(text.contains("JPY"), text)
    }

    func testRoundingDoesNotLoseACent() {
        // 0.1 + 0.2 style float noise must not turn 20.30 into 20.29
        let text = AmountInWords.string(20.30, currencyCode: "USD", locale: en).lowercased()
        XCTAssertTrue(text.contains("thirty cents"), text)
    }

    func testCustomaryByCurrencyOrLanguage() {
        XCTAssertTrue(AmountInWords.isCustomary(currencyCode: "INR", languageCode: ""))
        XCTAssertTrue(AmountInWords.isCustomary(currencyCode: "AED", languageCode: "en"))
        XCTAssertTrue(AmountInWords.isCustomary(currencyCode: "USD", languageCode: "ar"))
        XCTAssertFalse(AmountInWords.isCustomary(currencyCode: "USD", languageCode: "fr"))
    }
}
