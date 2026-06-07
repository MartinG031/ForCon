# Requirements

## Product Goal

Build a local macOS format conversion utility for common image, video, and document workflows. The first release should be useful without network access and should rely on Apple system frameworks where possible.

## Users

- macOS users who need quick one-off or batch conversion.
- Users who prefer a simple desktop UI instead of command-line tools.
- Developers who may later add more conversion backends.

## Functional Requirements

1. Select multiple files through the file picker.
2. Accept file drops from Finder.
3. Choose conversion category: automatic, image, video, document.
4. Choose output directory.
5. Choose target extension based on category.
6. Convert files in batch and keep successful outputs even if another file fails.
7. Show per-file success or failure.
8. Open the output directory after conversion.

## Format Scope

ForCon maintains a broad recognition list for popular formats and a narrower native-conversion list for formats currently supported by macOS framework backends. See `COMPATIBILITY.md` for the full list.

### Images

- Native inputs: `png`, `jpg`, `jpeg`, `tif`, `tiff`, `gif`, `bmp`, `heic`, `heif`, `webp`.
- Outputs: `png`, `jpg`, `jpeg`, `tiff`, `gif`, `bmp`, `heic`.
- Recognized popular inputs include `avif`, `jxl`, `jp2`, `svg`, `ico`, `icns`, `psd`, `ai`, `eps`, `tga`, `exr`, and common camera raw formats.

### Video

- Native inputs: `mov`, `mp4`, `m4v`, `avi`, `mpeg`, `mpg`, `3gp`, `3g2`.
- Outputs: `mov`, `mp4`, `m4v`.
- Recognized popular inputs include `mkv`, `webm`, `wmv`, `flv`, `f4v`, `ogv`, `vob`, `ts`, `m2ts`, `mts`, `divx`, `dv`, `mxf`, `rm`, and `rmvb`.

### Documents

- Native inputs: `pdf`, `txt`, `md`, `markdown`, `rtf`, `html`, `htm`, `csv`, `tsv`, `json`, `xml`, `yaml`, `yml`, `toml`, `log`.
- Outputs: `pdf`, `txt`, `rtf`, `html`, `png`, `jpg`, `jpeg`.
- PDF page image export emits one output file per page.
- Recognized popular inputs include Microsoft Office, OpenDocument, Apple iWork, EPUB, TeX, AsciiDoc, reStructuredText, MHTML, and DjVu formats.

## Non-Functional Requirements

- Core conversion logic must be testable without launching the UI.
- Batch conversion should not stop at the first failed file.
- The app should be fully local and avoid uploading user files.
- The first version should not introduce external binary dependencies.

## Out of Scope for First Release

- DRM-protected media.
- Actual conversion for recognized formats that need optional external backends, such as Office, OpenDocument, EPUB, MKV/WebM, AVIF/JPEG XL, and camera raw.
- OCR for scanned PDFs.
- Advanced video transcoding controls such as bitrate, frame rate, subtitles, and audio track selection.
