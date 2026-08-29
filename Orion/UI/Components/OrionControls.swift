import SwiftUI

// MARK: - Buttons (Magic Patterns Orion `Button`)

enum OrionButtonVariant {
    case primary
    case secondary
    case ghost
}

struct OrionButtonStyle: ButtonStyle {
    var variant: OrionButtonVariant = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(background(isPressed: configuration.isPressed))
            .foregroundStyle(foreground(isPressed: configuration.isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(borderColor(isPressed: configuration.isPressed), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func background(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? OrionColor.primaryHover : OrionColor.primary
        case .secondary:
            return isPressed ? Color(hex: 0xD7E5EF) : OrionColor.secondaryTint
        case .ghost:
            return isPressed ? Color(hex: 0xE8EDF2) : OrionColor.surfacePaper
        }
    }

    private func foreground(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return OrionColor.textInverse
        case .secondary:
            return Color(hex: 0x1F3A52)
        case .ghost:
            return isPressed ? OrionColor.textInk : OrionColor.textBody
        }
    }

    private func borderColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return OrionColor.primaryHover
        case .secondary:
            return OrionColor.secondary.opacity(0.45)
        case .ghost:
            return isPressed ? OrionColor.borderStrong : OrionColor.border
        }
    }
}

struct OrionPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OrionButtonStyle(variant: .primary).makeBody(configuration: configuration)
    }
}

struct OrionQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OrionButtonStyle(variant: .ghost).makeBody(configuration: configuration)
    }
}

struct OrionSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OrionButtonStyle(variant: .secondary).makeBody(configuration: configuration)
    }
}

// MARK: - Badge

enum OrionBadgeVariant { case olive, sky, neutral }

struct OrionBadge: View {
    var text: String
    var variant: OrionBadgeVariant = .olive
    var showDot: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if showDot {
                Circle().fill(dotColor).frame(width: 5, height: 5)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .tracking(0.2)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(foreground)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    private var background: Color {
        switch variant {
        case .olive: OrionColor.primaryTint
        case .sky: OrionColor.secondaryTint
        case .neutral: OrionColor.surfacePaper
        }
    }

    private var foreground: Color {
        switch variant {
        case .olive: Color(hex: 0x3A422A)
        case .sky: Color(hex: 0x1F3A52)
        case .neutral: OrionColor.textBody
        }
    }

    private var border: Color {
        switch variant {
        case .olive: Color(hex: 0xB9C2A6)
        case .sky: Color(hex: 0xA6C0D6)
        case .neutral: OrionColor.borderStrong
        }
    }

    private var dotColor: Color {
        switch variant {
        case .olive: OrionColor.primary
        case .sky: OrionColor.secondary
        case .neutral: OrionColor.textMuted
        }
    }
}

// MARK: - IconButton (Magic Patterns)

enum OrionIconButtonVariant { case `default`, primary, ghost, danger }
enum OrionIconButtonSize { case sm, md, lg }

struct OrionIconButton: View {
    var systemName: String
    var accessibilityLabel: String
    var variant: OrionIconButtonVariant = .default
    var size: OrionIconButtonSize = .md
    var isActive: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconPointSize, weight: .regular))
                .foregroundStyle(foreground)
                .frame(width: side, height: side)
                .background(background)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(border, lineWidth: variant == .ghost && !isActive ? 0 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .opacity(isDisabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
    }

    private var side: CGFloat {
        switch size {
        case .sm: 28
        case .md: 36
        case .lg: 44
        }
    }

    private var corner: CGFloat {
        switch size {
        case .sm: 5
        case .md: 6
        case .lg: 8
        }
    }

    private var iconPointSize: CGFloat {
        switch size {
        case .sm: 12
        case .md: 14
        case .lg: 16
        }
    }

    private var background: Color {
        if isActive {
            switch variant {
            case .default, .ghost: return Color(hex: 0xF0F2F4)
            case .primary: return OrionColor.textInk
            case .danger: return OrionColor.dangerTint
            }
        }
        switch variant {
        case .default: return OrionColor.surfacePaper
        case .primary: return OrionColor.textInk
        case .ghost: return .clear
        case .danger: return OrionColor.surfacePaper
        }
    }

    private var foreground: Color {
        switch variant {
        case .default: return isActive ? OrionColor.textInk : OrionColor.textBody
        case .primary: return OrionColor.textInverse
        case .ghost: return isActive ? OrionColor.textInk : OrionColor.textMuted
        case .danger: return OrionColor.danger
        }
    }

    private var border: Color {
        switch variant {
        case .default: return isActive ? OrionColor.borderStrong : OrionColor.border
        case .primary: return OrionColor.textInk
        case .ghost: return .clear
        case .danger: return OrionColor.danger.opacity(0.45)
        }
    }
}
