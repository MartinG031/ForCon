import Foundation

/// One concrete converter that can turn a given input extension into a target extension.
/// The engine plans an ordered list of routes per file and falls back to the next route
/// when one fails, so native converters are tried first and external tools cover the rest.
enum ConversionRoute: String, CaseIterable, Sendable {
    case nativeImage
    case imageMagick
    case nativeVideo
    case ffmpeg
    case nativeDocument
    case pandoc
    case libreOffice

    var displayName: String {
        switch self {
        case .nativeImage: "系统图片编码器"
        case .imageMagick: "ImageMagick"
        case .nativeVideo: "系统视频导出器"
        case .ffmpeg: "FFmpeg"
        case .nativeDocument: "系统文档转换"
        case .pandoc: "Pandoc"
        case .libreOffice: "LibreOffice"
        }
    }

    var category: FormatCategory {
        switch self {
        case .nativeImage, .imageMagick: .image
        case .nativeVideo, .ffmpeg: .video
        case .nativeDocument, .pandoc, .libreOffice: .document
        }
    }

    func canConvert(inputExtension input: String, targetExtension output: String) -> Bool {
        typealias Engine = FormatConversionEngine
        switch self {
        case .nativeImage:
            return Engine.nativeImageInputs.contains(input) && Engine.nativeImageOutputs.contains(output)
        case .imageMagick:
            return Engine.imageInputs.contains(input) && Engine.imageOutputs.contains(output)
        case .nativeVideo:
            return Engine.nativeVideoInputs.contains(input) && Engine.nativeVideoOutputs.contains(output)
        case .ffmpeg:
            return Engine.videoInputs.contains(input) && Engine.videoOutputs.contains(output)
        case .nativeDocument:
            return DocumentConverter.canConvert(inputExtension: input, targetExtension: output)
        case .pandoc:
            return ExternalDocumentConverter.pandocInputs.contains(input)
                && ExternalDocumentConverter.pandocTargets.contains(output)
        case .libreOffice:
            return ExternalDocumentConverter.libreOfficeInputs.contains(input)
                && ExternalDocumentConverter.libreOfficeTargets.contains(output)
        }
    }

    /// Routes for one file, in the order they should be attempted.
    static func plan(category: FormatCategory, inputExtension: String, targetExtension: String) -> [ConversionRoute] {
        allCases.filter {
            $0.category == category
                && $0.canConvert(inputExtension: inputExtension, targetExtension: targetExtension)
        }
    }

    func convert(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String,
        options: ConversionOptions
    ) async throws -> [URL] {
        let outputURL = outputDirectory
            .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(targetExtension)

        switch self {
        case .nativeImage:
            try ImageConverter().convert(
                inputURL: inputURL, outputURL: outputURL, targetExtension: targetExtension, options: options
            )
        case .imageMagick:
            return try await ExternalImageConverter().convert(
                inputURL: inputURL, outputURL: outputURL, targetExtension: targetExtension, options: options
            )
        case .nativeVideo:
            try await VideoConverter().convert(
                inputURL: inputURL, outputURL: outputURL, targetExtension: targetExtension, options: options
            )
        case .ffmpeg:
            try await ExternalVideoConverter().convert(
                inputURL: inputURL, outputURL: outputURL, targetExtension: targetExtension, options: options
            )
        case .nativeDocument:
            return try DocumentConverter().convert(
                inputURL: inputURL, outputDirectory: outputDirectory, targetExtension: targetExtension, options: options
            )
        case .pandoc:
            return try await ExternalDocumentConverter().convertWithPandoc(
                inputURL: inputURL, outputURL: outputURL
            )
        case .libreOffice:
            return try await ExternalDocumentConverter().convertWithLibreOffice(
                inputURL: inputURL, outputDirectory: outputDirectory, targetExtension: targetExtension
            )
        }

        return [outputURL]
    }
}
