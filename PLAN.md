# Development Plan

## Phase 1: Discovery and Scope

- Define supported categories and file formats.
- Prefer macOS system frameworks to avoid external installers.
- Split core conversion from UI.

## Phase 2: Core MVP

- Implement category detection.
- Implement safe output naming.
- Implement image conversion through ImageIO.
- Implement video conversion through AVFoundation.
- Implement text/PDF document conversions.
- Add regression tests for category detection, image conversion, and text-to-PDF conversion.

## Phase 3: macOS UI

- Build SwiftUI app shell.
- Add file picker and drag-and-drop.
- Add category and target format controls.
- Add output directory picker.
- Add batch progress and results.

## Phase 4: Verification

- Run `swift build`.
- Run `swift test`.
- Launch with `swift run ForCon` for manual UI verification.
- Package with `scripts/package-app.sh`.

## Phase 5: Future Work

- Add command-line mode for automation.
- Add `.app` packaging and signing workflow.
- Harden LibreOffice, FFmpeg, ImageMagick, and Pandoc format-specific edge cases.
- Add advanced video options.
- Add PDF OCR through Vision.
