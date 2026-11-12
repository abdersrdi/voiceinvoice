import Foundation

/// Writes an invoice total in words ("Rupees one thousand two hundred fifty and fifty paise only"), as buyers in
/// India, the Gulf and West Asia expect on an invoice. Numbers are spelled by the system for the document language;
/// the currency names are kept here for the common currencies of those markets and fall back to the ISO code.
enum AmountInWords {
    private struct Unit {
        var major: String
        var minor: String
    }

    /// Currency names by language. Languages or currencies not listed fall back to "<words> <CODE>".
    private static let names: [String: [String: Unit]] = [
        "en": [
            "INR": Unit(major: "rupees", minor: "paise"),
            "AED": Unit(major: "dirhams", minor: "fils"),
            "SAR": Unit(major: "riyals", minor: "halalas"),
            "QAR": Unit(major: "riyals", minor: "dirhams"),
            "KWD": Unit(major: "dinars", minor: "fils"),
            "BHD": Unit(major: "dinars", minor: "fils"),
            "OMR": Unit(major: "rials", minor: "baisa"),
            "PKR": Unit(major: "rupees", minor: "paisas"),
            "USD": Unit(major: "dollars", minor: "cents"),
            "EUR": Unit(major: "euros", minor: "cents"),
            "GBP": Unit(major: "pounds", minor: "pence")
        ],
        "ar": [
            "INR": Unit(major: "روبية", minor: "بيسة"),
            "AED": Unit(major: "درهم", minor: "فلس"),
            "SAR": Unit(major: "ريال", minor: "هللة"),
            "QAR": Unit(major: "ريال", minor: "درهم"),
            "KWD": Unit(major: "دينار", minor: "فلس"),
            "BHD": Unit(major: "دينار", minor: "فلس"),
            "OMR": Unit(major: "ريال", minor: "بيسة"),
            "USD": Unit(major: "دولار", minor: "سنت"),
            "EUR": Unit(major: "يورو", minor: "سنت")
        ],
        "hi": [
            "INR": Unit(major: "रुपये", minor: "पैसे"),
            "AED": Unit(major: "दिरहम", minor: "फ़िल्स"),
            "SAR": Unit(major: "रियाल", minor: "हलाला"),
            "USD": Unit(major: "डॉलर", minor: "सेंट"),
            "EUR": Unit(major: "यूरो", minor: "सेंट")
        ],
        "ur": [
            "PKR": Unit(major: "روپے", minor: "پیسے"),
            "INR": Unit(major: "روپے", minor: "پیسے"),
            "AED": Unit(major: "درہم", minor: "فلس"),
            "SAR": Unit(major: "ریال", minor: "ہللہ"),
            "USD": Unit(major: "ڈالر", minor: "سینٹ")
        ]
    ]

    private static let onlyWord: [String: String] = ["en": "only", "ar": "فقط", "hi": "मात्र", "ur": "صرف"]
    private static let andWord: [String: String] = ["en": "and", "ar": "و", "hi": "और", "ur": "اور"]

    /// Currencies where an amount in words is customary on invoices.
    static let customaryCurrencies: Set<String> = [
        "INR", "PKR", "BDT", "LKR", "NPR", "AED", "SAR", "QAR", "KWD", "BHD", "OMR", "EGP", "JOD", "IQD", "LBP"
    ]

    /// Whether the invoice should show an amount in words: by currency, or for Arabic, Hindi and Urdu documents.
    static func isCustomary(currencyCode: String, languageCode: String) -> Bool {
        customaryCurrencies.contains(currencyCode.uppercased())
            || ["ar", "hi", "ur"].contains(baseLanguage(languageCode))
    }

    private static func baseLanguage(_ code: String) -> String {
        String(code.split(separator: "-").first ?? "").lowercased()
    }

    static func string(_ amount: Double, currencyCode: String, locale: Locale) -> String {
        let digits = InvoiceMath.fractionDigits(for: currencyCode)
        let scale = Int(pow(10.0, Double(digits)))
        let minorTotal = Int((abs(amount) * Double(scale)).rounded())
        let major = minorTotal / scale
        let minor = minorTotal % scale

        let language = locale.language.languageCode?.identifier ?? "en"
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = locale
        func spell(_ value: Int) -> String { formatter.string(from: NSNumber(value: value)) ?? String(value) }

        let code = currencyCode.uppercased()
        let unit = names[language]?[code]
        let majorName = unit?.major ?? code
        let and = andWord[language] ?? "&"

        var parts: [String] = ["\(spell(major)) \(majorName)"]
        if minor > 0 {
            let minorName = unit?.minor ?? ""
            parts.append(and)
            parts.append("\(spell(minor)) \(minorName)".trimmingCharacters(in: .whitespaces))
        }
        if let only = onlyWord[language] { parts.append(only) }
        var text = parts.joined(separator: " ")
        if language == "en", let first = text.first { text = first.uppercased() + text.dropFirst() }
        return text
    }
}
