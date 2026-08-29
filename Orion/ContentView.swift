import AppKit
import MuffinCore
import SwiftUI

struct ContentView: View {
    @Bindable var session: RecordingSession
    @State private var destination: AppDestination = .newRecording
    @State private var recordingsShowingNote = false
    @State private var recordingsTab: RecordingsNoteTab = .transcript

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220)
                .frame(maxHeight: .infinity)

            mainPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 860, minHeight: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.light)
        .background {
            AppBackgroundLayer()
                .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: .orionNewRecording)) { _ in
            destination = .newRecording
        }
        .onReceive(NotificationCenter.default.publisher(for: .muffinFnPushBegan)) { _ in
            destination = .newRecording
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image("BrandMark")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text("Muffin")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OrionColor.textInk)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(AppDestination.allCases) { item in
                    SidebarNavButton(
                        title: item.title,
                        symbol: item.symbol,
                        isSelected: destination == item
                    ) {
                        if item == .recordings {
                            // Sidebar Recordings always returns to the list.
                            recordingsShowingNote = false
                        }
                        if item == .newRecording {
                            session.resetCompletionState()
                        }
                        destination = item
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(OrionColor.surfaceSidebar.opacity(0.92))
    }

    private var mainPane: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        switch destination {
        case .newRecording:
            RecordView(
                session: session,
                onOpenTranscript: {
                    openRecordingNote(tab: .transcript)
                },
                onOpenSummary: {
                    openRecordingNote(tab: .summary)
                }
            )
        case .recordings:
            RecordingsDeskView(
                session: session,
                showingNote: $recordingsShowingNote,
                tab: $recordingsTab,
                onNewRecording: {
                    destination = .newRecording
                }
            )
        case .templates:
            TemplatesView(templateStore: session.templateStore)
        case .settings:
            SettingsView(session: session)
        }
    }

    private func openRecordingNote(tab: RecordingsNoteTab) {
        recordingsTab = tab
        recordingsShowingNote = session.activeRecordingID != nil
        destination = .recordings
    }
}

private struct SidebarNavButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? OrionColor.primary : OrionColor.textMuted)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color(hex: 0x4A5232) : OrionColor.textBody)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? OrionColor.surfaceNavSelected : Color.clear)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(OrionColor.primary)
                        .frame(width: 3, height: 16)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView(session: RecordingSession())
        .frame(width: 1040, height: 680)
}
