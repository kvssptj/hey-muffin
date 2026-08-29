import Foundation

@MainActor
@Observable
public final class LLMRouter {
    private static let selectionKey = "muffin.llmProvider"

    private let apple = AppleFoundationProvider()
    private let openRouter = OpenRouterProvider()
    private let ollama = OllamaProvider()

    public var selectedID: LLMProviderID {
        didSet {
            UserDefaults.standard.set(selectedID.rawValue, forKey: Self.selectionKey)
        }
    }

    public init() {
        if let raw = UserDefaults.standard.string(forKey: Self.selectionKey),
           let saved = LLMProviderID(rawValue: raw) {
            selectedID = saved
        } else {
            selectedID = .apple
        }
    }

    public var providers: [any LLMProvider] {
        [apple, openRouter, ollama]
    }

    public var selectedProvider: any LLMProvider {
        provider(for: selectedID)
    }

    public func provider(for id: LLMProviderID) -> any LLMProvider {
        switch id {
        case .apple: apple
        case .openRouter: openRouter
        case .ollama: ollama
        }
    }

    public func transform(transcript: String, instructions: String) async throws -> String {
        try await selectedProvider.transform(transcript: transcript, instructions: instructions)
    }
}
