#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="$ROOT_DIR/Assets"
ICONSET_DIR="$ASSETS_DIR/AppIcon.iconset"
MASTER_PNG="$ASSETS_DIR/AppIcon-1024.png"

mkdir -p "$ASSETS_DIR" "$ICONSET_DIR"

swift "$ROOT_DIR/scripts/render-icon.swift" "$MASTER_PNG"

sips -z 16 16 "$MASTER_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$MASTER_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$MASTER_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$MASTER_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$MASTER_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$MASTER_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$MASTER_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$MASTER_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$MASTER_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$MASTER_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$ASSETS_DIR/AppIcon.icns"
