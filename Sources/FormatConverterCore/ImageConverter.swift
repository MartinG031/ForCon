import Foundation
import ImageIO
import UniformTypeIdentifiers

final class ImageConverter: @unchecked Sendable {
    func convert(
        inputURL: URL,
        outputURL: URL,
        targetExtension: String,
        options: ConversionOptions
    ) throws {
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw ConverterError.cannotReadInput(inputURL)
        }
        guard let outputType = imageType(for: targetExtension) else {
            throw ConverterError.unsupportedOutput(targetExtension, category: .image)
        }
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            outputType.identifier as CFString,
            CGImageSourceGetCount(source),
            nil
        ) else {
            throw ConverterError.cannotCreateOutput(outputURL)
        }

        let frameCount = max(CGImageSourceGetCount(source), 1)
        let destinationOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: max(0.0, min(1.0, options.imageQuality))
        ]

        for index in 0..<frameCount {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                throw ConverterError.conversionFailed("无法读取第 \(index + 1) 帧")
            }
            CGImageDestinationAddImage(destination, image, destinationOptions as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw ConverterError.conversionFailed("系统图片编码器没有完成输出")
        }
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
