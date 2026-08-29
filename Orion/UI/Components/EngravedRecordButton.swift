import SwiftUI

/// Magic Patterns `RecordButton` adapted for Muffin: press starts or stops (pause is a separate control).
struct EngravedRecordButton: View {
    var isRecording: Bool
    var isPaused: Bool = false
    var isBusy: Bool = false
    var action: () -> Void

    private let size: CGFloat = 168

    var body: some View {
        VStack(spacing: 14) {
            Button(action: action) {
                ZStack {
                    if isRecording && !isPaused && !isBusy {
                        Circle()
                            .strokeBorder(OrionColor.danger.opacity(0.35), lineWidth: 1)
                            .padding(10)
                    }

                    Circle()
                        .fill(OrionColor.surfacePaper)
                        .overlay(
                            Circle()
                                .strokeBorder(OrionColor.border, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.10), radius: 10, y: 5)

                    Circle()
                        .fill(innerFill)
                        .overlay(
                            Circle()
                                .strokeBorder(innerBorder, lineWidth: 1)
                        )
                        .frame(width: size * 0.52, height: size * 0.52)
                        .overlay {
                            if isBusy && !isRecording {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(OrionColor.textBody)
                            } else if isRecording {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(OrionColor.danger)
                                    .frame(width: 22, height: 22)
                            } else {
                                Image(systemName: "mic")
                                    .font(.system(size: 28, weight: .regular))
                                    .foregroundStyle(OrionColor.danger)
                            }
                        }
                }
                .frame(width: size, height: size)
                .contentShape(Circle())
                .opacity(isBusy && !isRecording ? 0.85 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isBusy && !isRecording)
            .help(isRecording ? "Stop & save" : (isBusy ? "Starting mic & speech…" : "Start recording"))

            RecordingIndicator(
                status: indicatorStatus,
                label: isRecording || isBusy ? nil : "Ready"
            )
        }
        .animation(.easeOut(duration: 0.15), value: isBusy)
        .animation(.easeOut(duration: 0.15), value: isRecording)
        .animation(.easeOut(duration: 0.15), value: isPaused)
    }

    private var indicatorStatus: RecordingIndicator.Status {
        if isBusy && !isRecording { return .stopped }
        if isRecording && isPaused { return .paused }
        if isRecording { return .recording }
        return .stopped
    }

    private var innerFill: Color {
        if isRecording && isPaused { return OrionColor.warningTint }
        if isRecording { return OrionColor.dangerTint }
        return Color(hex: 0xF4F6F8)
    }

    private var innerBorder: Color {
        if isRecording && isPaused { return Color(hex: 0xE5D4A8) }
        if isRecording { return Color(hex: 0xE5C4BC) }
        return OrionColor.border
    }
}
