#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="4.1"
URL="https://github.com/Genymobile/scrcpy/releases/download/v${VERSION}/scrcpy-macos-aarch64-v${VERSION}.tar.gz"
DEST="$ROOT/Sources/MirrorMacApp/Resources/Runtime"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DEST"
curl -L "$URL" -o "$TMP/scrcpy.tar.gz"
tar -xzf "$TMP/scrcpy.tar.gz" -C "$TMP"

PACKAGE_DIR="$(find "$TMP" -maxdepth 1 -type d -name 'scrcpy-*' -print -quit)"
cp "$PACKAGE_DIR/scrcpy" "$DEST/scrcpy"
cp "$PACKAGE_DIR/adb" "$DEST/adb"
cp "$PACKAGE_DIR/scrcpy-server" "$DEST/scrcpy-server"
chmod +x "$DEST/scrcpy" "$DEST/adb"

echo "Runtime copied to $DEST"
