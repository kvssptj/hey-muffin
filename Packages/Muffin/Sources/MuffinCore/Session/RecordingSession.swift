import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class RecordingSession {
    public let store: RecordingStore
    public let llmRouter = LLMRouter()
    public let templateStore = TemplateStore()
    public var selectedOutputTemplate: OutputTemplate = OutputTemplate.builtIns[0]
    private let recorder = Recorder()
    private let transcriber = Transcriber()

    public var recordings: [Recording] = []
    public var activeRecordingID: UUID?
    public var transcript = ""
    public var attributedTranscript = AttributedString()
    public var output = ""
    public var selectedTemplate: NoteTemplate = .summary
    public var customInstructions = ""
    public var isRecording = false
    public var isPaused = false
    public var isPreparingSpeech = false
    public var isGenerating = false
    public var elapsedSeconds: TimeInterval = 0
    public var statusMessage = "Checking speech…"
    public var errorMessage: String?
    public var speechReady = false

    private var timerTask: Task<Void, Never>?
    private var autosaveTask: Task<Void, Never>?
    private var recordStartedAt: Date?
    private var accumulatedPause: TimeInterval = 0
    private var pauseStartedAt: Date?
    private var activeMarkers: [RecordingMarker] = []

    public var canGenerate: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRecording && !isGenerating
    }

    public var canToggleRecording: Bool {
        // Generation runs in the background and must not block a new take.
        !isPreparingSpeech
    }

    public var elapsedLabel: String {
        let total = Int(elapsedSeconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    public var effectiveInstructions: String {
        if selectedTemplate == .custom {
            let custom = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
            if custom.isEmpty { return NoteTemplate.custom.instructions }
            return custom
        }
        return selectedTemplate.instructions
    }

    public init(store: RecordingStore? = nil) {
        do {
            self.store = try store ?? RecordingStore()
        } catch {
            self.store = try! RecordingStore(rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("Muffin-Fallback-Recordings", isDirectory: true))
            self.errorMessage = "Could not open Application Support/Muffin. Using a temporary folder for this session: \(error.localizedDescription)"
        }
        selectedOutputTemplate = templateStore.defaultTemplate
    }

    public func bootstrap() async {
        isPreparingSpeech = true
        defer { isPreparingSpeech = false }

        refreshRecordings()

        let micOK = await Recorder.requestPermission()
        if !micOK {
            statusMessage = "Mic access denied"
            errorMessage = "Grant microphone access in System Settings → Privacy & Security → Microphone, then relaunch Muffin."
            speechReady = false
            return
        }

        statusMessage = "Preparing SpeechAnalyzer…"
        await transcriber.prepare()
        speechReady = transcriber.isReady
        statusMessage = speechReady ? "Speech ready" : transcriber.statusMessage
        if !speechReady {
            errorMessage = "\(transcriber.statusMessage) Fix the language/model issue, then reopen Record."
        }
    }

    public func cancelRecording() async {
        guard isRecording || isPreparingSpeech else { return }
        recorder.stop()
        await transcriber.stop()
        stopTimer()
        isRecording = false
        isPaused = false
        isPreparingSpeech = false
        speechReady = transcriber.isReady
        let cancelledID = activeRecordingID
        activeRecordingID = nil
        transcript = ""
        attributedTranscript = AttributedString()
        output = ""
        elapsedSeconds = 0
        errorMessage = nil
        statusMessage = "Recording cancelled"
        if let id = cancelledID {
            try? store.delete(id: id)
        }
        refreshRecordings()
    }

    public func deleteRecording(id: UUID) {
        do {
            try store.delete(id: id)
            if activeRecordingID == id {
                activeRecordingID = nil
                transcript = ""
                attributedTranscript = AttributedString()
                output = ""
                elapsedSeconds = 0
            }
            refreshRecordings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func resetCompletionState() {
        guard !isRecording, !isPreparingSpeech else { return }
        activeRecordingID = nil
        transcript = ""
        attributedTranscript = AttributedString()
        output = ""
        errorMessage = nil
        elapsedSeconds = 0
    }

    public func refreshRecordings() {
        do {
            recordings = try store.list()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadRecording(id: UUID) {
        do {
            let recording = try store.recording(id: id)
            activeRecordingID = id
            transcript = try store.readTranscript(id: id)
            attributedTranscript = AttributedString(transcript)
            output = (try? store.readOutput(id: id, outputFileName: selectedOutputTemplate.outputFileName)) ?? ""
            elapsedSeconds = recording.meta.duration
            statusMessage = "Loaded \(recording.meta.title)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func toggleRecording() {
        guard canToggleRecording else { return }
        if isRecording {
            Task { await stopRecording() }
        } else {
            Task { await startRecording() }
        }
    }

    public func startRecording() async {
        errorMessage = nil
        guard !isRecording else { return }

        isPreparingSpeech = true
        statusMessage = "Starting mic & speech…"

        defer {
            if !isRecording { isPreparingSpeech = false }
        }

        if !speechReady {
            statusMessage = "Preparing SpeechAnalyzer…"
            await transcriber.prepare()
            speechReady = transcriber.isReady
            statusMessage = speechReady ? "Speech ready" : transcriber.statusMessage
            guard speechReady else {
                errorMessage = "\(transcriber.statusMessage) Can’t record until speech is ready."
                return
            }
        }

        do {
            let recording = try store.create()
            activeRecordingID = recording.id
            activeMarkers = []
            transcript = ""
            output = ""
            accumulatedPause = 0
            pauseStartedAt = nil
            isPaused = false

            let format = try await transcriber.start { [weak self] text, attributed in
                guard let self else { return }
                self.transcript = text
                self.attributedTranscript = attributed
                self.scheduleAutosave()
            }

            try recorder.start(targetFormat: format, fileURL: recording.audioURL) { [weak self] buffer in
                // Audio tap → MainActor; buffer is consumed immediately by SpeechAnalyzer.
                let retained = buffer
                Task { @MainActor in
                    self?.transcriber.append(retained)
                }
            }

            isRecording = true
            isPreparingSpeech = false
            recordStartedAt = Date()
            elapsedSeconds = 0
            statusMessage = "Recording"
            RecordingChime.playStart()
            refreshRecordings()
            startTimer()
        } catch {
            recorder.stop()
            await transcriber.stop()
            isRecording = false
            isPreparingSpeech = false
            errorMessage = "Couldn’t start capture: \(error.localizedDescription)"
            statusMessage = speechReady ? "Speech ready" : "Not ready"
        }
    }

    public func pauseRecording() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        pauseStartedAt = Date()
        recorder.setPaused(true)
        statusMessage = "Paused"
    }

    public func resumeRecording() {
        guard isRecording, isPaused else { return }
        if let pauseStartedAt {
            accumulatedPause += Date().timeIntervalSince(pauseStartedAt)
        }
        pauseStartedAt = nil
        isPaused = false
        recorder.setPaused(false)
        statusMessage = "Recording"
    }

    public func togglePause() {
        if isPaused { resumeRecording() } else { pauseRecording() }
    }

    public func addMarker(label: String = "Marker") {
        guard isRecording else { return }
        let marker = RecordingMarker(seconds: elapsedSeconds, label: label)
        activeMarkers.append(marker)
        statusMessage = "Marker at \(timeString(elapsedSeconds))"
        persistActiveMeta(duration: elapsedSeconds)
    }

    public func stopRecording() async {
        guard isRecording else { return }
        recorder.stop()
        await transcriber.stop()
        stopTimer()
        isRecording = false
        isPaused = false
        speechReady = transcriber.isReady

        if let id = activeRecordingID {
            do {
                try store.writeTranscript(id: id, text: transcript)
                var meta = try store.recording(id: id).meta
                meta.duration = elapsedSeconds
                meta.markers = activeMarkers
                if transcript.count > 40 {
                    let preview = String(transcript.prefix(48)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !preview.isEmpty { meta.title = preview + (transcript.count > 48 ? "…" : "") }
                }
                try store.updateMeta(meta)
                refreshRecordings()
            } catch {
                errorMessage = "Recording stopped, but disk write failed: \(error.localizedDescription)"
            }
        }

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(transcript, forType: .string)
            statusMessage = "Saved and copied to clipboard"
        } else {
            statusMessage = "Saved to disk (transcript was empty)"
        }
        RecordingChime.playStop()
    }

    /// Debounced write of the in-memory transcript to disk (~800ms).
    public func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await saveTranscriptNow()
        }
    }

    public func saveTranscriptNow() async {
        guard let id = activeRecordingID else { return }
        do {
            try store.writeTranscript(id: id, text: transcript)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateTranscript(_ text: String) {
        transcript = text
        scheduleAutosave()
    }

    public func exportPlainText() throws -> URL {
        guard let id = activeRecordingID else {
            throw RecordingStoreError.io("No recording selected. Open one from Library or finish a take first.")
        }
        try store.writeTranscript(id: id, text: transcript)
        return try store.exportPlainText(id: id)
    }

    public func revealInFinder(item: RevealItem = .folder) throws {
        guard let id = activeRecordingID else {
            throw RecordingStoreError.io("No recording selected. Open one from Library or finish a take first.")
        }
        try store.revealInFinder(id: id, item: item)
    }

    public func generate() async {
        errorMessage = nil
        guard canGenerate else { return }
        guard let id = activeRecordingID else {
            errorMessage = "Open a recording from Library (or finish a take) before generating."
            return
        }

        isGenerating = true
        statusMessage = "Generating with \(llmRouter.selectedProvider.displayName)…"
        defer { isGenerating = false }

        do {
            let latest = try store.readTranscript(id: id)
            let source = latest.isEmpty ? transcript : latest
            // Keep in-memory transcript in sync only while this take is still active.
            if activeRecordingID == id, !latest.isEmpty {
                transcript = latest
            }

            let result = try await llmRouter.transform(
                transcript: source,
                instructions: selectedOutputTemplate.prompt
            )
            try store.writeOutput(id: id, outputFileName: selectedOutputTemplate.outputFileName, text: result)
            if activeRecordingID == id {
                output = result
                statusMessage = "Wrote outputs/\(selectedOutputTemplate.outputFileName).md"
            }
        } catch {
            // Don't clobber a newer take's errors if the user already moved on.
            if activeRecordingID == id {
                errorMessage = "Generate failed: \(error.localizedDescription)"
                statusMessage = "Ready"
            }
        }
    }

    public func generate(id: UUID, template: NoteTemplate) async throws -> String {
        let text = try store.readTranscript(id: id)
        let instructions = template.instructions
        let result = try await llmRouter.transform(transcript: text, instructions: instructions)
        try store.writeOutput(id: id, template: template, text: result)
        return result
    }

    public func copyOutput() {
        guard !output.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        statusMessage = "Copied to clipboard"
    }

    public func selectTemplate(_ template: NoteTemplate) {
        selectedTemplate = template
        if let id = activeRecordingID {
            output = (try? store.readOutput(id: id, template: template)) ?? output
        }
    }

    public func selectOutputTemplate(_ template: OutputTemplate) {
        selectedOutputTemplate = template
        if let id = activeRecordingID {
            output = (try? store.readOutput(id: id, outputFileName: template.outputFileName)) ?? ""
        }
    }

    private func persistActiveMeta(duration: TimeInterval) {
        guard let id = activeRecordingID else { return }
        do {
            var meta = try store.recording(id: id).meta
            meta.duration = duration
            meta.markers = activeMarkers
            try store.updateMeta(meta)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                if let started = recordStartedAt {
                    var pauseExtra = accumulatedPause
                    if let pauseStartedAt, isPaused {
                        pauseExtra += Date().timeIntervalSince(pauseStartedAt)
                    }
                    elapsedSeconds = max(0, Date().timeIntervalSince(started) - pauseExtra)
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
