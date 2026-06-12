#!/usr/bin/env bash
set -euo pipefail

swift build -c release

APP_DIR=".build/release/Local Translator.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp .build/release/local-translator "$MACOS_DIR/local-translator"
cp Resources/Info.plist "$CONTENTS_DIR/Info.plist"

if command -v codesign >/dev/null 2>&1; then
    SIGN_IDENTITY="${LOCAL_TRANSLATOR_CODESIGN_IDENTITY:-}"

    if [[ -z "$SIGN_IDENTITY" ]] && command -v security >/dev/null 2>&1; then
        SIGN_IDENTITY="$(
            security find-identity -v -p codesigning \
                | awk -F '"' '
                    /"3rd Party Mac Developer Application:/ { print $2; exit }
                    /"Developer ID Application:/ { print $2; exit }
                    /"Apple Development:/ { fallback = fallback ? fallback : $2 }
                    /"Mac Developer:/ { fallback = fallback ? fallback : $2 }
                    END { if (fallback) print fallback }
                '
        )"
    fi

    if [[ -n "$SIGN_IDENTITY" ]]; then
        echo "Signing with identity: $SIGN_IDENTITY" >&2
        codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
    else
        echo "warning: no code-signing identity found; using ad-hoc signing, Accessibility permission may reset after rebuilds" >&2
        codesign --force --deep --sign - "$APP_DIR" >/dev/null
    fi
fi

echo "$APP_DIR"
