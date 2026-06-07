import Foundation

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

enum ExternalTool {
    static func require(_ names: [String]) throws -> String {
        for name in names {
            if let path = findExecutable(name) {
                return path
            }
        }
        throw ExternalToolError.missing(names.joined(separator: " / "))
    }

    static func run(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment()

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
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

    private static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchPaths().joined(separator: ":")
        return env
    }
}
