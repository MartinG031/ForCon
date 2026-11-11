import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageConverter {
    func convert(
        inputURL: URL,
        outputURL: URL,
        targetExtension: String,
        options: ConversionOptions
    ) throws {
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw ConverterError.cannotReadInput(inputURL)
        }
        guard let outputType = imageType(for: targetExtension) else {
            throw ConverterError.unsupportedOutput(targetExtension, category: .image)
        }

        let sourceFrames = CGImageSourceGetCount(source)
        let frameCount = supportsMultipleFrames(outputType) ? sourceFrames : 1
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            outputType.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw ConverterError.cannotCreateOutput(outputURL)
        }

        if !options.stripImageMetadata,
           let containerProperties = CGImageSourceCopyProperties(source, nil) {
            CGImageDestinationSetProperties(destination, containerProperties)
        }

        let maxDimension = options.resizeImages ? max(16, min(32_000, options.imageMaxDimension)) : nil
        for index in 0..<frameCount {
            let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
            let (image, oriented) = try frame(at: index, of: source, properties: sourceProperties, maxDimension: maxDimension)
            let properties = frameProperties(
                from: sourceProperties,
                oriented: oriented,
                options: options
            )
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw ConverterError.conversionFailed("系统图片编码器没有完成输出")
        }
    }

    /// Returns the frame, downscaled when it exceeds `maxDimension`. A downscaled frame has its
    /// EXIF orientation already applied, which the caller must reflect in the written properties.
    private func frame(
        at index: Int,
        of source: CGImageSource,
        properties: [CFString: Any],
        maxDimension: Int?
    ) throws -> (CGImage, oriented: Bool) {
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        if let maxDimension, max(width, height) > maxDimension {
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceShouldCacheImmediately: true
            ]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, index, thumbnailOptions as CFDictionary) {
                return (image, true)
            }
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
            throw ConverterError.conversionFailed("无法读取第 \(index + 1) 帧")
        }
        return (image, false)
    }

    private func frameProperties(
        from source: [CFString: Any],
        oriented: Bool,
        options: ConversionOptions
    ) -> [CFString: Any] {
        var properties: [CFString: Any]
        if options.stripImageMetadata {
            // Drop EXIF/GPS/IPTC but keep what changes how the pixels are shown or animated.
            properties = [:]
            for key in [kCGImagePropertyOrientation, kCGImagePropertyGIFDictionary, kCGImagePropertyPNGDictionary] {
                properties[key] = source[key]
            }
            if var png = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
                png = png.filter { [kCGImagePropertyAPNGDelayTime, kCGImagePropertyAPNGUnclampedDelayTime, kCGImagePropertyAPNGLoopCount].contains($0.key) }
                properties[kCGImagePropertyPNGDictionary] = png
            }
        } else {
            properties = source
        }
        properties[kCGImagePropertyPixelWidth] = nil
        properties[kCGImagePropertyPixelHeight] = nil
        if oriented {
            properties[kCGImagePropertyOrientation] = 1
            if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                tiff[kCGImagePropertyTIFFOrientation] = 1
                properties[kCGImagePropertyTIFFDictionary] = tiff
            }
        }
        properties[kCGImageDestinationLossyCompressionQuality] = max(0.0, min(1.0, options.imageQuality))
        return properties
    }

    private func supportsMultipleFrames(_ type: UTType) -> Bool {
        type == .gif || type == .tiff || type == .heic || type == .png
    }

    private func imageType(for ext: String) -> UTType? {
        switch ext {
        case "jpg", "jpeg": .jpeg
        case "png": .png
        case "tif", "tiff": .tiff
        case "gif": .gif
        case "bmp": .bmp
        case "heic": .heic
        default: nil
        }
    }
}
