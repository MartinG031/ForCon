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
    let message: String
    let downloadedURL: URL?
}

enum UpdateError: Error, LocalizedError {
    case missingManifestURL
    case invalidDownload
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .missingManifestURL:
            "未配置更新源。"
        case .invalidDownload:
            "更新包下载失败。"
        case .checksumMismatch:
            "更新包校验失败，已停止安装。"
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
                message: "当前已是最新版本 \(currentVersion)。",
                downloadedURL: nil
            )
        }

        let downloadedURL = try await download(manifest)
        return UpdateCheckResult(
            didDownload: true,
            message: "已下载 ForCon \(manifest.version)，请按提示安装。",
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
