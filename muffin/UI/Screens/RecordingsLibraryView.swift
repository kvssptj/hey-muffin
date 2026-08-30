import MuffinCore
import SwiftUI

struct RecordingsLibraryView: View {
    @Bindable var session: RecordingSession
    var onOpen: (UUID) -> Void
    var onNewRecording: () -> Void

    @State private var searchQuery = ""
    @State private var searchResults: [Recording]? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    private var displayedRecordings: [Recording] {
        searchResults ?? session.recordings
    }

    private var totalMinutes: Int {
        Int(displayedRecordings.reduce(0) { $0 + $1.meta.duration } / 60)
    }

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
                    subtitle: "Everything you've captured on this Mac — open a take for transcript and summary."
                ) {
                    HStack(spacing: 8) {
                        Button("Start recording", action: onNewRecording)
                            .buttonStyle(OrionPrimaryButtonStyle())
                    }
                } document: {
                    VStack(alignment: .leading, spacing: 16) {
                        searchFilterBar
                        recordingsList
                    }
                }
            }
        }
        .onAppear { session.refreshRecordings() }
    }

    // MARK: - Search + filter bar

    private var searchFilterBar: some View {
        HStack(alignment: .center, spacing: 16) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(OrionColor.textMuted)
                TextField("Search recordings", text: $searchQuery)
                    .font(.system(size: 13))
                    .foregroundStyle(OrionColor.textInk)
                    .textFieldStyle(.plain)
                    .onChange(of: searchQuery) { _, _ in scheduleSearch() }
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(OrionColor.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(OrionColor.background)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(OrionColor.border, lineWidth: 1)
            )

            Spacer(minLength: 0)

            // Stats
            statColumn(label: "RECORDINGS", value: "\(displayedRecordings.count)")
            statColumn(label: "MINUTES", value: "\(totalMinutes)")
        }
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(OrionColor.textMuted)
            Text(value)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(OrionColor.textInk)
        }
    }

    // MARK: - Recordings list

    @ViewBuilder
    private var recordingsList: some View {
        if displayedRecordings.isEmpty {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Text(searchQuery.isEmpty ? "No recordings match the filter." : "No results for \"\(searchQuery)\".")
                        .font(.system(size: 13))
                        .foregroundStyle(OrionColor.textMuted)
                }
                .padding(.vertical, 32)
                Spacer()
            }
        } else {
            OrionCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(displayedRecordings.enumerated()), id: \.element.id) { index, recording in
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
                        if index < displayedRecordings.count - 1 {
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

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if query.isEmpty {
                    searchResults = nil
                } else {
                    searchResults = (try? session.store.search(query: query)) ?? []
                }
            }
        }
    }
}
