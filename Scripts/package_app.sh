#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="$ROOT/Sources/MirrorMacApp/Resources/Runtime"
swift build --disable-sandbox --package-path "$ROOT" -c release
BIN_DIR="$(swift build --disable-sandbox --package-path "$ROOT" -c release --show-bin-path)"
APP="$ROOT/dist/MirrorMac.app"

for runtime in scrcpy adb scrcpy-server; do
    if [[ ! -f "$RUNTIME_DIR/$runtime" ]]; then
        echo "Missing runtime file: $RUNTIME_DIR/$runtime" >&2
        echo "Run ./Scripts/fetch_runtime_arm64.sh first." >&2
        exit 1
    fi
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/App/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN_DIR/MirrorMac" "$APP/Contents/MacOS/MirrorMac"
cp -R "$BIN_DIR/MirrorMac_MirrorMacApp.bundle" "$APP/"

chmod +x "$APP/Contents/MacOS/MirrorMac"
echo "Packaged $APP"
