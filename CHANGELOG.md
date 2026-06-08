# Changelog

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
