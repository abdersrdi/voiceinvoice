import Foundation

/// The phrase that starts an invoice in counter mode, per dictation language.
enum WakePhrase {
    static func phrases(for language: ParserLanguage) -> [String] {
        switch language {
        case .en: return ["new invoice", "hey invoice", "start invoice"]
        case .fr: return ["nouvelle facture", "dis facture"]
        case .es: return ["nueva factura", "oye factura"]
        case .it: return ["nuova fattura", "ehi fattura"]
        case .zh: return ["新发票", "新建发票", "开发票"]
        }
    }

    /// What to show the user, e.g. "New invoice".
    static func display(for language: ParserLanguage) -> String {
        let phrase = phrases(for: language).first ?? ""
        guard let first = phrase.first else { return phrase }
        return first.uppercased() + phrase.dropFirst()
    }

    /// Returns what was said after the wake phrase, or nil if the phrase was not heard.
    static func detect(in transcript: String, language: ParserLanguage) -> String? {
        var best: Range<String.Index>?
        for phrase in phrases(for: language) {
            guard let range = transcript.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) else {
                continue
            }
            if let current = best {
                if range.lowerBound < current.lowerBound { best = range }
            } else {
                best = range
            }
        }
        guard let match = best else { return nil }
        let trimSet = CharacterSet(charactersIn: ",.;:!?，。！？、").union(.whitespacesAndNewlines)
        return transcript[match.upperBound...].trimmingCharacters(in: trimSet)
    }
}

/// Decides when someone has finished speaking: nothing new for `silenceSeconds` after some words,
/// or no words at all for `noSpeechTimeout` after the wake phrase.
struct EndpointDetector {
    enum Decision: Equatable {
        case keepListening
        case finish
        case giveUp
    }

    var silenceSeconds: Double = 2.0
    var noSpeechTimeout: Double = 6.0

    private var lastText = ""
    private var lastChange: Date
    private let startedAt: Date

    init(now: Date) {
        lastChange = now
        startedAt = now
    }

    mutating func update(text: String, now: Date) -> Decision {
        if text != lastText {
            lastText = text
            lastChange = now
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return now.timeIntervalSince(startedAt) >= noSpeechTimeout ? .giveUp : .keepListening
        }
        return now.timeIntervalSince(lastChange) >= silenceSeconds ? .finish : .keepListening
    }
}
