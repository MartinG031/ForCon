# Design

## Architecture

The project is a Swift Package with two layers:

- `FormatConverterCore`: conversion models, category detection, file naming, and format-specific converters.
- `ForCon`: SwiftUI macOS app that handles selection, drag and drop, user options, progress, and result presentation.

This separation keeps the conversion engine testable and prevents UI state from leaking into format-specific logic.

## Conversion Backends

| Area | Framework | Reason |
| --- | --- | --- |
| Images | ImageIO, UniformTypeIdentifiers | Native, offline, broad macOS image support |
| Video | AVFoundation | Native export sessions and system codec support |
| PDF | PDFKit, AppKit | Native PDF text extraction and page rendering |
| Text/RTF/HTML | AppKit attributed strings | Good enough for first-release document conversion |

## Batch Behavior

`FormatConversionEngine.convert(_:)` returns one `ConversionResult` per input. Each result carries:

- input URL
- output URL list
- resolved category
- success or failure status

The engine uses a task group so independent conversions can run concurrently. Failures are captured per item instead of throwing out the whole batch.

## Output Naming

Outputs are written into the selected directory. Existing files are preserved by appending numeric suffixes:

- `photo.jpg`
- `photo-2.jpg`
- `photo-3.jpg`

PDF page image export uses page suffixes:

- `document-page-1.png`
- `document-page-2.png`

## Known Technical Limits

- AVFoundation only supports exports available for the input asset and current system codecs.
- ImageIO can read more image types than it can write; output validation intentionally exposes only known writable targets.
- Office files require a separate backend such as LibreOffice, Quick Look rendering, or a server-side document engine. They are not included in the dependency-free first release.
