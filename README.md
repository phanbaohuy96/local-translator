# Local Translator

Native macOS menu-bar translator backed by local Ollama.

## Build

```bash
swift test
./Scripts/build-app.sh
open ".build/release/Local Translator.app"
```

The app uses `http://localhost:11434/api/chat` and defaults to `qwen2.5:7b`.

## Behavior

- Status-bar app with no Dock icon.
- Global shortcut: Option-Space.
- Selected text capture via temporary copy, with clipboard restoration.
- Clipboard fallback when there is no selected text or Accessibility permission is missing.
- Session-only clipboard history, capped at 20 deduplicated items.
- Start at Login is off by default and user-controlled from the menu or settings.
