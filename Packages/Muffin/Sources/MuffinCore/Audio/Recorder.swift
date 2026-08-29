import AVFoundation
import Foundation

/// Captures microphone audio, optionally writes CAF, and yields PCM for transcription.
public final class Recorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private let writeQueue = DispatchQueue(label: "com.muffin.recorder.write")
    private var converter: AVAudioConverter?
    private var isRunning = false
    private var isPaused = false
    private var tapInstalled = false
    private var audioFile: AVAudioFile?

    public enum RecorderError: LocalizedError, Sendable {
        case noInput
        case conversionFailed
        case permissionDenied
        case engineStartFailed(String)
        case fileWriteFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noInput: "No microphone input is available."
            case .conversionFailed: "Could not convert microphone audio."
            case .permissionDenied: "Microphone access was denied."
            case .engineStartFailed(let detail): "Could not start microphone: \(detail)"
            case .fileWriteFailed(let detail): "Could not write audio file: \(detail)"
            }
        }
    }

    public init() {}

    public static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    public var paused: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isPaused
    }

    public func start(
        targetFormat: AVAudioFormat,
        fileURL: URL?,
        onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        if isRunning {
            stopLocked()
        }

        let input = engine.inputNode
        // Hardware format delivered by the input node tap.
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.noInput
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecorderError.conversionFailed
        }
        self.converter = converter

        if let fileURL {
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                // Persist mic PCM as-delivered — matches tap buffers; avoids ExtAudioFile converter abort.
                audioFile = try AVAudioFile(
                    forWriting: fileURL,
                    settings: inputFormat.settings,
                    commonFormat: inputFormat.commonFormat,
                    interleaved: inputFormat.isInterleaved
                )
            } catch {
                throw RecorderError.fileWriteFailed(error.localizedDescription)
            }
        } else {
            audioFile = nil
        }

        isPaused = false

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.lock.lock()
            let paused = self.isPaused
            let converter = self.converter
            self.lock.unlock()

            guard !paused, let converter else { return }

            // Copy for async disk write — never call AVAudioFile.write on the realtime tap thread.
            if let fileCopy = Self.copyBuffer(buffer) {
                self.writeQueue.async { [weak self] in
                    guard let self else { return }
                    self.lock.lock()
                    let file = self.audioFile
                    self.lock.unlock()
                    guard let file else { return }
                    do {
                        try file.write(from: fileCopy)
                    } catch {
                        // Non-fatal: keep capturing for transcription.
                    }
                }
            }

            let ratio = targetFormat.sampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
            guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: max(capacity, 1)) else {
                return
            }

            var error: NSError?
            var consumed = false
            let status = converter.convert(to: converted, error: &error) { _, outStatus in
                if consumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                consumed = true
                outStatus.pointee = .haveData
                return buffer
            }

            if status != .error, error == nil, converted.frameLength > 0 {
                onBuffer(converted)
            }
        }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            stopLocked()
            throw RecorderError.engineStartFailed(error.localizedDescription)
        }
        isRunning = true
    }

    public func setPaused(_ paused: Bool) {
        lock.lock()
        isPaused = paused
        lock.unlock()
    }

    public func stop() {
        // Finish pending writes before tearing down the file.
        writeQueue.sync {
            lock.lock()
            audioFile = nil
            lock.unlock()
        }
        lock.lock()
        defer { lock.unlock() }
        stopLocked(closingFile: false)
    }

    private func stopLocked(closingFile: Bool = true) {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning {
            engine.stop()
        }
        converter = nil
        if closingFile {
            audioFile = nil
        }
        isRunning = false
        isPaused = false
    }

    private static func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            return nil
        }
        copy.frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        if buffer.format.isInterleaved {
            if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
                memcpy(dst[0], src[0], Int(buffer.frameLength) * channels * MemoryLayout<Float>.size)
            } else if let src = buffer.int16ChannelData, let dst = copy.int16ChannelData {
                memcpy(dst[0], src[0], Int(buffer.frameLength) * channels * MemoryLayout<Int16>.size)
            } else if let src = buffer.int32ChannelData, let dst = copy.int32ChannelData {
                memcpy(dst[0], src[0], Int(buffer.frameLength) * channels * MemoryLayout<Int32>.size)
            }
        } else {
            for ch in 0..<channels {
                if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
                    memcpy(dst[ch], src[ch], Int(buffer.frameLength) * MemoryLayout<Float>.size)
                } else if let src = buffer.int16ChannelData, let dst = copy.int16ChannelData {
                    memcpy(dst[ch], src[ch], Int(buffer.frameLength) * MemoryLayout<Int16>.size)
                } else if let src = buffer.int32ChannelData, let dst = copy.int32ChannelData {
                    memcpy(dst[ch], src[ch], Int(buffer.frameLength) * MemoryLayout<Int32>.size)
                }
            }
        }
        return copy
    }
}
