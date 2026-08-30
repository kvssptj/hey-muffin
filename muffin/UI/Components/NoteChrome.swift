import SwiftUI

/// Recordings → note breadcrumb / back control.
struct NoteBreadcrumb: View {
    var trail: [(String, () -> Void)]
    var current: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(trail.enumerated()), id: \.offset) { _, item in
                Button(action: item.1) {
                    HStack(spacing: 4) {
                        if trail.first?.0 == item.0 {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(item.0)
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(OrionColor.secondary)
                }
                .buttonStyle(.plain)
                Text("/")
                    .font(.system(size: 12))
                    .foregroundStyle(OrionColor.textMuted)
            }
            Text(current)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(OrionColor.textInk)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }
}

/// Lightweight success / status toast (no heavy chrome).
struct OrionToast: View {
    var message: String
    var systemImage: String = "checkmark.circle.fill"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(OrionColor.primary)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OrionColor.textInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(OrionColor.primaryTint)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color(hex: 0xB9C2A6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
        .accessibilityAddTraits(.isStaticText)
    }
}
