import Foundation

final class ExternalDocumentConverter: @unchecked Sendable {
    private let libreOfficeTargets = Set([
        "pdf", "doc", "docx", "odt", "rtf", "html", "txt",
        "xls", "xlsx", "ods", "csv", "ppt", "pptx", "odp"
    ])
    private let pandocTargets = Set(["docx", "odt", "rtf", "html", "txt", "md", "epub"])

    func convert(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String
    ) throws -> [URL] {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        if shouldUsePandoc(inputURL: inputURL, targetExtension: targetExtension) {
            let outputURL = try FileNamer.uniqueOutputURL(
                inputURL: inputURL,
                outputDirectory: outputDirectory,
                targetExtension: targetExtension
            )
            try convertWithPandoc(inputURL: inputURL, outputURL: outputURL)
            return [outputURL]
        }

        if libreOfficeTargets.contains(targetExtension) {
            return try convertWithLibreOffice(
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
        return pandocInputs.contains(inputExtension) && pandocTargets.contains(targetExtension)
    }

    private func convertWithPandoc(inputURL: URL, outputURL: URL) throws {
        let pandoc = try ExternalTool.require(["pandoc"])
        try ExternalTool.run(pandoc, arguments: [inputURL.path, "-o", outputURL.path])
    }

    private func convertWithLibreOffice(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String
    ) throws -> [URL] {
        let soffice = try ExternalTool.require(["soffice", "libreoffice"])
        let before = Set(try FileManager.default.contentsOfDirectory(atPath: outputDirectory.path))
        try ExternalTool.run(
            soffice,
            arguments: [
                "--headless",
                "--convert-to",
                targetExtension,
                "--outdir",
                outputDirectory.path,
                inputURL.path
            ]
        )
        let after = Set(try FileManager.default.contentsOfDirectory(atPath: outputDirectory.path))
        let created = after.subtracting(before)
            .map { outputDirectory.appendingPathComponent($0) }
            .filter { $0.pathExtension.normalizedFileExtension == targetExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard let createdURL = created.first else {
            throw ConverterError.conversionFailed("LibreOffice 没有生成 .\(targetExtension) 文件")
        }

        let finalURL = try FileNamer.uniqueOutputURL(
            inputURL: inputURL,
            outputDirectory: outputDirectory,
            targetExtension: targetExtension
        )
        if createdURL != finalURL {
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            try FileManager.default.moveItem(at: createdURL, to: finalURL)
        }
        return [finalURL]
    }
}
