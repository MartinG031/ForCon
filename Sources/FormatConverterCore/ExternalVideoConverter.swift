import Foundation

struct ExternalVideoConverter {
    func convert(
        inputURL: URL,
        outputURL: URL,
        targetExtension: String,
        options: ConversionOptions
    ) async throws {
        let ffmpeg = try ExternalTool.require(["ffmpeg"])
        var arguments = ["-y", "-i", inputURL.path]

        switch targetExtension {
        case "mp4", "m4v":
            arguments.append(contentsOf: ["-c:v", "libx264", "-crf", options.videoQuality.ffmpegCRF, "-c:a", "aac", "-movflags", "+faststart"])
        case "webm":
            arguments.append(contentsOf: ["-c:v", "libvpx-vp9", "-crf", options.videoQuality.ffmpegCRF, "-b:v", "0", "-c:a", "libopus"])
        case "ogv", "ogg":
            arguments.append(contentsOf: ["-c:v", "libtheora", "-c:a", "libvorbis"])
        case "wmv":
            arguments.append(contentsOf: ["-c:v", "wmv2", "-c:a", "wmav2"])
        default:
            arguments.append(contentsOf: ["-c:v", "libx264", "-crf", options.videoQuality.ffmpegCRF, "-c:a", "aac"])
        }

        if options.removeAudio {
            arguments.append("-an")
        }

        arguments.append(outputURL.path)
        try await ExternalTool.run(ffmpeg, arguments: arguments)
    }
}
