import AppKit
import MuffinCore
import SwiftUI

struct TranscriptView: View {
    @Bindable var session: RecordingSession
    var showLibraryBreadcrumb: Bool = false
    var onBackToLibrary: (() -> Void)? = nil
    var onOpenSummary: (() -> Void)? = nil

    @State private var draft = ""
    @State private var copied = false
    @State private var exportedPath: String?
    @State private var toastMessage: String?

    var body: some View {
        Group {
            if session.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && session.activeRecordingID == nil {
                EmptyStateView(
                    title: "No transcript yet",
                    message: "Record something first. When you stop, we save transcript.md next to the audio so you can edit it here.",
                    systemImage: "doc.plaintext",
                    actionTitle: "Start recording",
                    action: {
                        NotificationCenter.default.post(name: .orionNewRecording, object: nil)
                    }
                )
            } else {
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if showLibraryBreadcrumb, let onBackToLibrary {
                                NoteBreadcrumb(
                                    trail: [("Library", onBackToLibrary)],
                                    current: "Transcript"
                                )
                            }

                            HStack(spacing: 6) {
                                OrionIconButton(
                                    systemName: copied ? "checkmark" : "doc.on.doc",
                                    accessibilityLabel: "Copy transcript",
                                    variant: .default,
                                    size: .sm,
                                    isActive: copied
                                ) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(draft, forType: .string)
                                    copied = true
                                    showToast("Copied to clipboard")
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                                }

                                Button("Export as .txt") {
                                    do {
                                        session.updateTranscript(draft)
                                        let url = try session.exportPlainText()
                                        exportedPath = url.lastPathComponent
                                        showToast("Exported \(url.lastPathComponent)")
                                    } catch {
                                        session.errorMessage = error.localizedDescription
                                    }
                                }
                                .buttonStyle(OrionQuietButtonStyle())

                                if let onOpenSummary {
                                    Button("Summary") { onOpenSummary() }
                                        .buttonStyle(OrionQuietButtonStyle())
                                }

                                Menu {
                                    Button("Show folder in Finder") { try? session.revealInFinder(item: .folder) }
                                    Button("Show audio.caf") { try? session.revealInFinder(item: .audio) }
                                    Button("Show transcript.md") { try? session.revealInFinder(item: .transcript) }
                                } label: {
                                    Image(systemName: "folder")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(OrionColor.textBody)
                                        .frame(width: 28, height: 28)
                                        .background(OrionColor.surfacePaper)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .strokeBorder(OrionColor.border, lineWidth: 1)
                                        )
                                }
                                .menuStyle(.borderlessButton)
                                .help("Reveal in Finder")

                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, showLibraryBreadcrumb ? 4 : 20)

                            if let exportedPath {
                                Text("Wrote \(exportedPath) next to the markdown file.")
                                    .font(OrionType.caption)
                                    .foregroundStyle(OrionColor.primary)
                                    .padding(.horizontal, 24)
                            }

                            TranscriptDocumentView(
                                title: "Transcript",
                                subtitle: session.isRecording
                                    ? "Live capture. Edits autosave when you stop."
                                    : "Edits autosave to transcript.md.",
                                meta: metaLine,
                                text: $draft,
                                isEditable: true
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                            .onChange(of: draft) { _, newValue in
                                session.updateTranscript(newValue)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if let toastMessage {
                        OrionToast(message: toastMessage)
                            .padding(.top, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: toastMessage)
                .onAppear { draft = session.transcript }
                .onChange(of: session.transcript) { _, newValue in
                    draft = newValue
                }
            }
        }
    }

    private var metaLine: String {
        if session.activeRecordingID != nil {
            let dur = Int(session.elapsedSeconds.rounded())
            return "Saved locally · \(dur / 60)m \(dur % 60)s"
        }
        return "Application Support/Muffin"
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastMessage == message { toastMessage = nil }
        }
    }
}
