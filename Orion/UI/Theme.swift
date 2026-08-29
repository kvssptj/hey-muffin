import SwiftUI

/// Color tokens synced from Magic Patterns Orion design system (`index.css` `:root`).
enum OrionColor {
    // MARK: - Surfaces
    static let background = Color(hex: 0xDDE7EF)
    static let surfacePaper = Color(hex: 0xFAFCFD)
    static let surfaceSidebar = Color(hex: 0xE7EEF4)
    static let surfaceNavSelected = Color(hex: 0xE2E7DE)
    static let surfaceSelected = Color(hex: 0xD6E4EF)

    // MARK: - Borders
    static let border = Color(hex: 0xCBD8E2)
    static let borderStrong = Color(hex: 0x6B7C8D)
    static let borderGuilloche = Color(hex: 0xC2D2DE)

    // MARK: - Text
    static let textInk = Color(hex: 0x262B33)
    static let textBody = Color(hex: 0x3E4650)
    static let textMuted = Color(hex: 0x5A6472)
    static let textInverse = Color(hex: 0xFFFFFF)

    // MARK: - Brand / actions
    static let primary = Color(hex: 0x4F5A3C)
    static let primaryHover = Color(hex: 0x3E472E)
    static let primaryTint = Color(hex: 0xE6EADD)
    static let secondary = Color(hex: 0x43678A)
    static let secondaryHover = Color(hex: 0x345677)
    static let secondaryTint = Color(hex: 0xE4EDF2)

    // MARK: - Status
    static let success = Color(hex: 0x4F6242)
    static let successTint = Color(hex: 0xE5EBE1)
    static let warning = Color(hex: 0x6F521C)
    static let warningTint = Color(hex: 0xF0E9DD)
    static let danger = Color(hex: 0x8C3A2C)
    static let dangerTint = Color(hex: 0xF0E2DE)
    static let focusRing = Color(hex: 0x2A3B4D)

    // MARK: - Semantic aliases (app chrome)
    static let paper = surfacePaper
    static let chrome = background
    static let hairline = borderGuilloche.opacity(0.65)
    static let selection = surfaceNavSelected
    static let highlight = surfaceSelected

    // MARK: - Legacy names (map onto Orion tokens so call sites keep compiling)
    static let ink = textInk
    static let inkDim = textMuted
    static let secondaryInk = textBody
    static let tertiaryInk = textMuted.opacity(0.85)
    static let warmIvory = surfacePaper
    static let stone = border
    static let mutedOlive = primary
    static let oliveDeep = primaryHover
    static let deepOlive = primaryHover
    static let paleOlive = primaryTint
    /// Light stroke / wash blue used by guilloché & meters (≈ border-guilloche).
    static let skyBlue = borderGuilloche
    static let paleBlue = secondaryTint
}

enum OrionType {
    static let wordmark = Font.system(size: 16, weight: .semibold, design: .serif)
    static let title = Font.system(size: 15, weight: .semibold, design: .serif)
    static let body = Font.system(size: 13.5, weight: .regular, design: .default)
    static let document = Font.system(size: 14, weight: .regular, design: .default)
    static let mono = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(OrionColor.hairline)
            .frame(height: 1)
    }
}

/// Soft surface veil so guilloché reads through chrome without Material blur.
struct OrionGlassFill: View {
    var ivoryOpacity: Double = 0.72

    var body: some View {
        Rectangle()
            .fill(OrionColor.surfaceSidebar.opacity(ivoryOpacity))
    }
}

struct IvoryPanel<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(OrionColor.surfacePaper.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(OrionColor.border, lineWidth: 1)
            )
    }
}

struct AppBackgroundLayer: View {
    var body: some View {
        GuillocheBackground()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .allowsHitTesting(false)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
