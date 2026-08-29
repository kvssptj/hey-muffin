import MuffinCore
import SwiftUI

struct RecordingsLibraryView: View {
    @Bindable var session: RecordingSession
    var onOpen: (UUID) -> Void
    var onNewRecording: () -> Void

    var body: some View {
        Group {
            if session.recordings.isEmpty {
                EmptyStateView(
                    title: "No recordings yet",
                    message: "Takes you capture land in Application Support/Muffin/Recordings. Open one to edit the transcript or generate a summary.",
                    systemImage: "waveform",
                    actionTitle: "Start recording",
                    action: onNewRecording
                )
            } else {
                DocumentPage(
                    title: "Recordings",
                    subtitle: "Everything you’ve captured on this Mac — open a take for transcript and summary."
                ) {
                    HStack(spacing: 8) {
                        Button("Start recording", action: onNewRecording)
                            .buttonStyle(OrionPrimaryButtonStyle())
                    }
                } document: {
                    OrionCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(session.recordings.enumerated()), id: \.element.id) { index, recording in
                                RecordingListItemView(
                                    title: recording.meta.title,
                                    durationSeconds: recording.meta.duration,
                                    date: recording.meta.createdAt,
                                    isSelected: session.activeRecordingID == recording.id,
                                    onOpen: { onOpen(recording.id) },
                                    onShowFolder: {
                                        try? session.store.revealInFinder(id: recording.id, item: .folder)
                                    },
                                    onShowTranscript: {
                                        try? session.store.revealInFinder(id: recording.id, item: .transcript)
                                    },
                                    onExport: {
                                        _ = try? session.store.exportPlainText(id: recording.id)
                                    },
                                    onDelete: {
                                        session.deleteRecording(id: recording.id)
                                    }
                                )
                                if index < session.recordings.count - 1 {
                                    Rectangle()
                                        .fill(OrionColor.border.opacity(0.7))
                                        .frame(height: 1)
                                        .padding(.leading, 64)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { session.refreshRecordings() }
    }
}
