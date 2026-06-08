#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_DIR="$(cd "$ROOT_DIR/.." && pwd)"
APP_NAME="ForCon"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
RELEASE_NAME="$APP_NAME-$VERSION"
OUTPUT_DIR="$PARENT_DIR/Release"
STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/forcon-release.XXXXXX")"
RELEASE_DIR="$STAGING_ROOT/$RELEASE_NAME"
trap 'rm -rf "$STAGING_ROOT"' EXIT

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/package-app.sh"
APP_CLEAN="$STAGING_ROOT/$APP_NAME.app"
ditto --norsrc "$ROOT_DIR/dist/$APP_NAME.app" "$APP_CLEAN"
codesign --force --deep --sign - "$APP_CLEAN"
codesign --verify --deep --strict --verbose=2 "$APP_CLEAN"

mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"/*.dmg "$OUTPUT_DIR"/*.zip
mkdir -p "$RELEASE_DIR"
ditto --norsrc "$APP_CLEAN" "$RELEASE_DIR/$APP_NAME.app"
ln -s /Applications "$RELEASE_DIR/Applications"

cat > "$RELEASE_DIR/README.txt" <<README
ForCon $VERSION

安装方式：
1. 把 ForCon.app 拖到 Applications 文件夹。
2. 从 Applications 打开 ForCon。

首次打开如遇到 macOS 安全提示：
1. 在提示窗口中选择“完成”或关闭提示。
2. 打开“系统设置 > 隐私与安全”。
3. 在安全性区域点击 ForCon 的“仍要打开”。
4. 或在 Finder 中右键 ForCon.app，选择“打开”。

功能：图片、视频、文档批量格式转换。

可信声明：
- ForCon 在本机处理文件，不上传到云端或第三方服务器。
- 输出文件只写入用户选择的输出目录。
- 只有检查或安装更新时才会读取 GitHub Releases 更新源。
- 下载的安装包会先做 SHA-256 校验。
- 转换能力来自 macOS 系统框架和本机安装的 ImageMagick、FFmpeg、Pandoc、LibreOffice。
- 可在 ForCon 设置中查看本机转换组件状态。
- 本发行包为本地 ad-hoc 签名；没有 Apple Developer ID 公证。
README

hdiutil create -volname "$APP_NAME" -srcfolder "$RELEASE_DIR" -ov -format UDZO "$OUTPUT_DIR/$RELEASE_NAME.dmg"
ditto -c -k --keepParent "$RELEASE_DIR" "$OUTPUT_DIR/$RELEASE_NAME.zip"
hdiutil verify "$OUTPUT_DIR/$RELEASE_NAME.dmg"
DMG_SHA256="$(shasum -a 256 "$OUTPUT_DIR/$RELEASE_NAME.dmg" | awk '{print $1}')"
if [[ -n "${FORCON_UPDATE_DOWNLOAD_URL:-}" ]]; then
    DOWNLOAD_URL="$FORCON_UPDATE_DOWNLOAD_URL"
elif [[ -n "${FORCON_GITHUB_REPOSITORY:-}" ]]; then
    DOWNLOAD_URL="https://github.com/$FORCON_GITHUB_REPOSITORY/releases/latest/download/$RELEASE_NAME.dmg"
else
    DOWNLOAD_URL="file://$OUTPUT_DIR/$RELEASE_NAME.dmg"
fi
cat > "$OUTPUT_DIR/latest.json" <<JSON
{
  "version": "$VERSION",
  "downloadURL": "$DOWNLOAD_URL",
  "sha256": "$DMG_SHA256",
  "notes": "ForCon $VERSION"
}
JSON
rm -rf "$ROOT_DIR/dist"

echo "$OUTPUT_DIR/$RELEASE_NAME.dmg"
echo "$OUTPUT_DIR/$RELEASE_NAME.zip"
