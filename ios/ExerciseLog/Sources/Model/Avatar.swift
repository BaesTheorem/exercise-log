import SwiftUI

/// The player's look, as chosen on the Character Design screen. Stored in
/// the log file so the Mac side can read it too. Every field is an index
/// into the option tables below, so old files decode with defaults.
struct Avatar: Codable, Equatable {
    var name: String = "Player"
    var female: Bool = false
    var head: Int = 1
    var jaw: Int = 0
    var torso: Int = 0
    var arms: Int = 0
    var hands: Int = 0
    var legs: Int = 0
    var feet: Int = 0
    var hairColor: Int = 0
    var torsoColor: Int = 1
    var legsColor: Int = 2
    var feetColor: Int = 0
    var skinColor: Int = 0

    static let headStyles = ["Bald", "Short", "Long", "Spiky", "Mohawk", "Ponytail", "Bob", "Pigtails", "Curly"]
    static let jawStyles = ["Clean", "Moustache", "Goatee", "Full beard", "Long beard"]
    static let torsoStyles = ["Shirt", "Vest", "Jacket", "Stripe", "Tunic"]
    static let armStyles = ["Sleeves", "Short sleeves", "Bare"]
    static let handStyles = ["Bare", "Gloves"]
    static let legStyles = ["Trousers", "Shorts", "Skirt"]
    static let feetStyles = ["Shoes", "Boots", "Sandals"]

    // Palettes, roughly the game's Makeover Mage swatches.
    static let hairColors: [UInt32] = [0x3D2B1F, 0x6B4423, 0xD9B458, 0xEFE0A5, 0xA63A1E, 0x1E1E1E, 0x8C8C8C, 0xE8E8E8, 0x2F8F3A, 0x2F5FB0, 0x6D3EA6, 0xD95FA8]
    static let clothColors: [UInt32] = [0xC9A26B, 0x8B5A2B, 0x5A3A1E, 0x6B7A2F, 0xB5A24A, 0xA6261E, 0x2F4FA6, 0x2F7A3A, 0x5E2E8A, 0xE6E6E6, 0x232323, 0xE0B200, 0x2FA6A6, 0xD96FA8, 0x7A7A7A, 0xF08A24]
    static let feetColors: [UInt32] = [0x6B4423, 0x3D2B1F, 0x232323, 0xC9A26B, 0xA6261E, 0x2F4FA6]
    static let skinColors: [UInt32] = [0xF2D1A8, 0xE6B989, 0xC99A6A, 0xA5734B, 0x7D5233, 0x5A3A22, 0x3F2917, 0xA8D47E]

    var hair: Color { Color(hex: Avatar.hairColors[hairColor % Avatar.hairColors.count]) }
    var cloth: Color { Color(hex: Avatar.clothColors[torsoColor % Avatar.clothColors.count]) }
    var trousers: Color { Color(hex: Avatar.clothColors[legsColor % Avatar.clothColors.count]) }
    var shoes: Color { Color(hex: Avatar.feetColors[feetColor % Avatar.feetColors.count]) }
    var skin: Color { Color(hex: Avatar.skinColors[skinColor % Avatar.skinColors.count]) }
}

/// Paints the avatar onto a 20 x 32 cell grid, part by part, later parts
/// over earlier ones. The right and bottom edge of every part is shaded so
/// the figure reads as the game's chunky low-poly model, not a flat sticker.
enum AvatarPainter {
    static let width = 20
    static let height = 32

    struct Cell: Hashable { let x: Int; let y: Int }

    /// Returns colour per filled cell, with shading applied.
    static func cells(for a: Avatar) -> [Cell: Color] {
        var grid: [Cell: (Color, Int)] = [:]
        var layer = 0
        func paint(_ xs: ClosedRange<Int>, _ ys: ClosedRange<Int>, _ c: Color) {
            for y in ys { for x in xs { grid[Cell(x: x, y: y)] = (c, layer) } }
        }
        func part(_ body: () -> Void) { layer += 1; body() }

        let f = a.female
        let torsoX: ClosedRange<Int> = f ? 7...12 : 6...13
        let armL: ClosedRange<Int> = f ? 5...6 : 4...5
        let armR: ClosedRange<Int> = f ? 13...14 : 14...15
        let eye = Color(hex: 0x1A1A1A)
        let seam = Color.black.opacity(0.35)

        // Legs and feet first so the torso sits over the waistband.
        part {
            switch a.legs {
            case 1:
                paint(6...13, 20...24, a.trousers)
                paint(6...13, 25...29, a.skin)
            case 2:
                paint(5...14, 20...25, a.trousers)
                paint(6...13, 26...29, a.skin)
            default:
                paint(6...13, 20...29, a.trousers)
            }
            paint(9...10, (a.legs == 2 ? 26 : 20)...29, seam)
        }
        part {
            switch a.feet {
            case 1: paint(5...9, 27...31, a.shoes); paint(10...14, 27...31, a.shoes)
            case 2: paint(5...9, 30...31, a.skin); paint(10...14, 30...31, a.skin); paint(5...14, 31...31, a.shoes)
            default: paint(5...9, 30...31, a.shoes); paint(10...14, 30...31, a.shoes)
            }
        }
        // Torso.
        part {
            let bottom = a.torso == 4 ? 22 : 19
            paint(torsoX, 10...bottom, a.cloth)
            if a.torso == 1 { paint(torsoX, 10...bottom, a.cloth); paint(torsoX.lowerBound...torsoX.lowerBound, 10...bottom, a.skin); paint(torsoX.upperBound...torsoX.upperBound, 10...bottom, a.skin) }
            if a.torso == 2 { paint(9...10, 10...12, a.skin); paint(8...8, 10...11, seam); paint(11...11, 10...11, seam) }
            if a.torso == 3 { paint(torsoX, 14...15, seam) }
        }
        // Arms.
        part {
            switch a.arms {
            case 1:
                paint(armL, 10...13, a.cloth); paint(armR, 10...13, a.cloth)
                paint(armL, 14...19, a.skin); paint(armR, 14...19, a.skin)
            case 2:
                paint(armL, 10...19, a.skin); paint(armR, 10...19, a.skin)
            default:
                paint(armL, 10...19, a.cloth); paint(armR, 10...19, a.cloth)
            }
        }
        // Hands.
        part {
            let c = a.hands == 1 ? a.shoes : a.skin
            paint(armL, 20...21, c); paint(armR, 20...21, c)
        }
        // Neck and head.
        part {
            paint(9...10, 9...9, a.skin)
            paint(7...12, 2...8, a.skin)
            paint(8...8, 5...5, eye); paint(11...11, 5...5, eye)
            paint(9...10, 7...7, seam)
        }
        // Jaw.
        part {
            switch a.jaw {
            case 1: paint(8...11, 6...6, a.hair)
            case 2: paint(9...10, 8...9, a.hair)
            case 3: paint(7...12, 7...9, a.hair); paint(9...10, 7...7, seam)
            case 4: paint(7...12, 7...9, a.hair); paint(8...11, 10...13, a.hair)
            default: break
            }
        }
        // Hair.
        part {
            switch a.head {
            case 1: paint(7...12, 1...2, a.hair)
            case 2: paint(7...12, 1...2, a.hair); paint(6...6, 2...10, a.hair); paint(13...13, 2...10, a.hair)
            case 3: paint(7...12, 1...1, a.hair); for x in [7, 9, 11] { paint(x...x, 0...0, a.hair) }
            case 4: paint(9...10, 0...2, a.hair)
            case 5: paint(7...12, 1...2, a.hair); paint(6...6, 2...5, a.hair); paint(13...13, 2...5, a.hair); paint(13...14, 6...12, a.hair)
            case 6: paint(6...13, 1...2, a.hair); paint(6...6, 3...8, a.hair); paint(13...13, 3...8, a.hair)
            case 7: paint(7...12, 1...2, a.hair); paint(5...5, 4...11, a.hair); paint(14...14, 4...11, a.hair); paint(6...6, 3...4, a.hair); paint(13...13, 3...4, a.hair)
            case 8: paint(6...13, 1...2, a.hair); for x in stride(from: 6, through: 13, by: 2) { paint(x...x, 0...0, a.hair) }; paint(6...6, 3...4, a.hair); paint(13...13, 3...4, a.hair)
            default: break
            }
        }

        // Shade the right and bottom edge of each part.
        var out: [Cell: Color] = [:]
        for (cell, (color, l)) in grid {
            let right = grid[Cell(x: cell.x + 1, y: cell.y)]
            let below = grid[Cell(x: cell.x, y: cell.y + 1)]
            let edge = (right?.1 != l) || (below?.1 != l)
            out[cell] = edge ? color.opacity(0.72) : color
        }
        return out
    }
}

/// The figure at any size; `scale` is points per cell.
struct AvatarView: View {
    let avatar: Avatar
    var scale: CGFloat = 4

    var body: some View {
        let cells = AvatarPainter.cells(for: avatar)
        Canvas { ctx, _ in
            ctx.fill(Path(CGRect(x: 0, y: 0, width: CGFloat(AvatarPainter.width) * scale, height: CGFloat(AvatarPainter.height) * scale)),
                     with: .color(.black.opacity(0.0)))
            for (cell, color) in cells {
                let r = CGRect(x: CGFloat(cell.x) * scale, y: CGFloat(cell.y) * scale, width: scale, height: scale)
                ctx.fill(Path(r), with: .color(color))
            }
        }
        .frame(width: CGFloat(AvatarPainter.width) * scale, height: CGFloat(AvatarPainter.height) * scale)
    }
}
