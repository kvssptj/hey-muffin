import AppKit
import MuffinCore
import Observation
import SwiftUI

/// App-wide session + Fn push-to-talk wiring (shared by window and menu bar).
@MainActor
@Observable
final class AppModel {
    let session = RecordingSession()
    /// Only stop on Fn release if this take was started by holding Fn.
    var recordingStartedByFn = false

    func bootstrap() async {
        await session.bootstrap()
        PushToTalkMonitor.shared.startIfTrusted()
    }

    func handleFnPushBegan() {
        guard !session.isRecording, !session.isPreparingSpeech else { return }
        recordingStartedByFn = true
        Task { await session.startRecording() }
    }

    func handleFnPushEnded() {
        guard recordingStartedByFn else { return }
        recordingStartedByFn = false
        Task { await session.stopRecording() }
    }

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            // Skip the status-item panel; bring a real app window forward.
            guard window.canBecomeKey || window.canBecomeMain else { continue }
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}
