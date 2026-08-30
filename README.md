# Muffin

**Your thoughts. Yours to own.**

Muffin transcribes your voice directly on your Mac — no account, no server, no subscription. Every recording saves as a plain Markdown file you already know how to read.

---

## Why Muffin

Most voice tools make you trade privacy for convenience. You log in, your audio goes to a server, a model you don't control processes it, and the transcript lives in someone else's database.

Muffin works differently. Audio stays on your machine. Transcription runs on-device via Apple's Speech framework. The output is a `.md` file in a folder you own. No sync layer means no server to breach, no subscription to cancel, no login to forget.

---

## Features

- **Local audio recording** — AVAudioEngine captures mic input straight to `audio.caf`. Start, stop, pause, add a marker — no cloud upload, ever.
- **On-device transcription** — SpeechAnalyzer writes `transcript.md` the moment you stop. Watch words appear live as you speak — no network call, ever.
- **Confidence highlighting** — Low-confidence words are highlighted in the live transcript so you can catch mis-heard names or jargon before saving.
- **Auto-save & auto-copy** — Transcript is saved to disk and copied to your clipboard the moment recording stops.
- **Menu bar access** — Start a recording from the menu bar without launching the full app.
- **Bring your own model** — Defaults to Apple Intelligence on-device ($0). Or bring your own key — OpenRouter, Ollama, whatever you run.
- **Editable transcripts** — Fix a mis-heard name, restructure a paragraph. Edits write back to the source `.md` file directly.
- **CLI for scripting** — `muffin list`, `muffin transcript`, `muffin generate` — reads the same folder the app writes to.
- **MCP server for agents** — Five stdio tools, no auth. Claude Desktop (or any MCP client) can list, read, edit, and summarize directly.

---

## Who this is not for

- There is no iPhone app.
- There is no cloud sync between devices.
- There is no team calendar integration or automatic meeting bot.

If you want an all-in-one corporate meeting suite, buy Granola or Wisprflow or Monologue. If you want a lightweight, local Mac tool that respects your disk and your privacy, you'll love Muffin.

---

## Requirements

- macOS 26 (Tahoe) or later
- No account needed
- Microphone + Speech Recognition permissions

---

## Getting Started

```bash
# CLI
swift build -product muffin
muffin list
muffin transcript <id>
muffin generate <id> --template summary
```

```json
// MCP — add to Claude Desktop config
{
  "mcpServers": {
    "muffin": {
      "command": "muffin-mcp",
      "args": []
    }
  }
}
```

---

## Architecture

All business logic lives in `Packages/Muffin` as `MuffinCore`. The `Orion` Xcode target is the SwiftUI macOS app shell. Two additional executables — `muffin` (CLI) and `muffin-mcp` (MCP server) — depend on `MuffinCore`.

Each recording is stored under `~/Library/Application Support/Muffin/Recordings/<UUID>/`:

```
<UUID>/
  audio.caf
  transcript.md
  transcript.txt
  meta.json
  outputs/
```

---

## License

MIT
