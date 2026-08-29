import SwiftUI

/// Magic Patterns `TranscriptDocument` + `TranscriptSegment` (simplified for editable Muffin transcripts).
struct TranscriptDocumentView: View {
    var title: String
    var subtitle: String? = nil
    var meta: String? = nil
    @Binding var text: String
    var isEditable: Bool = true
    var emptyMessage: String = "This transcript has no content yet."

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            OrionEngravedRule()
                .padding(.top, 18)
                .padding(.bottom, 16)

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(OrionColor.textMuted)
                    .padding(.top, 8)
            } else if isEditable {
                ZStack(alignment: .topLeading) {
                    Text(text.isEmpty ? " " : text)
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .lineSpacing(8)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.clear)
                    TextEditor(text: $text)
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .foregroundStyle(Color(hex: 0x3B424B))
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .lineSpacing(8)
                }
                .frame(minHeight: 280)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .foregroundStyle(Color(hex: 0x3B424B))
                            .lineSpacing(8)
                            .textSelection(.enabled)
                    }
                }
            }

            OrionEngravedRule()
                .padding(.top, 28)

            Text("End of transcript")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(OrionColor.textMuted)
                .padding(.top, 14)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .frame(maxWidth: 720, alignment: .leading)
        .background(OrionColor.surfacePaper)
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(Color(hex: 0xDFE2E6), lineWidth: 1)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let meta, !meta.isEmpty {
                Text(meta.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(OrionColor.textMuted)
            }
            Text(title)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(Color(hex: 0x1E232A))
                .tracking(-0.4)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(OrionColor.textBody)
            }
        }
    }

    private var paragraphs: [String] {
        text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct TranscriptSegmentView: View {
    var speaker: String
    var timestamp: String? = nil
    var text: String
    var isActive: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(speaker.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(OrionColor.primary)
                if let timestamp {
                    Text(timestamp)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(OrionColor.textMuted)
                }
            }
            Text(text)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(Color(hex: 0x3B424B))
                .lineSpacing(6)
                .textSelection(.enabled)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? OrionColor.surfaceSelected.opacity(0.7) : Color.clear)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isActive ? OrionColor.textInk : Color.clear)
                .frame(width: 2)
        }
    }
}
