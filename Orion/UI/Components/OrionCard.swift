import SwiftUI

/// Magic Patterns Orion `Card` — matte paper, hairline border, no shadow.
struct OrionCard<Content: View>: View {
    var padding: CGFloat = 20
    var muted: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(muted ? OrionColor.background : OrionColor.surfacePaper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(OrionColor.border, lineWidth: 1)
            )
    }
}
