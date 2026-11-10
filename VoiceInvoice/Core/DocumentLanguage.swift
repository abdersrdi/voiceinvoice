import Foundation

/// The language an invoice PDF is written in. Empty means "follow the app / phone language".
enum DocumentLanguage: String, CaseIterable, Identifiable {
    case en
    case fr
    case es
    case it
    case zhHans = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .es: return "Español"
        case .it: return "Italiano"
        case .zhHans: return "简体中文"
        }
    }

    static func locale(for code: String) -> Locale {
        code.isEmpty ? .current : Locale(identifier: code)
    }
}
