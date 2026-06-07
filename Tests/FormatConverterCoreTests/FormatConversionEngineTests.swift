import AppKit
import Foundation
import Testing
@testable import FormatConverterCore

@Suite("FormatConversionEngine")
struct FormatConversionEngineTests {
    @Test("detects categories from file extensions")
    func detectsCategories() {
        let engine = FormatConversionEngine()

        #expect(engine.detectedCategory(for: URL(filePath: "/tmp/sample.png")) == .image)
        #expect(engine.detectedCategory(for: URL(filePath: "/tmp/sample.avif")) == .image)
        #expect(engine.detectedCategory(for: URL(filePath: "/tmp/sample.psd")) == .image)
        #expect(engine.detectedCategory(for: URL(filePath: "/tmp/sample.mov")) == .video)
        #expect(engine.detectedCategory(for: URL(filePath: "/tmp/sample.mkv")) == .video)
        #expect(engine.detectedCategory(for: URL(filePath: "/tmp/sample.webm")) == .video)
        #expect(engine.detectedCategory(for: URL(filePath: "/tmp/sample.pdf")) == .document)
        #expect(engine.detectedCategory(for: URL(filePath: "/tmp/sample.docx")) == .document)
        #expect(engine.detectedCategory(for: URL(filePath: "/tmp/sample.odt")) == .document)
        #expect(engine.detectedCategory(for: URL(filePath: "/tmp/sample.unknown")) == nil)
    }

    @Test("shows broad popular output formats in the picker lists")
    func exposesBroadOutputFormats() {
        let engine = FormatConversionEngine()

        #expect(engine.supportedOutputs(for: .image).contains("webp"))
        #expect(engine.supportedOutputs(for: .image).contains("avif"))
        #expect(engine.supportedOutputs(for: .image).contains("svg"))
        #expect(engine.supportedOutputs(for: .video).contains("mkv"))
        #expect(engine.supportedOutputs(for: .video).contains("webm"))
        #expect(engine.supportedOutputs(for: .video).contains("wmv"))
        #expect(engine.supportedOutputs(for: .document).contains("docx"))
        #expect(engine.supportedOutputs(for: .document).contains("xlsx"))
        #expect(engine.supportedOutputs(for: .document).contains("epub"))
    }

    @Test("rejects files that do not match the selected category")
    func rejectsCategoryMismatch() async throws {
        let directory = try temporaryDirectory()
        let input = directory.appendingPathComponent("clip.mov")
        try Data("not a real movie".utf8).write(to: input)

        let request = ConversionRequest(
            inputURLs: [input],
            outputDirectory: directory,
            targetExtension: "avif",
            category: .image
        )

        let result = await FormatConversionEngine().convert(request)
        #expect(result.count == 1)
        #expect(!result[0].status.isSucceeded)
        #expect(result[0].status.message.contains("当前选择的是图片"))
    }

    @Test("automatic mode uses separate targets for each detected category")
    func automaticModeUsesCategoryTargets() async throws {
        let directory = try temporaryDirectory()
        let image = directory.appendingPathComponent("input.png")
        let video = directory.appendingPathComponent("clip.mov")
        try makePNG(at: image)
        try Data("not a real movie".utf8).write(to: video)

        let request = ConversionRequest(
            inputURLs: [image, video],
            outputDirectory: directory,
            targetExtension: "mkv",
            targetExtensionsByCategory: [
                .image: "jpg",
                .video: "mkv",
                .document: "pdf"
            ],
            category: .automatic
        )

        let result = await FormatConversionEngine().convert(request)
        let imageResult = try #require(result.first { $0.inputURL == image })
        #expect(imageResult.status.isSucceeded)
        #expect(imageResult.outputURLs.first?.pathExtension == "jpg")
    }

    @Test("converts PNG image to ICO through ImageMagick")
    func convertsImageThroughImageMagick() async throws {
        let directory = try temporaryDirectory()
        let input = directory.appendingPathComponent("input.png")
        try makePNG(at: input)

        let request = ConversionRequest(
            inputURLs: [input],
            outputDirectory: directory,
            targetExtension: "ico",
            category: .image,
            options: ConversionOptions(
                imageQuality: 0.8,
                resizeImages: true,
                imageMaxDimension: 256,
                stripImageMetadata: true
            )
        )

        let result = await FormatConversionEngine().convert(request)
        #expect(result.count == 1)
        #expect(result[0].status.isSucceeded)
        #expect(FileManager.default.fileExists(atPath: result[0].outputURLs[0].path))
    }

    @Test("converts Markdown to DOCX through Pandoc")
    func convertsMarkdownThroughPandoc() async throws {
        let directory = try temporaryDirectory()
        let input = directory.appendingPathComponent("notes.md")
        try "# Title\n\nForCon document conversion.".write(to: input, atomically: true, encoding: .utf8)

        let request = ConversionRequest(
            inputURLs: [input],
            outputDirectory: directory,
            targetExtension: "docx",
            category: .document
        )

        let result = await FormatConversionEngine().convert(request)
        #expect(result.count == 1)
        #expect(result[0].status.isSucceeded)
        #expect(FileManager.default.fileExists(atPath: result[0].outputURLs[0].path))
    }

    @Test("converts PNG image to JPEG")
    func convertsImage() async throws {
        let directory = try temporaryDirectory()
        let input = directory.appendingPathComponent("input.png")
        try makePNG(at: input)

        let request = ConversionRequest(
            inputURLs: [input],
            outputDirectory: directory,
            targetExtension: "jpg",
            category: .image
        )

        let result = await FormatConversionEngine().convert(request)
        #expect(result.count == 1)
        #expect(result[0].status.isSucceeded)
        #expect(FileManager.default.fileExists(atPath: result[0].outputURLs[0].path))
    }

    @Test("converts plain text to PDF")
    func convertsTextToPDF() async throws {
        let directory = try temporaryDirectory()
        let input = directory.appendingPathComponent("notes.txt")
        try "hello\nformat converter".write(to: input, atomically: true, encoding: .utf8)

        let request = ConversionRequest(
            inputURLs: [input],
            outputDirectory: directory,
            targetExtension: "pdf",
            category: .document
        )

        let result = await FormatConversionEngine().convert(request)
        #expect(result.count == 1)
        #expect(result[0].status.isSucceeded)
        #expect(FileManager.default.fileExists(atPath: result[0].outputURLs[0].path))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForConTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makePNG(at url: URL) throws {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 32, height: 32).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to build fixture PNG")
            return
        }
        try data.write(to: url)
    }
}
