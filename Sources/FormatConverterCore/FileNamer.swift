import Foundation

enum FileNamer {
    static func uniqueOutputURL(
        inputURL: URL,
        outputDirectory: URL,
        targetExtension: String,
        suffix: String? = nil
    ) throws -> URL {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let base = inputURL.deletingPathExtension().lastPathComponent
        let fileStem = [base, suffix].compactMap { $0 }.joined(separator: "-")
        var candidate = outputDirectory.appendingPathComponent(fileStem).appendingPathExtension(targetExtension)

        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputDirectory
                .appendingPathComponent("\(fileStem)-\(index)")
                .appendingPathExtension(targetExtension)
            index += 1
        }
        return candidate
    }
}
