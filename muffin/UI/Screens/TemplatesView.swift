import MuffinCore
import SwiftUI

struct TemplatesView: View {
    @Bindable var templateStore: TemplateStore

    @State private var selectedID: String = ""
    @State private var draft: OutputTemplate = OutputTemplate.builtIns[0]
    /// Non-nil when the user clicked "+ New template" but hasn't saved yet.
    @State private var pendingNew: OutputTemplate? = nil
    /// ID to return to if the user discards a pending new template.
    @State private var priorSelectedID: String = ""
    @State private var confirmingDelete = false
    @State private var confirmingReset = false

    private var isDirty: Bool {
        if pendingNew != nil { return true }
        guard let saved = templateStore.templates.first(where: { $0.id == draft.id }) else { return false }
        return draft != saved
    }

    private var canRestoreBuiltIn: Bool {
        guard draft.isBuiltIn,
              let original = OutputTemplate.builtIns.first(where: { $0.id == draft.id }),
              let saved = templateStore.templates.first(where: { $0.id == draft.id }) else { return false }
        return saved != original
    }

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
                .frame(width: 240)
                .frame(maxHeight: .infinity)

            Rectangle()
                .fill(OrionColor.border)
                .frame(width: 1)

            rightPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if selectedID.isEmpty, let first = templateStore.templates.first {
                select(first)
            }
        }
    }

    // MARK: - Left panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("TEMPLATES")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(OrionColor.primary)
                Spacer()
                Text("\(templateStore.templates.count + (pendingNew != nil ? 1 : 0))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(OrionColor.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.top, 20)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(templateStore.templates) { template in
                        templateRow(template)
                        if template.id != templateStore.templates.last?.id || pendingNew != nil {
                            Rectangle()
                                .fill(OrionColor.border.opacity(0.7))
                                .frame(height: 1)
                        }
                    }
                    // Unsaved new template row
                    if let pending = pendingNew {
                        pendingRow(pending)
                    }
                }
                .background(OrionColor.surfacePaper)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(OrionColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.horizontal, 10)
            }

            Divider()
                .padding(.top, 8)

            Button {
                guard pendingNew == nil else { return }
                priorSelectedID = selectedID
                let t = OutputTemplate(
                    id: UUID().uuidString,
                    name: "New template",
                    description: "",
                    prompt: "",
                    isBuiltIn: false
                )
                pendingNew = t
                draft = t
                selectedID = t.id
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("New template")
                        .font(.system(size: 13))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .foregroundStyle(pendingNew != nil ? OrionColor.textMuted.opacity(0.4) : OrionColor.textMuted)
            .disabled(pendingNew != nil)
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .background(OrionColor.surfaceSidebar.opacity(0.6))
    }

    @ViewBuilder
    private func templateRow(_ template: OutputTemplate) -> some View {
        let isSelected = template.id == selectedID
        let isDefault  = template.id == templateStore.defaultTemplateID
        let isModified = template.isBuiltIn &&
            OutputTemplate.builtIns.first(where: { $0.id == template.id }) != template
        Button {
            if pendingNew != nil {
                pendingNew = nil
            }
            select(template)
        } label: {
            HStack(spacing: 0) {
                Capsule()
                    .fill(isSelected ? OrionColor.primary : Color.clear)
                    .frame(width: 3, height: 16)
                    .padding(.leading, 4)
                    .padding(.trailing, 8)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(template.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OrionColor.textInk)
                            .lineLimit(1)
                        if isModified {
                            Circle()
                                .fill(OrionColor.primary.opacity(0.6))
                                .frame(width: 5, height: 5)
                        }
                    }
                    if isDefault {
                        Text("Default")
                            .font(.system(size: 11))
                            .foregroundStyle(OrionColor.primary)
                    } else {
                        Text(template.description.isEmpty ? " " : template.description)
                            .font(.system(size: 11))
                            .foregroundStyle(OrionColor.textMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? OrionColor.surfaceNavSelected : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pendingRow(_ template: OutputTemplate) -> some View {
        HStack(spacing: 0) {
            Capsule()
                .fill(OrionColor.primary)
                .frame(width: 3, height: 16)
                .padding(.leading, 4)
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(draft.name.isEmpty ? "New template" : draft.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OrionColor.textInk)
                    .italic()
                    .lineLimit(1)
                Text("Unsaved")
                    .font(.system(size: 11))
                    .foregroundStyle(OrionColor.textMuted)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrionColor.surfaceNavSelected)
    }

    // MARK: - Right panel

    private var rightPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OrionCard(padding: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Header
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(draft.name.isEmpty ? "New template" : draft.name)
                                .font(.system(size: 17, weight: .semibold, design: .serif))
                                .foregroundStyle(OrionColor.textInk)
                            Spacer(minLength: 8)
                            if draft.id == templateStore.defaultTemplateID {
                                OrionBadge(text: "Default", variant: .olive)
                            }
                            if draft.isBuiltIn {
                                OrionBadge(text: "Built-in", variant: .sky)
                            }
                        }

                        if !draft.description.isEmpty {
                            Text(draft.description)
                                .font(OrionType.caption)
                                .foregroundStyle(OrionColor.textMuted)
                        }

                        OrionEngravedRule()

                        fieldLabel("Name")
                        TextField("Template name", text: $draft.name)
                            .textFieldStyle(TemplateFieldStyle())

                        fieldLabel("Description")
                        TextField("Short description", text: $draft.description)
                            .textFieldStyle(TemplateFieldStyle())

                        fieldLabel("System prompt")
                        ZStack(alignment: .topLeading) {
                            Text(draft.prompt.isEmpty ? " " : draft.prompt)
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .lineSpacing(5)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(Color.clear)
                            TextEditor(text: $draft.prompt)
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .foregroundStyle(OrionColor.textInk)
                                .scrollContentBackground(.hidden)
                                .scrollDisabled(true)
                                .lineSpacing(5)
                        }
                        .frame(minHeight: 160)
                        .padding(8)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(OrionColor.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        OrionEngravedRule()

                        HStack(spacing: 8) {
                            // Restore factory defaults (built-ins only, when overridden)
                            if canRestoreBuiltIn {
                                Button("Restore defaults") {
                                    confirmingReset = true
                                }
                                .buttonStyle(OrionQuietButtonStyle())
                                .fixedSize()
                                .confirmationDialog(
                                    "Restore \"\(draft.name)\" to factory defaults?",
                                    isPresented: $confirmingReset,
                                    titleVisibility: .visible
                                ) {
                                    Button("Restore defaults", role: .destructive) {
                                        templateStore.resetToBuiltIn(id: draft.id)
                                        if let restored = templateStore.templates.first(where: { $0.id == draft.id }) {
                                            draft = restored
                                        }
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("Your edits to this template will be lost.")
                                }
                            }

                            // Delete (custom templates only)
                            if !draft.isBuiltIn && pendingNew == nil {
                                Button("Delete") { confirmingDelete = true }
                                    .buttonStyle(OrionQuietButtonStyle())
                                    .foregroundStyle(OrionColor.danger)
                                    .fixedSize()
                                    .confirmationDialog(
                                        "Delete \"\(draft.name)\"?",
                                        isPresented: $confirmingDelete,
                                        titleVisibility: .visible
                                    ) {
                                        Button("Delete", role: .destructive) {
                                            let idToDelete = draft.id
                                            if let first = templateStore.templates.first(where: { $0.id != idToDelete }) {
                                                select(first)
                                            }
                                            templateStore.delete(id: idToDelete)
                                        }
                                        Button("Cancel", role: .cancel) {}
                                    }
                            }

                            Spacer(minLength: 0)

                            // Discard (new unsaved template)
                            if pendingNew != nil {
                                Button("Discard") {
                                    pendingNew = nil
                                    if let prior = templateStore.templates.first(where: { $0.id == priorSelectedID })
                                        ?? templateStore.templates.first {
                                        select(prior)
                                    }
                                }
                                .buttonStyle(OrionQuietButtonStyle())
                                .fixedSize()
                            } else if isDirty {
                                // Revert unsaved edits on an existing template
                                Button("Revert") {
                                    if let saved = templateStore.templates.first(where: { $0.id == draft.id }) {
                                        draft = saved
                                    }
                                }
                                .buttonStyle(OrionQuietButtonStyle())
                                .fixedSize()
                            }

                            Button("Save template") {
                                templateStore.save(draft)
                                pendingNew = nil
                                selectedID = draft.id
                            }
                            .buttonStyle(OrionPrimaryButtonStyle())
                            .fixedSize()
                            .disabled(!isDirty)
                        }
                    }
                }

                // Set as default (only when not already default)
                if draft.id != templateStore.defaultTemplateID && pendingNew == nil {
                    OrionCard(padding: 20) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Set as default")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(OrionColor.textInk)
                                Text("Applied automatically when a recording finishes.")
                                    .font(OrionType.caption)
                                    .foregroundStyle(OrionColor.textMuted)
                            }
                            Spacer(minLength: 16)
                            Button("Set as default") {
                                templateStore.setDefault(draft)
                            }
                            .buttonStyle(OrionSecondaryButtonStyle())
                            .fixedSize()
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Helpers

    private func select(_ template: OutputTemplate) {
        selectedID = template.id
        draft = template
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(OrionColor.textMuted)
    }
}

private struct TemplateFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 13))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(OrionColor.border, lineWidth: 1)
            )
    }
}
