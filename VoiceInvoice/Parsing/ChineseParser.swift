import Foundation

/// Simplified Chinese: "两件衬衫每件二十块，一条裤子四十块" -> 衬衫 2 x 20, 裤子 1 x 40.
enum ChineseParser {
    private static let digitValues: [Character: Int] = [
        "零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
    ]
    private static let unitValues: [Character: Int] = ["十": 10, "百": 100, "千": 1000]
    private static let measures = "个件条双瓶杯份包箱盒本张只台套袋支根碗盘"
    private static let notNumberAfterOne: Set<Character> = ["共", "起", "些", "下", "定", "般", "样", "直"]

    static func parse(_ text: String) -> [ParsedItem] {
        let normalized = normalizeNumerals(text)
        return splitSegments(normalized).compactMap(parseSegment)
    }

    // MARK: Numerals

    static func isNumeralChar(_ ch: Character) -> Bool {
        digitValues[ch] != nil || unitValues[ch] != nil || ch == "万"
    }

    /// Replaces runs of Chinese numerals ("二十五") with digits ("25").
    static func normalizeNumerals(_ text: String) -> String {
        let chars = Array(text)
        var out = ""
        var i = 0
        while i < chars.count {
            guard isNumeralChar(chars[i]) else {
                out.append(chars[i])
                i += 1
                continue
            }
            var j = i
            while j < chars.count {
                if isNumeralChar(chars[j]) {
                    j += 1
                } else if chars[j] == "点", j > i, j + 1 < chars.count, digitValues[chars[j + 1]] != nil {
                    j += 1
                } else {
                    break
                }
            }
            let run = String(chars[i..<j])
            if run == "一", j < chars.count, notNumberAfterOne.contains(chars[j]) {
                out.append(contentsOf: run)
            } else if let value = numberValue(run) {
                out.append(contentsOf: format(value))
            } else {
                out.append(contentsOf: run)
            }
            i = j
        }
        return out
    }

    static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    static func numberValue(_ run: String) -> Double? {
        let parts = run.split(separator: "点", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard let integerPart = parts.first, let integer = integerValue(integerPart) else { return nil }
        var value = Double(integer)
        if parts.count == 2 {
            var digits = ""
            for ch in parts[1] {
                guard let d = digitValues[ch] else { return nil }
                digits += String(d)
            }
            if let fraction = Double("0." + digits) { value += fraction }
        }
        return value
    }

    static func integerValue(_ text: String) -> Int? {
        let chars = Array(text)
        guard !chars.isEmpty else { return nil }
        // Positional style: "二零二" -> 202
        if chars.allSatisfy({ digitValues[$0] != nil }) {
            var digits = ""
            for ch in chars { digits += String(digitValues[ch] ?? 0) }
            return Int(digits)
        }
        var total = 0
        var section = 0
        var number = 0
        for ch in chars {
            if let d = digitValues[ch] {
                number = d
            } else if let unit = unitValues[ch] {
                section += (number == 0 ? 1 : number) * unit
                number = 0
            } else if ch == "万" {
                section += number
                total += max(section, 1) * 10_000
                section = 0
                number = 0
            } else {
                return nil
            }
        }
        return total + section + number
    }

    // MARK: Segments

    static func splitSegments(_ text: String) -> [String] {
        var working = text
        for word in ["还有", "以及", "然后", "另外", "再加", "再来", "还要", "和", "跟"] {
            working = working.replacingOccurrences(of: word, with: "|")
        }
        let separators = CharacterSet(charactersIn: "|，,。；;、！!？?\n")
        return working.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static let quantityRegex = try? NSRegularExpression(
        pattern: "^\\s*(?:我要|要|买|卖|加|来|再来|给我|我|再)?\\s*(\\d+(?:\\.\\d+)?)\\s*[\(measures)]?\\s*(.*)$"
    )
    private static let priceRegex = try? NSRegularExpression(
        pattern: "(每[\(measures)]?|单价|一共|总共|共计|合计|总价|共)?\\s*(\\d+(?:\\.\\d+)?)\\s*(块钱|块|元|欧元|美元|人民币|欧|刀)?"
    )
    private static let leadingFiller = try? NSRegularExpression(pattern: "^(?:我要|要|买|卖|加|来|再来|给我|我|再)+")

    private static func group(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    static func parseSegment(_ segment: String) -> ParsedItem? {
        var quantity = 1.0
        var rest = segment

        let whole = NSRange(segment.startIndex..., in: segment)
        if let regex = quantityRegex, let match = regex.firstMatch(in: segment, range: whole),
           let qtyText = group(match, 1, in: segment), let qty = Double(qtyText), qty > 0 {
            quantity = qty
            rest = group(match, 2, in: segment) ?? ""
        } else if let regex = leadingFiller {
            rest = regex.stringByReplacingMatches(in: segment, range: whole, withTemplate: "")
        }

        var price = 0.0
        var isTotal = false
        var name = rest

        if let regex = priceRegex {
            let restRange = NSRange(rest.startIndex..., in: rest)
            let matches = regex.matches(in: rest, range: restRange)
            let trimmedEnd = rest.trimmingCharacters(in: .whitespaces).utf16.count
            let chosen = matches.last { match in
                let hasMarker = group(match, 1, in: rest) != nil
                let hasCurrency = group(match, 3, in: rest) != nil
                let atEnd = match.range.location + match.range.length >= trimmedEnd
                return hasMarker || hasCurrency || atEnd
            }
            if let match = chosen, let priceText = group(match, 2, in: rest), let value = Double(priceText) {
                price = value
                if let marker = group(match, 1, in: rest) {
                    isTotal = !(marker.hasPrefix("每") || marker == "单价")
                }
                if let range = Range(match.range, in: rest) {
                    name = rest.replacingCharacters(in: range, with: "")
                }
            }
        }

        let trimSet = CharacterSet(charactersIn: "的了每各 ").union(.whitespaces)
        name = name.trimmingCharacters(in: trimSet)
        if name.isEmpty && price == 0 { return nil }

        let unitPrice = (isTotal && quantity > 0) ? price / quantity : price
        return ParsedItem(name: name, quantity: quantity, unitPrice: unitPrice, rawText: segment)
    }
}
