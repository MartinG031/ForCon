import Foundation

public final class FormatConversionEngine: @unchecked Sendable {
    private let imageConverter = ImageConverter()
    private let videoConverter = VideoConverter()
    private let documentConverter = DocumentConverter()
    private let externalImageConverter = ExternalImageConverter()
    private let externalVideoConverter = ExternalVideoConverter()
    private let externalDocumentConverter = ExternalDocumentConverter()

    public init() {}

    public func supportedOutputs(for category: FormatCategory) -> [String] {
        switch category {
        case .automatic:
            Array(Set(Self.imageOutputs + Self.videoOutputs + Self.documentOutputs)).sorted()
        case .image:
            Self.imageOutputs
        case .video:
            Self.videoOutputs
        case .document:
            Self.documentOutputs
        }
    }

    public func detectedCategory(for url: URL) -> FormatCategory? {
        let ext = url.pathExtension.normalizedFileExtension
        if Self.imageInputs.contains(ext) { return .image }
        if Self.videoInputs.contains(ext) { return .video }
        if Self.documentInputs.contains(ext) { return .document }
        return nil
    }

    public func convert(_ request: ConversionRequest) async -> [ConversionResult] {
        await withTaskGroup(of: ConversionResult.self) { group in
            for inputURL in request.inputURLs {
                group.addTask {
                    await self.convertOne(inputURL, request: request)
                }
            }

            var results: [ConversionResult] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.inputURL.lastPathComponent < $1.inputURL.lastPathComponent }
        }
    }

    private func convertOne(_ inputURL: URL, request: ConversionRequest) async -> ConversionResult {
        do {
            let category = try resolvedCategory(for: inputURL, requested: request.category)
            let targetExtension = resolvedTargetExtension(for: category, request: request)
            try validateOutput(targetExtension, for: category)

            let outputURLs: [URL]
            switch category {
            case .image:
                let outputURL = try FileNamer.uniqueOutputURL(
                    inputURL: inputURL,
                    outputDirectory: request.outputDirectory,
                    targetExtension: targetExtension
                )
                if isNativeRoute(inputURL: inputURL, targetExtension: targetExtension, category: category) {
                    try imageConverter.convert(
                        inputURL: inputURL,
                        outputURL: outputURL,
                        targetExtension: targetExtension,
                        options: request.options
                    )
                } else {
                    try externalImageConverter.convert(
                        inputURL: inputURL,
                        outputURL: outputURL,
                        targetExtension: targetExtension,
                        options: request.options
                    )
                }
                outputURLs = [outputURL]
            case .video:
                let outputURL = try FileNamer.uniqueOutputURL(
                    inputURL: inputURL,
                    outputDirectory: request.outputDirectory,
                    targetExtension: targetExtension
                )
                if isNativeRoute(inputURL: inputURL, targetExtension: targetExtension, category: category) {
                    try await videoConverter.convert(
                        inputURL: inputURL,
                        outputURL: outputURL,
                        targetExtension: targetExtension,
                        options: request.options
                    )
                } else {
                    try externalVideoConverter.convert(
                        inputURL: inputURL,
                        outputURL: outputURL,
                        targetExtension: targetExtension,
                        options: request.options
                    )
                }
                outputURLs = [outputURL]
            case .document:
                if isNativeRoute(inputURL: inputURL, targetExtension: targetExtension, category: category) {
                    outputURLs = try documentConverter.convert(
                        inputURL: inputURL,
                        outputDirectory: request.outputDirectory,
                        targetExtension: targetExtension,
                        options: request.options
                    )
                } else {
                    outputURLs = try externalDocumentConverter.convert(
                        inputURL: inputURL,
                        outputDirectory: request.outputDirectory,
                        targetExtension: targetExtension
                    )
                }
            case .automatic:
                throw ConverterError.unsupportedInput(inputURL)
            }

            return ConversionResult(
                inputURL: inputURL,
                outputURLs: outputURLs,
                category: category,
                status: .succeeded
            )
        } catch {
            return ConversionResult(
                inputURL: inputURL,
                outputURLs: [],
                category: detectedCategory(for: inputURL) ?? request.category,
                status: .failed(error.localizedDescription)
            )
        }
    }

    private func resolvedCategory(for inputURL: URL, requested: FormatCategory) throws -> FormatCategory {
        let detected = detectedCategory(for: inputURL)
        if requested != .automatic {
            if let detected, detected != requested {
                throw ConverterError.categoryMismatch(inputURL, expected: requested, actual: detected)
            }
            return requested
        }
        guard let category = detected else {
            throw ConverterError.unsupportedInput(inputURL)
        }
        return category
    }

    private func validateOutput(_ targetExtension: String, for category: FormatCategory) throws {
        guard supportedOutputs(for: category).contains(targetExtension) else {
            throw ConverterError.unsupportedOutput(targetExtension, category: category)
        }
    }

    private func resolvedTargetExtension(for category: FormatCategory, request: ConversionRequest) -> String {
        if request.category == .automatic,
           let target = request.targetExtensionsByCategory[category],
           supportedOutputs(for: category).contains(target) {
            return target
        }
        return request.targetExtension
    }

    private func isNativeRoute(
        inputURL: URL,
        targetExtension: String,
        category: FormatCategory
    ) -> Bool {
        let ext = inputURL.pathExtension.normalizedFileExtension
        let nativeInput = switch category {
        case .image:
            Self.nativeImageInputs.contains(ext)
        case .video:
            Self.nativeVideoInputs.contains(ext)
        case .document:
            Self.nativeDocumentInputs.contains(ext)
        case .automatic:
            false
        }

        let nativeOutput = switch category {
        case .image:
            Self.nativeImageOutputs.contains(targetExtension)
        case .video:
            Self.nativeVideoOutputs.contains(targetExtension)
        case .document:
            Self.nativeDocumentOutputs.contains(targetExtension)
        case .automatic:
            false
        }

        return nativeInput && nativeOutput
    }
}

public extension FormatConversionEngine {
    static let nativeImageInputs = Set(["png", "jpg", "jpeg", "jpe", "jfif", "tif", "tiff", "gif", "bmp", "dib", "heic", "heif", "webp"])
    static let nativeImageOutputs = ["bmp", "gif", "heic", "jpeg", "jpg", "png", "tiff"]
    static let imageOutputs = [
        "avif", "bmp", "exr", "gif", "heic", "heif", "icns", "ico", "jpeg",
        "jp2", "jpg", "jxl", "pdf", "png", "svg", "tga", "tiff", "webp"
    ]
    static let imageInputs = nativeImageInputs.union([
        "avif", "jxl", "jp2", "j2k", "jpf", "svg", "svgz", "ico", "icns",
        "psd", "psb", "ai", "eps", "tga", "exr", "hdr", "dds",
        "raw", "dng", "cr2", "cr3", "nef", "nrw", "arw", "srf", "sr2",
        "raf", "orf", "rw2", "pef", "srw", "x3f", "erf", "kdc", "mrw"
    ])

    static let nativeVideoInputs = Set(["mov", "qt", "mp4", "m4v", "avi", "mpeg", "mpg", "mpe", "3gp", "3g2"])
    static let nativeVideoOutputs = ["m4v", "mov", "mp4"]
    static let videoOutputs = [
        "3gp", "avi", "flv", "m2ts", "m4v", "mkv", "mov", "mp4", "mpeg",
        "mpg", "ogv", "ts", "webm", "wmv"
    ]
    static let videoInputs = nativeVideoInputs.union([
        "mkv", "webm", "wmv", "asf", "flv", "f4v", "ogv", "ogg", "vob",
        "ts", "m2ts", "mts", "m2v", "divx", "dv", "mxf", "rm", "rmvb",
        "mod", "tod", "amv"
    ])

    static let nativeDocumentInputs = Set([
        "pdf", "txt", "text", "md", "markdown", "rtf", "html", "htm",
        "csv", "tsv", "json", "xml", "yaml", "yml", "toml", "log"
    ])
    static let nativeDocumentOutputs = ["html", "jpeg", "jpg", "pdf", "png", "rtf", "txt"]
    static let documentOutputs = [
        "csv", "doc", "docx", "epub", "html", "jpeg", "jpg", "json", "md",
        "odp", "ods", "odt", "pdf", "png", "ppt", "pptx", "rtf", "tsv",
        "txt", "xls", "xlsx", "xml"
    ]
    static let documentInputs = nativeDocumentInputs.union([
        "doc", "docx", "docm", "dot", "dotx", "odt", "ott", "pages",
        "xls", "xlsx", "xlsm", "ods", "numbers", "ppt", "pptx", "pptm",
        "pps", "ppsx", "odp", "key", "epub", "mobi", "azw", "azw3",
        "tex", "latex", "adoc", "asciidoc", "rst", "mhtml", "mht", "djvu"
    ])
}
