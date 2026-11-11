import Foundation

struct ExternalDocumentConverter {
    static let pandocInputs = Set([
        "md", "markdown", "rst", "html", "htm", "txt", "text", "tex", "latex",
        "epub", "docx", "odt", "rtf"
    ])
    static let pandocTargets = Set(["docx", "odt", "rtf", "html", "txt", "md", "epub"])

    static let libreOfficeInputs = Set([
        "doc", "docx", "docm", "dot", "dotx", "odt", "ott", "pages", "rtf", "txt", "text",
        "html", "htm", "mhtml", "mht", "xls", "xlsx", "xlsm", "ods", "numbers", "csv", "tsv",
        "ppt", "pptx", "pptm", "pps", "ppsx", "odp", "key"
    ])
    static let libreOfficeTargets = Set([
        "pdf", "doc", "docx", "odt", "rtf", "html", "txt",
        "xls", "xlsx", "ods", "csv", "ppt", "pptx", "odp"
    ])

    func convertWithPandoc(inputURL: URL, outputURL: URL) async throws -> [URL] {
        let pandoc = try ExternalTool.require(["pandoc"])
        var arguments = [inputURL.path, "-o", outputURL.path]
        if outputURL.pathExtension.normalizedFileExtension == "txt" {
            arguments.append(contentsOf: ["-t", "plain"])
        }
        try await ExternalTool.run(pandoc, arguments: arguments)
        return [outputURL]
    }

    func convertWithLibreOffice(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String
    ) async throws -> [URL] {
        let soffice = try ExternalTool.require(["soffice", "libreoffice"])
        let profileURL = outputDirectory.appendingPathComponent("libreoffice-profile", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: profileURL) }
        try await ExternalTool.run(
            soffice,
            arguments: [
                "-env:UserInstallation=\(profileURL.absoluteString)",
                "--headless",
                "--convert-to",
                targetExtension,
                "--outdir",
                outputDirectory.path,
                inputURL.path
            ]
        )
        let outputURL = outputDirectory
            .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(targetExtension)
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw ConverterError.conversionFailed("LibreOffice 没有生成 .\(targetExtension) 文件")
        }

        return [outputURL]
    }
}
