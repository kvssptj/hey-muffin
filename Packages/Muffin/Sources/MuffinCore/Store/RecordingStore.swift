import AppKit
import Foundation

public enum RecordingStoreError: LocalizedError, Sendable {
    case notFound(UUID)
    case io(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id): "Recording not found: \(id.uuidString)"
        case .io(let message): message
        }
    }
}

/// On-disk store under Application Support/Muffin/Recordings/<yyyy-MM-dd-HHmmss>/.
public final class RecordingStore: @unchecked Sendable {
    public let rootURL: URL
    private let fm = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(rootURL: URL? = nil) throws {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let support = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.rootURL = support
                .appendingPathComponent("Muffin", isDirectory: true)
                .appendingPathComponent("Recordings", isDirectory: true)
        }
        try fm.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
    }

    public func list() throws -> [Recording] {
        let contents = try fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var recordings: [Recording] = []
        for folder in contents {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let metaURL = folder.appendingPathComponent("meta.json")
            guard fm.fileExists(atPath: metaURL.path) else { continue }
            let data = try Data(contentsOf: metaURL)
            let meta = try decoder.decode(RecordingMeta.self, from: data)
            recordings.append(Recording(meta: meta, folderURL: folder))
        }
        return recordings.sorted { $0.meta.createdAt > $1.meta.createdAt }
    }

    public func recording(id: UUID) throws -> Recording {
        // Fast path: legacy UUID-named folder (backward compat for existing recordings).
        let legacy = rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
        let legacyMeta = legacy.appendingPathComponent("meta.json")
        if fm.fileExists(atPath: legacyMeta.path),
           let data = try? Data(contentsOf: legacyMeta),
           let meta = try? decoder.decode(RecordingMeta.self, from: data),
           meta.id == id {
            return Recording(meta: meta, folderURL: legacy)
        }
        // Scan all folders for a meta.json whose id matches.
        let contents = (try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for folder in contents {
            let metaURL = folder.appendingPathComponent("meta.json")
            guard fm.fileExists(atPath: metaURL.path),
                  let data = try? Data(contentsOf: metaURL),
                  let meta = try? decoder.decode(RecordingMeta.self, from: data),
                  meta.id == id else { continue }
            return Recording(meta: meta, folderURL: folder)
        }
        throw RecordingStoreError.notFound(id)
    }

    public func create(title: String? = nil) throws -> Recording {
        let id = UUID()
        let now = Date()

        // Build a human-readable folder name: yyyy-MM-dd-HHmmss
        let folderFormatter = DateFormatter()
        folderFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        folderFormatter.locale = Locale(identifier: "en_US_POSIX")
        let base = folderFormatter.string(from: now)
        var folderName = base
        var suffix = 2
        while fm.fileExists(atPath: rootURL.appendingPathComponent(folderName).path) {
            folderName = "\(base)-\(suffix)"
            suffix += 1
        }

        let folder = rootURL.appendingPathComponent(folderName, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try fm.createDirectory(at: folder.appendingPathComponent("outputs", isDirectory: true), withIntermediateDirectories: true)

        let titleFormatter = DateFormatter()
        titleFormatter.dateStyle = .medium
        titleFormatter.timeStyle = .short
        let defaultTitle = title ?? "Recording \(titleFormatter.string(from: now))"

        let meta = RecordingMeta(id: id, title: defaultTitle)
        let recording = Recording(meta: meta, folderURL: folder)
        try writeMeta(meta, for: recording)
        try writeTranscript("", for: recording)
        return recording
    }

    public func writeMeta(_ meta: RecordingMeta, for recording: Recording) throws {
        let data = try encoder.encode(meta)
        try data.write(to: recording.metaURL, options: .atomic)
    }

    public func updateMeta(_ meta: RecordingMeta) throws {
        let recording = try recording(id: meta.id)
        try writeMeta(meta, for: recording)
    }

    public func readTranscript(id: UUID) throws -> String {
        let recording = try recording(id: id)
        guard fm.fileExists(atPath: recording.transcriptURL.path) else { return "" }
        return try String(contentsOf: recording.transcriptURL, encoding: .utf8)
    }

    public func writeTranscript(_ text: String, for recording: Recording) throws {
        try text.write(to: recording.transcriptURL, atomically: true, encoding: .utf8)
    }

    public func writeTranscript(id: UUID, text: String) throws {
        let recording = try recording(id: id)
        try writeTranscript(text, for: recording)
    }

    public func readOutput(id: UUID, template: NoteTemplate) throws -> String? {
        let recording = try recording(id: id)
        let url = recording.outputsURL.appendingPathComponent("\(template.outputFileName).md")
        guard fm.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func writeOutput(id: UUID, template: NoteTemplate, text: String) throws {
        let recording = try recording(id: id)
        try fm.createDirectory(at: recording.outputsURL, withIntermediateDirectories: true)
        let url = recording.outputsURL.appendingPathComponent("\(template.outputFileName).md")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    public func delete(id: UUID) throws {
        let folder = try recording(id: id).folderURL
        try fm.trashItem(at: folder, resultingItemURL: nil)
    }

    public func readOutput(id: UUID, outputFileName: String) throws -> String? {
        let recording = try recording(id: id)
        let url = recording.outputsURL.appendingPathComponent("\(outputFileName).md")
        guard fm.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func writeOutput(id: UUID, outputFileName: String, text: String) throws {
        let recording = try recording(id: id)
        try fm.createDirectory(at: recording.outputsURL, withIntermediateDirectories: true)
        let url = recording.outputsURL.appendingPathComponent("\(outputFileName).md")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Writes transcript.txt next to transcript.md (markdown stripped).
    @discardableResult
    public func exportPlainText(id: UUID) throws -> URL {
        let recording = try recording(id: id)
        let md = try readTranscript(id: id)
        let plain = MarkdownPlainText.convert(md)
        try plain.write(to: recording.plainTranscriptURL, atomically: true, encoding: .utf8)
        return recording.plainTranscriptURL
    }

    public func search(query: String) throws -> [Recording] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return try list() }
        return try list().filter { recording in
            let transcript = (try? readTranscript(id: recording.id)) ?? ""
            return transcript.localizedCaseInsensitiveContains(q)
                || recording.meta.title.localizedCaseInsensitiveContains(q)
        }
    }

    @MainActor
    public func revealInFinder(id: UUID, item: RevealItem = .folder) throws {
        let recording = try recording(id: id)
        let url: URL
        switch item {
        case .folder: url = recording.folderURL
        case .audio: url = recording.audioURL
        case .transcript: url = recording.transcriptURL
        }
        if item != .folder, !fm.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([recording.folderURL])
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
