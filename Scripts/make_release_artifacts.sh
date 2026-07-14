#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/Scripts/fetch_runtime_arm64.sh"
"$ROOT/Scripts/package_app.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/dist/MirrorMac.app/Contents/Info.plist")"
ARCHIVE="$ROOT/dist/MirrorMac-${VERSION}-macos-arm64.zip"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
(cd "$ROOT/dist" && ditto -c -k --sequesterRsrc --keepParent "MirrorMac.app" "$(basename "$ARCHIVE")")
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
echo "Created $ARCHIVE"
echo "Created $ARCHIVE.sha256"
