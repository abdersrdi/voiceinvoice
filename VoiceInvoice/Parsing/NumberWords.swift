import Foundation

/// Turns spoken number words ("one hundred and fifty", "quatre-vingt-dix", "treinta y cinco")
/// into values, for English, French, Spanish and Italian.
enum NumberWords {
    static func parse(_ toks: [Tok], at start: Int, lex: Lexicon) -> (value: Double, length: Int)? {
        var i = start
        var total = 0
        var current = 0
        var consumed = false
        var hasThousand = false

        scan: while i < toks.count {
            let tok = toks[i]
            if tok.value != nil || tok.isSep { break scan }

            // French "quatre-vingt(s)" = 80
            if lex.language == .fr, tok.key == "quatre", i + 1 < toks.count,
               toks[i + 1].key == "vingt" || toks[i + 1].key == "vingts",
               current % 100 == 0 {
                current += 80
                i += 2
                consumed = true
                continue scan
            }

            guard let kind = lex.numbers[tok.key] else { break scan }
            switch kind {
            case .small(let v):
                if v == 0 && consumed { break scan }
                guard canAppendSmall(current: current, value: v, lex: lex) else { break scan }
                current += v
                i += 1
                consumed = true
            case .hundred:
                guard current < 100 else { break scan }
                current = max(current, 1) * 100
                i += 1
                consumed = true
            case .thousand:
                guard !hasThousand else { break scan }
                total += max(current, 1) * 1000
                current = 0
                hasThousand = true
                i += 1
                consumed = true
            case .fixedHundred(let v):
                guard current == 0 else { break scan }
                current = v
                i += 1
                consumed = true
            case .fixedThousand(let v):
                guard !hasThousand, current == 0 else { break scan }
                total += v
                hasThousand = true
                i += 1
                consumed = true
            case .connector:
                guard consumed, i + 1 < toks.count, toks[i + 1].value == nil,
                      let next = lex.numbers[toks[i + 1].key],
                      case .small(let v) = next,
                      connectorAllowed(current: current, total: total, next: v, lex: lex)
                else { break scan }
                i += 1
            }
        }

        guard consumed else { return nil }
        var value = Double(total + current)

        if i < toks.count, toks[i].value == nil, lex.decimalWords.contains(toks[i].key) {
            var j = i + 1
            var digits = ""
            while j < toks.count {
                if let n = toks[j].value, digits.isEmpty, n >= 0, n == n.rounded() {
                    digits = String(Int(n))
                    j += 1
                    break
                }
                guard toks[j].value == nil, let kind = lex.numbers[toks[j].key],
                      case .small(let v) = kind else { break }
                if v <= 9 {
                    digits += String(v)
                    j += 1
                } else if digits.isEmpty {
                    digits = String(v)
                    j += 1
                    break
                } else {
                    break
                }
            }
            if !digits.isEmpty, let fraction = Double("0." + digits) {
                value += fraction
                i = j
            }
        }
        return (value, i - start)
    }

    static func canAppendSmall(current: Int, value: Int, lex: Lexicon) -> Bool {
        if current == 0 { return true }
        let low = current % 100
        if value == 0 { return false }
        if low == 0 { return true }
        if low >= 20, low % 10 == 0, (1...9).contains(value) { return true }
        if lex.language == .fr {
            if (low == 60 || low == 80), (10...19).contains(value) { return true }
            if low == 10, (7...9).contains(value) { return true } // dix-sept, dix-huit, dix-neuf
        }
        return false
    }

    static func connectorAllowed(current: Int, total: Int, next: Int, lex: Lexicon) -> Bool {
        let low = current % 100
        switch lex.language {
        case .en:
            return next < 100 && ((current >= 100 && low == 0) || (total > 0 && current == 0))
        case .fr:
            return [20, 30, 40, 50, 60].contains(low) && (next == 1 || next == 11)
        case .es:
            return low >= 30 && low % 10 == 0 && (1...9).contains(next)
        case .it, .zh:
            return false
        }
    }
}
