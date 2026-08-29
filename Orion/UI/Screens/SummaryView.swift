import AppKit
import MuffinCore
import SwiftUI

struct SummaryView: View {
    @Bindable var session: RecordingSession
    var showLibraryBreadcrumb: Bool = false
    var onBackToLibrary: (() -> Void)? = nil
    var onOpenTranscript: (() -> Void)? = nil

    @State private var copied = false
    @State private var toastMessage: String?
    /// Avoid re-kicking auto-generate for the same recording + format.
    @State private var autoGenerateKey: String?

    var body: some View {
        Group {
            if session.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && session.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(
                    title: "No summary yet",
                    message: "Pick a format and generate a summary from a transcript. The provider is set in Settings.",
                    systemImage: "doc.text",
                    actionTitle: "Start recording",
                    action: {
                        NotificationCenter.default.post(name: .orionNewRecording, object: nil)
                    }
                )
            } else {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        if showLibraryBreadcrumb, let onBackToLibrary {
                            NoteBreadcrumb(
                                trail: {
                                    var trail: [(String, () -> Void)] = [("Recordings", onBackToLibrary)]
                                    if let onOpenTranscript {
                                        trail.append(("Transcript", onOpenTranscript))
                                    }
                                    return trail
                                }(),
                                current: "Summary"
                            )
                        }

                        DocumentPage(
                            title: "Summary",
                            subtitle: "Uses \(session.llmRouter.selectedProvider.displayName) from Settings. Always reads the latest transcript.md."
                        ) {
                            HStack(spacing: 8) {
                                if let onOpenTranscript {
                                    Button("Transcript") { onOpenTranscript() }
                                        .buttonStyle(OrionQuietButtonStyle())
                                }

                                Picker("Format", selection: Binding(
                                    get: { session.selectedOutputTemplate },
                                    set: { session.selectOutputTemplate($0) }
                                )) {
                                    ForEach(session.templateStore.templates) { t in
                                        Text(t.name).tag(t)
                                    }
                                }
                                .frame(width: 160)

                                Button(session.isGenerating ? "Generating…" : "Generate summary") {
                                    Task { await session.generate() }
                                }
                                .buttonStyle(OrionPrimaryButtonStyle())
                                .disabled(!session.canGenerate)

                                Button(copied ? "Copied" : "Copy summary") {
                                    session.copyOutput()
                                    copied = true
                                    showToast("Summary copied")
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                                }
                                .buttonStyle(OrionQuietButtonStyle())
                                .disabled(session.output.isEmpty)

                                if session.activeRecordingID != nil {
                                    Button("Finder") {
                                        try? session.revealInFinder(item: .folder)
                                    }
                                    .buttonStyle(OrionQuietButtonStyle())
                                }
                            }
                        } document: {
                            VStack(alignment: .leading, spacing: 20) {
                                let parsed = SummaryDocumentParser.parse(
                                    output: session.output,
                                    template: NoteTemplate(rawValue: session.selectedOutputTemplate.id) ?? .summary
                                )

                                SummaryDocumentView(
                                    title: session.selectedOutputTemplate.name,
                                    meta: metaLine,
                                    summary: parsed.summary,
                                    keyPoints: parsed.keyPoints,
                                    decisions: parsed.decisions,
                                    actionItems: parsed.actionItems,
                                    aiLabel: session.llmRouter.selectedProvider.displayName,
                                    isLoading: session.isGenerating,
                                    error: session.errorMessage
                                )
                            }
                        }
                    }

                    if let toastMessage {
                        OrionToast(message: toastMessage)
                            .padding(.top, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: toastMessage)
                .task(id: autoGenerateIdentity) {
                    await autoGenerateIfNeeded()
                }
            }
        }
    }

    private var autoGenerateIdentity: String {
        let id = session.activeRecordingID?.uuidString ?? "none"
        return "\(id)|\(session.selectedOutputTemplate.id)"
    }

    private var metaLine: String? {
        guard session.activeRecordingID != nil else { return nil }
        let dur = Int(session.elapsedSeconds.rounded())
        return "\(session.selectedOutputTemplate.name) · \(dur / 60)m \(dur % 60)s · \(session.llmRouter.selectedProvider.displayName)"
    }

    @MainActor
    private func autoGenerateIfNeeded() async {
        let key = autoGenerateIdentity
        guard session.canGenerate else { return }
        guard session.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard autoGenerateKey != key else { return }
        autoGenerateKey = key
        await session.generate()
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastMessage == message { toastMessage = nil }
        }
    }
}
