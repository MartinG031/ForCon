import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
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
        try XCTSkipUnless(isExternalToolInstalled("imagemagick"), "ImageMagick is not installed")
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
        let output = try XCTUnwrap(result[0].outputURLs.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }

    func testReportsAllNumberedImageOutputs() async throws {
        try XCTSkipUnless(isExternalToolInstalled("imagemagick"), "ImageMagick is not installed")
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("frames.tiff")
        let magick = try ExternalTool.require(["magick", "convert"])
        try await ExternalTool.run(magick, arguments: ["-size", "32x32", "xc:red", "xc:blue", input.path])

        let request = ConversionRequest(inputURLs: [input], outputDirectory: directory, targetExtension: "tga")
        let results = await FormatConversionEngine().convert(request)
        let result = try XCTUnwrap(results.first)
        XCTAssertTrue(result.status.isSucceeded, result.status.message)
        XCTAssertEqual(result.outputURLs.map(\.lastPathComponent), ["frames-0.tga", "frames-1.tga"])
        XCTAssertTrue(result.outputURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    func testConvertsMarkdownThroughPandoc() async throws {
        try XCTSkipUnless(isExternalToolInstalled("pandoc"), "Pandoc is not installed")
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
        let output = try XCTUnwrap(result[0].outputURLs.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
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
        let output = try XCTUnwrap(result[0].outputURLs.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
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
        let output = try XCTUnwrap(result[0].outputURLs.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }

    func testConcurrentBatchesPreserveExistingAndSameNamedOutputs() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let existing = output.appendingPathComponent("shared.jpg")
        let original = Data("existing output".utf8)
        try original.write(to: existing)

        let inputs = try (0..<12).map { index in
            let folder = directory.appendingPathComponent("input-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let input = folder.appendingPathComponent("shared.png")
            try makePNG(at: input)
            return input
        }
        let engine = FormatConversionEngine()
        let first = ConversionRequest(inputURLs: Array(inputs.prefix(6)), outputDirectory: output, targetExtension: "jpg")
        let second = ConversionRequest(inputURLs: Array(inputs.suffix(6)), outputDirectory: output, targetExtension: "jpg")
        async let firstResults = engine.convert(first)
        async let secondResults = engine.convert(second)
        let results = await firstResults + secondResults

        XCTAssertEqual(results.map(\.inputURL), inputs)
        XCTAssertTrue(results.allSatisfy(\.status.isSucceeded))
        let names = results.flatMap(\.outputURLs).map(\.lastPathComponent)
        XCTAssertEqual(Set(names).count, inputs.count)
        XCTAssertEqual(try Data(contentsOf: existing), original)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: output.path)), Set(names + ["shared.jpg"]))
    }

    func testLibreOfficePublishesOnlyItsOwnOutputs() async throws {
        try XCTSkipUnless(isExternalToolInstalled("libreoffice"), "LibreOffice is not installed")
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("output", isDirectory: true)
        let inputs = try (0..<2).map { index in
            let folder = directory.appendingPathComponent("source \(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let input = folder.appendingPathComponent("table.csv")
            try "name,value\nitem,\(index)\n".write(to: input, atomically: true, encoding: .utf8)
            return input
        }
        let request = ConversionRequest(inputURLs: inputs, outputDirectory: output, targetExtension: "xlsx")
        let results = await FormatConversionEngine().convert(request)

        XCTAssertEqual(results.count, inputs.count)
        for result in results {
            XCTAssertTrue(result.status.isSucceeded, result.status.message)
        }
        XCTAssertEqual(Set(results.flatMap(\.outputURLs).map(\.lastPathComponent)), ["table.xlsx", "table-2.xlsx"])
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: output.path)), ["table.xlsx", "table-2.xlsx"])
    }

    func testFailedBatchItemLeavesNoOutput() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("output", isDirectory: true)
        let valid = directory.appendingPathComponent("valid.png")
        let invalid = directory.appendingPathComponent("invalid.png")
        try makePNG(at: valid)
        try Data("invalid image".utf8).write(to: invalid)

        let request = ConversionRequest(inputURLs: [valid, invalid], outputDirectory: output, targetExtension: "jpg")
        let results = await FormatConversionEngine().convert(request)

        XCTAssertEqual(results.map(\.inputURL), [invalid, valid])
        XCTAssertEqual(results.map(\.status.isSucceeded), [false, true])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: output.path), ["valid.jpg"])
    }

    func testConvertsVideoThroughFFmpeg() async throws {
        try XCTSkipUnless(isExternalToolInstalled("ffmpeg"), "FFmpeg is not installed")
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("clip.mov")
        let ffmpeg = try ExternalTool.require(["ffmpeg"])
        try await ExternalTool.run(ffmpeg, arguments: [
            "-f", "lavfi", "-i", "color=s=32x32:r=10", "-t", "0.3", "-c:v", "mpeg4", input.path
        ])
        let request = ConversionRequest(inputURLs: [input], outputDirectory: directory, targetExtension: "mkv")
        let results = await FormatConversionEngine().convert(request)
        let result = try XCTUnwrap(results.first)
        XCTAssertTrue(result.status.isSucceeded, result.status.message)
        let output = try XCTUnwrap(result.outputURLs.first)
        XCTAssertEqual(output.lastPathComponent, "clip.mkv")
        let data = try Data(contentsOf: output)
        XCTAssertEqual(Array(data.prefix(4)), [0x1A, 0x45, 0xDF, 0xA3])
    }

    func testEveryAdvertisedOutputHasARoute() {
        let inputsByCategory: [FormatCategory: Set<String>] = [
            .image: FormatConversionEngine.imageInputs,
            .video: FormatConversionEngine.videoInputs,
            .document: FormatConversionEngine.documentInputs
        ]
        for (category, inputs) in inputsByCategory {
            for output in FormatConversionEngine().supportedOutputs(for: category) {
                let reachable = inputs.contains {
                    !ConversionRoute.plan(category: category, inputExtension: $0, targetExtension: output).isEmpty
                }
                XCTAssertTrue(reachable, "\(category) output .\(output) has no converter")
            }
        }
    }

    func testPlansNativeRoutesBeforeExternalFallbacks() {
        XCTAssertEqual(ConversionRoute.plan(category: .video, inputExtension: "avi", targetExtension: "mp4"), [.nativeVideo, .ffmpeg])
        XCTAssertEqual(ConversionRoute.plan(category: .image, inputExtension: "png", targetExtension: "jpg"), [.nativeImage, .imageMagick])
        XCTAssertEqual(ConversionRoute.plan(category: .image, inputExtension: "png", targetExtension: "webp"), [.imageMagick])
        XCTAssertEqual(ConversionRoute.plan(category: .document, inputExtension: "md", targetExtension: "docx"), [.pandoc])
        XCTAssertEqual(ConversionRoute.plan(category: .document, inputExtension: "txt", targetExtension: "pdf"), [.nativeDocument, .libreOffice])
        XCTAssertEqual(ConversionRoute.plan(category: .document, inputExtension: "txt", targetExtension: "png"), [])
    }

    func testUnroutablePairFailsWithClearMessage() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: input)

        let request = ConversionRequest(inputURLs: [input], outputDirectory: directory, targetExtension: "png", category: .document)
        let results = await FormatConversionEngine().convert(request)
        let result = try XCTUnwrap(results.first)

        XCTAssertFalse(result.status.isSucceeded)
        XCTAssertTrue(result.status.message.contains("暂不支持转换为 .png"), result.status.message)
    }

    func testNativeImageHonorsResizeAndMetadataOptions() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("photo.jpg")
        try makeJPEGWithGPS(at: input, size: 64)

        func convert(strip: Bool, into name: String) async throws -> ConversionResult {
            let output = directory.appendingPathComponent(name, isDirectory: true)
            let request = ConversionRequest(
                inputURLs: [input],
                outputDirectory: output,
                targetExtension: "png",
                options: ConversionOptions(resizeImages: true, imageMaxDimension: 16, stripImageMetadata: strip)
            )
            let results = await FormatConversionEngine().convert(request)
            return try XCTUnwrap(results.first)
        }

        let stripped = try await convert(strip: true, into: "stripped")
        XCTAssertTrue(stripped.status.isSucceeded, stripped.status.message)
        XCTAssertEqual(stripped.route, ConversionRoute.nativeImage.displayName)
        let strippedProperties = try imageProperties(at: XCTUnwrap(stripped.outputURLs.first))
        XCTAssertEqual(strippedProperties[kCGImagePropertyPixelWidth] as? Int, 16)
        XCTAssertNil(strippedProperties[kCGImagePropertyGPSDictionary])

        let kept = try await convert(strip: false, into: "kept")
        XCTAssertTrue(kept.status.isSucceeded, kept.status.message)
        let keptProperties = try imageProperties(at: XCTUnwrap(kept.outputURLs.first))
        XCTAssertEqual(keptProperties[kCGImagePropertyPixelWidth] as? Int, 16)
        XCTAssertNotNil(keptProperties[kCGImagePropertyGPSDictionary])
    }

    func testCancellationTerminatesExternalTool() async throws {
        let started = Date()
        let task = Task {
            try await ExternalTool.run("/bin/sleep", arguments: ["30"])
        }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()

        do {
            try await task.value
            XCTFail("Cancelled tool should not succeed")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testFallsBackToFFmpegWhenSystemExporterCannotRead() async throws {
        try XCTSkipUnless(isExternalToolInstalled("ffmpeg"), "FFmpeg is not installed")
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // A Matroska stream behind a .mov name: AVFoundation is tried first and must fail.
        let input = directory.appendingPathComponent("disguised.mov")
        let ffmpeg = try ExternalTool.require(["ffmpeg"])
        try await ExternalTool.run(ffmpeg, arguments: [
            "-f", "lavfi", "-i", "color=s=32x32:r=10", "-t", "0.3", "-c:v", "mpeg4", "-f", "matroska", input.path
        ])

        let output = directory.appendingPathComponent("output", isDirectory: true)
        let request = ConversionRequest(inputURLs: [input], outputDirectory: output, targetExtension: "mp4")
        let results = await FormatConversionEngine().convert(request)
        let result = try XCTUnwrap(results.first)

        XCTAssertTrue(result.status.isSucceeded, result.status.message)
        XCTAssertEqual(result.route, ConversionRoute.ffmpeg.displayName)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: output.path), ["disguised.mp4"])
    }

    func testSystemExporterRemovesAudio() async throws {
        try XCTSkipUnless(isExternalToolInstalled("ffmpeg"), "FFmpeg is not installed")
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("talk.mov")
        let ffmpeg = try ExternalTool.require(["ffmpeg"])
        try await ExternalTool.run(ffmpeg, arguments: [
            "-f", "lavfi", "-i", "color=s=64x64:r=10", "-f", "lavfi", "-i", "sine=frequency=440",
            "-t", "0.5", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", input.path
        ])

        let output = directory.appendingPathComponent("output", isDirectory: true)
        let request = ConversionRequest(
            inputURLs: [input],
            outputDirectory: output,
            targetExtension: "mp4",
            options: ConversionOptions(removeAudio: true)
        )
        let results = await FormatConversionEngine().convert(request)
        let result = try XCTUnwrap(results.first)

        XCTAssertTrue(result.status.isSucceeded, result.status.message)
        XCTAssertEqual(result.route, ConversionRoute.nativeVideo.displayName)
        let asset = AVURLAsset(url: try XCTUnwrap(result.outputURLs.first))
        let audio = try await asset.loadTracks(withMediaType: .audio)
        let video = try await asset.loadTracks(withMediaType: .video)
        XCTAssertTrue(audio.isEmpty)
        XCTAssertFalse(video.isEmpty)
    }

    private func imageProperties(at url: URL) throws -> [CFString: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    private func makeJPEGWithGPS(at url: URL, size: Int) throws {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 31.2, kCGImagePropertyGPSLatitudeRef: "N"]
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func isExternalToolInstalled(_ name: String) -> Bool {
        ExternalTool.requiredToolStatuses().first { $0.name == name }?.isInstalled == true
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
