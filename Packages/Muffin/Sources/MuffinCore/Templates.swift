import Foundation

public enum NoteTemplate: String, CaseIterable, Identifiable, Sendable, Codable {
    case summary
    case meetingNotes
    case actionItems
    case blogDraft
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .summary: "Summary"
        case .meetingNotes: "Meeting notes"
        case .actionItems: "Action items"
        case .blogDraft: "Blog draft"
        case .custom: "Custom"
        }
    }

    /// Filename stem under outputs/ (no extension).
    public var outputFileName: String { rawValue }

    public var instructions: String {
        switch self {
        case .summary:
            """
            Summarize the voice-note transcript clearly and concisely. \
            Use short paragraphs. Preserve important names, numbers, and decisions. \
            Do not invent details that are not in the transcript.
            """
        case .meetingNotes:
            """
            Turn the transcript into structured meeting notes with these sections: \
            Attendees (if mentioned), Topics, Decisions, Action Items, and Open Questions. \
            Use bullet points. Do not invent details that are not in the transcript.
            """
        case .actionItems:
            """
            Extract action items from the transcript as a numbered list. \
            For each item include the owner if mentioned and any deadline. \
            If nothing actionable appears, say so briefly.
            """
        case .blogDraft:
            """
            Turn the transcript into a readable blog draft with a title, short intro, \
            and sections with headings. Keep the author's voice. Do not invent facts.
            """
        case .custom:
            """
            Follow the user's custom instructions exactly when rewriting the transcript.
            """
        }
    }
}

// MARK: - OutputTemplate

public struct OutputTemplate: Identifiable, Codable, Sendable, Hashable, Equatable {
    public var id: String
    public var name: String
    public var description: String
    public var prompt: String
    public var isBuiltIn: Bool

    public init(id: String, name: String, description: String, prompt: String, isBuiltIn: Bool = false) {
        self.id = id; self.name = name; self.description = description
        self.prompt = prompt; self.isBuiltIn = isBuiltIn
    }

    public var outputFileName: String { id }

    public static let builtIns: [OutputTemplate] = [
        OutputTemplate(
            id: "summary",
            name: "Executive brief",
            description: "Tight prose plus the handful of points that matter.",
            prompt: "Summarise the transcript for an executive reader in under 120 words of plain prose, then list at most four points worth remembering. Prioritise outcomes and numbers over process. No preamble, no restating the request.",
            isBuiltIn: true
        ),
        OutputTemplate(
            id: "meetingNotes",
            name: "Meeting recap",
            description: "Prose summary, key points, decisions and owned follow-ups.",
            prompt: "You are given a verbatim transcript of a spoken recording. Produce a recap for someone who was not present.\n\nReturn: a two-to-four sentence prose summary, up to six key points, every decision that was locked in, and any follow-up task with an owner and due date if one was stated. Quote figures exactly. Never invent an owner.",
            isBuiltIn: true
        ),
        OutputTemplate(
            id: "actionItems",
            name: "Action items",
            description: "Just the commitments — nothing else survives the pass.",
            prompt: "Extract only explicit commitments from the transcript. One line each, starting with a verb. Attach an owner only when a name was spoken, and a due date only when one was stated. If nothing was committed to, return an empty list rather than guessing.",
            isBuiltIn: true
        ),
        OutputTemplate(
            id: "blogDraft",
            name: "Field journal",
            description: "First-person notes that keep the speaker's own phrasing.",
            prompt: "Rewrite the transcript as tidy first-person field notes. Keep the speaker's vocabulary and hedging intact; fix only disfluencies and false starts. Close with anything the speaker told themselves to do next.",
            isBuiltIn: true
        ),
    ]
}

// MARK: - TemplateStore

@MainActor
@Observable
public final class TemplateStore {
    public private(set) var templates: [OutputTemplate]
    public private(set) var defaultTemplateID: String

    private static let defaultIDKey        = "muffin.defaultTemplateID"
    private static let customKey           = "muffin.customTemplates"
    private static let builtInOverridesKey = "muffin.builtInOverrides"

    public init() {
        // Load any user overrides for built-ins.
        var builtIns = OutputTemplate.builtIns
        if let data = UserDefaults.standard.data(forKey: Self.builtInOverridesKey),
           let overrides = try? JSONDecoder().decode([String: OutputTemplate].self, from: data) {
            builtIns = builtIns.map { t in overrides[t.id] ?? t }
        }

        // Load custom templates.
        var customs: [OutputTemplate] = []
        if let data = UserDefaults.standard.data(forKey: Self.customKey),
           let decoded = try? JSONDecoder().decode([OutputTemplate].self, from: data) {
            customs = decoded
        }

        templates = builtIns + customs
        defaultTemplateID = UserDefaults.standard.string(forKey: Self.defaultIDKey)
            ?? OutputTemplate.builtIns[0].id
    }

    public var defaultTemplate: OutputTemplate {
        templates.first { $0.id == defaultTemplateID } ?? templates[0]
    }

    public func setDefault(_ t: OutputTemplate) {
        defaultTemplateID = t.id
        UserDefaults.standard.set(t.id, forKey: Self.defaultIDKey)
    }

    /// Saves a template (built-in override or custom). Creates if new.
    public func save(_ t: OutputTemplate) {
        if let i = templates.firstIndex(where: { $0.id == t.id }) {
            templates[i] = t
        } else {
            templates.append(t)
        }
        persistAll()
    }

    /// Deletes a custom template. No-op for built-ins.
    public func delete(id: String) {
        guard templates.first(where: { $0.id == id })?.isBuiltIn == false else { return }
        if defaultTemplateID == id {
            defaultTemplateID = OutputTemplate.builtIns[0].id
            UserDefaults.standard.set(defaultTemplateID, forKey: Self.defaultIDKey)
        }
        templates.removeAll { $0.id == id }
        persistAll()
    }

    /// Restores a built-in template to its factory prompt/name.
    public func resetToBuiltIn(id: String) {
        guard let original = OutputTemplate.builtIns.first(where: { $0.id == id }),
              let i = templates.firstIndex(where: { $0.id == id }) else { return }
        templates[i] = original
        persistAll()
    }

    private func persistAll() {
        // Custom templates.
        let customData = try? JSONEncoder().encode(templates.filter { !$0.isBuiltIn })
        UserDefaults.standard.set(customData, forKey: Self.customKey)

        // Built-in overrides (only those differing from factory defaults).
        var overrides: [String: OutputTemplate] = [:]
        for t in templates where t.isBuiltIn {
            if let original = OutputTemplate.builtIns.first(where: { $0.id == t.id }), t != original {
                overrides[t.id] = t
            }
        }
        let overridesData = try? JSONEncoder().encode(overrides)
        UserDefaults.standard.set(overridesData, forKey: Self.builtInOverridesKey)
    }
}
