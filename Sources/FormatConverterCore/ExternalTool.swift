import Foundation

public struct ExternalToolStatus: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
    public let purpose: String
    public let executablePath: String?
    public let installHint: String

    public var isInstalled: Bool {
        executablePath != nil
    }

    public init(
        name: String,
        displayName: String,
        purpose: String,
        executablePath: String?,
        installHint: String
    ) {
        self.id = name
        self.name = name
        self.displayName = displayName
        self.purpose = purpose
        self.executablePath = executablePath
        self.installHint = installHint
    }
}

enum ExternalToolError: Error, LocalizedError {
    case missing(String)
    case failed(tool: String, message: String)

    var errorDescription: String? {
        switch self {
        case .missing(let tool):
            "缺少转换组件：\(tool)。请先安装后再转换该格式。"
        case .failed(let tool, let message):
            "\(tool) 转换失败：\(message)"
        }
    }
}

public enum ExternalTool {
    public static func requiredToolStatuses() -> [ExternalToolStatus] {
        [
            status(
                name: "imagemagick",
                displayName: "ImageMagick",
                purpose: "扩展图片格式转换，例如 AVIF、WEBP、ICO、SVG 等",
                executableNames: ["magick", "convert"],
                installHint: "brew install imagemagick"
            ),
            status(
                name: "ffmpeg",
                displayName: "FFmpeg",
                purpose: "扩展视频格式转换，例如 MKV、WEBM、AVI、3GP 等",
                executableNames: ["ffmpeg"],
                installHint: "brew install ffmpeg"
            ),
            status(
                name: "pandoc",
                displayName: "Pandoc",
                purpose: "扩展 Markdown、HTML、DOCX、EPUB 等文档转换",
                executableNames: ["pandoc"],
                installHint: "brew install pandoc"
            ),
            status(
                name: "libreoffice",
                displayName: "LibreOffice",
                purpose: "扩展 Office 文档导入导出，例如 DOCX、ODT、XLSX 等",
                executableNames: ["soffice"],
                installHint: "brew install --cask libreoffice"
            )
        ]
    }

    static func require(_ names: [String]) throws -> String {
        for name in names {
            if let path = findExecutable(name) {
                return path
            }
        }
        throw ExternalToolError.missing(names.joined(separator: " / "))
    }

    static func run(_ executable: String, arguments: [String]) throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("forcon-tool-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logURL)
        defer {
            try? logHandle.close()
            try? FileManager.default.removeItem(at: logURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment()
        process.standardOutput = logHandle
        process.standardError = logHandle

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            try? logHandle.synchronize()
            let data = (try? Data(contentsOf: logURL)) ?? Data()
            let output = String(data: data.suffix(16_384), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ExternalToolError.failed(
                tool: URL(fileURLWithPath: executable).lastPathComponent,
                message: output?.isEmpty == false ? output! : "退出码 \(process.terminationStatus)"
            )
        }
    }

    private static func findExecutable(_ name: String) -> String? {
        let candidates = searchPaths().map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func searchPaths() -> [String] {
        var paths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/Applications/LibreOffice.app/Contents/MacOS"
        ]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            paths.append(contentsOf: path.split(separator: ":").map(String.init))
        }
        return Array(NSOrderedSet(array: paths)) as? [String] ?? paths
    }

    private static func status(
        name: String,
        displayName: String,
        purpose: String,
        executableNames: [String],
        installHint: String
    ) -> ExternalToolStatus {
        ExternalToolStatus(
            name: name,
            displayName: displayName,
            purpose: purpose,
            executablePath: executableNames.compactMap(findExecutable).first,
            installHint: installHint
        )
    }

    private static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchPaths().joined(separator: ":")
        return env
    }
}
