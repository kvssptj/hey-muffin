import MuffinCore
import SwiftUI

/// Unified Recordings: list of takes, then one note with Transcript | Summary tabs.
struct RecordingsDeskView: View {
    @Bindable var session: RecordingSession
    @Binding var showingNote: Bool
    @Binding var tab: RecordingsNoteTab
    var onNewRecording: () -> Void

    @State private var confirmingDelete = false

    private var activeTitle: String {
        guard let id = session.activeRecordingID,
              let recording = session.recordings.first(where: { $0.id == id }) else {
            return "Recording"
        }
        return recording.meta.title
    }

    private var activeMeta: String {
        let dur = Int(session.elapsedSeconds.rounded())
        let words = session.transcript
            .split { $0.isWhitespace || $0.isNewline }
            .filter { !$0.isEmpty }
            .count
        return "\(dur / 60)m \(dur % 60)s · \(words) words"
    }

    var body: some View {
        Group {
            if showingNote, session.activeRecordingID != nil {
                notePane
            } else {
                RecordingsLibraryView(
                    session: session,
                    onOpen: { id in
                        session.loadRecording(id: id)
                        tab = .transcript
                        showingNote = true
                    },
                    onNewRecording: onNewRecording
                )
            }
        }
    }

    private var notePane: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                NoteBreadcrumb(
                    trail: [("Recordings", {
                        showingNote = false
                    })],
                    current: activeTitle
                )
                .padding(.top, 0)

                HStack(alignment: .firstTextBaseline) {
                    Text(activeTitle)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(OrionColor.textInk)
                        .lineLimit(2)
                    Spacer(minLength: 12)
                    Text(activeMeta)
                        .font(.system(size: 12))
                        .foregroundStyle(OrionColor.textMuted)
                        .fixedSize()
                    OrionIconButton(
                        systemName: "trash",
                        accessibilityLabel: "Delete recording",
                        variant: .ghost,
                        size: .sm
                    ) {
                        confirmingDelete = true
                    }
                }
                .padding(.horizontal, 24)
                .confirmationDialog(
                    "Delete \"\(activeTitle)\"?",
                    isPresented: $confirmingDelete,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        if let id = session.activeRecordingID {
                            showingNote = false
                            session.deleteRecording(id: id)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The audio, transcript, and any summaries will be moved to the Trash.")
                }

                HStack(spacing: 0) {
                    ForEach(RecordingsNoteTab.allCases) { item in
                        Button {
                            tab = item
                        } label: {
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(tab == item ? OrionColor.primary : OrionColor.textMuted)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(tab == item ? OrionColor.primary : Color.clear)
                                        .frame(height: 2)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
            }
            .background(OrionColor.surfacePaper.opacity(0.72))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(OrionColor.border)
                    .frame(height: 1)
            }

            Group {
                switch tab {
                case .transcript:
                    TranscriptView(
                        session: session,
                        showLibraryBreadcrumb: false,
                        onOpenSummary: { tab = .summary }
                    )
                    .id(session.activeRecordingID)
                case .summary:
                    SummaryView(
                        session: session,
                        showLibraryBreadcrumb: false,
                        onOpenTranscript: { tab = .transcript }
                    )
                    .id(session.activeRecordingID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
