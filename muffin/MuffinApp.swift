import AppKit
import MuffinCore
import SwiftUI

@main
struct MuffinApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(session: model.session)
                .preferredColorScheme(.light)
                .task { await model.bootstrap() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    PushToTalkMonitor.shared.handleAppBecameActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: .muffinFnPushBegan)) { _ in
                    model.handleFnPushBegan()
                }
                .onReceive(NotificationCenter.default.publisher(for: .muffinFnPushEnded)) { _ in
                    model.handleFnPushEnded()
                }
        }
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Start recording") {
                    NotificationCenter.default.post(name: .muffinNewRecording, object: nil)
                    model.session.toggleRecording()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!model.session.canToggleRecording || model.session.isRecording)
            }
        }

        MenuBarExtra {
            MenuBarRecordingMenu(session: model.session) {
                model.openMainWindow()
            }
        } label: {
            MenuBarStatusLabel(session: model.session)
        }
    }
}

extension Notification.Name {
    static let muffinNewRecording = Notification.Name("muffinNewRecording")
}
