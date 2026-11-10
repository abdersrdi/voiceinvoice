import Foundation

enum ParserLanguage: String, CaseIterable, Identifiable {
    case en, fr, es, it, zh

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .en: return "en-US"
        case .fr: return "fr-FR"
        case .es: return "es-ES"
        case .it: return "it-IT"
        case .zh: return "zh-CN"
        }
    }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .es: return "Español"
        case .it: return "Italiano"
        case .zh: return "简体中文"
        }
    }

    static func preferred(for locale: Locale = .current) -> ParserLanguage {
        let code = locale.language.languageCode?.identifier ?? "en"
        return ParserLanguage(rawValue: code) ?? .en
    }
}

struct ParsedItem: Identifiable {
    let id = UUID()
    var name: String
    var quantity: Double
    var unitPrice: Double
    var rawText: String

    /// The user has to look at this line: no price heard, or no name.
    var needsReview: Bool { unitPrice <= 0 || name.isEmpty }
}
