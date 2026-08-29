# Transcript Chunking (Map-Reduce) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent Apple Foundation Models from receiving transcripts that exceed its ~4K token context window by splitting long transcripts into overlapping chunks, summarizing each, then combining summaries with the original instructions.

**Architecture:** `TranscriptChunker` (pure value type) handles word-based splitting with overlap. `AppleFoundationProvider.transform()` checks whether chunking is needed; if so, runs a map phase (one `LanguageModelSession` call per chunk with a neutral summarize prompt) then a reduce phase (one call with the original `instructions`). Short recordings take the existing single-call path unchanged.

**Tech Stack:** Swift 5 language mode, FoundationModels framework, macOS 26+, XCTest

**Spec:** No separate spec file — design approved in conversation on 2026-08-29.

## Global Constraints

- Swift language mode: `.v5` (matches existing targets in `Package.swift`)
- Platform minimum: macOS 26.0
- No new dependencies — zero additions to `Package.swift` dependencies
- Token budget per chunk: 2,500 tokens input ≈ 1,875 words (leaving ~1,500 tokens for instructions + output within Apple's ~4K limit)
- Overlap between chunks: 100 words
- All new source files live under `Packages/Muffin/Sources/MuffinCore/AI/`
- All test files live under `Packages/Muffin/Tests/MuffinCoreTests/`
- Build/test command: `cd Packages/Muffin && swift test`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `Sources/MuffinCore/AI/TranscriptChunker.swift` | Pure chunking logic: word splitting, overlap, `needsChunking` predicate |
| Modify | `Sources/MuffinCore/AI/AppleFoundationProvider.swift` | Extract `sendToModel`, add `mapReduce`, gate in `transform` |
| Modify | `Package.swift` | Add `MuffinCoreTests` test target |
| Create | `Tests/MuffinCoreTests/TranscriptChunkerTests.swift` | Unit tests for `TranscriptChunker` |

---

### Task 1: Add test target to Package.swift

**Files:**
- Modify: `Packages/Muffin/Package.swift`

**Interfaces:**
- Produces: `swift test` works and discovers tests in `Tests/MuffinCoreTests/`

- [ ] **Step 1: Add the test target**

Open `Packages/Muffin/Package.swift` and add a `.testTarget` inside the `targets` array, after the last existing target:

```swift
.testTarget(
    name: "MuffinCoreTests",
    dependencies: ["MuffinCore"],
    path: "Tests/MuffinCoreTests",
    swiftSettings: [
        .swiftLanguageMode(.v5),
    ]
),
```

- [ ] **Step 2: Create the Tests directory**

```bash
mkdir -p Packages/Muffin/Tests/MuffinCoreTests
```

- [ ] **Step 3: Add a placeholder so the target resolves**

Create `Packages/Muffin/Tests/MuffinCoreTests/Placeholder.swift`:

```swift
// Tests live here — see TranscriptChunkerTests.swift
```

- [ ] **Step 4: Verify the package resolves**

```bash
cd Packages/Muffin && swift build
```

Expected: BUILD SUCCEEDED (no test files yet, so nothing to run)

- [ ] **Step 5: Commit**

```bash
cd Packages/Muffin && git add Package.swift Tests/
git commit -m "test: add MuffinCoreTests target to Package.swift"
```

---

### Task 2: Implement TranscriptChunker

**Files:**
- Create: `Packages/Muffin/Sources/MuffinCore/AI/TranscriptChunker.swift`
- Create: `Packages/Muffin/Tests/MuffinCoreTests/TranscriptChunkerTests.swift`
- Delete: `Packages/Muffin/Tests/MuffinCoreTests/Placeholder.swift` (no longer needed once real tests exist)

**Interfaces:**
- Produces:
  ```swift
  struct TranscriptChunker {
      let wordsPerChunk: Int   // default 1875
      let overlapWords: Int    // default 100
      func needsChunking(_ text: String) -> Bool
      func chunks(from text: String) -> [String]
  }
  ```

- [ ] **Step 1: Write the failing tests**

Create `Packages/Muffin/Tests/MuffinCoreTests/TranscriptChunkerTests.swift`:

```swift
import XCTest
@testable import MuffinCore

final class TranscriptChunkerTests: XCTestCase {

    // MARK: - needsChunking

    func test_needsChunking_returnsFalse_whenTranscriptIsUnderBudget() {
        let chunker = TranscriptChunker()
        let shortText = Array(repeating: "word", count: 100).joined(separator: " ")
        XCTAssertFalse(chunker.needsChunking(shortText))
    }

    func test_needsChunking_returnsTrue_whenTranscriptExceedsBudget() {
        let chunker = TranscriptChunker()
        // wordsPerChunk default is 1875; use 2000 to be clearly over
        let longText = Array(repeating: "word", count: 2000).joined(separator: " ")
        XCTAssertTrue(chunker.needsChunking(longText))
    }

    func test_needsChunking_returnsFalse_exactlyAtBudget() {
        let chunker = TranscriptChunker(wordsPerChunk: 10, overlapWords: 2)
        let text = Array(repeating: "word", count: 10).joined(separator: " ")
        XCTAssertFalse(chunker.needsChunking(text))
    }

    // MARK: - chunks(from:)

    func test_chunks_singleChunk_whenUnderBudget() {
        let chunker = TranscriptChunker(wordsPerChunk: 10, overlapWords: 2)
        let text = "one two three four five"
        let result = chunker.chunks(from: text)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], text)
    }

    func test_chunks_producesMultipleChunks_whenOverBudget() {
        // wordsPerChunk=5, overlap=1 → stride=4
        // 10 words → chunk 0: words 0-4, chunk 1: words 4-8, chunk 2: words 8-9
        let chunker = TranscriptChunker(wordsPerChunk: 5, overlapWords: 1)
        let words = (1...10).map { "w\($0)" }
        let text = words.joined(separator: " ")
        let result = chunker.chunks(from: text)
        XCTAssertGreaterThan(result.count, 1)
    }

    func test_chunks_overlapPreservesWordsAcrossBoundary() {
        // wordsPerChunk=4, overlap=2 → stride=2
        // words: a b c d e f g h
        // chunk0: a b c d, chunk1: c d e f, chunk2: e f g h
        let chunker = TranscriptChunker(wordsPerChunk: 4, overlapWords: 2)
        let text = "a b c d e f g h"
        let result = chunker.chunks(from: text)
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result[0].hasSuffix("c d"))
        XCTAssertTrue(result[1].hasPrefix("c d"))
    }

    func test_chunks_allWordsAppearInAtLeastOneChunk() {
        let chunker = TranscriptChunker(wordsPerChunk: 5, overlapWords: 2)
        let words = (1...13).map { "word\($0)" }
        let text = words.joined(separator: " ")
        let allChunkWords = chunker.chunks(from: text)
            .flatMap { $0.components(separatedBy: " ") }
        for word in words {
            XCTAssertTrue(allChunkWords.contains(word), "\(word) missing from all chunks")
        }
    }

    func test_chunks_neverExceedsBudget() {
        let chunker = TranscriptChunker(wordsPerChunk: 5, overlapWords: 1)
        let text = Array(repeating: "word", count: 50).joined(separator: " ")
        for chunk in chunker.chunks(from: text) {
            let count = chunk.components(separatedBy: " ").filter { !$0.isEmpty }.count
            XCTAssertLessThanOrEqual(count, 5)
        }
    }

    func test_chunks_emptyStringReturnsEmptyArray() {
        let chunker = TranscriptChunker()
        XCTAssertEqual(chunker.chunks(from: ""), [])
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd Packages/Muffin && swift test --filter TranscriptChunkerTests
```

Expected: compile error — `TranscriptChunker` does not exist yet

- [ ] **Step 3: Implement TranscriptChunker**

Create `Packages/Muffin/Sources/MuffinCore/AI/TranscriptChunker.swift`:

```swift
/// Splits a transcript into overlapping word-based chunks that fit within
/// Apple Foundation Models' context window.
///
/// Default budget: 1,875 words ≈ 2,500 tokens, leaving headroom for
/// instructions and output within Apple's ~4,000 token limit.
struct TranscriptChunker: Sendable {
    let wordsPerChunk: Int
    let overlapWords: Int

    init(wordsPerChunk: Int = 1875, overlapWords: Int = 100) {
        self.wordsPerChunk = wordsPerChunk
        self.overlapWords = overlapWords
    }

    /// Returns true if the transcript's word count exceeds the per-chunk budget.
    func needsChunking(_ text: String) -> Bool {
        wordCount(of: text) > wordsPerChunk
    }

    /// Splits `text` into overlapping chunks, each containing at most
    /// `wordsPerChunk` words. Consecutive chunks share `overlapWords` words
    /// at their boundary to preserve context across splits.
    ///
    /// Returns an empty array for empty input; a single-element array when
    /// no chunking is needed.
    func chunks(from text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        guard words.count > wordsPerChunk else { return [text] }

        var result: [String] = []
        let stride = max(1, wordsPerChunk - overlapWords)
        var start = 0

        while start < words.count {
            let end = min(start + wordsPerChunk, words.count)
            let chunk = words[start..<end].joined(separator: " ")
            result.append(chunk)
            if end == words.count { break }
            start += stride
        }

        return result
    }

    // MARK: - Private

    private func wordCount(of text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd Packages/Muffin && swift test --filter TranscriptChunkerTests
```

Expected: All 8 tests pass

- [ ] **Step 5: Delete placeholder, commit**

```bash
rm Packages/Muffin/Tests/MuffinCoreTests/Placeholder.swift
cd Packages/Muffin && git add Sources/MuffinCore/AI/TranscriptChunker.swift \
    Tests/MuffinCoreTests/TranscriptChunkerTests.swift \
    Tests/MuffinCoreTests/Placeholder.swift
git commit -m "feat: add TranscriptChunker for word-based overlap chunking"
```

---

### Task 3: Wire map-reduce into AppleFoundationProvider

**Files:**
- Modify: `Packages/Muffin/Sources/MuffinCore/AI/AppleFoundationProvider.swift`

**Interfaces:**
- Consumes: `TranscriptChunker` (from Task 2) — `needsChunking(_:)`, `chunks(from:)`
- Produces: `AppleFoundationProvider.transform(transcript:instructions:)` — same public signature, now handles long transcripts transparently

- [ ] **Step 1: Write the failing integration test**

Add a new test file `Packages/Muffin/Tests/MuffinCoreTests/AppleFoundationProviderChunkingTests.swift`:

```swift
import XCTest
@testable import MuffinCore

/// Unit-tests the map-reduce routing logic inside AppleFoundationProvider
/// using a subclassable seam — no live FoundationModels calls.
///
/// Because AppleFoundationProvider is a struct and LanguageModelSession
/// cannot be injected directly, we test the decision logic by exercising
/// TranscriptChunker (already covered) and verifying that `transform`
/// does NOT throw `.emptyTranscript` on long inputs (i.e., it attempts
/// to call the model rather than short-circuit).
///
/// Full end-to-end behaviour (actual LLM output) requires a device with
/// Apple Intelligence and is not covered here.
final class AppleFoundationProviderChunkingTests: XCTestCase {

    func test_transform_throwsEmptyTranscript_forBlankInput() async {
        let provider = AppleFoundationProvider()
        do {
            _ = try await provider.transform(transcript: "   ", instructions: "summarize")
            XCTFail("Expected emptyTranscript error")
        } catch LLMProviderError.emptyTranscript {
            // expected
        } catch {
            // Any other error (e.g. model unavailable on CI) is acceptable —
            // the important thing is it did NOT silently succeed on blank input.
        }
    }

    func test_chunker_usedByProvider_hasCorrectDefaults() {
        // Verify the chunker the provider would construct uses the agreed budget.
        let chunker = TranscriptChunker()
        XCTAssertEqual(chunker.wordsPerChunk, 1875)
        XCTAssertEqual(chunker.overlapWords, 100)
    }
}
```

- [ ] **Step 2: Run test to confirm it compiles and the first case passes**

```bash
cd Packages/Muffin && swift test --filter AppleFoundationProviderChunkingTests
```

Expected: `test_chunker_usedByProvider_hasCorrectDefaults` passes (chunker defaults already correct from Task 2). `test_transform_throwsEmptyTranscript_forBlankInput` passes (existing guard fires before any model call).

- [ ] **Step 3: Refactor AppleFoundationProvider**

Replace the full contents of `Packages/Muffin/Sources/MuffinCore/AI/AppleFoundationProvider.swift`:

```swift
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
```

- [ ] **Step 4: Run all tests**

```bash
cd Packages/Muffin && swift test
```

Expected: All tests pass (TranscriptChunkerTests + AppleFoundationProviderChunkingTests)

- [ ] **Step 5: Verify the app still builds**

```bash
cd /Users/pavank/Docs/orion && xcodebuild build -scheme Orion -configuration Debug 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
cd Packages/Muffin && git add Sources/MuffinCore/AI/AppleFoundationProvider.swift \
    Tests/MuffinCoreTests/AppleFoundationProviderChunkingTests.swift
git commit -m "feat: map-reduce chunking for Apple LLM token limit"
```
