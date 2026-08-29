# Orion DS → Muffin (Phases 1–4)

Ported from Magic Patterns design system `Orion` into SwiftUI.

| Phase | Components | Files |
|-------|------------|--------|
| 1 | Button, Card, EmptyState, AppShell nav | `OrionControls.swift`, `OrionCard.swift`, `DocumentChrome.swift`, `ContentView.swift` |
| 2 | RecordButton, Waveform, RecordingIndicator, Timecode | `EngravedRecordButton.swift`, `WaveformView.swift`, `RecordingChrome.swift`, `RecordView.swift` |
| 3 | RecordingListItem | `RecordingListItemView.swift`, `RecordingsLibraryView.swift` |
| 4 | SummaryDocument, TranscriptDocument | `SummaryDocumentView.swift`, `TranscriptDocumentView.swift`, `SummaryView.swift`, `TranscriptView.swift` |

Skipped: Dialog, Toast, form primitives (use AppKit/SwiftUI system), full Note-desk IA (separate plan).
