import Foundation

public struct OllamaProvider: LLMProvider {
    public let id: LLMProviderID = .ollama
    public let displayName = "Ollama"

    public init() {}

    public var isAvailable: Bool { false }

    public func transform(transcript: String, instructions: String) async throws -> String {
        throw LLMProviderError.notConfigured(
            "Ollama isn’t wired yet. Settings fields are saved locally, but Generate can’t call localhost until we hook it up."
        )
    }
}
