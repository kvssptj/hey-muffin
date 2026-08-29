import AppKit
import MuffinCore
import SwiftUI

struct RecordView: View {
    @Bindable var session: RecordingSession
    var onOpenTranscript: () -> Void
    var onOpenSummary: () -> Void

    @State private var copiedFlash = false
    @State private var toastMessage: String?

    // MARK: - Home message

    private var homeMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1

        let pool: [String]
        switch hour {
        case 5..<12:
            pool = [
                "Good morning.",
                "Ready.",
                "Nothing is saved until you stop.",
                "Transcription runs on-device.",
            ]
        case 12..<14:
            pool = [
                "Good afternoon.",
                "Ready.",
                "Tap to start. Stop to save.",
            ]
        case 14..<18:
            pool = [
                "Good afternoon.",
                "Ready when you are.",
                "Transcripts autosave while you speak.",
                "Audio and transcript save to the same folder.",
            ]
        case 18..<22:
            pool = [
                "Good evening.",
                "Ready.",
                "Everything stays on your Mac.",
                "Hold Fn anywhere to start recording.",
            ]
        default:
            pool = [
                "Good evening.",
                "Still here.",
                "Ready.",
                "Nothing requires an account.",
            ]
        }

        return pool[dayOfYear % pool.count]
    }

    private var showCompletion: Bool {
        !session.isRecording
            && !session.isPreparingSpeech
            && session.activeRecordingID != nil
            && !session.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var wordCount: Int {
        session.transcript
            .split { $0.isWhitespace || $0.isNewline }
            .filter { !$0.isEmpty }
            .count
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 12)

                        VStack(spacing: 20) {
                            if showCompletion {
                                completionCard
                                    .frame(maxWidth: 520)
                            } else {
                                if !session.isRecording && !session.isPreparingSpeech {
                                    Text(homeMessage)
                                        .font(.system(size: 16, weight: .regular, design: .serif))
                                        .italic()
                                        .foregroundStyle(OrionColor.textMuted)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 380)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                EngravedRecordButton(
                                    isRecording: session.isRecording,
                                    isPaused: session.isPaused,
                                    isBusy: session.isPreparingSpeech
                                ) {
                                    session.toggleRecording()
                                }
                                .disabled(!session.canToggleRecording)

                                OrionCard(padding: 18) {
                                    VStack(spacing: 14) {
                                        TimecodeView(
                                            value: session.elapsedSeconds,
                                            tone: session.isRecording && !session.isPaused ? .recording : .default,
                                            showHours: true,
                                            size: 28
                                        )

                                        WaveformView(
                                            state: waveformState,
                                            level: session.isRecording && !session.isPaused ? 0.7 : 0.25
                                        )
                                        .frame(maxWidth: 300)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .frame(maxWidth: 360)

                                if session.isRecording {
                                    HStack(spacing: 8) {
                                        Button(session.isPaused ? "Resume" : "Pause") {
                                            session.togglePause()
                                        }
                                        .buttonStyle(OrionQuietButtonStyle())

                                        Button("Stop & save") {
                                            session.toggleRecording()
                                        }
                                        .buttonStyle(OrionSecondaryButtonStyle())

                                        Button("Cancel") {
                                            Task { await session.cancelRecording() }
                                        }
                                        .buttonStyle(OrionQuietButtonStyle())
                                        .foregroundStyle(OrionColor.danger)
                                    }
                                } else if !session.speechReady {
                                    Text(session.statusMessage)
                                        .font(.system(size: 13))
                                        .foregroundStyle(OrionColor.textMuted)
                                }

                                liveTranscriptCard
                                    .frame(maxWidth: 520)
                            }
                        }
                        .animation(.easeInOut(duration: 0.25), value: session.isRecording)
                        .animation(.easeInOut(duration: 0.25), value: session.isPreparingSpeech)

                        if let error = session.errorMessage, !showCompletion {
                            Text(error)
                                .font(OrionType.caption)
                                .foregroundStyle(OrionColor.danger)
                                .textSelection(.enabled)
                                .padding(.top, 12)
                        }

                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .scrollBounceBehavior(.basedOnSize)

                if let toastMessage {
                    OrionToast(message: toastMessage)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .animation(.easeOut(duration: 0.2), value: toastMessage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var waveformState: WaveformView.State {
        if session.isRecording && session.isPaused { return .paused }
        if session.isRecording { return .recording }
        return .idle
    }

    private var completionCard: some View {
        OrionCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OrionColor.primary)
                    Text("Recording saved")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(OrionColor.textInk)
                    Spacer(minLength: 8)
                    OrionBadge(text: completionMeta, variant: .olive)
                }

                Text(clipboardNote)
                    .font(.system(size: 12.5))
                    .foregroundStyle(OrionColor.textMuted)

                OrionEngravedRule()

                Text("TRANSCRIPT")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(OrionColor.primary)

                Text(session.attributedTranscript.confidenceStyled())
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(OrionColor.textInk)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                OrionEngravedRule()

                HStack(spacing: 8) {
                    Button("Open transcript") { onOpenTranscript() }
                        .buttonStyle(OrionPrimaryButtonStyle())
                        .fixedSize()

                    Button("Generate summary") { onOpenSummary() }
                        .buttonStyle(OrionSecondaryButtonStyle())
                        .fixedSize()

                    Button(copiedFlash ? "Copied" : "Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(session.transcript, forType: .string)
                        copiedFlash = true
                        showToast("Copied to clipboard")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            copiedFlash = false
                        }
                    }
                    .buttonStyle(OrionQuietButtonStyle())
                    .fixedSize()

                    Button("Record another") {
                        Task { await session.startRecording() }
                    }
                    .buttonStyle(OrionQuietButtonStyle())
                    .disabled(!session.canToggleRecording)
                    .fixedSize()

                    Spacer(minLength: 0)

                    OrionIconButton(
                        systemName: "folder",
                        accessibilityLabel: "Show in Finder",
                        variant: .ghost,
                        size: .sm
                    ) {
                        try? session.revealInFinder(item: .folder)
                        showToast("Opened in Finder")
                    }
                }

                if let error = session.errorMessage {
                    Text(error)
                        .font(OrionType.caption)
                        .foregroundStyle(OrionColor.danger)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var clipboardNote: String {
        if session.statusMessage.localizedCaseInsensitiveContains("clipboard") {
            return "On disk · already on your clipboard"
        }
        return "Saved on this Mac"
    }

    private var completionMeta: String {
        let dur = Int(session.elapsedSeconds.rounded())
        return "\(dur / 60)m \(dur % 60)s · \(wordCount) words"
    }

    private var liveTranscriptCard: some View {
        OrionCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("LIVE TRANSCRIPT")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(OrionColor.primary)
                    Spacer()
                    if session.isRecording {
                        OrionBadge(text: "Streaming", variant: .sky, showDot: true)
                    }
                }

                if session.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(session.isRecording || session.isPreparingSpeech
                         ? "Waiting for speech…"
                         : "Words show up here as you talk. Nothing is written to disk until you stop.")
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(OrionColor.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                } else {
                    Text(session.attributedTranscript.confidenceStyled())
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(OrionColor.textInk)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                }
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastMessage == message { toastMessage = nil }
        }
    }
}
