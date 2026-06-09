---
name: local-translator
description: Use when working on this repository's Swift macOS menu-bar translator, including AppKit/SwiftUI UI, selected-text capture, Ollama streaming, login item behavior, packaging, and tests.
---

# Local Translator Skill

## Scope

Use this skill for changes in the `local-translator` repository. The app is a native macOS menu-bar utility that captures selected text or clipboard fallback and streams translation from local Ollama.

## Architecture Map

- `Sources/local-translator/App/`: app entry point and dependency wiring.
- `Sources/local-translator/Services/`: status-independent logic for hotkey, clipboard capture, login item, history, and Ollama.
- `Sources/local-translator/UI/`: AppKit controllers and SwiftUI views.
- `Sources/local-translator/ViewModels/`: translation coordination and presentation state.
- `Tests/local-translatorTests/`: Swift Testing coverage for prompt, history, error, model, and concurrency behavior.
- `Resources/Info.plist`: app bundle metadata, including `LSUIElement`.
- `Scripts/build-app.sh`: release build and `.app` packaging.

## Implementation Rules

- Keep selected-text capture focused on the source app until copy completes; do not show or activate the popup before capture.
- Always restore the previous pasteboard after selected-text capture.
- Treat translation as single-flight: cancel or ignore stale streams when a newer translation starts.
- Keep Settings and popup model fields backed by the same `TranslationViewModel.model`.
- Do not persist clipboard history.
- Do not add external network dependencies; Ollama is localhost only.
- Keep Start at Login disabled by default and controlled through `LoginItemService`.

## Verification

Before finishing:

```bash
rtk swift test
rtk ./Scripts/build-app.sh
rtk codesign --verify --deep --strict ".build/release/Local Translator.app"
```

For UI-sensitive changes, also launch:

```bash
rtk open ".build/release/Local Translator.app"
```

Then manually check status item, `Option-Space`, selected text capture, clipboard fallback, and readable Ollama errors.
