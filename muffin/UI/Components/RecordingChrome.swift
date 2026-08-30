import SwiftUI

/// Magic Patterns `RecordingIndicator` + `Timecode`.
struct RecordingIndicator: View {
    enum Status { case recording, paused, stopped }

    var status: Status = .recording
    var seconds: TimeInterval? = nil
    var label: String? = nil
    var hideLabel: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if status == .recording {
                    Circle()
                        .fill(OrionColor.danger.opacity(0.35))
                        .frame(width: 10, height: 10)
                        .scaleEffect(1.35)
                }
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 12, height: 12)

            if !hideLabel {
                Text(label ?? defaultLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(textColor)
            }

            if let seconds {
                TimecodeView(value: seconds, tone: status == .recording ? .recording : .default)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var defaultLabel: String {
        switch status {
        case .recording: "Recording"
        case .paused: "Paused"
        case .stopped: "Stopped"
        }
    }

    private var dotColor: Color {
        switch status {
        case .recording: OrionColor.danger
        case .paused: OrionColor.warning
        case .stopped: OrionColor.textMuted
        }
    }

    private var textColor: Color {
        switch status {
        case .recording: OrionColor.danger
        case .paused: OrionColor.warning
        case .stopped: OrionColor.textMuted
        }
    }
}

enum TimecodeTone { case `default`, muted, recording }

struct TimecodeView: View {
    var value: TimeInterval
    var tone: TimecodeTone = .default
    var showHours: Bool = true
    var size: CGFloat = 13

    var body: some View {
        Text(Self.format(value, showHours: showHours))
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
            .monospacedDigit()
    }

    private var color: Color {
        switch tone {
        case .default: OrionColor.textInk
        case .muted: OrionColor.textMuted
        case .recording: OrionColor.danger
        }
    }

    static func format(_ seconds: TimeInterval, showHours: Bool = true) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if showHours || h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
