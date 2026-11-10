import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: CGFloat(alpha)))
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// Palette taken from the iPhone 18 Pro finishes: Burgundy, Glacier Blue, Deep Black.
enum Theme {
    static let burgundy = Color(hex: 0x6B1F2E)
    static let burgundyDeep = Color(hex: 0x2A0A12)
    static let burgundyLight = Color(hex: 0x9A3347)
    static let glacier = Color(hex: 0xA9D0E8)

    static let accent = Color.dynamic(light: 0x6B1F2E, dark: 0xA9D0E8)
    static let background = Color.dynamic(light: 0xF6F2F3, dark: 0x0E0507)
    static let card = Color.dynamic(light: 0xFFFFFF, dark: 0x1B0C10)
    static let separator = Color.dynamic(light: 0xE8DFE1, dark: 0x2E1A1F)
    static let secondaryText = Color.dynamic(light: 0x7A6A6E, dark: 0xA99AA0)

    static let heroGradient = LinearGradient(
        colors: [burgundyLight, burgundy, burgundyDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func amount(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
