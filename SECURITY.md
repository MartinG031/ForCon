# Security

ForCon processes selected files locally on your Mac. It does not upload source files or converted output files to cloud services or third-party servers.

## Network Access

ForCon contacts GitHub Releases only when it checks for updates or installs an update. Update downloads are verified with the SHA-256 checksum published in `latest.json`.

## macOS Gatekeeper

Current public builds are ad-hoc signed and are not notarized with an Apple Developer ID. macOS may show a security warning on first launch. To open the app, use System Settings > Privacy & Security > Open Anyway, or right-click `ForCon.app` and choose Open.

## External Tools

Some conversions depend on tools installed on the local Mac, including ImageMagick, FFmpeg, Pandoc, and LibreOffice. ForCon can show their installation status in Settings.

## Reporting Issues

Use GitHub Issues for bugs, conversion failures, and security concerns:

https://github.com/MartinG031/ForCon/issues

