import SwiftUI
import UIKit

/// MD3 tonal roles from a teal seed, themed flat and sharp: square corners,
/// no shadows, hairline outlines separating layers.
enum Theme {
    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    static let primary = dyn(0x006A60, 0x53DBC9)
    static let onPrimary = dyn(0xFFFFFF, 0x003731)
    static let primaryContainer = dyn(0x74F8E5, 0x005048)
    static let onPrimaryContainer = dyn(0x00201C, 0x74F8E5)
    static let secondaryContainer = dyn(0xCCE8E2, 0x334B47)
    static let onSecondaryContainer = dyn(0x051F1C, 0xCCE8E2)
    static let tertiaryContainer = dyn(0xFFE08A, 0x5C4A00)
    static let onTertiaryContainer = dyn(0x241A00, 0xFFE08A)
    static let surface = dyn(0xF8FAF9, 0x111413)
    static let surfaceLow = dyn(0xF2F4F3, 0x191C1B)
    static let surfaceHigh = dyn(0xE6E9E7, 0x282B2A)
    static let onSurface = dyn(0x191C1B, 0xE0E3E1)
    static let onSurfaceVariant = dyn(0x3F4946, 0xBEC9C5)
    static let outline = dyn(0x6F7976, 0x89938F)
    static let outlineVariant = dyn(0xBEC9C5, 0x3F4946)
    static let error = dyn(0xBA1A1A, 0xFFB4AB)
    static let errorContainer = dyn(0xFFDAD6, 0x93000A)

    static let hairline: CGFloat = 0.5
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

struct Hairline: ViewModifier {
    var color: Color = Theme.outlineVariant
    var width: CGFloat = 1
    func body(content: Content) -> some View {
        content.overlay(Rectangle().strokeBorder(color, lineWidth: width))
    }
}

extension View {
    func hairline(_ color: Color = Theme.outlineVariant, width: CGFloat = 1) -> some View {
        modifier(Hairline(color: color, width: width))
    }
}

/// Outlined MD3 button, square.
struct OutlinedButton: ButtonStyle {
    var tint: Color = Theme.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? tint.opacity(0.12) : Color.clear)
            .hairline(tint.opacity(0.6))
            .contentShape(Rectangle())
    }
}

/// Filled MD3 button, square.
struct FilledButton: ButtonStyle {
    var fill: Color = Theme.primary
    var text: Color = Theme.onPrimary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1))
            .contentShape(Rectangle())
    }
}
