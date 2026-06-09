# Agent Guidance

## Project

This repository contains a native Swift macOS menu-bar app for local text translation through Ollama. Keep it macOS-only unless the user explicitly changes scope.

## Required Shell Wrapper

Always prefix shell commands with `rtk`.

Examples:

```bash
rtk swift test
rtk ./Scripts/build-app.sh
rtk git status --short
```

Use `rtk proxy <cmd>` only when the wrapper mangles flags, shell metacharacters, or multi-part commands.

## Development Rules

- Work from the repository root: `/Users/admin/personal/projects/ai/local-translator`.
- Prefer SwiftPM-compatible changes; the app is packaged by `Scripts/build-app.sh`.
- Do not commit generated `.build/` artifacts.
- Keep clipboard history session-only and in memory.
- Keep network traffic local to Ollama at `http://localhost:11434/api/chat`.
- Preserve the status-bar/no-Dock behavior through `LSUIElement`.
- Start at Login must remain user-controlled and off by default.

## Verification

Run these before handing off code changes:

```bash
rtk swift test
rtk ./Scripts/build-app.sh
rtk codesign --verify --deep --strict ".build/release/Local Translator.app"
```

Manual checks that cannot be fully automated from SwiftPM:

- Menu-bar icon appears after launch.
- `Option-Space` opens the translator from another app.
- Selected text capture restores the original clipboard.
- Clipboard fallback works without Accessibility permission.
- Missing Ollama or missing model shows a readable error.
