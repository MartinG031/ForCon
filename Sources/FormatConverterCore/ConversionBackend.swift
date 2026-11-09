import Foundation

struct ConversionBackend {
    let category: FormatCategory
    let native: Bool

    func convert(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String,
        options: ConversionOptions
    ) async throws -> [URL] {
        let outputURL = outputDirectory
            .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(targetExtension)

        switch (category, native) {
        case (.image, true):
            try ImageConverter().convert(
                inputURL: inputURL, outputURL: outputURL, targetExtension: targetExtension, options: options
            )
        case (.image, false):
            return try await ExternalImageConverter().convert(
                inputURL: inputURL, outputURL: outputURL, targetExtension: targetExtension, options: options
            )
        case (.video, true):
            try await VideoConverter().convert(
                inputURL: inputURL, outputURL: outputURL, targetExtension: targetExtension, options: options
            )
        case (.video, false):
            try await ExternalVideoConverter().convert(
                inputURL: inputURL, outputURL: outputURL, targetExtension: targetExtension, options: options
            )
        case (.document, true):
            return try DocumentConverter().convert(
                inputURL: inputURL, outputDirectory: outputDirectory, targetExtension: targetExtension, options: options
            )
        case (.document, false):
            return try await ExternalDocumentConverter().convert(
                inputURL: inputURL, outputDirectory: outputDirectory, targetExtension: targetExtension
            )
        case (.automatic, _):
            throw ConverterError.unsupportedInput(inputURL)
        }

        return [outputURL]
    }
}
