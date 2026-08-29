import SwiftUI

enum AppDestination: String, Hashable, CaseIterable, Identifiable {
    case newRecording
    case recordings
    case templates
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newRecording: "Record"
        case .recordings: "Recordings"
        case .templates: "Templates"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .newRecording: "mic"
        case .recordings: "recordingtape"
        case .templates: "text.badge.plus"
        case .settings: "gearshape"
        }
    }
}

enum RecordingsNoteTab: String, Hashable, CaseIterable, Identifiable {
    case transcript
    case summary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transcript: "Transcript"
        case .summary: "Summary"
        }
    }
}
