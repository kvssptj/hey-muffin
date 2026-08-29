import AVFoundation
import Foundation
import Speech

/// Live on-device transcription via SpeechAnalyzer + SpeechTranscriber.
@MainActor
public final class Transcriber {
    public enum TranscriberError: LocalizedError, Sendable {
        case unavailable
        case unsupportedLocale
        case noAudioFormat
        case notPrepared

        public var errorDescription: String? {
            switch self {
            case .unavailable: "On-device speech isn’t available on this Mac."
            case .unsupportedLocale: "Your system language isn’t supported for SpeechAnalyzer. Switch language in System Settings or try again later."
            case .noAudioFormat: "Couldn’t find a mic format SpeechAnalyzer accepts. Check the input device and try again."
            case .notPrepared: "Speech isn’t ready yet. Wait a second and try Start recording again."
            }
        }
    }

    public private(set) var statusMessage = "Checking speech…"
    public private(set) var isReady = false

    private var locale: Locale?
    private var analyzer: SpeechAnalyzer?
    private var speechTranscriber: SpeechTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var warmedFormat: AVAudioFormat?
    private var isWarmed = false
    private var rewarmTask: Task<Void, Never>?

    public init() {}

    public func prepare() async {
        guard SpeechTranscriber.isAvailable else {
            statusMessage = TranscriberError.unavailable.localizedDescription
            isReady = false
            return
        }

        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: .current) else {
            statusMessage = TranscriberError.unsupportedLocale.localizedDescription
            isReady = false
            return
        }

        locale = supported

        do {
            let probe = SpeechTranscriber(
                locale: supported,
                transcriptionOptions: [.etiquetteReplacements],
                reportingOptions: [.volatileResults],
                attributeOptions: [.audioTimeRange, .transcriptionConfidence]
            )
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
                statusMessage = "Downloading speech model…"
                try await request.downloadAndInstall()
            }
            statusMessage = "Speech ready (\(supported.identifier))"
            isReady = true
            try await warmAnalyzer()
        } catch {
            statusMessage = error.localizedDescription
            isReady = false
        }
    }

    public func start(
        onTranscript: @escaping @MainActor (String, AttributedString) -> Void
    ) async throws -> AVAudioFormat {
        guard isReady, locale != nil else { throw TranscriberError.notPrepared }

        rewarmTask?.cancel()
        rewarmTask = nil

        if !isWarmed {
            try await warmAnalyzer()
        }

        guard let format = warmedFormat, let transcriber = speechTranscriber, let analyzer else {
            throw TranscriberError.noAudioFormat
        }

        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        inputBuilder = continuation

        var finalized = ""
        var finalizedAttributed = AttributedString()
        var volatile = ""
        var volatileAttributed = AttributedString()

        resultsTask = Task { @MainActor in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let attributed = AttributedString(result.text)
                    if result.isFinal {
                        if !text.isEmpty {
                            let separator = finalized.isEmpty ? AttributedString() : AttributedString(" ")
                            finalized = finalized.isEmpty ? text : finalized + " " + text
                            finalizedAttributed = finalizedAttributed + separator + attributed
                        }
                        volatile = ""
                        volatileAttributed = AttributedString()
                        onTranscript(finalized, finalizedAttributed)
                    } else {
                        volatile = text
                        volatileAttributed = attributed
                        if volatile.isEmpty {
                            onTranscript(finalized, finalizedAttributed)
                        } else if finalized.isEmpty {
                            onTranscript(volatile, volatileAttributed)
                        } else {
                            onTranscript(
                                finalized + " " + volatile,
                                finalizedAttributed + AttributedString(" ") + volatileAttributed
                            )
                        }
                    }
                }
            } catch is CancellationError {
            } catch {
                statusMessage = error.localizedDescription
            }
        }

        analysisTask = Task {
            do {
                try await analyzer.start(inputSequence: stream)
            } catch is CancellationError {
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                }
            }
        }

        isWarmed = false
        statusMessage = "Listening…"
        return format
    }

    public func append(_ buffer: AVAudioPCMBuffer) {
        inputBuilder?.yield(AnalyzerInput(buffer: buffer))
    }

    public func stop() async {
        inputBuilder?.finish()
        inputBuilder = nil

        if let analyzer {
            do {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
            } catch {
                await analyzer.cancelAndFinishNow()
            }
        }

        analysisTask?.cancel()
        resultsTask?.cancel()
        analysisTask = nil
        resultsTask = nil
        analyzer = nil
        speechTranscriber = nil
        warmedFormat = nil
        isWarmed = false
        statusMessage = isReady ? "Speech ready" : statusMessage

        rewarmTask?.cancel()
        rewarmTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, isReady else { return }
            try? await warmAnalyzer()
        }
    }

    private func warmAnalyzer() async throws {
        guard isReady, let locale else { throw TranscriberError.notPrepared }

        await tearDownWarmState()

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [.etiquetteReplacements],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange, .transcriptionConfidence]
        )
        speechTranscriber = transcriber

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriberError.noAudioFormat
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        try await analyzer.prepareToAnalyze(in: format)
        warmedFormat = format
        isWarmed = true
    }

    private func tearDownWarmState() async {
        inputBuilder?.finish()
        inputBuilder = nil
        analysisTask?.cancel()
        resultsTask?.cancel()
        analysisTask = nil
        resultsTask = nil
        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }
        analyzer = nil
        speechTranscriber = nil
        warmedFormat = nil
        isWarmed = false
    }
}
