#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_DIR="$(cd "$ROOT_DIR/.." && pwd)"
APP_NAME="ForCon"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
RELEASE_NAME="$APP_NAME-$VERSION"
TAG="v$VERSION"
OUTPUT_DIR="$PARENT_DIR/Release"

if [[ -z "${FORCON_GITHUB_REPOSITORY:-}" ]]; then
    echo "请先设置 FORCON_GITHUB_REPOSITORY，例如：MartinG031/ForCon" >&2
    exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "未找到 GitHub CLI：请先安装 gh 并登录。" >&2
    exit 2
fi

gh repo view "$FORCON_GITHUB_REPOSITORY" >/dev/null

FORCON_GITHUB_REPOSITORY="$FORCON_GITHUB_REPOSITORY" "$ROOT_DIR/scripts/package-release.sh"

NOTES_FILE="$(mktemp "${TMPDIR:-/tmp}/forcon-release-notes.XXXXXX.md")"
trap 'rm -f "$NOTES_FILE"' EXIT
if [[ -f "$ROOT_DIR/CHANGELOG.md" ]]; then
    awk -v version="$VERSION" '
        $0 ~ "^## \\[" version "\\]" || $0 ~ "^## " version {
            found = 1
            next
        }
        found && /^## / {
            exit
        }
        found {
            print
        }
    ' "$ROOT_DIR/CHANGELOG.md" > "$NOTES_FILE"
fi
if [[ ! -s "$NOTES_FILE" ]]; then
    echo "ForCon $VERSION" > "$NOTES_FILE"
fi

DMG_ASSET="$OUTPUT_DIR/$RELEASE_NAME.dmg"
ZIP_ASSET="$OUTPUT_DIR/$RELEASE_NAME.zip"
MANIFEST_ASSET="$OUTPUT_DIR/latest.json"
DMG_SHA256="$(shasum -a 256 "$DMG_ASSET" | awk '{print $1}')"
cat > "$MANIFEST_ASSET" <<JSON
{
  "version": "$VERSION",
  "downloadURL": "https://github.com/$FORCON_GITHUB_REPOSITORY/releases/latest/download/$RELEASE_NAME.dmg",
  "sha256": "$DMG_SHA256",
  "notes": "ForCon $VERSION"
}
JSON

if gh release view "$TAG" --repo "$FORCON_GITHUB_REPOSITORY" >/dev/null 2>&1; then
    gh release edit "$TAG" --repo "$FORCON_GITHUB_REPOSITORY" --title "$RELEASE_NAME" --notes-file "$NOTES_FILE" --latest
    gh release upload "$TAG" "$DMG_ASSET" "$ZIP_ASSET" --repo "$FORCON_GITHUB_REPOSITORY" --clobber
    gh release upload "$TAG" "$MANIFEST_ASSET" --repo "$FORCON_GITHUB_REPOSITORY" --clobber
else
    gh release create "$TAG" "$DMG_ASSET" "$ZIP_ASSET" "$MANIFEST_ASSET" --repo "$FORCON_GITHUB_REPOSITORY" --title "$RELEASE_NAME" --notes-file "$NOTES_FILE" --latest
fi

echo "https://github.com/$FORCON_GITHUB_REPOSITORY/releases/latest/download/latest.json"
echo "https://github.com/$FORCON_GITHUB_REPOSITORY/releases/latest/download/$RELEASE_NAME.dmg"
