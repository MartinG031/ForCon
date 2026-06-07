import Foundation

public enum FormatCategory: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case image
    case video
    case document

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .automatic: "自动"
        case .image: "图片"
        case .video: "视频"
        case .document: "文档"
        }
    }
}

public struct ConversionRequest: Sendable {
    public var inputURLs: [URL]
    public var outputDirectory: URL
    public var targetExtension: String
    public var targetExtensionsByCategory: [FormatCategory: String]
    public var category: FormatCategory
    public var options: ConversionOptions

    public init(
        inputURLs: [URL],
        outputDirectory: URL,
        targetExtension: String,
        targetExtensionsByCategory: [FormatCategory: String] = [:],
        category: FormatCategory = .automatic,
        options: ConversionOptions = ConversionOptions()
    ) {
        self.inputURLs = inputURLs
        self.outputDirectory = outputDirectory
        self.targetExtension = targetExtension.normalizedFileExtension
        self.targetExtensionsByCategory = targetExtensionsByCategory.mapValues(\.normalizedFileExtension)
        self.category = category
        self.options = options
    }
}

public struct ConversionOptions: Sendable {
    public var imageQuality: Double
    public var resizeImages: Bool
    public var imageMaxDimension: Int
    public var stripImageMetadata: Bool
    public var videoQuality: VideoQuality
    public var removeAudio: Bool
    public var documentImageScale: Double

    public init(
        imageQuality: Double = 0.9,
        resizeImages: Bool = false,
        imageMaxDimension: Int = 2048,
        stripImageMetadata: Bool = false,
        videoQuality: VideoQuality = .high,
        removeAudio: Bool = false,
        documentImageScale: Double = 2.0
    ) {
        self.imageQuality = imageQuality
        self.resizeImages = resizeImages
        self.imageMaxDimension = imageMaxDimension
        self.stripImageMetadata = stripImageMetadata
        self.videoQuality = videoQuality
        self.removeAudio = removeAudio
        self.documentImageScale = documentImageScale
    }
}

public enum VideoQuality: String, CaseIterable, Identifiable, Sendable {
    case high
    case medium
    case small

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .high: "高质量"
        case .medium: "均衡"
        case .small: "小体积"
        }
    }

    var ffmpegCRF: String {
        switch self {
        case .high: "18"
        case .medium: "23"
        case .small: "30"
        }
    }

    var avFoundationPreset: String {
        switch self {
        case .high: "AVAssetExportPresetHighestQuality"
        case .medium: "AVAssetExportPresetMediumQuality"
        case .small: "AVAssetExportPresetLowQuality"
        }
    }
}

public struct ConversionResult: Identifiable, Sendable {
    public let id: UUID
    public let inputURL: URL
    public let outputURLs: [URL]
    public let category: FormatCategory
    public let status: ConversionStatus

    public init(
        id: UUID = UUID(),
        inputURL: URL,
        outputURLs: [URL],
        category: FormatCategory,
        status: ConversionStatus
    ) {
        self.id = id
        self.inputURL = inputURL
        self.outputURLs = outputURLs
        self.category = category
        self.status = status
    }
}

public enum ConversionStatus: Sendable {
    case succeeded
    case failed(String)

    public var isSucceeded: Bool {
        if case .succeeded = self { true } else { false }
    }

    public var message: String {
        switch self {
        case .succeeded: "完成"
        case .failed(let message): message
        }
    }
}

public enum ConverterError: Error, LocalizedError, Sendable {
    case unsupportedInput(URL)
    case unsupportedOutput(String, category: FormatCategory)
    case cannotCreateOutput(URL)
    case cannotReadInput(URL)
    case conversionFailed(String)
    case categoryMismatch(URL, expected: FormatCategory, actual: FormatCategory)
    case videoExportUnavailable
    case videoExportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedInput(let url):
            "不支持的输入文件：\(url.lastPathComponent)"
        case .unsupportedOutput(let ext, let category):
            "\(category.displayName) 不支持输出为 .\(ext)"
        case .cannotCreateOutput(let url):
            "无法创建输出文件：\(url.path)"
        case .cannotReadInput(let url):
            "无法读取输入文件：\(url.path)"
        case .conversionFailed(let message):
            "转换失败：\(message)"
        case .categoryMismatch(let url, let expected, let actual):
            "\(url.lastPathComponent) 是\(actual.displayName)文件，当前选择的是\(expected.displayName)。请切换类型或使用自动。"
        case .videoExportUnavailable:
            "当前视频无法使用系统导出器转换"
        case .videoExportFailed(let message):
            "视频转换失败：\(message)"
        }
    }
}

extension String {
    var normalizedFileExtension: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }
}
