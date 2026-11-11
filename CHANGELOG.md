# Changelog

## [Unreleased]

- Route each file through an ordered list of converters that support its exact input/output pair, falling back to the next one (for example FFmpeg after the system video exporter) when a converter fails.
- Report unsupported input/output pairs before converting, and removed TSV, JSON and XML document outputs that no converter could produce.
- System image conversion now honors resizing and metadata stripping, keeps metadata when not stripping, and only writes multiple frames to formats that support them.
- System video export now really removes audio when requested.
- Cancelling a conversion now stops running external tools and system video exports.
- Pandoc now writes plain text for `.txt`, accepts DOCX/ODT/RTF input, and ImageMagick applies EXIF orientation.

## [0.1.34]

- Schedule large batches with bounded image, video, and document queues.
- Isolate conversion outputs and preserve existing files when names collide.
- Wait asynchronously for external tools and isolate concurrent LibreOffice jobs.

## [0.1.33]

- Aligned the single-category output format label and picker on one row in the sidebar.
- Made the settings sheet more compact with tighter section spacing, smaller controls, and reduced padding.

## [0.1.32]

- Kept the adaptive macOS UI layer from 0.1.30.
- Prevented GitHub Actions from republishing a tag when the release already has the final DMG, ZIP, and update manifest.
- Restored atomic asset creation for new GitHub releases to avoid local and CI release assets racing each other.

## [0.1.31]

- Kept the adaptive macOS UI layer from 0.1.30.
- Hardened GitHub release publishing so `latest.json` is regenerated from the final DMG SHA before upload.
- Split release asset uploads to reduce stale manifest risk when GitHub Actions republishes a tag.

## [0.1.30]

- Added adaptive macOS UI styling with Liquid Glass on macOS 26+ when built with a compatible SDK.
- Added native material fallbacks for older macOS versions and GitHub Actions' Swift 5.10 runner.
- Updated sidebar, settings, permission, about, result, and action surfaces to use the adaptive style layer.

## [0.1.29]

- Added a manual update dialog from the macOS ForCon menu.
- The update dialog now shows either an "更新版本" action when an update exists or "已是最新版本" when no update exists.
- Closing secondary windows before installing updates reduces the chance of sheets or auxiliary windows blocking app exit.

## [0.1.28]

- Fixed GitHub Actions test stability by skipping external-tool integration tests when optional local tools are not installed on the runner.

## [0.1.27]

- Fixed GitHub Actions Swift 5.10 build compatibility by marking SwiftUI views that access the main-actor view model as `@MainActor`.

## [0.1.26]

- Moved manual update installation to the macOS ForCon app menu.
- Removed the update install button from the Settings sheet to avoid sheet-driven termination issues.
- After scheduling an update install, ForCon now exits directly so the background installer can replace and reopen the app.
- Fixed GitHub Actions compatibility by using a Swift 5.10 package manifest and XCTest.

## [0.1.25]

- Added a conversion component status panel in Settings for ImageMagick, FFmpeg, Pandoc, and LibreOffice.
- Settings now remembers each section's expanded or collapsed state.
- Hardened the updater relaunch flow and added updater logs at `~/Library/Logs/ForConUpdater.log`.
- Improved the DMG `README.txt` with clearer Gatekeeper and privacy guidance.
- Added GitHub Actions release automation.
