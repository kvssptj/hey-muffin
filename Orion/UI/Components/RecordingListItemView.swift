import SwiftUI

/// Magic Patterns `RecordingListItem` — hairline row, mono duration, overflow menu.
struct RecordingListItemView: View {
    var title: String
    var durationSeconds: TimeInterval
    var date: Date
    var isSelected: Bool = false
    var onOpen: () -> Void
    var onShowFolder: (() -> Void)? = nil
    var onShowTranscript: (() -> Void)? = nil
    var onExport: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? OrionColor.textInk : OrionColor.border, lineWidth: 1)
                            .background(Circle().fill(isSelected ? OrionColor.textInk : OrionColor.surfacePaper))
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isSelected ? OrionColor.textInverse : OrionColor.textBody)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(OrionColor.textInk)
                            .lineLimit(1)
                        Text(Self.formatDate(date))
                            .font(.system(size: 12))
                            .foregroundStyle(OrionColor.textMuted)
                    }

                    Spacer(minLength: 8)

                    Text(Self.formatDuration(durationSeconds))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(OrionColor.textBody)
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                if let onShowFolder {
                    Button("Show folder in Finder", action: onShowFolder)
                }
                if let onShowTranscript {
                    Button("Show transcript.md", action: onShowTranscript)
                }
                if let onExport {
                    Button("Export transcript.txt", action: onExport)
                }
                if onDelete != nil {
                    Divider()
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete recording", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OrionColor.textMuted)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.clear)
                    )
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("More options")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isSelected ? OrionColor.surfaceSelected.opacity(0.55) : Color.clear)
        .confirmationDialog(
            "Delete \"\(title)\"?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The audio, transcript, and any summaries will be moved to the Trash.")
        }
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}
