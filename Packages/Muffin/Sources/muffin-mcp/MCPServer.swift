import Foundation
import MuffinCore

/// Minimal MCP server over stdio (JSON-RPC 2.0, newline-delimited).
@main
enum MuffinMCPMain {
    static func main() async {
        let server = MCPServer()
        await server.run()
    }
}

actor MCPServer {
    private let store: RecordingStore

    init() {
        do {
            store = try RecordingStore()
        } catch {
            fputs("Failed to open store: \(error)\n", stderr)
            store = try! RecordingStore(rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("Muffin-MCP-Fallback", isDirectory: true))
        }
    }

    func run() async {
        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            let id = obj["id"]
            let method = obj["method"] as? String ?? ""
            let params = obj["params"] as? [String: Any] ?? [:]

            let response: [String: Any]
            do {
                let result = try await handle(method: method, params: params)
                response = [
                    "jsonrpc": "2.0",
                    "id": id as Any,
                    "result": result,
                ]
            } catch {
                response = [
                    "jsonrpc": "2.0",
                    "id": id as Any,
                    "error": [
                        "code": -32000,
                        "message": error.localizedDescription,
                    ],
                ]
            }
            writeJSON(response)
        }
    }

    private func handle(method: String, params: [String: Any]) async throws -> Any {
        switch method {
        case "initialize":
            return [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [:] as [String: Any]],
                "serverInfo": ["name": "muffin-mcp", "version": "1.0.0"],
            ]
        case "notifications/initialized", "initialized":
            return [:] as [String: Any]
        case "tools/list":
            return ["tools": toolsManifest()]
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let args = params["arguments"] as? [String: Any] ?? [:]
            let text = try await callTool(name: name, args: args)
            return [
                "content": [["type": "text", "text": text]],
                "isError": false,
            ]
        case "ping":
            return [:] as [String: Any]
        default:
            throw MCPError.unknownMethod(method)
        }
    }

    private func toolsManifest() -> [[String: Any]] {
        [
            tool("list_recordings", "List all recordings with id, title, date, duration", [:]),
            tool("get_transcript", "Get raw transcript text", ["id": stringProp("Recording UUID")]),
            tool("search_transcripts", "Search transcripts", ["query": stringProp("Search query")]),
            tool("edit_transcript", "Overwrite stored transcript", [
                "id": stringProp("Recording UUID"),
                "text": stringProp("New transcript markdown"),
            ]),
            tool("generate_summary", "Run template pipeline", [
                "id": stringProp("Recording UUID"),
                "template": stringProp("summary | meetingNotes | actionItems | blogDraft"),
            ]),
        ]
    }

    private func callTool(name: String, args: [String: Any]) async throws -> String {
        switch name {
        case "list_recordings":
            let items = try store.list()
            let df = ISO8601DateFormatter()
            let rows = items.map {
                [
                    "id": $0.id.uuidString,
                    "title": $0.meta.title,
                    "createdAt": df.string(from: $0.meta.createdAt),
                    "duration": $0.meta.duration,
                ] as [String: Any]
            }
            return prettyJSON(rows)

        case "get_transcript":
            let id = try requireUUID(args["id"])
            return try store.readTranscript(id: id)

        case "search_transcripts":
            let query = args["query"] as? String ?? ""
            let hits = try store.search(query: query)
            return prettyJSON(hits.map { ["id": $0.id.uuidString, "title": $0.meta.title] })

        case "edit_transcript":
            let id = try requireUUID(args["id"])
            let text = args["text"] as? String ?? ""
            try store.writeTranscript(id: id, text: text)
            return "OK"

        case "generate_summary":
            let id = try requireUUID(args["id"])
            let templateName = args["template"] as? String ?? "summary"
            guard let template = NoteTemplate(rawValue: templateName) else {
                throw MCPError.badArgs("Unknown template \(templateName)")
            }
            let session = await MainActor.run { RecordingSession(store: store) }
            return try await session.generate(id: id, template: template)

        default:
            throw MCPError.unknownMethod(name)
        }
    }

    private func tool(_ name: String, _ description: String, _ props: [String: Any]) -> [String: Any] {
        [
            "name": name,
            "description": description,
            "inputSchema": [
                "type": "object",
                "properties": props,
            ],
        ]
    }

    private func stringProp(_ description: String) -> [String: Any] {
        ["type": "string", "description": description]
    }

    private func requireUUID(_ value: Any?) throws -> UUID {
        guard let s = value as? String, let id = UUID(uuidString: s) else {
            throw MCPError.badArgs("Expected UUID id")
        }
        return id
    }

    private func prettyJSON(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: data, encoding: .utf8)
        else { return "[]" }
        return s
    }

    private func writeJSON(_ obj: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj),
              var line = String(data: data, encoding: .utf8)
        else { return }
        line.append("\n")
        fputs(line, stdout)
        fflush(stdout)
    }
}

enum MCPError: LocalizedError {
    case unknownMethod(String)
    case badArgs(String)

    var errorDescription: String? {
        switch self {
        case .unknownMethod(let m): "Unknown method: \(m)"
        case .badArgs(let m): m
        }
    }
}
