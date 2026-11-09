import Foundation

struct ExternalImageConverter {
    func convert(
        inputURL: URL,
        outputURL: URL,
        targetExtension: String,
        options: ConversionOptions
    ) async throws -> [URL] {
        let magick = try ExternalTool.require(["magick", "convert"])
        let qualityValue = String(max(1, min(100, Int(options.imageQuality * 100))))
        var arguments = [inputURL.path]

        if options.resizeImages {
            let size = max(16, min(32_000, options.imageMaxDimension))
            arguments.append(contentsOf: ["-resize", "\(size)x\(size)>"])
        }

        if options.stripImageMetadata {
            arguments.append("-strip")
        }

        if ["jpg", "jpeg", "webp", "avif", "heic", "heif"].contains(targetExtension) {
            arguments.append(contentsOf: ["-quality", qualityValue])
        }

        if targetExtension == "ico" {
            arguments.append(contentsOf: ["-define", "icon:auto-resize=256,128,64,48,32,16"])
        }

        arguments.append(outputURL.path)
        try await ExternalTool.run(magick, arguments: arguments)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            return [outputURL]
        }

        // ImageMagick appends frame numbers for formats that store one image per file.
        return try fileManager.contentsOfDirectory(
            at: outputURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.normalizedFileExtension == targetExtension }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
