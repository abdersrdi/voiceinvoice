import Foundation

/// A token of dictated text. `key` is lowercase and accent-free, used for vocabulary lookups.
struct Tok {
    var raw: String
    var key: String
    var value: Double?
    var isSep = false
}

enum NumKind {
    case small(Int)          // 0...99
    case hundred             // multiplier: "hundred", "cent(s)"
    case thousand            // multiplier: "thousand", "mille", "mil"
    case fixedHundred(Int)   // fused hundreds: "doscientos", "duecento"
    case fixedThousand(Int)  // fused thousands: "duemila"
    case connector           // "and", "et", "y"
}

/// Per-language vocabulary for the rule-based parser (English, French, Spanish, Italian).
struct Lexicon {
    let language: ParserLanguage
    let decimalComma: Bool
    let splitApostrophes: Bool
    let numbers: [String: NumKind]
    let decimalWords: Set<String>
    let determiners: Set<String>
    let fillers: Set<String>
    let separators: Set<String>
    let atWords: Set<String>
    let forWords: Set<String>
    let eachPhrases: [[String]]
    let totalPhrases: [[String]]
    let currency: Set<String>
    let noConvertAfter: Set<String>

    static func key(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
    }

    private static let symbols: Set<String> = ["$", "€", "£", "¥"]

    static func forLanguage(_ language: ParserLanguage) -> Lexicon {
        switch language {
        case .en: return english
        case .fr: return french
        case .es: return spanish
        case .it: return italian
        case .zh: return english // Chinese uses ChineseParser; never reached
        }
    }

    // MARK: English

    static let english: Lexicon = {
        var m: [String: NumKind] = [:]
        let small = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
                     "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
                     "seventeen", "eighteen", "nineteen"]
        for (i, w) in small.enumerated() { m[w] = .small(i) }
        let tens = ["twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
        for (i, w) in tens.enumerated() { m[w] = .small((i + 2) * 10) }
        m["hundred"] = .hundred
        m["thousand"] = .thousand
        m["and"] = .connector
        return Lexicon(
            language: .en,
            decimalComma: false,
            splitApostrophes: false,
            numbers: m,
            decimalWords: ["point"],
            determiners: ["a", "an", "the", "some"],
            fillers: ["put", "in", "add", "adding", "please", "i", "sold", "sell", "got", "have",
                      "we", "also", "plus", "then", "next", "another"],
            separators: ["and", "also", "plus", "then"],
            atWords: ["at"],
            forWords: ["for"],
            eachPhrases: [["each"], ["apiece"], ["per", "piece"], ["per", "item"], ["per", "unit"],
                          ["per"], ["a", "piece"]],
            totalPhrases: [["in", "total"], ["total"], ["altogether"], ["overall"], ["all", "together"]],
            currency: ["dollars", "dollar", "bucks", "buck", "euros", "euro", "pounds", "pound",
                       "quid", "usd", "eur", "gbp", "$", "€", "£", "¥"],
            noConvertAfter: []
        )
    }()

    // MARK: French

    static let french: Lexicon = {
        var m: [String: NumKind] = [:]
        let small = ["zero", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf",
                     "dix", "onze", "douze", "treize", "quatorze", "quinze", "seize"]
        for (i, w) in small.enumerated() { m[w] = .small(i) }
        m["une"] = .small(1)
        let tens: [(String, Int)] = [("vingt", 20), ("trente", 30), ("quarante", 40), ("cinquante", 50),
                                     ("soixante", 60), ("septante", 70), ("huitante", 80),
                                     ("octante", 80), ("nonante", 90)]
        for (w, v) in tens { m[w] = .small(v) }
        m["cent"] = .hundred
        m["cents"] = .hundred
        m["mille"] = .thousand
        m["et"] = .connector
        return Lexicon(
            language: .fr,
            decimalComma: true,
            splitApostrophes: true,
            numbers: m,
            decimalWords: ["virgule"],
            determiners: ["un", "une", "des", "le", "la", "les", "du", "de", "d", "l"],
            fillers: ["mets", "met", "mettre", "mettez", "ajoute", "ajouter", "ajoutez", "j", "ai",
                      "vendu", "aussi", "encore", "alors", "donc"],
            separators: ["et", "aussi", "puis", "ensuite", "plus"],
            atWords: ["a", "au", "aux"],
            forWords: ["pour"],
            eachPhrases: [["chacun"], ["chacune"], ["la", "piece"], ["l", "unite"], ["par", "piece"],
                          ["piece"], ["par"]],
            totalPhrases: [["au", "total"], ["en", "tout"], ["en", "total"], ["total"], ["ensemble"]],
            currency: ["euros", "euro", "dollars", "dollar", "francs", "franc", "balles", "balle",
                       "eur", "usd", "$", "€", "£", "¥"],
            noConvertAfter: []
        )
    }()

    // MARK: Spanish

    static let spanish: Lexicon = {
        var m: [String: NumKind] = [:]
        let small = ["cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
                     "diez", "once", "doce", "trece", "catorce", "quince", "dieciseis", "diecisiete",
                     "dieciocho", "diecinueve", "veinte"]
        for (i, w) in small.enumerated() { m[w] = .small(i) }
        m["un"] = .small(1)
        m["una"] = .small(1)
        let veinti = ["veintiuno", "veintidos", "veintitres", "veinticuatro", "veinticinco",
                      "veintiseis", "veintisiete", "veintiocho", "veintinueve"]
        for (i, w) in veinti.enumerated() { m[w] = .small(21 + i) }
        m["veintiun"] = .small(21)
        m["veintiuna"] = .small(21)
        let tens: [(String, Int)] = [("treinta", 30), ("cuarenta", 40), ("cincuenta", 50),
                                     ("sesenta", 60), ("setenta", 70), ("ochenta", 80), ("noventa", 90)]
        for (w, v) in tens { m[w] = .small(v) }
        m["cien"] = .fixedHundred(100)
        m["ciento"] = .fixedHundred(100)
        let hundreds: [(String, Int)] = [("doscientos", 200), ("trescientos", 300), ("cuatrocientos", 400),
                                         ("quinientos", 500), ("seiscientos", 600), ("setecientos", 700),
                                         ("ochocientos", 800), ("novecientos", 900)]
        for (w, v) in hundreds {
            m[w] = .fixedHundred(v)
            m[String(w.dropLast()) + "as"] = .fixedHundred(v)
        }
        m["mil"] = .thousand
        m["y"] = .connector
        return Lexicon(
            language: .es,
            decimalComma: true,
            splitApostrophes: false,
            numbers: m,
            decimalWords: ["coma"],
            determiners: ["un", "una", "unos", "unas", "el", "la", "los", "las", "de"],
            fillers: ["pon", "poner", "anade", "agrega", "agregar", "he", "vendido", "vendi",
                      "tambien", "ademas", "otro", "otra"],
            separators: ["y", "tambien", "ademas", "luego"],
            atWords: ["a"],
            forWords: ["por", "para"],
            eachPhrases: [["cada", "uno"], ["cada", "una"], ["cada"], ["c/u"]],
            totalPhrases: [["en", "total"], ["en", "todo"], ["en", "conjunto"], ["total"], ["todo"]],
            currency: ["euros", "euro", "dolares", "dolar", "pesos", "peso", "libras", "libra",
                       "eur", "usd", "$", "€", "£", "¥"],
            noConvertAfter: ["cada"]
        )
    }()

    // MARK: Italian

    static let italian: Lexicon = {
        var m: [String: NumKind] = [:]
        let small = ["zero", "uno", "due", "tre", "quattro", "cinque", "sei", "sette", "otto", "nove",
                     "dieci", "undici", "dodici", "tredici", "quattordici", "quindici", "sedici",
                     "diciassette", "diciotto", "diciannove"]
        for (i, w) in small.enumerated() { m[w] = .small(i) }
        m["un"] = .small(1)
        m["una"] = .small(1)
        let tens: [(String, Int)] = [("venti", 20), ("trenta", 30), ("quaranta", 40), ("cinquanta", 50),
                                     ("sessanta", 60), ("settanta", 70), ("ottanta", 80), ("novanta", 90)]
        let units: [(String, Int)] = [("uno", 1), ("due", 2), ("tre", 3), ("quattro", 4), ("cinque", 5),
                                      ("sei", 6), ("sette", 7), ("otto", 8), ("nove", 9)]
        for (stem, value) in tens {
            m[stem] = .small(value)
            for (unit, unitValue) in units {
                let base = (unit == "uno" || unit == "otto") ? String(stem.dropLast()) : stem
                m[base + unit] = .small(value + unitValue)
            }
        }
        m["cento"] = .fixedHundred(100)
        m["mille"] = .thousand
        for (unit, unitValue) in units where unitValue >= 2 {
            m[unit + "cento"] = .fixedHundred(unitValue * 100)
            m[unit + "mila"] = .fixedThousand(unitValue * 1000)
        }
        return Lexicon(
            language: .it,
            decimalComma: true,
            splitApostrophes: true,
            numbers: m,
            decimalWords: ["virgola"],
            determiners: ["un", "uno", "una", "il", "lo", "la", "i", "gli", "le", "l", "di"],
            fillers: ["metti", "aggiungi", "inserisci", "segna", "ho", "venduto", "anche", "ancora", "poi"],
            separators: ["e", "anche", "poi", "inoltre"],
            atWords: ["a"],
            forWords: ["per"],
            eachPhrases: [["l", "uno"], ["l", "una"], ["ciascuno"], ["ciascuna"], ["cadauno"],
                          ["cadauna"], ["ognuno"], ["ognuna"], ["cad"]],
            totalPhrases: [["in", "totale"], ["in", "tutto"], ["totale"], ["complessivamente"]],
            currency: ["euro", "euri", "dollari", "dollaro", "eur", "usd", "$", "€", "£", "¥"],
            noConvertAfter: ["l"]
        )
    }()
}
