import AVFoundation
import Foundation

struct VideoConverter {
    func convert(
        inputURL: URL,
        outputURL: URL,
        targetExtension: String,
        options: ConversionOptions
    ) async throws {
        let source = AVURLAsset(url: inputURL)
        let asset = options.removeAudio ? try await videoOnly(source) : source
        guard let export = AVAssetExportSession(asset: asset, presetName: options.videoQuality.avFoundationPreset) else {
            throw ConverterError.videoExportUnavailable
        }
        guard let fileType = outputFileType(for: targetExtension),
              export.supportedFileTypes.contains(fileType) else {
            throw ConverterError.unsupportedOutput(targetExtension, category: .video)
        }

        export.outputURL = outputURL
        export.outputFileType = fileType
        export.shouldOptimizeForNetworkUse = true

        let session = UncheckedExportSession(export)
        await withTaskCancellationHandler {
            await session.value.export()
        } onCancel: {
            session.value.cancelExport()
        }
        try Task.checkCancellation()
        switch export.status {
        case .completed:
            return
        case .failed, .cancelled:
            throw ConverterError.videoExportFailed(export.error?.localizedDescription ?? "系统导出器已取消")
        default:
            throw ConverterError.videoExportFailed("系统导出器状态异常：\(export.status.rawValue)")
        }
    }

    /// Builds a composition with only the video tracks, so the export really has no audio.
    private func videoOnly(_ asset: AVURLAsset) async throws -> AVAsset {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else {
            throw ConverterError.videoExportFailed("没有可导出的视频轨道")
        }
        let duration = try await asset.load(.duration)
        let composition = AVMutableComposition()
        for track in tracks {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }
            try compositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)
            compositionTrack.preferredTransform = try await track.load(.preferredTransform)
        }
        return composition
    }

    private func outputFileType(for ext: String) -> AVFileType? {
        switch ext {
        case "mov": .mov
        case "mp4": .mp4
        case "m4v": .m4v
        default: nil
        }
    }
}

/// AVAssetExportSession is thread-safe for `export()` / `cancelExport()` but not marked Sendable.
private struct UncheckedExportSession: @unchecked Sendable {
    let value: AVAssetExportSession
    init(_ value: AVAssetExportSession) { self.value = value }
}
