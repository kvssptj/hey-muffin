import ArgumentParser
import Foundation
import MuffinCore

@main
struct MuffinCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "muffin",
        abstract: "Muffin voice notes — list, export, search, and generate from disk.",
        subcommands: [ListCmd.self, TranscriptCmd.self, RevealCmd.self, GenerateCmd.self, SearchCmd.self, ExportCmd.self]
    )
}

struct ListCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List recordings")

    func run() throws {
        let store = try RecordingStore()
        let items = try store.list()
        if items.isEmpty {
            print("No recordings.")
            return
        }
        let df = ISO8601DateFormatter()
        for r in items {
            let dur = String(format: "%.0fs", r.meta.duration)
            print("\(r.id.uuidString)\t\(df.string(from: r.meta.createdAt))\t\(dur)\t\(r.meta.title)")
        }
    }
}

struct TranscriptCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "transcript", abstract: "Print or save a transcript")

    @Argument(help: "Recording UUID")
    var id: String

    @Option(name: .long, help: "md or txt")
    var format: String = "md"

    @Option(name: .long, help: "Optional output path")
    var out: String?

    func run() async throws {
        let store = try RecordingStore()
        let uuid = try parseID(id)
        let text: String
        if format == "txt" {
            _ = try store.exportPlainText(id: uuid)
            text = try String(contentsOf: store.recording(id: uuid).plainTranscriptURL, encoding: .utf8)
        } else {
            text = try store.readTranscript(id: uuid)
        }
        if let out {
            try text.write(to: URL(fileURLWithPath: out), atomically: true, encoding: .utf8)
            print(out)
        } else {
            print(text)
        }
    }
}

struct RevealCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "reveal", abstract: "Reveal recording in Finder")

    @Argument var id: String

    @Option(name: .long, help: "folder | audio | transcript")
    var item: String = "folder"

    func run() async throws {
        let store = try RecordingStore()
        let uuid = try parseID(id)
        let reveal: RevealItem = switch item {
        case "audio": .audio
        case "transcript": .transcript
        default: .folder
        }
        try await MainActor.run {
            try store.revealInFinder(id: uuid, item: reveal)
        }
    }
}

struct GenerateCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "generate", abstract: "Run a template against a recording")

    @Argument var id: String

    @Option(name: .long, help: "summary | meetingNotes | actionItems | blogDraft")
    var template: String = "summary"

    func run() async throws {
        let uuid = try parseID(id)
        guard let tmpl = NoteTemplate(rawValue: template) else {
            throw ValidationError("Unknown template: \(template)")
        }
        let session = await MainActor.run { RecordingSession() }
        let result = try await session.generate(id: uuid, template: tmpl)
        print(result)
    }
}

struct SearchCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search", abstract: "Search transcripts")

    @Argument var query: String

    func run() throws {
        let store = try RecordingStore()
        let hits = try store.search(query: query)
        if hits.isEmpty {
            print("No matches.")
            return
        }
        for r in hits {
            print("\(r.id.uuidString)\t\(r.meta.title)")
        }
    }
}

struct ExportCmd: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Write transcript.txt next to transcript.md"
    )

    @Argument var id: String

    func run() throws {
        let store = try RecordingStore()
        let uuid = try parseID(id)
        let url = try store.exportPlainText(id: uuid)
        print(url.path)
    }
}

private func parseID(_ raw: String) throws -> UUID {
    guard let id = UUID(uuidString: raw) else {
        throw ValidationError("Invalid UUID: \(raw)")
    }
    return id
}
