import AppKit
import MuffinCore
import SwiftUI

struct SettingsView: View {
    @Bindable var session: RecordingSession
    @AppStorage("muffin.openrouter.baseURL") private var openRouterBaseURL = "https://openrouter.ai/api/v1/chat/completions"
    @AppStorage("muffin.openrouter.model") private var openRouterModel = "anthropic/claude-sonnet-4"
    @AppStorage("muffin.openrouter.apiKey") private var openRouterAPIKey = ""
    @AppStorage("muffin.ollama.baseURL") private var ollamaBaseURL = "http://localhost:11434/v1/chat/completions"
    @AppStorage("muffin.ollama.model") private var ollamaModel = "llama3.1"

    var body: some View {
        DocumentPage(
            title: "Settings",
            subtitle: "Providers, Hold Fn, and how agents reach your recordings via CLI or MCP."
        ) {
            EmptyView()
        } document: {
            VStack(alignment: .leading, spacing: 28) {
                settingsSection(
                    title: "LLM provider",
                    blurb: "Used only when you generate a summary. On-device transcription never leaves this Mac."
                ) {
                    fieldLabel("Active provider")
                    Picker("Provider", selection: Binding(
                        get: { session.llmRouter.selectedID },
                        set: { session.llmRouter.selectedID = $0 }
                    )) {
                        ForEach(LLMProviderID.allCases) { id in
                            let provider = session.llmRouter.provider(for: id)
                            Text(provider.displayName + (provider.isAvailable ? "" : " (not wired yet)"))
                                .tag(id)
                        }
                    }
                    .labelsHidden()

                    switch session.llmRouter.selectedID {
                    case .apple:
                        caption("Apple Intelligence on this Mac. No API key. Enable Apple Intelligence in System Settings if Generate fails.")

                    case .openRouter:
                        fieldLabel("Base URL")
                        TextField("https://openrouter.ai/api/v1/chat/completions", text: $openRouterBaseURL)
                            .textFieldStyle(OrionFieldStyle())
                            .font(OrionType.mono)
                        fieldLabel("Model")
                        TextField("anthropic/claude-sonnet-4", text: $openRouterModel)
                            .textFieldStyle(OrionFieldStyle())
                            .font(OrionType.mono)
                        fieldLabel("API key")
                        SecureField("sk-or-…", text: $openRouterAPIKey)
                            .textFieldStyle(OrionFieldStyle())
                            .font(OrionType.mono)
                        caption("Keys stay on this Mac. Network Generate is not fully wired yet.")

                    case .ollama:
                        fieldLabel("Base URL")
                        TextField("http://localhost:11434/v1/chat/completions", text: $ollamaBaseURL)
                            .textFieldStyle(OrionFieldStyle())
                            .font(OrionType.mono)
                        fieldLabel("Model")
                        TextField("llama3.1", text: $ollamaModel)
                            .textFieldStyle(OrionFieldStyle())
                            .font(OrionType.mono)
                        caption("Run `ollama serve` and pull the model first. Network Generate is not fully wired yet.")
                    }
                }

                settingsSection(
                    title: "Hold Fn to record",
                    blurb: "Push-to-talk from anywhere on your Mac. Release Fn to stop, chime, and copy the transcript."
                ) {
                    if PushToTalkMonitor.shared.isTrusted {
                        Text(PushToTalkMonitor.shared.isMonitoring
                             ? "Accessibility is on. Hold Fn works system-wide."
                             : "Accessibility is on. Reopen Record if Hold Fn still doesn’t respond.")
                            .font(OrionType.body)
                            .foregroundStyle(OrionColor.textInk)
                    } else {
                        Text("Needs Accessibility so Muffin can see Fn while other apps are focused.")
                            .font(OrionType.body)
                            .foregroundStyle(OrionColor.textInk)
                        HStack(spacing: 8) {
                            Button("Allow Accessibility") {
                                PushToTalkMonitor.shared.requestAccessFromUser()
                            }
                            .buttonStyle(OrionPrimaryButtonStyle())
                            Button("Open Privacy settings") {
                                PushToTalkMonitor.shared.openAccessibilitySettings()
                            }
                            .buttonStyle(OrionQuietButtonStyle())
                        }
                        .padding(.top, 4)
                    }
                    caption("The permission sheet only appears when you click Allow — it will not flash and vanish on launch.")
                }

                settingsSection(
                    title: "CLI",
                    blurb: "Talk to the same on-disk library from Terminal. Build the package once, then use the `muffin` binary."
                ) {
                    caption("From the repo:")
                    codeBlock("""
                    cd Packages/Muffin
                    swift build -c release
                    """)
                    caption("Useful commands:")
                    codeBlock("""
                    .build/release/muffin list
                    .build/release/muffin transcript <uuid>
                    .build/release/muffin search "keyword"
                    .build/release/muffin generate <uuid> --template summary
                    .build/release/muffin reveal <uuid>
                    """)
                    caption("Optional: copy `.build/release/muffin` somewhere on your PATH (e.g. `/usr/local/bin`).")
                    Button("Copy build commands") {
                        copyToClipboard("""
                        cd Packages/Muffin && swift build -c release
                        .build/release/muffin list
                        """)
                    }
                    .buttonStyle(OrionQuietButtonStyle())
                }

                settingsSection(
                    title: "MCP for agents",
                    blurb: "Expose recordings to Cursor (or any MCP client) over stdio. Agents can list takes, read/search transcripts, and generate summaries."
                ) {
                    caption("1. Build the MCP server:")
                    codeBlock("""
                    cd Packages/Muffin
                    swift build -c release --product muffin-mcp
                    """)
                    caption("2. Add to Cursor MCP config (`~/.cursor/mcp.json` or project `.cursor/mcp.json`):")
                    codeBlock("""
                    {
                      "mcpServers": {
                        "muffin": {
                          "command": "/ABSOLUTE/PATH/TO/Packages/Muffin/.build/release/muffin-mcp"
                        }
                      }
                    }
                    """)
                    caption("3. Tools agents get:")
                    VStack(alignment: .leading, spacing: 4) {
                        bullet("list_recordings — id, title, date, duration")
                        bullet("get_transcript — raw transcript for a UUID")
                        bullet("search_transcripts — keyword search")
                        bullet("edit_transcript — overwrite stored markdown")
                        bullet("generate_summary — template: summary, meetingNotes, actionItems, blogDraft")
                    }
                    caption("Replace the absolute path with your machine’s path to `muffin-mcp`. Restart Cursor after editing mcp.json.")
                    Button("Copy MCP snippet") {
                        copyToClipboard("""
                        {
                          "mcpServers": {
                            "muffin": {
                              "command": "/ABSOLUTE/PATH/TO/Packages/Muffin/.build/release/muffin-mcp"
                            }
                          }
                        }
                        """)
                    }
                    .buttonStyle(OrionQuietButtonStyle())
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        blurb: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let body = content()
        return OrionCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(OrionType.title)
                    .foregroundStyle(OrionColor.textInk)
                Text(blurb)
                    .font(OrionType.caption)
                    .foregroundStyle(OrionColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                body
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11.5, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(OrionColor.textMuted)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(OrionType.caption)
            .foregroundStyle(OrionColor.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·")
                .foregroundStyle(OrionColor.primary)
            Text(text)
                .font(OrionType.caption)
                .foregroundStyle(OrionColor.textBody)
        }
    }

    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(OrionType.mono)
            .foregroundStyle(OrionColor.textInk)
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OrionColor.background.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(OrionColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct OrionFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(OrionColor.border, lineWidth: 1)
            )
    }
}
