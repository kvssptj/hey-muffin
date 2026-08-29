# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

**Muffin** — a macOS 26.0 voice-note recorder that captures audio, transcribes it on-device via Apple's Speech Recognition, and generates structured outputs (summaries, meeting notes, action items) using LLMs. The repo is named `orion` but the product is Muffin (`com.muffin.app`).

## Build Commands

**Xcode app (primary):**
```bash
xcodebuild build -scheme Orion -configuration Debug
xcodebuild test -scheme Orion
```

**Swift Package (MuffinCore library + CLI + MCP server):**
```bash
cd Packages/Muffin
swift build                   # debug
swift build -c release        # release
swift build -product muffin   # CLI only
swift build -product muffin-mcp  # MCP server only
swift test
```

## Architecture

### Package Split

All business logic lives in the `Packages/Muffin` Swift package as `MuffinCore`. The `Orion` Xcode target is purely the SwiftUI macOS app shell. Two additional executables in the package — `muffin` (CLI) and `muffin-mcp` (MCP server) — depend on `MuffinCore` for headless/programmatic access.

### Core Data Flow

1. **Record** — `Recorder` (AVAudioEngine, `@unchecked Sendable`) captures PCM audio, writes `audio.caf` to disk
2. **Transcribe** — `Transcriber` uses `SpeechAnalyzer`/`SpeechTranscriber` for live on-device transcription, emitting volatile (interim) and finalized segments
3. **Coordinate** — `RecordingSession` (`@MainActor`, `@Observable`) is the central state machine: owns `Recorder` + `Transcriber`, tracks recording state, accumulates transcript
4. **Generate** — `LLMRouter` dispatches to one of three `LLMProvider` implementations: `AppleFoundationProvider` (Apple Intelligence), `OpenRouterProvider` (HTTP), `OllamaProvider` (local)
5. **Persist** — `RecordingStore` saves each recording under `~/Library/Application Support/Muffin/Recordings/<UUID>/` with `audio.caf`, `transcript.md`, `transcript.txt`, `meta.json`, and an `outputs/` directory

### Key Patterns

- **`@Observable` actors** — all state owners (`AppModel`, `RecordingSession`, `LLMRouter`, `PushToTalkMonitor`) use Swift Observation; views bind via `@Bindable`. No `@StateObject`/`@EnvironmentObject`.
- **Protocol-driven LLM** — `LLMProvider` protocol makes providers swappable at runtime; selection stored in UserDefaults
- **Push-to-talk** — `PushToTalkMonitor` listens globally for the Fn key via Accessibility APIs; `AppModel` wires it to `RecordingSession`
- **Strict concurrency** — Swift concurrency checking set to `targeted`; use actors and `@MainActor` annotations consistently
- **Minimal dependencies** — only `swift-argument-parser` (v1.5+); no networking libraries, no third-party UI frameworks

### Disk Layout Per Recording
```
<UUID>/
  audio.caf
  transcript.md
  transcript.txt
  meta.json          # RecordingMetadata: id, title, duration, markers, timestamps
  outputs/           # One file per template (summary, meetingNotes, actionItems, blogDraft)
```

### UI Organization
```
Orion/UI/
  Theme.swift             # Design tokens: OrionColor, OrionType (sourced from Magic Patterns)
  AppNavigation.swift     # AppDestination enum drives navigation
  Screens/                # Top-level views (RecordView, SummaryView, TranscriptView, …)
  Components/             # Reusable widgets (WaveformView, EngravedRecordButton, OrionCard, …)
```

## Platform Targets

- macOS 26.0 minimum (Swift 6.2 toolchain, Swift 5 language mode)
- No iOS target — this is macOS-only
- Requires Microphone + Speech Recognition entitlements; Accessibility permission for Fn key monitoring
