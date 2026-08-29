import Foundation

public struct OpenRouterProvider: LLMProvider {
    public let id: LLMProviderID = .openRouter
    public let displayName = "OpenRouter"

    public init() {}

    public var isAvailable: Bool { false }

    public func transform(transcript: String, instructions: String) async throws -> String {
        throw LLMProviderError.notConfigured(
            "OpenRouter isn’t wired yet. Settings fields are saved locally, but Generate can’t call the API until we hook it up."
        )
    }
}
