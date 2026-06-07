#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ForCon"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
if [[ -n "${FORCON_UPDATE_MANIFEST_URL:-}" ]]; then
    UPDATE_MANIFEST_URL="$FORCON_UPDATE_MANIFEST_URL"
elif [[ -n "${FORCON_GITHUB_REPOSITORY:-}" ]]; then
    UPDATE_MANIFEST_URL="https://github.com/$FORCON_GITHUB_REPOSITORY/releases/latest/download/latest.json"
else
    UPDATE_MANIFEST_URL="file://$ROOT_DIR/../Release/latest.json"
fi
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/make-icon.sh"
swift build -c release --product "$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>ForCon</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>local.codex.ForCon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ForCon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>${VERSION//./}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>ForConUpdateManifestURL</key>
    <string>$UPDATE_MANIFEST_URL</string>
</dict>
</plist>
PLIST

echo "$APP_DIR"
