# Local Translator

Native macOS menu-bar translator backed by local Ollama.

## Features

- Persistent menu-bar icon with no Dock icon.
- Global shortcuts: `Option-Space` translates, `Command-Option-R` rewrites.
- Selected-text capture by temporary copy, with clipboard restoration.
- Clipboard fallback when no selection is available or Accessibility permission is missing.
- Floating translator popup with source preview, English notes, Vietnamese translation, and session history.
- Session-only clipboard history capped at 20 deduplicated items.
- Streaming Ollama chat responses from `http://localhost:11434/api/chat`.
- User-controlled Start at Login, disabled by default.

## Requirements

- macOS 13 or newer.
- Xcode command line tools with SwiftPM.
- Ollama running locally.
- Default model:

```bash
ollama pull qwen2.5:7b
ollama serve
```

The model can be changed from the popup or Settings.

## Build And Run

```bash
swift test
./Scripts/build-app.sh
open ".build/release/Local Translator.app"
```

The app uses `http://localhost:11434/api/chat` and defaults to `qwen2.5:7b`.

## Usage

1. Launch the app.
2. Grant Accessibility permission when prompted if selected-text capture is needed.
3. Select text in another app and press `Option-Space` to translate or `Command-Option-R` to rewrite.
4. If no selected text is captured, the app translates current clipboard text.
5. Use the menu-bar icon for Open Translator, Clipboard History, Settings, Start at Login, and Quit.

## Development

Run verification before handing off changes:

```bash
swift test
./Scripts/build-app.sh
codesign --verify --deep --strict ".build/release/Local Translator.app"
```

Project notes for future agents live in `AGENTS.md`. A compact project skill is available at `docs/skills/local-translator/SKILL.md`.

## Repository

SSH remote for the public GitHub repository:

```bash
phanbaohuy96:phanbaohuy96/local-translator.git
```
