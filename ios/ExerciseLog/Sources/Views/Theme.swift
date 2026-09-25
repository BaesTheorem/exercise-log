import SwiftUI
import UIKit

/// Old School RuneScape interface skin: stone panels, parchment dialogs,
/// the RuneScape bitmap font with its one-pixel drop shadow, yellow labels,
/// orange headers, and bevelled edges instead of shadows or rounding.
///
/// Fonts are RuneLite's `runescape.ttf` family (family "RuneScape",
/// PostScript "RuneScape" / "RuneScapeBold"; the small face is family
/// "RuneScape Small"). Pixel fonts stay crisp at 16 and multiples of it.
enum RS {
    // Text colours straight from the game's chat and interface palette.
    static let yellow = Color(hex: 0xFFFF00)
    static let orange = Color(hex: 0xFF981F)
    static let white = Color(hex: 0xFFFFFF)
    static let green = Color(hex: 0x00FF00)
    static let red = Color(hex: 0xFF0000)
    static let cyan = Color(hex: 0x00FFFF)
    static let grey = Color(hex: 0x9F9F9F)
    static let parchmentInk = Color(hex: 0x2A1E0E)

    // Surfaces.
    static let stone = Color(hex: 0x4A4034)
    static let stoneDark = Color(hex: 0x2E2720)
    static let stoneDarker = Color(hex: 0x1E1912)
    static let slot = Color(hex: 0x3B3327)
    static let parchment = Color(hex: 0xD6C7A0)
    static let bevelLight = Color(hex: 0x8A7A63)
    static let bevelDark = Color(hex: 0x1A1510)
    static let outline = Color(hex: 0x120E0A)

    static func font(_ size: CGFloat = 16, bold: Bool = false) -> Font {
        Font.custom(bold ? "RuneScapeBold" : "RuneScape", size: size)
    }
    static func small(_ size: CGFloat = 16) -> Font {
        Font.custom("RuneScape-Small", size: size)
    }

    static func stoneImage() -> Image { Image("stone_tile").resizable(resizingMode: .tile) }
    static func parchmentImage() -> Image { Image("parchment_tile").resizable(resizingMode: .tile) }
    static func darkImage() -> Image { Image("dark_tile").resizable(resizingMode: .tile) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// The game's text shadow: one pixel down-right, pure black, no blur.
struct RSTextShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: .black, radius: 0, x: 1, y: 1)
    }
}

/// Bevelled stone edge: light top-left, dark bottom-right, black outline.
struct Bevel: ViewModifier {
    var inset: Bool = false
    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let light = inset ? RS.bevelDark : RS.bevelLight
                let dark = inset ? RS.bevelLight : RS.bevelDark
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: w, y: 0))
                }.stroke(light, lineWidth: 2)
                Path { p in
                    p.move(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h))
                }.stroke(dark, lineWidth: 2)
                Rectangle().strokeBorder(RS.outline, lineWidth: 1)
            }
        }
    }
}

extension View {
    func rsText(_ size: CGFloat = 16, bold: Bool = false, color: Color = RS.yellow) -> some View {
        self.font(RS.font(size, bold: bold)).foregroundStyle(color).modifier(RSTextShadow())
    }
    func rsSmall(_ size: CGFloat = 16, color: Color = RS.white) -> some View {
        self.font(RS.small(size)).foregroundStyle(color).modifier(RSTextShadow())
    }
    func bevel(inset: Bool = false) -> some View { modifier(Bevel(inset: inset)) }
    func stonePanel() -> some View { background(RS.stone).background(RS.stoneImage()).bevel() }
    func stoneSlot() -> some View { background(RS.slot).bevel(inset: true) }
    func parchmentPanel() -> some View { background(RS.parchment).background(RS.parchmentImage()).bevel() }
    /// Kept for call sites that predate the skin; a hairline is now a bevel.
    func hairline(_ color: Color = RS.bevelDark, width: CGFloat = 1) -> some View { bevel(inset: true) }
}

/// Stone button: yellow label, bevel out, bevel in while pressed.
struct StoneButton: ButtonStyle {
    var color: Color = RS.yellow
    var fill: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rsText(16, color: color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: fill ? .infinity : nil)
            .background(configuration.isPressed ? RS.stoneDark : RS.stone)
            .bevel(inset: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

// Names the older views still use; both map onto the stone button now.
typealias OutlinedButton = StoneButton
struct FilledButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StoneButton(color: RS.orange, fill: true).makeBody(configuration: configuration)
    }
}

/// Pixel skill icons from the wiki, drawn without smoothing so they stay
/// pixel art at 2x and 3x.
struct SkillIcon: View {
    let name: String
    var size: CGFloat = 20
    var body: some View {
        Image(name)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

extension Exercise {
    /// Which skill tab an exercise belongs under. Push and arm work is
    /// Strength, pulls are Attack, legs are Agility, trunk is Hitpoints.
    var skillIcon: String {
        let n = name.lowercased()
        if n.contains("pull") || n.contains("row") { return "Attack_icon" }
        if n.contains("squat") || n.contains("calf") || n.contains("calves") || n.contains("leg") { return "Agility_icon" }
        if n.contains("abs") || n.contains("oblique") || n.contains("core") || n.contains("plank") { return "Hitpoints_icon" }
        return "Strength_icon"
    }
}

/// UIKit chrome that SwiftUI does not expose: navigation bar as stone with
/// an orange RuneScape title, and the same for sheets.
enum RSAppearance {
    static func install() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 0.18, green: 0.15, blue: 0.125, alpha: 1)
        nav.shadowColor = .black
        let title = UIFont(name: "RuneScapeBold", size: 22) ?? .boldSystemFont(ofSize: 20)
        nav.titleTextAttributes = [.font: title, .foregroundColor: UIColor(red: 1, green: 0.6, blue: 0.12, alpha: 1)]
        nav.buttonAppearance.normal.titleTextAttributes = [.font: UIFont(name: "RuneScape", size: 18) ?? .systemFont(ofSize: 17),
                                                            .foregroundColor: UIColor.yellow]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = .yellow
        UITableView.appearance().backgroundColor = .clear

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 0.18, green: 0.15, blue: 0.125, alpha: 1)
        tab.shadowColor = .black
        let small = UIFont(name: "RuneScape", size: 14) ?? .systemFont(ofSize: 12)
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.font: small, .foregroundColor: UIColor.lightGray]
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.font: small, .foregroundColor: UIColor.yellow]
        tab.stackedLayoutAppearance.normal.iconColor = .lightGray
        tab.stackedLayoutAppearance.selected.iconColor = .yellow
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

// Old names kept so untouched call sites still compile; they now resolve
// to the RuneScape palette.
enum Theme {
    static let primary = RS.yellow
    static let onPrimary = RS.outline
    static let primaryContainer = RS.stone
    static let onPrimaryContainer = RS.yellow
    static let secondaryContainer = RS.slot
    static let onSecondaryContainer = RS.yellow
    static let tertiaryContainer = RS.parchment
    static let onTertiaryContainer = RS.parchmentInk
    static let surface = RS.stoneDark
    static let surfaceLow = RS.stone
    static let surfaceHigh = RS.stone
    static let onSurface = RS.white
    static let onSurfaceVariant = RS.grey
    static let outline = RS.grey
    static let outlineVariant = RS.bevelDark
    static let error = RS.red
    static let errorContainer = RS.stoneDark
    static let hairline: CGFloat = 1
}
