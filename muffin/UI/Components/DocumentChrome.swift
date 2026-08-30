import SwiftUI

struct DocumentPage<Toolbar: View, Body: View>: View {
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var toolbar: () -> Toolbar
    @ViewBuilder var document: () -> Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(OrionColor.textInk)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12.5))
                            .foregroundStyle(OrionColor.textMuted)
                    }
                    toolbar()
                        .padding(.top, 4)
                }
                .padding(.bottom, 14)
                .overlay(alignment: .bottom) {
                    OrionEngravedRule()
                }

                document()
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 48)
            .frame(maxWidth: 720, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(OrionColor.surfacePaper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(OrionColor.border, lineWidth: 1)
            )
            .padding(.vertical, 24)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
    }
}

struct PaperPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EditorialSection: View {
    var title: String
    var bodyText: String
    var accent: OrionSectionAccent = .olive

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrionSectionHeading(title: title, accent: accent)
            Text(bodyText)
                .font(.system(size: 15))
                .foregroundStyle(OrionColor.textBody)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }
}

/// Magic Patterns `EmptyState` — quiet, no card chrome by default.
struct EmptyStateView: View {
    var title: String
    var message: String
    var systemImage: String? = nil
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 40)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(OrionColor.textMuted)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .strokeBorder(OrionColor.borderStrong, lineWidth: 1)
                            .background(Circle().fill(OrionColor.surfacePaper.opacity(0.7)))
                    )
            }
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OrionColor.textInk)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(OrionColor.textBody)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(OrionPrimaryButtonStyle())
                    .padding(.top, 8)
            }
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
