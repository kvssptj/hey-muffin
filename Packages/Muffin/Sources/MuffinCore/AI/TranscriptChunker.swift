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
