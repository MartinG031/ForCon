import Foundation
import FormatConverterCore
import Observation
import AppKit
import Darwin
import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
final class ConverterViewModel {
    var inputURLs: [URL] = []
    var outputDirectory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0] {
        didSet { saveSettings() }
    }
    var category: FormatCategory = .automatic {
        didSet {
            normalizeTargetExtension()
            saveSettings()
        }
    }
    var targetExtension = "pdf" {
        didSet { saveTargetExtension(); saveSettings() }
    }
    var imageTargetExtension = "png" {
        didSet { saveTargetExtension(.image, imageTargetExtension) }
    }
    var videoTargetExtension = "mp4" {
        didSet { saveTargetExtension(.video, videoTargetExtension) }
    }
    var documentTargetExtension = "pdf" {
        didSet { saveTargetExtension(.document, documentTargetExtension) }
    }
    var imageQuality = 0.9 { didSet { saveSettings() } }
    var resizeImages = false { didSet { saveSettings() } }
    var imageMaxDimension = 2048.0 { didSet { saveSettings() } }
    var stripImageMetadata = false { didSet { saveSettings() } }
    var videoQuality: VideoQuality = .high { didSet { saveSettings() } }
    var removeAudio = false { didSet { saveSettings() } }
    var documentImageScale = 2.0 { didSet { saveSettings() } }
    var results: [ConversionResult] = []
    var message: String?
    var hasError = false
    var isConverting = false
    var progress = 0.0
    var processedCount = 0
    var totalCount = 0
    var estimatedRemainingText: String?
    var isCheckingForUpdate = false
    var updateMessage: String?
    var externalToolStatuses: [ExternalToolStatus] = []

    private let engine = FormatConversionEngine()
    private let updateManager = UpdateManager()
    private let defaults = UserDefaults.standard
    private var conversionStartDate: Date?

    init() {
        loadSettings()
        normalizeTargetExtension()
        refreshExternalToolStatuses()
    }

    var availableOutputExtensions: [String] {
        engine.supportedOutputs(for: category)
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "开发版"
    }

    func availableOutputExtensions(for category: FormatCategory) -> [String] {
        engine.supportedOutputs(for: category)
    }

    var canConvert: Bool {
        !inputURLs.isEmpty && !targetExtension.isEmpty && !isConverting
    }

    func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item]
        if panel.runModal() == .OK {
            add(panel.urls)
        }
    }

    func pickOutputDirectory() {
        _ = requestOutputDirectoryAccess()
    }

    @discardableResult
    func requestOutputDirectoryAccess() -> Bool {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "请选择 ForCon 保存转换结果的位置。"
        panel.prompt = "授权"
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
            return true
        }
        return false
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                Task { @MainActor in
                    self.add([url])
                }
            }
        }
        return true
    }

    func add(_ urls: [URL]) {
        let current = Set(inputURLs)
        inputURLs.append(contentsOf: urls.filter { !current.contains($0) })
        message = nil
        hasError = false

        if category == .automatic,
           targetExtension == "pdf",
           let first = inputURLs.first,
           let detected = engine.detectedCategory(for: first) {
            targetExtension = engine.supportedOutputs(for: detected).first ?? targetExtension
        }
    }

    func remove(_ url: URL) {
        inputURLs.removeAll { $0 == url }
    }

    func clear() {
        inputURLs = []
        results = []
        message = nil
        hasError = false
        progress = 0
        processedCount = 0
        totalCount = 0
        estimatedRemainingText = nil
        conversionStartDate = nil
    }

    func detectedCategory(for url: URL) -> FormatCategory? {
        engine.detectedCategory(for: url)
    }

    func detectedCategoryName(for url: URL) -> String {
        engine.detectedCategory(for: url)?.displayName ?? "未知类型"
    }

    func convert() async {
        guard canConvert else { return }
        isConverting = true
        progress = 0
        processedCount = 0
        totalCount = inputURLs.count
        estimatedRemainingText = "正在估算"
        conversionStartDate = Date()
        results = []
        message = "正在转换 0/\(totalCount)"
        hasError = false

        let request = ConversionRequest(
            inputURLs: inputURLs,
            outputDirectory: outputDirectory,
            targetExtension: targetExtension,
            targetExtensionsByCategory: [
                .image: imageTargetExtension,
                .video: videoTargetExtension,
                .document: documentTargetExtension
            ],
            category: category,
            options: ConversionOptions(
                imageQuality: imageQuality,
                resizeImages: resizeImages,
                imageMaxDimension: Int(imageMaxDimension),
                stripImageMetadata: stripImageMetadata,
                videoQuality: videoQuality,
                removeAudio: removeAudio,
                documentImageScale: documentImageScale
            )
        )
        let converted = await engine.convert(request) { result in
            await MainActor.run {
                self.results.append(result)
                self.processedCount += 1
                self.progress = self.totalCount == 0 ? 0 : Double(self.processedCount) / Double(self.totalCount)
                self.message = "正在转换 \(self.processedCount)/\(self.totalCount)"
                self.estimatedRemainingText = self.estimatedRemainingDurationText()
                self.hasError = self.results.contains { !$0.status.isSucceeded }
            }
        }
        results = converted
        let successCount = converted.filter(\.status.isSucceeded).count
        let failedCount = converted.count - successCount
        progress = 1
        isConverting = false
        hasError = failedCount > 0
        estimatedRemainingText = conversionElapsedText()
        message = failedCount == 0 ? "已完成 \(successCount) 个文件" : "完成 \(successCount) 个，失败 \(failedCount) 个"
        conversionStartDate = nil
    }

    func checkForUpdates() async {
        guard !isCheckingForUpdate else { return }
        isCheckingForUpdate = true
        updateMessage = "正在检查更新..."
        defer { isCheckingForUpdate = false }

        do {
            let result = try await updateManager.checkForUpdates()
            updateMessage = result.message
            if result.shouldRestart {
                try? await Task.sleep(for: .seconds(1))
                exit(0)
            }
        } catch {
            updateMessage = error.localizedDescription
        }
    }

    func checkForUpdatesOnLaunch() async {
        guard !isCheckingForUpdate else { return }
        isCheckingForUpdate = true
        updateMessage = "正在检查更新..."
        defer { isCheckingForUpdate = false }

        do {
            let availability = try await updateManager.checkAvailability()
            updateMessage = availability.message
        } catch {
            updateMessage = "自动检查更新失败：\(error.localizedDescription)"
        }
    }

    func refreshExternalToolStatuses() {
        externalToolStatuses = ExternalTool.requiredToolStatuses()
    }

    private func normalizeTargetExtension() {
        let outputs = availableOutputExtensions
        let saved = defaults.string(forKey: targetKey(for: category))
        if let saved, outputs.contains(saved) {
            targetExtension = saved
        } else if !outputs.contains(targetExtension) {
            targetExtension = outputs.first ?? ""
        }
        imageTargetExtension = normalizedSavedTarget(for: .image, default: imageTargetExtension)
        videoTargetExtension = normalizedSavedTarget(for: .video, default: videoTargetExtension)
        documentTargetExtension = normalizedSavedTarget(for: .document, default: documentTargetExtension)
    }

    private func saveTargetExtension() {
        defaults.set(targetExtension, forKey: targetKey(for: category))
    }

    private func saveTargetExtension(_ category: FormatCategory, _ extensionValue: String) {
        defaults.set(extensionValue, forKey: targetKey(for: category))
    }

    private func loadSettings() {
        if let rawCategory = defaults.string(forKey: SettingsKey.category),
           let savedCategory = FormatCategory(rawValue: rawCategory) {
            category = savedCategory
        }
        if let outputPath = defaults.string(forKey: SettingsKey.outputDirectory), !outputPath.isEmpty {
            outputDirectory = URL(fileURLWithPath: outputPath)
        }
        imageQuality = readDouble(SettingsKey.imageQuality, default: imageQuality)
        resizeImages = defaults.bool(forKey: SettingsKey.resizeImages)
        imageMaxDimension = readDouble(SettingsKey.imageMaxDimension, default: imageMaxDimension)
        stripImageMetadata = defaults.bool(forKey: SettingsKey.stripImageMetadata)
        if let rawQuality = defaults.string(forKey: SettingsKey.videoQuality),
           let savedQuality = VideoQuality(rawValue: rawQuality) {
            videoQuality = savedQuality
        }
        removeAudio = defaults.bool(forKey: SettingsKey.removeAudio)
        documentImageScale = readDouble(SettingsKey.documentImageScale, default: documentImageScale)
        if let savedTarget = defaults.string(forKey: targetKey(for: category)) {
            targetExtension = savedTarget
        }
        imageTargetExtension = normalizedSavedTarget(for: .image, default: imageTargetExtension)
        videoTargetExtension = normalizedSavedTarget(for: .video, default: videoTargetExtension)
        documentTargetExtension = normalizedSavedTarget(for: .document, default: documentTargetExtension)
    }

    private func saveSettings() {
        defaults.set(category.rawValue, forKey: SettingsKey.category)
        defaults.set(outputDirectory.path, forKey: SettingsKey.outputDirectory)
        defaults.set(imageQuality, forKey: SettingsKey.imageQuality)
        defaults.set(resizeImages, forKey: SettingsKey.resizeImages)
        defaults.set(imageMaxDimension, forKey: SettingsKey.imageMaxDimension)
        defaults.set(stripImageMetadata, forKey: SettingsKey.stripImageMetadata)
        defaults.set(videoQuality.rawValue, forKey: SettingsKey.videoQuality)
        defaults.set(removeAudio, forKey: SettingsKey.removeAudio)
        defaults.set(documentImageScale, forKey: SettingsKey.documentImageScale)
    }

    private func readDouble(_ key: String, default defaultValue: Double) -> Double {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.double(forKey: key)
    }

    private func estimatedRemainingDurationText() -> String? {
        guard let conversionStartDate else { return nil }
        guard processedCount > 0, totalCount > processedCount else {
            return processedCount >= totalCount ? nil : "正在估算"
        }
        let elapsed = Date().timeIntervalSince(conversionStartDate)
        let average = elapsed / Double(processedCount)
        let remaining = average * Double(totalCount - processedCount)
        return "预计剩余 \(formatDuration(remaining))"
    }

    private func conversionElapsedText() -> String? {
        guard let conversionStartDate else { return nil }
        return "用时 \(formatDuration(Date().timeIntervalSince(conversionStartDate)))"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        if seconds < 60 {
            return "\(seconds)秒"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes < 60 {
            return remainder == 0 ? "\(minutes)分钟" : "\(minutes)分\(remainder)秒"
        }
        let hours = minutes / 60
        let minuteRemainder = minutes % 60
        return minuteRemainder == 0 ? "\(hours)小时" : "\(hours)小时\(minuteRemainder)分钟"
    }

    private func targetKey(for category: FormatCategory) -> String {
        "\(SettingsKey.targetExtensionPrefix).\(category.rawValue)"
    }

    private func normalizedSavedTarget(for category: FormatCategory, default defaultValue: String) -> String {
        let outputs = engine.supportedOutputs(for: category)
        if let saved = defaults.string(forKey: targetKey(for: category)), outputs.contains(saved) {
            return saved
        }
        return outputs.contains(defaultValue) ? defaultValue : (outputs.first ?? defaultValue)
    }

    private enum SettingsKey {
        static let category = "settings.category"
        static let outputDirectory = "settings.outputDirectory"
        static let targetExtensionPrefix = "settings.targetExtension"
        static let imageQuality = "settings.imageQuality"
        static let resizeImages = "settings.resizeImages"
        static let imageMaxDimension = "settings.imageMaxDimension"
        static let stripImageMetadata = "settings.stripImageMetadata"
        static let videoQuality = "settings.videoQuality"
        static let removeAudio = "settings.removeAudio"
        static let documentImageScale = "settings.documentImageScale"
    }
}
