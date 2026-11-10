import XCTest
@testable import VoiceInvoice

final class LineItemParserTests: XCTestCase {
    private func parse(_ text: String, _ language: ParserLanguage) -> [(name: String, qty: Double, price: Double)] {
        LineItemParser.parse(text, language: language).map { ($0.name.lowercased(), $0.quantity, $0.unitPrice) }
    }

    private func assertItems(
        _ text: String,
        _ language: ParserLanguage,
        _ expected: [(String, Double, Double)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = parse(text, language)
        XCTAssertEqual(actual.count, expected.count, "item count for “\(text)”: \(actual)", file: file, line: line)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a.name, e.0, "name for “\(text)”", file: file, line: line)
            XCTAssertEqual(a.qty, e.1, accuracy: 0.0001, "qty for “\(text)”", file: file, line: line)
            XCTAssertEqual(a.price, e.2, accuracy: 0.0001, "price for “\(text)”", file: file, line: line)
        }
    }

    // MARK: English

    func testEnglishSpec() {
        assertItems(
            "Put in two shirts at 20 bucks each and also a pair of pants for 40",
            .en,
            [("shirts", 2, 20), ("pair of pants", 1, 40)]
        )
    }

    func testEnglishNumberWords() {
        assertItems("three hats at twenty five dollars each", .en, [("hats", 3, 25)])
        assertItems("a jacket for one hundred and fifty dollars", .en, [("jacket", 1, 150)])
        assertItems("a watch for two thousand five hundred", .en, [("watch", 1, 2500)])
    }

    func testEnglishTotalPriceForQuantity() {
        assertItems("three coffees for 12", .en, [("coffees", 3, 4)])
        assertItems("three coffees for 12 dollars in total", .en, [("coffees", 3, 4)])
        assertItems("three coffees for 4 each", .en, [("coffees", 3, 4)])
    }

    func testEnglishSymbolsAndDecimals() {
        assertItems("2 bags at $12.50 each", .en, [("bags", 2, 12.5)])
        assertItems("a scarf for twenty point five", .en, [("scarf", 1, 20.5)])
        assertItems("a lamp for $1,200", .en, [("lamp", 1, 1200)])
    }

    func testEnglishPriceFirst() {
        assertItems("20 dollars for a shirt", .en, [("shirt", 1, 20)])
    }

    func testMissingPriceNeedsReview() {
        let items = LineItemParser.parse("two shirts", language: .en)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.quantity, 2)
        XCTAssertTrue(items.first?.needsReview ?? false)
    }

    func testEmptyAndFillerOnly() {
        XCTAssertTrue(LineItemParser.parse("", language: .en).isEmpty)
        XCTAssertTrue(LineItemParser.parse("put in", language: .en).isEmpty)
    }

    // MARK: French

    func testFrench() {
        assertItems(
            "deux chemises à vingt euros chacune et un pantalon pour quarante euros",
            .fr,
            [("chemises", 2, 20), ("pantalon", 1, 40)]
        )
    }

    func testFrenchNumbers() {
        assertItems("un sac à quatre-vingt-dix euros", .fr, [("sac", 1, 90)])
        assertItems("un sac à soixante-dix euros", .fr, [("sac", 1, 70)])
        assertItems("un sac à soixante et onze euros", .fr, [("sac", 1, 71)])
        assertItems("un sac à vingt et un euros", .fr, [("sac", 1, 21)])
        assertItems("une montre à deux cents euros", .fr, [("montre", 1, 200)])
        assertItems("un manteau à mille deux cent cinquante euros", .fr, [("manteau", 1, 1250)])
    }

    func testFrenchTotalAndDecimal() {
        assertItems("trois cafés pour douze euros", .fr, [("cafés", 3, 4)])
        assertItems("une écharpe à 12,50 €", .fr, [("écharpe", 1, 12.5)])
    }

    // MARK: Spanish

    func testSpanish() {
        assertItems(
            "dos camisas a veinte euros cada una y unos pantalones por cuarenta euros",
            .es,
            [("camisas", 2, 20), ("pantalones", 1, 40)]
        )
    }

    func testSpanishNumbers() {
        assertItems("un bolso a treinta y cinco euros", .es, [("bolso", 1, 35)])
        assertItems("un reloj a doscientos cincuenta euros", .es, [("reloj", 1, 250)])
        assertItems("un abrigo a mil quinientos euros", .es, [("abrigo", 1, 1500)])
        assertItems("una bufanda a veintiún euros", .es, [("bufanda", 1, 21)])
    }

    func testSpanishTotal() {
        assertItems("tres cafés por doce euros", .es, [("cafés", 3, 4)])
    }

    // MARK: Italian

    func testItalian() {
        assertItems(
            "due camicie a venti euro l'uno e un paio di pantaloni a quaranta euro",
            .it,
            [("camicie", 2, 20), ("paio di pantaloni", 1, 40)]
        )
    }

    func testItalianNumbers() {
        assertItems("una borsa a trentacinque euro", .it, [("borsa", 1, 35)])
        assertItems("una borsa a ventuno euro", .it, [("borsa", 1, 21)])
        assertItems("un orologio a duecentocinquanta euro", .it, [("orologio", 1, 250)])
        assertItems("un cappotto a mille e duecento euro", .it, [("cappotto", 1, 1200)])
    }

    func testItalianTotal() {
        assertItems("tre caffè per dodici euro", .it, [("caffè", 3, 4)])
    }

    // MARK: Chinese

    func testChinese() {
        assertItems("两件衬衫每件二十块，一条裤子四十块", .zh, [("衬衫", 2, 20), ("裤子", 1, 40)])
    }

    func testChineseTotalAndDigits() {
        assertItems("三杯咖啡一共十二块", .zh, [("咖啡", 3, 4)])
        assertItems("2件衬衫每件20块 和 1条裤子40块", .zh, [("衬衫", 2, 20), ("裤子", 1, 40)])
    }

    func testChineseNumerals() {
        XCTAssertEqual(ChineseParser.integerValue("二十五"), 25)
        XCTAssertEqual(ChineseParser.integerValue("十二"), 12)
        XCTAssertEqual(ChineseParser.integerValue("一百零五"), 105)
        XCTAssertEqual(ChineseParser.integerValue("一千二百"), 1200)
        XCTAssertEqual(ChineseParser.numberValue("二十点五"), 20.5)
    }
}

final class NumberWordsTests: XCTestCase {
    func testParseDigitsLocales() {
        XCTAssertEqual(LineItemParser.parseDigits("1,000", decimalComma: false), 1000)
        XCTAssertEqual(LineItemParser.parseDigits("12.50", decimalComma: false), 12.5)
        XCTAssertEqual(LineItemParser.parseDigits("12,50", decimalComma: true), 12.5)
        XCTAssertEqual(LineItemParser.parseDigits("1.234,56", decimalComma: true), 1234.56)
        XCTAssertEqual(LineItemParser.parseDigits("1,234.56", decimalComma: false), 1234.56)
        XCTAssertEqual(LineItemParser.parseDigits("1.000.000", decimalComma: true), 1_000_000)
        XCTAssertNil(LineItemParser.parseDigits("abc", decimalComma: false))
    }

    func testAdjacentNumbersStaySeparate() {
        let toks = LineItemParser.mergeNumbers(
            LineItemParser.tokenize("two three", lex: .english),
            lex: .english
        )
        XCTAssertEqual(toks.compactMap(\.value), [2, 3])
    }
}
