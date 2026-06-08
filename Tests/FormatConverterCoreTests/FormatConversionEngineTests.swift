import AppKit
import Foundation
import XCTest
@testable import FormatConverterCore

final class FormatConversionEngineTests: XCTestCase {
    func testDetectsCategories() {
        let engine = FormatConversionEngine()

        XCTAssertEqual(engine.detectedCategory(for: URL(fileURLWithPath: "/tmp/sample.png")), .image)
        XCTAssertEqual(engine.detectedCategory(for: URL(fileURLWithPath: "/tmp/sample.avif")), .image)
        XCTAssertEqual(engine.detectedCategory(for: URL(fileURLWithPath: "/tmp/sample.psd")), .image)
        XCTAssertEqual(engine.detectedCategory(for: URL(fileURLWithPath: "/tmp/sample.mov")), .video)
        XCTAssertEqual(engine.detectedCategory(for: URL(fileURLWithPath: "/tmp/sample.mkv")), .video)
        XCTAssertEqual(engine.detectedCategory(for: URL(fileURLWithPath: "/tmp/sample.webm")), .video)
        XCTAssertEqual(engine.detectedCategory(for: URL(fileURLWithPath: "/tmp/sample.pdf")), .document)
        XCTAssertEqual(engine.detectedCategory(for: URL(fileURLWithPath: "/tmp/sample.docx")), .document)
        XCTAssertEqual(engine.detectedCategory(for: URL(fileURLWithPath: "/tmp/sample.odt")), .document)
        XCTAssertNil(engine.detectedCategory(for: URL(fileURLWithPath: "/tmp/sample.unknown")))
    }

    func testExposesBroadOutputFormats() {
        let engine = FormatConversionEngine()

        XCTAssertTrue(engine.supportedOutputs(for: .image).contains("webp"))
        XCTAssertTrue(engine.supportedOutputs(for: .image).contains("avif"))
        XCTAssertTrue(engine.supportedOutputs(for: .image).contains("svg"))
        XCTAssertTrue(engine.supportedOutputs(for: .video).contains("mkv"))
        XCTAssertTrue(engine.supportedOutputs(for: .video).contains("webm"))
        XCTAssertTrue(engine.supportedOutputs(for: .video).contains("wmv"))
        XCTAssertTrue(engine.supportedOutputs(for: .document).contains("docx"))
        XCTAssertTrue(engine.supportedOutputs(for: .document).contains("xlsx"))
        XCTAssertTrue(engine.supportedOutputs(for: .document).contains("epub"))
    }

    func testRejectsCategoryMismatch() async throws {
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
        XCTAssertEqual(result.count, 1)
        XCTAssertFalse(result[0].status.isSucceeded)
        XCTAssertTrue(result[0].status.message.contains("当前选择的是图片"))
    }

    func testAutomaticModeUsesCategoryTargets() async throws {
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
        let imageResult = try XCTUnwrap(result.first { $0.inputURL == image })
        XCTAssertTrue(imageResult.status.isSucceeded)
        XCTAssertEqual(imageResult.outputURLs.first?.pathExtension, "jpg")
    }

    func testConvertsImageThroughImageMagick() async throws {
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
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].status.isSucceeded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result[0].outputURLs[0].path))
    }

    func testConvertsMarkdownThroughPandoc() async throws {
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
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].status.isSucceeded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result[0].outputURLs[0].path))
    }

    func testConvertsImage() async throws {
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
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].status.isSucceeded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result[0].outputURLs[0].path))
    }

    func testConvertsTextToPDF() async throws {
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
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].status.isSucceeded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result[0].outputURLs[0].path))
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
            XCTFail("Failed to build fixture PNG")
            return
        }
        try data.write(to: url)
    }
}
