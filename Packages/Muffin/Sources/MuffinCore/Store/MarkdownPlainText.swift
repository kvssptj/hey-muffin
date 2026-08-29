import Foundation

/// Strips common markdown syntax for plain-text export.
public enum MarkdownPlainText {
    public static func convert(_ markdown: String) -> String {
        var lines: [String] = []
        var inFence = false
        for raw in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(raw)
            if line.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence { continue }

            while let range = line.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                line.removeSubrange(range)
            }
            while let range = line.range(of: #"^[\*\-+]\s+"#, options: .regularExpression) {
                line.removeSubrange(range)
            }
            while let range = line.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                line.removeSubrange(range)
            }
            while let range = line.range(of: #"^>\s?"#, options: .regularExpression) {
                line.removeSubrange(range)
            }

            line = line.replacingOccurrences(of: #"!\[([^\]]*)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
            line = line.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
            line = line.replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
            line = line.replacingOccurrences(of: #"(\*\*|__)(.*?)\1"#, with: "$2", options: .regularExpression)
            line = line.replacingOccurrences(of: #"(\*|_)(.*?)\1"#, with: "$2", options: .regularExpression)
            lines.append(line)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
