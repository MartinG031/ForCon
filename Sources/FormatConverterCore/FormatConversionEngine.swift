import Foundation

public final class FormatConversionEngine: Sendable {
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

    public func convert(
        _ request: ConversionRequest,
        onResult: (@Sendable (ConversionResult) async -> Void)? = nil
    ) async -> [ConversionResult] {
        let inputs = request.inputURLs.enumerated().map { index, url in
            BatchInput(index: index, url: url, category: detectedCategory(for: url))
        }
        let lanes = Dictionary(grouping: inputs) { input in
            request.category == .automatic ? input.category ?? .automatic : request.category
        }
        let processorCount = ProcessInfo.processInfo.activeProcessorCount

        return await withTaskGroup(of: (FormatCategory, Int, ConversionResult).self) { group in
            var pending = lanes.mapValues { $0.makeIterator() }

            func enqueueNext(in lane: FormatCategory) {
                guard let input = pending[lane]?.next() else { return }
                group.addTask {
                    let result = await self.convertOne(input, request: request)
                    return (lane, input.index, result)
                }
            }

            for lane in lanes.keys {
                let limit = switch lane {
                case .image: max(1, min(4, processorCount - 1))
                case .video, .document: max(1, min(2, processorCount / 2))
                case .automatic: 1
                }
                for _ in 0..<limit {
                    enqueueNext(in: lane)
                }
            }

            var results: [(index: Int, result: ConversionResult)] = []
            results.reserveCapacity(inputs.count)
            while let (lane, index, result) = await group.next() {
                enqueueNext(in: lane)
                results.append((index, result))
                if let onResult {
                    await onResult(result)
                }
            }
            return results.sorted {
                let lhs = $0.result.inputURL.lastPathComponent
                let rhs = $1.result.inputURL.lastPathComponent
                return lhs == rhs ? $0.index < $1.index : lhs < rhs
            }.map(\.result)
        }
    }

    private struct BatchInput: Sendable {
        let index: Int
        let url: URL
        let category: FormatCategory?
    }

    private func convertOne(_ input: BatchInput, request: ConversionRequest) async -> ConversionResult {
        do {
            try Task.checkCancellation()
            let category = try resolvedCategory(for: input, requested: request.category)
            let targetExtension = resolvedTargetExtension(for: category, request: request)
            try validateOutput(targetExtension, for: category)

            let backend = ConversionBackend(
                category: category,
                native: isNativeRoute(inputURL: input.url, targetExtension: targetExtension, category: category)
            )
            let output = try ConversionOutput(directory: request.outputDirectory)
            defer { output.discard() }
            let stagedFiles = try await backend.convert(
                inputURL: input.url,
                outputDirectory: output.stagingDirectory,
                targetExtension: targetExtension,
                options: request.options
            )
            try Task.checkCancellation()
            let outputURLs = try output.publish(stagedFiles)

            return ConversionResult(
                inputURL: input.url,
                outputURLs: outputURLs,
                category: category,
                status: .succeeded
            )
        } catch {
            return ConversionResult(
                inputURL: input.url,
                outputURLs: [],
                category: input.category ?? request.category,
                status: .failed(error.localizedDescription)
            )
        }
    }

    private func resolvedCategory(for input: BatchInput, requested: FormatCategory) throws -> FormatCategory {
        if requested != .automatic {
            if let detected = input.category, detected != requested {
                throw ConverterError.categoryMismatch(input.url, expected: requested, actual: detected)
            }
            return requested
        }
        guard let category = input.category else {
            throw ConverterError.unsupportedInput(input.url)
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
