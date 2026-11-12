import Foundation

/// The language an invoice PDF is written in. Empty means "follow the app / phone language".
enum DocumentLanguage: String, CaseIterable, Identifiable {
    case en
    case fr
    case es
    case it
    case zhHans = "zh-Hans"
    case ar
    case hi
    case ur

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .es: return "Español"
        case .it: return "Italiano"
        case .zhHans: return "简体中文"
        case .ar: return "العربية"
        case .hi: return "हिन्दी"
        case .ur: return "اردو"
        }
    }

    /// Arabic and Urdu are written right to left.
    var isRightToLeft: Bool { self == .ar || self == .ur }

    static func isRightToLeft(code: String) -> Bool {
        DocumentLanguage(rawValue: code)?.isRightToLeft ?? false
    }

    static func locale(for code: String) -> Locale {
        code.isEmpty ? .current : Locale(identifier: code)
    }
}
