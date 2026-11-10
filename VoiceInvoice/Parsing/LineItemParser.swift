import Foundation

/// Rule-based parser: dictated text -> invoice line items.
/// Handles "two shirts at 20 each and a pair of pants for 40" in English, French, Spanish,
/// Italian (here) and Simplified Chinese (see ChineseParser).
enum LineItemParser {
    static func parse(_ text: String, language: ParserLanguage) -> [ParsedItem] {
        if language == .zh {
            return ChineseParser.parse(text)
        }
        let lex = Lexicon.forLanguage(language)
        let tokens = mergeNumbers(tokenize(text, lex: lex), lex: lex)
        return segments(tokens, lex: lex).compactMap { parseSegment($0, lex: lex) }
    }

    // MARK: Tokenizing

    static func tokenize(_ text: String, lex: Lexicon) -> [Tok] {
        var out: [Tok] = []
        var current = ""
        let chars = Array(text)
        let currencySymbols: Set<Character> = ["$", "€", "£", "¥"]
        let punctuation: Set<Character> = [",", ".", ";", ":", "!", "?", "\n"]
        let apostrophes: Set<Character> = ["'", "’"]

        func appendWord(_ word: String) {
            if let value = parseDigits(word, decimalComma: lex.decimalComma) {
                out.append(Tok(raw: word, key: word, value: value))
                return
            }
            if word.contains("-") {
                let parts = word.split(separator: "-").map(String.init)
                if parts.count > 1, parts.allSatisfy({ lex.numbers[Lexicon.key($0)] != nil }) {
                    for part in parts {
                        out.append(Tok(raw: part, key: Lexicon.key(part), value: nil))
                    }
                    return
                }
            }
            if lex.language == .it, lex.numbers[Lexicon.key(word)] == nil,
               let parts = decompose(Lexicon.key(word), lex: lex) {
                for part in parts {
                    out.append(Tok(raw: part, key: part, value: nil))
                }
                return
            }
            if word.allSatisfy({ !$0.isLetter && !$0.isNumber }) { return }
            out.append(Tok(raw: word, key: Lexicon.key(word), value: nil))
        }

        func flush() {
            if !current.isEmpty {
                appendWord(current)
                current = ""
            }
        }

        for (index, ch) in chars.enumerated() {
            if ch.isWhitespace && ch != "\n" {
                flush()
            } else if currencySymbols.contains(ch) {
                flush()
                out.append(Tok(raw: String(ch), key: String(ch), value: nil))
            } else if punctuation.contains(ch) {
                let prevIsDigit = current.last.map { $0.isASCII && $0.isNumber } ?? false
                let nextIsDigit = index + 1 < chars.count && chars[index + 1].isASCII && chars[index + 1].isNumber
                if (ch == "," || ch == ".") && prevIsDigit && nextIsDigit {
                    current.append(ch)
                } else {
                    flush()
                    out.append(Tok(raw: String(ch), key: String(ch), value: nil, isSep: true))
                }
            } else if apostrophes.contains(ch) {
                if lex.splitApostrophes {
                    flush()
                } else {
                    current.append(ch)
                }
            } else {
                current.append(ch)
            }
        }
        flush()
        return out
    }

    /// Splits a fused Italian number ("duecentocinquanta") into known number words.
    static func decompose(_ key: String, lex: Lexicon) -> [String]? {
        let chars = Array(key)
        guard chars.count >= 6 else { return nil }
        var best = [[String]?](repeating: nil, count: chars.count + 1)
        best[0] = []
        for end in 1...chars.count {
            for start in 0..<end {
                guard let prefix = best[start] else { continue }
                let piece = String(chars[start..<end])
                guard piece != "e", lex.numbers[piece] != nil else { continue }
                let candidate = prefix + [piece]
                if let existing = best[end], existing.count <= candidate.count { continue }
                best[end] = candidate
            }
        }
        if let result = best[chars.count], result.count > 1 { return result }
        return nil
    }

    static func parseDigits(_ text: String, decimalComma: Bool) -> Double? {
        let isDigit: (Character) -> Bool = { $0 >= "0" && $0 <= "9" }
        guard let first = text.first, isDigit(first), let last = text.last, isDigit(last),
              text.allSatisfy({ isDigit($0) || $0 == "," || $0 == "." }) else { return nil }

        let hasComma = text.contains(",")
        let hasDot = text.contains(".")
        var normalized = text

        if hasComma && hasDot {
            let lastComma = text.lastIndex(of: ",")!
            let lastDot = text.lastIndex(of: ".")!
            if lastComma > lastDot {
                normalized = text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = text.replacingOccurrences(of: ",", with: "")
            }
        } else if hasComma {
            let parts = text.split(separator: ",", omittingEmptySubsequences: false)
            let looksThousands = parts.count > 1 && parts[0].count <= 3 && parts.dropFirst().allSatisfy { $0.count == 3 }
            if decimalComma {
                normalized = parts.count == 2 ? text.replacingOccurrences(of: ",", with: ".")
                                              : text.replacingOccurrences(of: ",", with: "")
            } else if looksThousands {
                normalized = text.replacingOccurrences(of: ",", with: "")
            } else if parts.count == 2 {
                normalized = text.replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = text.replacingOccurrences(of: ",", with: "")
            }
        } else if hasDot {
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            let looksThousands = parts.count > 1 && parts[0].count <= 3 && parts.dropFirst().allSatisfy { $0.count == 3 }
            if parts.count > 2 || (decimalComma && looksThousands) {
                normalized = text.replacingOccurrences(of: ".", with: "")
            }
        }
        return Double(normalized)
    }

    static func mergeNumbers(_ toks: [Tok], lex: Lexicon) -> [Tok] {
        var out: [Tok] = []
        var i = 0
        while i < toks.count {
            let tok = toks[i]
            let blocked = out.last.map { lex.noConvertAfter.contains($0.key) } ?? false
            if tok.value == nil, !tok.isSep, !blocked,
               let (value, length) = NumberWords.parse(toks, at: i, lex: lex) {
                let raw = toks[i..<(i + length)].map(\.raw).joined(separator: " ")
                out.append(Tok(raw: raw, key: raw, value: value))
                i += length
            } else {
                out.append(tok)
                i += 1
            }
        }
        return out
    }

    // MARK: Segmenting

    static func segments(_ toks: [Tok], lex: Lexicon) -> [[Tok]] {
        var result: [[Tok]] = []
        var current: [Tok] = []
        for tok in toks {
            let isBreak = tok.isSep || (tok.value == nil && lex.separators.contains(tok.key))
            if isBreak {
                if !current.isEmpty { result.append(current) }
                current = []
            } else {
                current.append(tok)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    // MARK: One segment

    static func matchPhrase(_ phrases: [[String]], in toks: [Tok], at index: Int) -> Int? {
        var best: Int?
        for phrase in phrases where index + phrase.count <= toks.count {
            var matches = true
            for (offset, word) in phrase.enumerated() {
                let tok = toks[index + offset]
                if tok.value != nil || tok.key != word {
                    matches = false
                    break
                }
            }
            if matches, phrase.count > (best ?? 0) { best = phrase.count }
        }
        return best
    }

    static func parseSegment(_ input: [Tok], lex: Lexicon) -> ParsedItem? {
        var t = input
        while let first = t.first, first.value == nil, lex.fillers.contains(first.key) {
            t.removeFirst()
        }
        guard !t.isEmpty else { return nil }
        let rawText = t.map(\.raw).joined(separator: " ")

        let numberIndexes = t.indices.filter { t[$0].value != nil }
        var qtyIndex: Int?
        var priceIndex: Int?

        func isCurrency(_ i: Int) -> Bool {
            i >= 0 && i < t.count && t[i].value == nil && lex.currency.contains(t[i].key)
        }

        if numberIndexes.count == 1, let only = numberIndexes.first {
            if only == 0 && !isCurrency(1) {
                qtyIndex = only
            } else {
                priceIndex = only
            }
        } else if numberIndexes.count >= 2 {
            if numberIndexes.first == 0 { qtyIndex = 0 }
            priceIndex = numberIndexes.last
        }

        var quantity: Double = 1
        if let q = qtyIndex, let value = t[q].value, value > 0 { quantity = value }

        var marked = Set<Int>()
        if let q = qtyIndex { marked.insert(q) }
        var atSeen = false, forSeen = false, eachSeen = false, totalSeen = false

        if let p = priceIndex {
            marked.insert(p)
            // Words just before the price: "at", "for", currency symbols, an article ("a hundred").
            var j = p - 1
            while j >= 0, p - j <= 3, j != qtyIndex {
                let key = t[j].key
                if t[j].value != nil { break }
                if lex.currency.contains(key) {
                    marked.insert(j)
                } else if lex.atWords.contains(key) {
                    atSeen = true
                    marked.insert(j)
                } else if lex.forWords.contains(key) {
                    forSeen = true
                    marked.insert(j)
                } else if lex.totalPhrases.contains(where: { $0 == [key] }) {
                    totalSeen = true
                    marked.insert(j)
                } else if lex.determiners.contains(key), j + 1 < t.count, marked.contains(j + 1) {
                    marked.insert(j)
                } else {
                    break
                }
                j -= 1
            }
            // Words just after the price: currency, "each", "in total".
            var k = p + 1
            while k < t.count, t[k].value == nil {
                if let n = matchPhrase(lex.eachPhrases, in: t, at: k) {
                    eachSeen = true
                    for x in k..<(k + n) { marked.insert(x) }
                    k += n
                } else if let n = matchPhrase(lex.totalPhrases, in: t, at: k) {
                    totalSeen = true
                    for x in k..<(k + n) { marked.insert(x) }
                    k += n
                } else if lex.currency.contains(t[k].key) {
                    marked.insert(k)
                    k += 1
                } else {
                    break
                }
            }
            if k < t.count, t[k].value == nil, lex.forWords.contains(t[k].key) {
                marked.insert(k) // "20 dollars for a shirt"
            }
        }

        let priceIsTotal: Bool
        if totalSeen {
            priceIsTotal = true
        } else if eachSeen || atSeen {
            priceIsTotal = false
        } else if forSeen {
            priceIsTotal = quantity > 1
        } else {
            priceIsTotal = false
        }

        var price = 0.0
        if let p = priceIndex, let value = t[p].value { price = value }
        let unitPrice = (priceIsTotal && quantity > 0) ? price / quantity : price

        var nameTokens: [Tok] = []
        for (i, tok) in t.enumerated() where !marked.contains(i) {
            nameTokens.append(tok)
        }
        while nameTokens.count > 1, let first = nameTokens.first, first.value == nil,
              lex.determiners.contains(first.key) {
            nameTokens.removeFirst()
        }
        if nameTokens.count == 1, nameTokens[0].value == nil, lex.determiners.contains(nameTokens[0].key) {
            nameTokens = []
        }
        var name = nameTokens.map(\.raw).joined(separator: " ")
        if let first = name.first {
            name = first.uppercased() + name.dropFirst()
        }

        if name.isEmpty && priceIndex == nil { return nil }
        return ParsedItem(name: name, quantity: quantity, unitPrice: unitPrice, rawText: rawText)
    }
}
