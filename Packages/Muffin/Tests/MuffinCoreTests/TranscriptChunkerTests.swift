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
