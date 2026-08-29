import AppKit
import Foundation

/// Short UI sounds for record start / stop.
public enum RecordingChime {
    public static func playStart() {
        guard let sound = NSSound(named: NSSound.Name("Tink")), sound.play() else {
            NSSound.beep()
            return
        }
    }

    public static func playStop() {
        guard let sound = NSSound(named: NSSound.Name("Pop")), sound.play() else {
            NSSound.beep()
            return
        }
    }
}
