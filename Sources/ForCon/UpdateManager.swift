import CryptoKit
import Foundation

struct UpdateManifest: Decodable {
    let version: String
    let downloadURL: URL
    let sha256: String?
    let notes: String?
}

struct UpdateCheckResult {
    let didDownload: Bool
    let shouldRestart: Bool
    let message: String
    let downloadedURL: URL?
}

enum UpdateError: Error, LocalizedError {
    case missingManifestURL
    case invalidDownload
    case checksumMismatch
    case appNotFoundInDiskImage
    case cannotMountDiskImage
    case cannotScheduleInstall(String)

    var errorDescription: String? {
        switch self {
        case .missingManifestURL:
            "未配置更新源。"
        case .invalidDownload:
            "更新包下载失败。"
        case .checksumMismatch:
            "更新包校验失败，已停止安装。"
        case .appNotFoundInDiskImage:
            "更新包中没有找到 ForCon.app。"
        case .cannotMountDiskImage:
            "无法挂载更新包。"
        case .cannotScheduleInstall(let reason):
            "无法自动安装更新：\(reason)"
        }
    }
}

final class UpdateManager: Sendable {
    func checkForUpdates() async throws -> UpdateCheckResult {
        let manifest = try await loadManifest()
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        guard Self.compare(manifest.version, currentVersion) == .orderedDescending else {
            return UpdateCheckResult(
                didDownload: false,
                shouldRestart: false,
                message: "当前已是最新版本 \(currentVersion)。",
                downloadedURL: nil
            )
        }

        let downloadedURL = try await download(manifest)
        try installDownloadedApp(from: downloadedURL)
        return UpdateCheckResult(
            didDownload: true,
            shouldRestart: true,
            message: "已下载 ForCon \(manifest.version)，即将自动安装并重启。",
            downloadedURL: downloadedURL
        )
    }

    private func loadManifest() async throws -> UpdateManifest {
        guard let url = manifestURL() else {
            throw UpdateError.missingManifestURL
        }
        let data: Data
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            let (remoteData, _) = try await URLSession.shared.data(from: url)
            data = remoteData
        }
        return try JSONDecoder().decode(UpdateManifest.self, from: data)
    }

    private func download(_ manifest: UpdateManifest) async throws -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let destination = downloads.appendingPathComponent("ForCon-\(manifest.version).dmg")

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        if manifest.downloadURL.isFileURL {
            try FileManager.default.copyItem(at: manifest.downloadURL, to: destination)
        } else {
            let (temporaryURL, _) = try await URLSession.shared.download(from: manifest.downloadURL)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
        }

        if let expected = manifest.sha256, !expected.isEmpty {
            let actual = try sha256(of: destination)
            guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
                try? FileManager.default.removeItem(at: destination)
                throw UpdateError.checksumMismatch
            }
        }

        return destination
    }

    private func manifestURL() -> URL? {
        if let override = UserDefaults.standard.string(forKey: "settings.updateManifestURL"),
           let url = URL(string: override), !override.isEmpty {
            return url
        }

        guard let value = Bundle.main.infoDictionary?["ForConUpdateManifestURL"] as? String,
              !value.isEmpty else {
            return nil
        }
        return URL(string: value)
    }

    private func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func installDownloadedApp(from diskImageURL: URL) throws {
        let mountPoint = try mount(diskImageURL)
        let sourceApp = mountPoint.appendingPathComponent("ForCon.app")
        guard FileManager.default.fileExists(atPath: sourceApp.path) else {
            try? detach(mountPoint)
            throw UpdateError.appNotFoundInDiskImage
        }

        let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let stagingApp = applications.appendingPathComponent(".ForCon.app.installing")
        let targetApp = applications.appendingPathComponent("ForCon.app")

        do {
            if FileManager.default.fileExists(atPath: stagingApp.path) {
                try FileManager.default.removeItem(at: stagingApp)
            }
            try FileManager.default.copyItem(at: sourceApp, to: stagingApp)
            try launchInstallerScript(
                stagingApp: stagingApp,
                targetApp: targetApp,
                mountPoint: mountPoint,
                diskImageURL: diskImageURL
            )
        } catch {
            try? FileManager.default.removeItem(at: stagingApp)
            try? detach(mountPoint)
            throw UpdateError.cannotScheduleInstall(error.localizedDescription)
        }
    }

    private func mount(_ diskImageURL: URL) throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", diskImageURL.path, "-nobrowse", "-readonly"]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UpdateError.cannotMountDiskImage
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        guard let mountPath = text
            .split(separator: "\n")
            .compactMap({ line -> String? in
                guard let range = line.range(of: "/Volumes/") else { return nil }
                return String(line[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            })
            .last else {
            throw UpdateError.cannotMountDiskImage
        }
        return URL(fileURLWithPath: mountPath, isDirectory: true)
    }

    private func detach(_ mountPoint: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint.path, "-quiet"]
        try process.run()
        process.waitUntilExit()
    }

    private func launchInstallerScript(
        stagingApp: URL,
        targetApp: URL,
        mountPoint: URL,
        diskImageURL: URL
    ) throws {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("forcon-install-\(UUID().uuidString).zsh")
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let script = """
        #!/bin/zsh
        set -e
        pid="$1"
        staging="$2"
        target="$3"
        mount="$4"
        dmg="$5"

        while kill -0 "$pid" 2>/dev/null; do
            sleep 0.2
        done

        rm -rf "$target"
        mv "$staging" "$target"
        xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
        open "$target"
        hdiutil detach "$mount" -quiet 2>/dev/null || true
        rm -f "$dmg" 2>/dev/null || true
        rm -f "$0" 2>/dev/null || true
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            scriptURL.path,
            "\(currentPID)",
            stagingApp.path,
            targetApp.path,
            mountPoint.path,
            diskImageURL.path
        ]
        try process.run()
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let lValue = index < left.count ? left[index] : 0
            let rValue = index < right.count ? right[index] : 0
            if lValue < rValue { return .orderedAscending }
            if lValue > rValue { return .orderedDescending }
        }
        return .orderedSame
    }
}
