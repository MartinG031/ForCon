# Compatibility

ForCon tracks two levels of compatibility:

- Native conversion: handled today by macOS frameworks in the app.
- External backend conversion: handled by ImageMagick, FFmpeg, Pandoc, or LibreOffice when the native macOS route is not enough.
- Recognized format: common file type detected by the app. Some specialized formats still depend on the underlying external tool's codec support.

The format list is based on common formats described by Wikipedia pages for image formats, video formats, container formats, MP4, document formats, Office Open XML, OpenDocument, and the general list of file formats.

## Images

### Native Conversion Inputs

`png`, `jpg`, `jpeg`, `jpe`, `jfif`, `tif`, `tiff`, `gif`, `bmp`, `dib`, `heic`, `heif`, `webp`

### Output Formats Shown in App

`png`, `jpg`, `jpeg`, `webp`, `avif`, `heic`, `heif`, `tiff`, `gif`, `bmp`, `ico`, `icns`, `svg`, `pdf`, `jp2`, `jxl`, `tga`, `exr`

### Native Conversion Outputs

`png`, `jpg`, `jpeg`, `tiff`, `gif`, `bmp`, `heic`

### Recognized Common Inputs

`avif`, `jxl`, `jp2`, `j2k`, `jpf`, `svg`, `svgz`, `ico`, `icns`, `psd`, `psb`, `ai`, `eps`, `tga`, `exr`, `hdr`, `dds`, `raw`, `dng`, `cr2`, `cr3`, `nef`, `nrw`, `arw`, `srf`, `sr2`, `raf`, `orf`, `rw2`, `pef`, `srw`, `x3f`, `erf`, `kdc`, `mrw`

## Video

### Native Conversion Inputs

`mov`, `qt`, `mp4`, `m4v`, `avi`, `mpeg`, `mpg`, `mpe`, `3gp`, `3g2`

### Output Formats Shown in App

`mp4`, `mov`, `m4v`, `mkv`, `webm`, `avi`, `wmv`, `flv`, `ogv`, `mpeg`, `mpg`, `ts`, `m2ts`, `3gp`

### Native Conversion Outputs

`mov`, `mp4`, `m4v`

### Recognized Common Inputs

`mkv`, `webm`, `wmv`, `asf`, `flv`, `f4v`, `ogv`, `ogg`, `vob`, `ts`, `m2ts`, `mts`, `m2v`, `divx`, `dv`, `mxf`, `rm`, `rmvb`, `mod`, `tod`, `amv`

## Documents

### Native Conversion Inputs

`pdf`, `txt`, `text`, `md`, `markdown`, `rtf`, `html`, `htm`, `csv`, `tsv`, `json`, `xml`, `yaml`, `yml`, `toml`, `log`

### Output Formats Shown in App

`pdf`, `docx`, `doc`, `odt`, `rtf`, `txt`, `md`, `html`, `epub`, `pptx`, `ppt`, `odp`, `xlsx`, `xls`, `ods`, `csv`, `tsv`, `json`, `xml`, `png`, `jpg`, `jpeg`

### Native Conversion Outputs

`pdf`, `txt`, `rtf`, `html`, `png`, `jpg`, `jpeg`

### Recognized Common Inputs

`doc`, `docx`, `docm`, `dot`, `dotx`, `odt`, `ott`, `pages`, `xls`, `xlsx`, `xlsm`, `ods`, `numbers`, `ppt`, `pptx`, `pptm`, `pps`, `ppsx`, `odp`, `key`, `epub`, `mobi`, `azw`, `azw3`, `tex`, `latex`, `adoc`, `asciidoc`, `rst`, `mhtml`, `mht`, `djvu`

## External Backend Coverage

- FFmpeg: `mkv`, `webm`, `wmv`, `flv`, `vob`, `ts`, `m2ts`, `mxf`, `rmvb`, advanced `mp4/mov` transcoding.
- LibreOffice: `doc`, `docx`, `odt`, `xls`, `xlsx`, `ods`, `ppt`, `pptx`, `odp`.
- Pandoc: `md`, `rst`, `adoc`, `html`, `docx`, `epub`, `tex`.
- ImageMagick: `ico`, `webp`, `avif`, `heic`, `svg`, `psd`, `tga`, `exr`, broader raster conversion.

## Common Settings

- Image quality controls lossy formats such as `jpg`, `jpeg`, `webp`, `avif`, `heic`, and `heif`.
- Image max dimension resizes images through ImageMagick when enabled.
- Strip image metadata removes EXIF/profile metadata on ImageMagick routes.
- Video quality maps to FFmpeg CRF values and AVFoundation quality presets.
- Remove audio passes `-an` on FFmpeg routes and disables audio on native video export when possible.
- PDF image scale controls PDF page rendering resolution for `pdf -> png/jpg/jpeg`.

## Remaining Roadmap

- Apple Quick Look: `pages`, `numbers`, `key` preview-based PDF export when available.
