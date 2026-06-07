import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

final class DocumentConverter: @unchecked Sendable {
    func convert(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String,
        options: ConversionOptions
    ) throws -> [URL] {
        let inputExtension = inputURL.pathExtension.normalizedFileExtension

        if inputExtension == "pdf" {
            return try convertPDF(
                inputURL: inputURL,
                outputDirectory: outputDirectory,
                targetExtension: targetExtension,
                options: options
            )
        }

        return try convertTextLikeDocument(
            inputURL: inputURL,
            outputDirectory: outputDirectory,
            targetExtension: targetExtension
        )
    }

    private func convertPDF(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String,
        options: ConversionOptions
    ) throws -> [URL] {
        guard let document = PDFDocument(url: inputURL) else {
            throw ConverterError.cannotReadInput(inputURL)
        }

        switch targetExtension {
        case "txt":
            let outputURL = try FileNamer.uniqueOutputURL(
                inputURL: inputURL,
                outputDirectory: outputDirectory,
                targetExtension: targetExtension
            )
            try (document.string ?? "").write(to: outputURL, atomically: true, encoding: .utf8)
            return [outputURL]
        case "png", "jpg", "jpeg":
            return try renderPDFPages(
                document: document,
                inputURL: inputURL,
                outputDirectory: outputDirectory,
                targetExtension: targetExtension,
                options: options
            )
        case "pdf":
            let outputURL = try FileNamer.uniqueOutputURL(
                inputURL: inputURL,
                outputDirectory: outputDirectory,
                targetExtension: targetExtension
            )
            guard document.write(to: outputURL) else {
                throw ConverterError.cannotCreateOutput(outputURL)
            }
            return [outputURL]
        default:
            throw ConverterError.unsupportedOutput(targetExtension, category: .document)
        }
    }

    private func renderPDFPages(
        document: PDFDocument,
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String,
        options: ConversionOptions
    ) throws -> [URL] {
        var outputURLs: [URL] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale = CGFloat(max(1.0, min(4.0, options.documentImageScale)))
            let image = NSImage(size: NSSize(width: bounds.width * scale, height: bounds.height * scale))

            image.lockFocus()
            guard let context = NSGraphicsContext.current?.cgContext else {
                image.unlockFocus()
                throw ConverterError.conversionFailed("无法创建 PDF 渲染上下文")
            }
            NSColor.white.set()
            context.fill(CGRect(origin: .zero, size: image.size))
            context.saveGState()
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            image.unlockFocus()

            let suffix = "page-\(pageIndex + 1)"
            let outputURL = try FileNamer.uniqueOutputURL(
                inputURL: inputURL,
                outputDirectory: outputDirectory,
                targetExtension: targetExtension,
                suffix: suffix
            )
            try write(image: image, to: outputURL, targetExtension: targetExtension)
            outputURLs.append(outputURL)
        }
        return outputURLs
    }

    private func convertTextLikeDocument(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String
    ) throws -> [URL] {
        let attributed = try attributedString(from: inputURL)
        let outputURL = try FileNamer.uniqueOutputURL(
            inputURL: inputURL,
            outputDirectory: outputDirectory,
            targetExtension: targetExtension
        )

        switch targetExtension {
        case "pdf":
            try writePDF(attributed, to: outputURL)
        case "txt":
            try attributed.string.write(to: outputURL, atomically: true, encoding: .utf8)
        case "rtf":
            let range = NSRange(location: 0, length: attributed.length)
            let data = try attributed.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            try data.write(to: outputURL)
        case "html":
            let range = NSRange(location: 0, length: attributed.length)
            let data = try attributed.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
            )
            try data.write(to: outputURL)
        default:
            throw ConverterError.unsupportedOutput(targetExtension, category: .document)
        }

        return [outputURL]
    }

    private func attributedString(from inputURL: URL) throws -> NSAttributedString {
        let ext = inputURL.pathExtension.normalizedFileExtension
        let data = try Data(contentsOf: inputURL)

        switch ext {
        case "rtf":
            return try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        case "html", "htm":
            return try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
        default:
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                throw ConverterError.cannotReadInput(inputURL)
            }
            return NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.textColor
                ]
            )
        }
    }

    private func writePDF(_ attributed: NSAttributedString, to outputURL: URL) throws {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 54
        let textRect = pageRect.insetBy(dx: margin, dy: margin)

        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        var pageRanges: [NSRange] = []
        var glyphIndex = 0
        while glyphIndex < layoutManager.numberOfGlyphs || pageRanges.isEmpty {
            let container = NSTextContainer(size: textRect.size)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            let glyphRange = layoutManager.glyphRange(for: container)
            pageRanges.append(glyphRange)
            glyphIndex = NSMaxRange(glyphRange)
            if glyphRange.length == 0 { break }
        }

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw ConverterError.cannotCreateOutput(outputURL)
        }

        for (pageIndex, glyphRange) in pageRanges.enumerated() {
            context.beginPDFPage([kCGPDFContextMediaBox as String: pageRect] as CFDictionary)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            NSColor.white.set()
            pageRect.fill()
            let container = layoutManager.textContainers[pageIndex]
            layoutManager.drawBackground(forGlyphRange: glyphRange, at: textRect.origin)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: textRect.origin)
            _ = container
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }
        context.closePDF()
        try pdfData.write(to: outputURL, options: .atomic)
    }

    private func write(image: NSImage, to outputURL: URL, targetExtension: String) throws {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            throw ConverterError.conversionFailed("无法编码 PDF 页面图片")
        }

        let fileType: NSBitmapImageRep.FileType = targetExtension == "png" ? .png : .jpeg
        guard let data = bitmap.representation(using: fileType, properties: [.compressionFactor: 0.9]) else {
            throw ConverterError.cannotCreateOutput(outputURL)
        }
        try data.write(to: outputURL)
    }
}
