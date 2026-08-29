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

        let chunker = TranscriptChunker()
        if chunker.needsChunking(trimmed) {
            return try await mapReduce(transcript: trimmed, instructions: instructions, chunker: chunker)
        } else {
            return try await sendToModel(prompt: trimmed, instructions: instructions)
        }
    }

    // MARK: - Private

    /// Map phase: summarize each chunk independently.
    /// Reduce phase: apply the caller's original `instructions` to the joined summaries.
    private func mapReduce(
        transcript: String,
        instructions: String,
        chunker: TranscriptChunker
    ) async throws -> String {
        let chunks = chunker.chunks(from: transcript)
        let total = chunks.count

        // Map
        var summaries: [String] = []
        for (index, chunk) in chunks.enumerated() {
            let mapInstructions = """
            You are summarizing part \(index + 1) of \(total) of a longer transcript. \
            Extract and preserve the key points, decisions, and names mentioned. Be concise.
            """
            let summary = try await sendToModel(prompt: chunk, instructions: mapInstructions)
            summaries.append(summary)
        }

        // Reduce
        let combined = summaries.enumerated()
            .map { "Part \($0.offset + 1) of \(total):\n\($0.element)" }
            .joined(separator: "\n\n")
        return try await sendToModel(prompt: combined, instructions: instructions)
    }

    private func sendToModel(prompt: String, instructions: String) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw LLMProviderError.unavailable(availabilityMessage)
        }
        let session = LanguageModelSession(model: model, instructions: instructions)
        let response = try await session.respond(to: "Transcript:\n\(prompt)")
        return response.content
    }
}
