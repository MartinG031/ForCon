import Foundation

struct ConversionOutput {
    private static let publishLock = NSLock()

    let stagingDirectory: URL
    private let directory: URL

    init(directory: URL) throws {
        self.directory = directory
        stagingDirectory = directory.appendingPathComponent(".forcon-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
    }

    func publish(_ files: [URL]) throws -> [URL] {
        guard !files.isEmpty else {
            throw ConverterError.conversionFailed("转换组件没有生成输出文件")
        }
        for file in files {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                throw ConverterError.cannotCreateOutput(file)
            }
        }

        return try Self.publishLock.withLock {
            var published: [URL] = []
            do {
                for file in files {
                    let destination = try FileNamer.uniqueOutputURL(
                        inputURL: file,
                        outputDirectory: directory,
                        targetExtension: file.pathExtension
                    )
                    try FileManager.default.moveItem(at: file, to: destination)
                    published.append(destination)
                }
            } catch {
                for file in published {
                    try? FileManager.default.removeItem(at: file)
                }
                throw error
            }
            return published
        }
    }

    func discard() {
        try? FileManager.default.removeItem(at: stagingDirectory)
    }
}
