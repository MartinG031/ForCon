import Foundation

struct ExternalDocumentConverter {
    private static let libreOfficeTargets = Set([
        "pdf", "doc", "docx", "odt", "rtf", "html", "txt",
        "xls", "xlsx", "ods", "csv", "ppt", "pptx", "odp"
    ])
    private static let pandocTargets = Set(["docx", "odt", "rtf", "html", "txt", "md", "epub"])

    func convert(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String
    ) async throws -> [URL] {
        if shouldUsePandoc(inputURL: inputURL, targetExtension: targetExtension) {
            let outputURL = try FileNamer.uniqueOutputURL(
                inputURL: inputURL,
                outputDirectory: outputDirectory,
                targetExtension: targetExtension
            )
            let pandoc = try ExternalTool.require(["pandoc"])
            try await ExternalTool.run(pandoc, arguments: [inputURL.path, "-o", outputURL.path])
            return [outputURL]
        }

        if Self.libreOfficeTargets.contains(targetExtension) {
            return try await convertWithLibreOffice(
                inputURL: inputURL,
                outputDirectory: outputDirectory,
                targetExtension: targetExtension
            )
        }

        throw ConverterError.unsupportedOutput(targetExtension, category: .document)
    }

    private func shouldUsePandoc(inputURL: URL, targetExtension: String) -> Bool {
        let inputExtension = inputURL.pathExtension.normalizedFileExtension
        let pandocInputs = Set(["md", "markdown", "rst", "adoc", "asciidoc", "html", "htm", "txt", "tex", "latex", "epub"])
        return pandocInputs.contains(inputExtension) && Self.pandocTargets.contains(targetExtension)
    }

    private func convertWithLibreOffice(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String
    ) async throws -> [URL] {
        let soffice = try ExternalTool.require(["soffice", "libreoffice"])
        let profileURL = outputDirectory.appendingPathComponent("libreoffice-profile", isDirectory: true)
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
