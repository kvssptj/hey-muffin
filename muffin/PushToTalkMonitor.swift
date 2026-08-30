import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation
import Observation

extension Notification.Name {
    /// Posted when Fn is pressed (hold-to-talk begin).
    static let muffinFnPushBegan = Notification.Name("muffinFnPushBegan")
    /// Posted when Fn is released (hold-to-talk end).
    static let muffinFnPushEnded = Notification.Name("muffinFnPushEnded")
}

/// Global hold-Fn → push-to-talk. Requires Accessibility permission.
/// Never auto-prompts; only `requestAccessFromUser()` shows the system dialog.
@MainActor
@Observable
final class PushToTalkMonitor {
    static let shared = PushToTalkMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnIsDown = false
    private(set) var isTrusted = false
    private(set) var isMonitoring = false

    private init() {}

    /// Silent (or prompted) trust check. Default is silent — no system sheet.
    @discardableResult
    func refreshTrust(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: prompt] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(opts)
        return isTrusted
    }

    /// Start the Fn listener only if already trusted. Never prompts.
    func startIfTrusted() {
        refreshTrust(prompt: false)
        guard isTrusted else {
            stop()
            return
        }
        guard eventTap == nil else {
            isMonitoring = true
            return
        }
        installTap()
    }

    /// User-initiated: open System Settings and optionally show the trust sheet once.
    func requestAccessFromUser() {
        openAccessibilitySettings()
        // Prompt only from an explicit click so the sheet stays attached to a user gesture.
        refreshTrust(prompt: true)
        if isTrusted {
            startIfTrusted()
        }
    }

    func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    /// Call when the app becomes active — picks up trust after the user toggles it in Settings.
    func handleAppBecameActive() {
        let wasTrusted = isTrusted
        refreshTrust(prompt: false)
        if isTrusted {
            startIfTrusted()
        } else if wasTrusted {
            stop()
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        fnIsDown = false
        isMonitoring = false
    }

    private func installTap() {
        let mask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, _ in
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keyCode == CGKeyCode(kVK_Function) else {
                return Unmanaged.passUnretained(event)
            }

            switch type {
            case .keyDown:
                PushToTalkMonitor.postBeganIfNeeded()
            case .keyUp:
                PushToTalkMonitor.postEndedIfNeeded()
            case .flagsChanged:
                if event.flags.contains(.maskSecondaryFn) {
                    PushToTalkMonitor.postBeganIfNeeded()
                } else {
                    PushToTalkMonitor.postEndedIfNeeded()
                }
            default:
                break
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: nil
        ) else {
            isTrusted = false
            isMonitoring = false
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        isMonitoring = true
    }

    nonisolated private static func postBeganIfNeeded() {
        DispatchQueue.main.async {
            let monitor = PushToTalkMonitor.shared
            guard !monitor.fnIsDown else { return }
            monitor.fnIsDown = true
            NotificationCenter.default.post(name: .muffinFnPushBegan, object: nil)
        }
    }

    nonisolated private static func postEndedIfNeeded() {
        DispatchQueue.main.async {
            let monitor = PushToTalkMonitor.shared
            guard monitor.fnIsDown else { return }
            monitor.fnIsDown = false
            NotificationCenter.default.post(name: .muffinFnPushEnded, object: nil)
        }
    }
}
