import Foundation

public enum LLMProviderID: String, CaseIterable, Identifiable, Codable, Sendable {
    case apple
    case openRouter
    case ollama

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .apple: "Apple"
        case .openRouter: "OpenRouter"
        case .ollama: "Ollama"
        }
    }
}

public protocol LLMProvider: Sendable {
    var id: LLMProviderID { get }
    var displayName: String { get }
    var isAvailable: Bool { get }
    func transform(transcript: String, instructions: String) async throws -> String
}

public enum LLMProviderError: LocalizedError, Sendable {
    case notConfigured(String)
    case unavailable(String)
    case emptyTranscript

    public var errorDescription: String? {
        switch self {
        case .notConfigured(let message): message
        case .unavailable(let message): message
            case .emptyTranscript: "Transcript is empty. Record or open one from Library, then try again."
        }
    }
}
