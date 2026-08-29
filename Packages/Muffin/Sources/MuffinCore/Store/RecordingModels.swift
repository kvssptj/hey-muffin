import Foundation

public struct RecordingMarker: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var seconds: TimeInterval
    public var label: String

    public init(id: UUID = UUID(), seconds: TimeInterval, label: String = "Marker") {
        self.id = id
        self.seconds = seconds
        self.label = label
    }
}

public struct RecordingMeta: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var duration: TimeInterval
    public var markers: [RecordingMarker]

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        markers: [RecordingMarker] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.markers = markers
    }
}

public struct Recording: Hashable, Sendable, Identifiable {
    public var meta: RecordingMeta
    public var folderURL: URL

    public var id: UUID { meta.id }

    public var audioURL: URL { folderURL.appendingPathComponent("audio.caf") }
    public var transcriptURL: URL { folderURL.appendingPathComponent("transcript.md") }
    public var plainTranscriptURL: URL { folderURL.appendingPathComponent("transcript.txt") }
    public var metaURL: URL { folderURL.appendingPathComponent("meta.json") }
    public var outputsURL: URL { folderURL.appendingPathComponent("outputs", isDirectory: true) }

    public init(meta: RecordingMeta, folderURL: URL) {
        self.meta = meta
        self.folderURL = folderURL
    }
}

public enum RevealItem: String, Sendable {
    case folder
    case audio
    case transcript
}
