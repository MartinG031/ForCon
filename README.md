# ForCon

ForCon 是一个原生 macOS 格式转换工具，使用 SwiftUI 构建界面，将转换能力放在独立的 `FormatConverterCore` 模块中，便于测试和后续扩展。

## 当前能力

- 图片：`png`、`jpg/jpeg`、`tiff`、`gif`、`bmp`、`heic` 之间转换。
- 视频：通过 AVFoundation 导出 `mov`、`mp4`、`m4v`。
- 文档：文本类文件转换为 `pdf`、`txt`、`rtf`、`html`；PDF 可导出文本或按页渲染为 `png/jpg`。
- 扩展后端：ImageMagick、FFmpeg、Pandoc、LibreOffice。
- 支持批量文件、拖拽、输出目录选择、转换结果列表。
- 常用设置按类型分组：图片设置、视频设置、文档设置；侧边栏支持滚动，适配较小窗口。
- 自动更新按钮会读取 GitHub Releases 更新清单，下载新版 DMG 并校验 SHA-256。
- 会记住上一次选择的类型、各类型输出格式、输出目录和常用设置。
- 手动选择图片/视频/文档类型时，会拦截不匹配的文件，避免交给错误后端转换。
- 自动识别模式会按文件实际类型分别使用图片、视频、文档的输出格式，支持混合批量转换。
- 已加入常见图片、视频、文档输入和输出格式清单；完整列表见 `COMPATIBILITY.md`。

## 可信声明

- ForCon 在本机处理文件，不上传到云端或第三方服务器。
- 输出文件只写入用户选择的输出目录。
- 只有点击自动更新时才会读取更新源；下载的安装包会先做 SHA-256 校验。
- 转换能力来自 macOS 系统框架和本机安装的 ImageMagick、FFmpeg、Pandoc、LibreOffice。
- 发行包为本地 ad-hoc 签名；没有 Apple Developer ID 公证。

## 开发运行

```bash
cd macos-format-converter
swift build
swift test
swift run ForCon
```

`swift run` 会启动调试版 macOS 窗口。生成可双击运行的 `.app`：

```bash
scripts/package-app.sh
open dist/ForCon.app
```

生成正式发行包：

```bash
scripts/package-release.sh
```

生成指向 GitHub Releases 的发行包：

```bash
FORCON_GITHUB_REPOSITORY='MartinG031/ForCon' scripts/package-release.sh
```

直接发布到 GitHub Releases：

```bash
FORCON_GITHUB_REPOSITORY='MartinG031/ForCon' scripts/package-github-release.sh
```

GitHub 仓库需要是公开仓库，否则 App 无法免登录读取 `latest.json` 和下载 DMG。脚本会上传 `ForCon-版本号.dmg`、`ForCon-版本号.zip` 和 `latest.json` 到 `v版本号` Release。App 内更新源会指向：

```text
https://github.com/MartinG031/ForCon/releases/latest/download/latest.json
```

也可以手动指定任意线上更新源：

```bash
FORCON_UPDATE_MANIFEST_URL='https://example.com/forcon/latest.json' \
FORCON_UPDATE_DOWNLOAD_URL='https://example.com/forcon/ForCon-0.1.12.dmg' \
scripts/package-release.sh
```

更新清单格式：

```json
{
  "version": "0.1.12",
  "downloadURL": "https://github.com/MartinG031/ForCon/releases/latest/download/ForCon-0.1.12.dmg",
  "sha256": "DMG 的 SHA-256",
  "notes": "ForCon 0.1.12"
}
```

每次功能更新先修改 `VERSION`，发行脚本会用它更新 App 内版本号并生成对应名称的 DMG/ZIP；脚本会先清空旧发行包。
构建缓存和临时 app 包可用 `scripts/clean-generated.sh` 清理。

## 目录

- `Sources/FormatConverterCore/`：转换核心，不依赖界面状态。
- `Sources/ForCon/`：SwiftUI macOS 应用。
- `Tests/FormatConverterCoreTests/`：核心转换回归测试。
- `REQUIREMENTS.md`：需求说明。
- `DESIGN.md`：设计与技术决策。
- `PLAN.md`：开发计划。
- `COMPATIBILITY.md`：兼容格式清单。
- `VERSION`：当前发行版本号。

## 注意

视频转换优先使用系统 AVFoundation；更宽的图片、视频和文档格式会自动调用 Homebrew 安装的 ImageMagick、FFmpeg、Pandoc 或 LibreOffice。部分格式仍会受底层工具自身编解码支持限制。
