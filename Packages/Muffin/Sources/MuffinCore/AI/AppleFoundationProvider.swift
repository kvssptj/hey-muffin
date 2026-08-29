import Foundation
import FoundationModels

public struct AppleFoundationProvider: LLMProvider {
    public let id: LLMProviderID = .apple
    public let displayName = "Apple"

    public init() {}

    public var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    public var availabilityMessage: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Ready"
        case .unavailable(.deviceNotEligible):
            return "This Mac is not eligible for Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in System Settings."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence model is still downloading or not ready."
        case .unavailable:
            return "Apple Intelligence is unavailable."
        }
    }

    public func transform(transcript: String, instructions: String) async throws -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LLMProviderError.emptyTranscript }

        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw LLMProviderError.unavailable(availabilityMessage)
        }

        let session = LanguageModelSession(
            model: model,
            instructions: instructions
        )
        let prompt = """
        Transcript:
        \(trimmed)
        """
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
