import MuffinCore
import SwiftUI

/// SwiftUI port of Magic Patterns Orion `SummaryDocument`.
/// Paper surface with serif title, engraved rules, diamond section markers (olive = insight, sky = commitment).
struct SummaryDocumentView: View {
    var title: String
    var meta: String? = nil
    var summary: String? = nil
    var keyPoints: [String] = []
    var decisions: [String] = []
    var actionItems: [SummaryActionItem] = []
    var aiLabel: String = "AI generated"
    var hideAIIndicator: Bool = false
    var isLoading: Bool = false
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            OrionEngravedRule()
                .padding(.top, 18)

            Group {
                if let error {
                    errorBanner(error)
                        .padding(.top, 22)
                } else if isLoading {
                    skeleton
                        .padding(.top, 26)
                } else {
                    bodyContent
                        .padding(.top, 26)
                }
            }

            OrionEngravedRule()
                .padding(.top, 32)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .frame(maxWidth: 720, alignment: .leading)
        .background(OrionColor.surfacePaper)
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(Color(hex: 0xDFE2E6), lineWidth: 1)
        )
        .shadow(color: OrionColor.textInk.opacity(0.06), radius: 1, y: 1)
        .shadow(color: OrionColor.textInk.opacity(0.12), radius: 16, y: 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(Color(hex: 0x1E232A))
                    .tracking(-0.3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if !hideAIIndicator {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .regular))
                        Text(aiLabel.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1.4)
                    }
                    .foregroundStyle(OrionColor.textMuted)
                    .padding(.top, 6)
                }
            }

            if let meta, !meta.isEmpty {
                Text(meta)
                    .font(.system(size: 12.5))
                    .tracking(0.3)
                    .foregroundStyle(OrionColor.textMuted)
            }
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        let hasContent = !(summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || !keyPoints.isEmpty
            || !decisions.isEmpty
            || !actionItems.isEmpty

        if !hasContent {
            Text("No summary content yet.")
                .font(.system(size: 15))
                .italic()
                .foregroundStyle(OrionColor.textMuted)
        } else {
            VStack(alignment: .leading, spacing: 28) {
                if let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    section(title: "Summary", accent: .olive) {
                        Text(summary)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(Color(hex: 0x3B424B))
                            .lineSpacing(8)
                            .textSelection(.enabled)
                    }
                }

                if !keyPoints.isEmpty {
                    section(title: "Key Points", accent: .olive) {
                        bulletList(keyPoints, accent: OrionColor.primary)
                    }
                }

                if !decisions.isEmpty {
                    section(title: "Decisions", accent: .sky) {
                        bulletList(decisions, accent: OrionColor.secondary)
                    }
                }

                if !actionItems.isEmpty {
                    section(title: "Action Items", accent: .sky) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(actionItems) { item in
                                actionRow(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private func capsule(width: CGFloat?) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color(hex: 0xE4E7EB))
            .frame(maxWidth: width == nil ? .infinity : width)
            .frame(height: 10)
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    capsule(width: 120)
                    capsule(width: nil)
                    capsule(width: nil)
                    capsule(width: 200)
                }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14, weight: .medium))
            Text(message)
                .font(.system(size: 14))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(hex: 0x7A3F2C))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrionColor.dangerTint)
        .overlay(
            Rectangle()
                .strokeBorder(Color(hex: 0xD8B9AE), lineWidth: 1)
        )
    }

    private func section<Content: View>(
        title: String,
        accent: OrionSectionAccent,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            OrionSectionHeading(title: title, accent: accent)
            content()
        }
    }

    private func bulletList(_ items: [String], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(accent)
                        .frame(width: 5, height: 5)
                        .padding(.top, 8)
                    Text(item)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: 0x3B424B))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func actionRow(_ item: SummaryActionItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.done ? "checkmark" : "circle")
                .font(.system(size: 13, weight: item.done ? .semibold : .regular))
                .foregroundStyle(item.done ? OrionColor.primary : OrionColor.borderStrong)
                .frame(width: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.system(size: 15))
                    .foregroundStyle(item.done ? OrionColor.textMuted : Color(hex: 0x3B424B))
                    .strikethrough(item.done)
                    .textSelection(.enabled)
                if item.owner != nil || item.due != nil {
                    Text([item.owner, item.due].compactMap { $0 }.joined(separator: " · ").uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(OrionColor.textMuted)
                }
            }
        }
    }
}

struct SummaryActionItem: Identifiable, Hashable {
    var id: String
    var label: String
    var owner: String? = nil
    var due: String? = nil
    var done: Bool = false
}

enum OrionSectionAccent {
    case olive, sky

    var color: Color {
        switch self {
        case .olive: OrionColor.primary
        case .sky: OrionColor.secondary
        }
    }
}

struct OrionSectionHeading: View {
    var title: String
    var accent: OrionSectionAccent = .olive

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Rectangle()
                .fill(accent.color)
                .frame(width: 7, height: 7)
                .rotationEffect(.degrees(45))
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .tracking(1.8)
                .foregroundStyle(OrionColor.textInk)
        }
    }
}

struct OrionEngravedRule: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: 0xE4E7EB))
            .frame(height: 1)
    }
}

// MARK: - Parse markdown-ish LLM output into SummaryDocument fields

enum SummaryDocumentParser {
    static func parse(output: String, template: NoteTemplate) -> (
        summary: String?,
        keyPoints: [String],
        decisions: [String],
        actionItems: [SummaryActionItem]
    ) {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (nil, [], [], [])
        }

        let keyPoints = lines(in: trimmed, headings: ["key points", "highlights", "takeaways"])
        let decisions = lines(in: trimmed, headings: ["decisions", "decision"])
        let actionLines = lines(in: trimmed, headings: ["action items", "actions", "next steps", "todos"])

        let actionItems: [SummaryActionItem] = {
            if !actionLines.isEmpty {
                return actionLines.enumerated().map { i, line in
                    SummaryActionItem(id: "\(i)", label: stripBullet(line))
                }
            }
            if template == .actionItems {
                return bulletOrNumbered(trimmed).enumerated().map { i, line in
                    SummaryActionItem(id: "\(i)", label: line)
                }
            }
            return []
        }()

        let summaryText: String? = {
            if let section = prose(in: trimmed, headings: ["summary", "overview"]) {
                return section
            }
            // Whole body as summary when no structured sections found
            if keyPoints.isEmpty && decisions.isEmpty && actionItems.isEmpty {
                return trimmed
            }
            // Lead paragraphs before first known heading
            let before = proseBeforeHeadings(trimmed)
            return before.isEmpty ? nil : before
        }()

        let points: [String] = {
            if !keyPoints.isEmpty { return keyPoints.map(stripBullet) }
            if summaryText == trimmed {
                // Derive a few bullets from sentences when unstructured
                return trimmed
                    .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.count > 24 }
                    .prefix(5)
                    .map { $0 }
            }
            return []
        }()

        return (summaryText, points, decisions.map(stripBullet), actionItems)
    }

    private static func lines(in text: String, headings: [String]) -> [String] {
        let rows = text.components(separatedBy: .newlines)
        guard let start = rows.firstIndex(where: { line in
            let lower = normalizeHeading(line)
            return headings.contains { lower == $0 || lower.hasPrefix($0) }
        }) else { return [] }

        var collected: [String] = []
        for line in rows.suffix(from: start + 1) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !collected.isEmpty { break }
                continue
            }
            let lower = normalizeHeading(trimmed)
            if knownHeadings.contains(where: { lower == $0 || lower.hasPrefix($0) }) { break }
            collected.append(trimmed)
        }
        return collected
    }

    private static func prose(in text: String, headings: [String]) -> String? {
        let rows = lines(in: text, headings: headings)
        let joined = rows.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }

    private static func proseBeforeHeadings(_ text: String) -> String {
        var collected: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = normalizeHeading(trimmed)
            if knownHeadings.contains(where: { lower == $0 || lower.hasPrefix($0) }) { break }
            if !trimmed.isEmpty { collected.append(trimmed) }
        }
        return collected.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bulletOrNumbered(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map(stripBullet)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func stripBullet(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("- ") || s.hasPrefix("• ") || s.hasPrefix("* ") {
            s = String(s.dropFirst(2))
        }
        if let dot = s.firstIndex(of: "."), s[..<dot].allSatisfy(\.isNumber) {
            s = String(s[s.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    private static func normalizeHeading(_ line: String) -> String {
        line.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "#*_ "))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let knownHeadings = [
        "summary", "overview", "key points", "highlights", "takeaways",
        "decisions", "decision", "action items", "actions", "next steps", "todos",
    ]
}
