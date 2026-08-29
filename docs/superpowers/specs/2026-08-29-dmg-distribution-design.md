# DMG Distribution via GitHub Releases

**Date:** 2026-08-29
**Status:** Approved

## Problem

Muffin has no distribution pipeline. Users have no way to install the app without building it from source. The goal is to let anyone download and install Muffin on macOS with minimal friction.

## Constraints

- No Apple Developer account → no notarization, no Developer ID signing
- Ad-hoc signing only (`CODE_SIGN_IDENTITY = -`), already set in the Xcode project
- Users will see a one-time Gatekeeper prompt; they must right-click → Open on first launch
- Distribution via GitHub Releases (free, public repo)
- Builds must be fully automated — developer runs one command to ship

## Out of Scope

- Notarization (requires $99/year Apple Developer account)
- Sparkle auto-updates
- Homebrew tap
- Mac App Store

## Files

Two files added to the repo:

```
.github/
  workflows/
    release.yml           ← GitHub Actions release pipeline
scripts/
  export-options.plist    ← xcodebuild export configuration
```

---

## `scripts/export-options.plist`

Tells `xcodebuild -exportArchive` how to export the app without a developer account.

Key settings:
- `method = mac-application` — direct distribution (no App Store, no Developer ID)
- `signingStyle = manual`
- `signingCertificate = -` — ad-hoc signing
- `stripSwiftSymbols = true` — reduces binary size

---

## `.github/workflows/release.yml`

### Trigger

```yaml
on:
  push:
    tags:
      - 'v*'
```

Fires when a tag matching `v*` (e.g. `v1.0.0`) is pushed to the repo.

### Runner

`macos-15` — free GitHub Actions runner, ships with Xcode 26.

### Steps

1. **Checkout** — full clone
2. **Select Xcode** — pin to Xcode 26.3 via `DEVELOPER_DIR`
3. **Archive** — `xcodebuild archive -scheme Orion -configuration Release -archivePath Muffin.xcarchive`
4. **Export** — `xcodebuild -exportArchive -archivePath Muffin.xcarchive -exportPath dist/ -exportOptionsPlist scripts/export-options.plist`
5. **Install create-dmg** — `brew install create-dmg`
6. **Package DMG** — `create-dmg` produces `Muffin-{version}.dmg` with:
   - Custom window size
   - Drag-to-Applications symlink
   - App icon positioned on the left
7. **Publish release** — `gh release create v{version} Muffin-{version}.dmg --generate-notes`

### Version extraction

Version is extracted from the git tag (`v1.0.0` → `1.0.0`) via:
```bash
VERSION="${GITHUB_REF_NAME#v}"
```

### DMG filename

`Muffin-{version}.dmg` — e.g. `Muffin-1.0.0.dmg`

---

## User Install Flow

1. Visit `github.com/kvssptj/orion/releases`
2. Download `Muffin-{version}.dmg`
3. Double-click the DMG — Finder window opens
4. Drag Muffin.app to the Applications shortcut
5. Eject the DMG
6. First launch only: right-click Muffin in Applications → Open → click Open in the dialog

The README will include a note explaining step 6 so users are not confused by the Gatekeeper warning.

---

## Developer Release Flow

```bash
# Bump version in Xcode (Marketing Version field), commit, then:
git tag v1.0.0
git push --tags
# GitHub Actions runs automatically (~10-15 min)
# DMG appears at github.com/kvssptj/orion/releases/tag/v1.0.0
```

---

## Error Handling

- If `xcodebuild archive` fails, the workflow fails fast and no release is created
- If `create-dmg` fails, the workflow fails before the release is published
- The GitHub Release is only created after the DMG exists — no empty releases

---

## Testing the Pipeline

Before the first real release, test with a pre-release tag:
```bash
git tag v0.1.0-beta
git push --tags
```
Delete the test release from GitHub after verifying the DMG works.
