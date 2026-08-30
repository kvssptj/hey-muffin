import MuffinCore
import SwiftUI

struct MenuBarStatusLabel: View {
    @Bindable var session: RecordingSession

    var body: some View {
        Image("MenuBarIcon")
            .renderingMode(.template)
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if session.isPreparingSpeech { return "Muffin: starting" }
        if session.isRecording && session.isPaused { return "Muffin: paused" }
        if session.isRecording { return "Muffin: recording" }
        return "Muffin"
    }
}

struct MenuBarRecordingMenu: View {
    @Bindable var session: RecordingSession
    var onOpenMainWindow: () -> Void

    var body: some View {
        if session.isRecording {
            Text(session.isPaused ? "Paused · \(timeString)" : "Recording · \(timeString)")
            Divider()
            Button(session.isPaused ? "Resume recording" : "Pause recording") {
                session.togglePause()
            }
            Button("Stop & save") {
                session.toggleRecording()
            }
        } else {
            Button("Start recording") {
                session.toggleRecording()
            }
            .disabled(!session.canToggleRecording)
        }

        Divider()

        Button("Open Muffin") {
            onOpenMainWindow()
        }

        if !PushToTalkMonitor.shared.isTrusted {
            Divider()
            Button("Allow Accessibility for Hold Fn…") {
                PushToTalkMonitor.shared.requestAccessFromUser()
            }
        }
    }

    private var timeString: String {
        let total = Int(session.elapsedSeconds)
        return String(format: "%02d:%02d", (total % 3600) / 60, total % 60)
    }
}
