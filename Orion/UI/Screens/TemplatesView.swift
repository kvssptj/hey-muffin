import MuffinCore
import SwiftUI

struct TemplatesView: View {
    @Bindable var templateStore: TemplateStore

    @State private var selectedID: String = ""
    @State private var draft: OutputTemplate = OutputTemplate.builtIns[0]

    private var selected: OutputTemplate? {
        templateStore.templates.first { $0.id == selectedID }
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
        .onChange(of: templateStore.defaultTemplateID) { _, _ in
            // Refresh draft if the default badge changes
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
                Text("\(templateStore.templates.count)")
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
                        if template.id != templateStore.templates.last?.id {
                            Rectangle()
                                .fill(OrionColor.border.opacity(0.7))
                                .frame(height: 1)
                        }
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
                let t = templateStore.addNew()
                select(t)
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
            .foregroundStyle(OrionColor.textMuted)
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .background(OrionColor.surfaceSidebar.opacity(0.6))
    }

    @ViewBuilder
    private func templateRow(_ template: OutputTemplate) -> some View {
        let isSelected = template.id == selectedID
        let isDefault  = template.id == templateStore.defaultTemplateID
        Button { select(template) } label: {
            HStack(spacing: 0) {
                // Selected indicator
                Capsule()
                    .fill(isSelected ? OrionColor.primary : Color.clear)
                    .frame(width: 3, height: 16)
                    .padding(.leading, 4)
                    .padding(.trailing, 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OrionColor.textInk)
                        .lineLimit(1)

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

    // MARK: - Right panel

    private var rightPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Card 1: identity + prompt
                OrionCard(padding: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Header
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(draft.name)
                                .font(.system(size: 17, weight: .semibold, design: .serif))
                                .foregroundStyle(OrionColor.textInk)
                            Spacer(minLength: 8)
                            if draft.id == templateStore.defaultTemplateID {
                                OrionBadge(text: "Default", variant: .olive)
                            }
                        }

                        if !draft.description.isEmpty {
                            Text(draft.description)
                                .font(OrionType.caption)
                                .foregroundStyle(OrionColor.textMuted)
                        }

                        OrionEngravedRule()

                        // Name field
                        fieldLabel("Name")
                        TextField("Template name", text: $draft.name)
                            .textFieldStyle(TemplateFieldStyle())
                            .disabled(draft.isBuiltIn)

                        // Prompt
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
                                .disabled(draft.isBuiltIn)
                        }
                        .frame(minHeight: 160)
                        .padding(8)
                        .background(draft.isBuiltIn ? OrionColor.background.opacity(0.5) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(OrionColor.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        if !draft.isBuiltIn {
                            OrionEngravedRule()
                            HStack(spacing: 8) {
                                Spacer(minLength: 0)
                                Button("Revert") {
                                    if let original = templateStore.templates.first(where: { $0.id == draft.id }) {
                                        draft = original
                                    }
                                }
                                .buttonStyle(OrionQuietButtonStyle())
                                .fixedSize()

                                Button("Save template") {
                                    templateStore.save(draft)
                                }
                                .buttonStyle(OrionPrimaryButtonStyle())
                                .fixedSize()
                            }
                        }
                    }
                }

                // Card 2: set as default (only when not already default)
                if draft.id != templateStore.defaultTemplateID {
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

// Matches the OrionFieldStyle used in SettingsView
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
