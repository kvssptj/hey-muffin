# Muffin Note Desk — Design Spec

**Date:** 2026-08-29  
**Status:** Draft for approval

## Problem

1. **Split IA:** Transcript and “Outputs” are separate sidebar destinations. Opening a recording from Library lands on Transcript only; producing a summary means navigating away. Users want one note surface.
2. **Wrong product language:** “Output” / “Outputs” is engineer-speak. The right-hand artifact is a **summary**. The user picks a **summary format** (concise summary, meeting notes, action items, blog draft, custom), then generates.
3. **UI polish:** Current chrome feels disconnected from a calm desk for voice notes.

## Goals

- Library → open recording → **one Note view** with **raw transcript** and **summary** side by side.
- User chooses **summary format** in that view, then generates / copies without leaving.
- Optional UI enhancement (Option A by default) without a full rebrand.
- Keep Record, menu bar, Hold Fn, and on-disk layout unchanged (`outputs/<format>.md` can stay as the folder name on disk; UI never says “output”).

## Non-goals (this pass)

- Favorites product work
- OpenRouter/Ollama networking
- Redesigning Record / guilloché from scratch
- Mobile / multi-window note editing
- Renaming the on-disk `outputs/` directory (optional later; not required for this pass)

---

## Information architecture

### Sidebar (after)

| Item | Role |
|------|------|
| Record | Capture only |
| Library | List of recordings on disk |
| *(removed)* Transcript | Merged into Note |
| *(removed)* Outputs | Merged into Note as Summary pane |
| Favorites | Unchanged empty state |
| Settings | Unchanged |

There is **no** top-level “Transcript” / “Outputs” nav. The note surface is reached by:

- Opening a row in Library, or
- After Stop & save / “Open note” from Record

### Note view layout

**Wide (≥ ~1000pt):** horizontal split

```
┌──────────────────────────────────────────────────────────┐
│  Title · duration · date           [Finder] [Export…]    │
├───────────────────────┬──────────────────────────────────┤
│  TRANSCRIPT           │  SUMMARY                         │
│  editable TextEditor  │  Format ▾  (Summary / Meeting… ) │
│  autosave             │  Provider ▾ · Generate summary   │
│                       │  result body · Copy              │
└───────────────────────┴──────────────────────────────────┘
```

**Narrow:** segmented control `Transcript | Summary` (full width).

### Summary formats (user-facing)

Same set as today’s templates; copy calls them **formats**, not templates/outputs:

| Format (UI) | Disk file (unchanged) |
|-------------|------------------------|
| Summary | `outputs/summary.md` |
| Meeting notes | `outputs/meetingNotes.md` |
| Action items | `outputs/actionItems.md` |
| Blog draft | `outputs/blogDraft.md` |
| Custom | `outputs/custom.md` (+ custom instructions field) |

### Behavior

- Opening a recording loads `transcript.md` and the **currently selected format’s** markdown (empty if missing).
- Changing **format** reloads that format’s file for the active recording (does not auto-regenerate).
- **Generate summary** always reads the latest transcript (flush editor draft first), writes the selected format’s file, shows result in the Summary pane.
- Copy transcript / Copy summary on each pane.
- After recording stops, navigate to Note (recommended).

---

## UI enhancement options

Pick **one** for the implementation plan’s visual tasks:

### Option A — Polish in place (recommended)

Keep olive / ivory / New York / guilloché. Fix hierarchy and density:

- One page chrome for Note
- Softer split; pane labels **TRANSCRIPT** / **SUMMARY**
- Library rows as quiet list
- Primary action: **Generate summary** on the Summary pane only

### Option B — Note-first desk

Same IA; Record secondary; Library + Note dominate.

### Option C — Visual refresh

Defer unless A still feels wrong after Note IA lands.

**Default for the plan:** **Option A**.

---

## Success criteria

- Library → Note shows transcript + **summary** side by side (or segmented).
- User can switch **summary format** and generate without leaving Note.
- No user-facing “Output(s)” copy in sidebar, Note, or empty states.
- Sidebar has no separate Transcript / Outputs entries.
- Visual polish (A) clarifies primary actions; no purple/glow/dark-mode drift.

## Open decisions for approval

1. Confirm **Option A** for UI polish (vs B/C).
2. Confirm removing Transcript + Outputs from sidebar.
3. After Stop & save: auto-open Note — **yes** (recommended) or stay on Record?
4. Summary + format picker naming — locked as preferred; confirm to proceed.
