# ForCon

ForCon 是一款原生 macOS 格式转换工具，用于批量转换图片、视频和文档。

[下载最新版 ForCon](https://github.com/MartinG031/ForCon/releases/latest/download/ForCon-0.1.15.dmg)

## 主要功能

- 批量添加文件，支持拖拽。
- 自动识别图片、视频、文档类型。
- 自动模式下可为图片、视频、文档分别选择输出格式。
- 支持常用图片格式转换，例如 PNG、JPG、JPEG、TIFF、GIF、BMP、HEIC、WEBP、AVIF、ICO 等。
- 支持常用视频格式转换，例如 MP4、MOV、M4V、MKV、AVI、WEBM、3GP 等。
- 支持常用文档格式转换，例如 PDF、TXT、RTF、HTML、DOCX、ODT、EPUB、Markdown 等。
- 提供图片质量、图片尺寸、视频质量、移除音频、PDF 图片倍率等常用设置。
- 记住上一次选择的类型、输出格式、输出目录和常用设置。
- 支持 GitHub Releases 在线更新，下载后校验 SHA-256，并自动安装重启。

## 安装

1. 下载最新版 DMG。
2. 打开 DMG。
3. 将 `ForCon.app` 拖入 `Applications`。
4. 首次打开时，如果 macOS 提示安全确认，请右键 `ForCon.app`，选择“打开”。

## 使用方式

1. 点击“添加文件”，或直接把文件拖入窗口。
2. 选择“自动”“图片”“视频”或“文档”。
3. 选择输出格式。
4. 按需展开“常用设置”。
5. 选择输出目录。
6. 点击“开始转换”。

## 自动更新

点击侧边栏的“自动更新”后，ForCon 会：

- 从 GitHub Releases 读取更新清单。
- 下载新版 DMG。
- 校验 SHA-256。
- 自动替换 `/Applications/ForCon.app`。
- 自动重新打开新版 ForCon。

## 隐私与可信说明

- ForCon 在本机处理文件，不上传到云端或第三方服务器。
- 输出文件只写入用户选择的输出目录。
- 只有点击“自动更新”时才会访问 GitHub Releases。
- 下载的更新包会先做 SHA-256 校验。
- 当前发行包为本地 ad-hoc 签名，尚未使用 Apple Developer ID 公证。

## 转换能力说明

ForCon 会优先使用 macOS 系统能力处理常见转换。更广泛的图片、视频和文档格式依赖本机安装的转换工具，例如 ImageMagick、FFmpeg、Pandoc 和 LibreOffice。部分格式能否成功转换，仍取决于这些本机工具的编解码支持。

---

# ForCon

ForCon is a native macOS format converter for batch image, video, and document conversion.

[Download the latest ForCon release](https://github.com/MartinG031/ForCon/releases/latest/download/ForCon-0.1.15.dmg)

## Features

- Add files in batches, including drag and drop.
- Automatically detect image, video, and document files.
- In Auto mode, choose separate output formats for images, videos, and documents.
- Convert common image formats such as PNG, JPG, JPEG, TIFF, GIF, BMP, HEIC, WEBP, AVIF, and ICO.
- Convert common video formats such as MP4, MOV, M4V, MKV, AVI, WEBM, and 3GP.
- Convert common document formats such as PDF, TXT, RTF, HTML, DOCX, ODT, EPUB, and Markdown.
- Common settings for image quality, image size, video quality, audio removal, and PDF image scale.
- Remembers the last selected mode, output formats, output folder, and common settings.
- Supports GitHub Releases based online updates with SHA-256 verification, automatic installation, and restart.

## Installation

1. Download the latest DMG.
2. Open the DMG.
3. Drag `ForCon.app` into `Applications`.
4. On first launch, if macOS shows a security prompt, right-click `ForCon.app` and choose "Open".

## How To Use

1. Click "Add Files", or drag files into the window.
2. Choose Auto, Image, Video, or Document mode.
3. Choose the output format.
4. Adjust Common Settings if needed.
5. Choose an output folder.
6. Click Start Conversion.

## Auto Update

When you click Auto Update, ForCon will:

- Read the update manifest from GitHub Releases.
- Download the new DMG.
- Verify the SHA-256 checksum.
- Replace `/Applications/ForCon.app` automatically.
- Reopen the updated ForCon app.

## Privacy And Trust

- ForCon processes files locally on your Mac.
- Files are not uploaded to cloud services or third-party servers.
- Output files are written only to the folder you choose.
- GitHub Releases is contacted only when you click Auto Update.
- Downloaded update packages are verified with SHA-256 before installation.
- Current release builds are locally ad-hoc signed and are not notarized with an Apple Developer ID.

## Conversion Notes

ForCon uses macOS system capabilities for common conversions where possible. Broader image, video, and document support depends on locally installed tools such as ImageMagick, FFmpeg, Pandoc, and LibreOffice. Some formats may still depend on the codecs and import/export support available in those tools.
