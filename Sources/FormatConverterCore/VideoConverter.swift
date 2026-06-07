import AVFoundation
import Foundation

final class VideoConverter: @unchecked Sendable {
    func convert(
        inputURL: URL,
        outputURL: URL,
        targetExtension: String,
        options: ConversionOptions
    ) async throws {
        let asset = AVURLAsset(url: inputURL)
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
        if options.removeAudio {
            export.audioMix = AVAudioMix()
        }

        await export.export()
        switch export.status {
        case .completed:
            return
        case .failed, .cancelled:
            throw ConverterError.videoExportFailed(export.error?.localizedDescription ?? "系统导出器已取消")
        default:
            throw ConverterError.videoExportFailed("系统导出器状态异常：\(export.status.rawValue)")
        }
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
