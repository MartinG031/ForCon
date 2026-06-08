import AppKit
import FormatConverterCore
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()
    @State private var didCheckForUpdatesOnLaunch = false
    @State private var isSettingsPresented = false
    @AppStorage("startup.permissions.completed") private var startupPermissionsCompleted = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            mainPanel
        }
        .onReceive(NotificationCenter.default.publisher(for: .forConAddFiles)) { _ in
            viewModel.pickFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: .forConChooseOutputDirectory)) { _ in
            viewModel.pickOutputDirectory()
        }
        .onReceive(NotificationCenter.default.publisher(for: .forConStartConversion)) { _ in
            Task { await viewModel.convert() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .forConClearFiles)) { _ in
            viewModel.clear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .forConCheckForUpdates)) { _ in
            Task { await viewModel.checkForUpdates() }
        }
        .task {
            guard !didCheckForUpdatesOnLaunch else { return }
            didCheckForUpdatesOnLaunch = true
            await viewModel.checkForUpdatesOnLaunch()
        }
        .sheet(isPresented: Binding(
            get: { !startupPermissionsCompleted },
            set: { if !$0 { startupPermissionsCompleted = true } }
        )) {
            StartupPermissionView(viewModel: viewModel) {
                startupPermissionsCompleted = true
            }
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: viewModel)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("格式转换")
                            .font(.title2.weight(.semibold))
                        Text("图片、视频、文档批量转换")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Picker("类型", selection: $viewModel.category) {
                        ForEach(FormatCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)

                    outputFormatSection

                    Divider()

                    Button {
                        viewModel.pickFiles()
                    } label: {
                        Label("添加文件", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button {
                        Task { await viewModel.convert() }
                    } label: {
                        Label("开始转换", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canConvert)

                }
                .padding(20)
            }
            Button {
                isSettingsPresented = true
            } label: {
                Label("设置", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 280)
    }

    private var outputFormatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("输出格式")
                .font(.headline)
            if viewModel.category == .automatic {
                targetPicker("图片", selection: $viewModel.imageTargetExtension, category: .image)
                targetPicker("视频", selection: $viewModel.videoTargetExtension, category: .video)
                targetPicker("文档", selection: $viewModel.documentTargetExtension, category: .document)
            } else {
                Picker("", selection: $viewModel.targetExtension) {
                    ForEach(viewModel.availableOutputExtensions, id: \.self) { ext in
                        Text(".\(ext)").tag(ext)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func targetPicker(
        _ title: String,
        selection: Binding<String>,
        category: FormatCategory
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(viewModel.availableOutputExtensions(for: category), id: \.self) { ext in
                    Text(".\(ext)").tag(ext)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 96)
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if viewModel.inputURLs.isEmpty {
                emptyState
            } else {
                fileList
            }
            Divider()
            resultPanel
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("\(viewModel.inputURLs.count) 个文件")
                .font(.headline)
            Spacer()
            if viewModel.isConverting {
                HStack(spacing: 8) {
                    Text("\(viewModel.processedCount)/\(viewModel.totalCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let estimatedRemainingText = viewModel.estimatedRemainingText {
                        Text(estimatedRemainingText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: viewModel.progress)
                        .frame(width: 180)
                }
            }
            Button {
                viewModel.clear()
            } label: {
                Label("清空", systemImage: "trash")
            }
            .disabled(viewModel.inputURLs.isEmpty || viewModel.isConverting)
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("拖入文件或点击添加文件")
                .font(.title3.weight(.medium))
            Text("支持图片、视频和常见文本/PDF 文档转换")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.handleDrop(providers)
        }
    }

    private var fileList: some View {
        List {
            ForEach(viewModel.inputURLs, id: \.self) { url in
                HStack(spacing: 12) {
                    Image(systemName: iconName(for: url))
                        .frame(width: 24)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                        Text(viewModel.detectedCategoryName(for: url))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        viewModel.remove(url)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isConverting)
                }
                .padding(.vertical, 4)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.handleDrop(providers)
        }
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("结果")
                    .font(.headline)
                Spacer()
                if !viewModel.results.isEmpty {
                    Button {
                        NSWorkspace.shared.open(viewModel.outputDirectory)
                    } label: {
                        Label("打开输出目录", systemImage: "folder")
                    }
                }
            }

            if let message = viewModel.message {
                Text(message)
                    .foregroundStyle(viewModel.hasError ? .red : .secondary)
                    .lineLimit(2)
            }

            if !viewModel.results.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.results) { result in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: result.status.isSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(result.status.isSucceeded ? .green : .orange)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.inputURL.lastPathComponent)
                                    Text(result.status.message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !result.outputURLs.isEmpty {
                                        Text(result.outputURLs.map(\.lastPathComponent).joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func iconName(for url: URL) -> String {
        switch viewModel.detectedCategory(for: url) {
        case .image: "photo"
        case .video: "film"
        case .document: "doc.text"
        default: "doc"
        }
    }
}

private struct StartupPermissionView: View {
    @Bindable var viewModel: ConverterViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                Text("开始使用 ForCon")
                    .font(.title2.weight(.semibold))
                Text("首次启动需要确认文件读写位置。ForCon 只会处理你选择或拖入的文件，并把结果写入授权的输出目录。")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    icon: "folder.badge.gearshape",
                    title: "输出目录权限",
                    detail: viewModel.outputDirectory.path
                )
                permissionRow(
                    icon: "doc.badge.plus",
                    title: "输入文件访问",
                    detail: "通过添加文件或拖入文件时逐次授权"
                )
                permissionRow(
                    icon: "arrow.down.circle",
                    title: "在线更新",
                    detail: "仅检查或安装更新时访问 GitHub Releases"
                )
            }

            HStack {
                Button("选择输出目录并继续") {
                    if viewModel.requestOutputDirectoryAccess() {
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("使用下载文件夹") {
                    onComplete()
                }
            }
        }
        .padding(28)
        .frame(width: 520)
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct SettingsView: View {
    @Bindable var viewModel: ConverterViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settings.section.outputDirectory.expanded") private var outputDirectoryExpanded = true
    @AppStorage("settings.section.image.expanded") private var imageExpanded = true
    @AppStorage("settings.section.video.expanded") private var videoExpanded = true
    @AppStorage("settings.section.document.expanded") private var documentExpanded = true
    @AppStorage("settings.section.dependencies.expanded") private var dependenciesExpanded = true
    @AppStorage("settings.section.app.expanded") private var appExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设置")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    outputDirectorySettings
                    Divider()
                    imageSettings
                    Divider()
                    videoSettings
                    Divider()
                    documentSettings
                    Divider()
                    dependencySettings
                    Divider()
                    appSettings
                }
                .padding(24)
            }
        }
        .frame(width: 620, height: 720)
    }

    private var appSettings: some View {
        SettingsSection(title: "应用", icon: "app.badge", isExpanded: $appExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("当前版本")
                    Spacer()
                    Text(viewModel.currentVersion)
                        .foregroundStyle(.secondary)
                }

                if let updateMessage = viewModel.updateMessage {
                    Text(updateMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }

    private var outputDirectorySettings: some View {
        SettingsSection(title: "输出目录", icon: "folder", isExpanded: $outputDirectoryExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.outputDirectory.path)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)

                Button {
                    viewModel.pickOutputDirectory()
                } label: {
                    Label("选择输出目录", systemImage: "folder")
                }
            }
        }
    }

    private var imageSettings: some View {
        SettingsSection(title: "图片设置", icon: "photo", isExpanded: $imageExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                imageQualityControl
                Toggle("限制图片尺寸", isOn: $viewModel.resizeImages)
                HStack {
                    Text("最大边长")
                    Spacer()
                    Text("\(Int(viewModel.imageMaxDimension)) px")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.imageMaxDimension, in: 256...8192, step: 256)
                    .disabled(!viewModel.resizeImages)
                Toggle("移除图片元数据", isOn: $viewModel.stripImageMetadata)
            }
        }
    }

    private var videoSettings: some View {
        SettingsSection(title: "视频设置", icon: "film", isExpanded: $videoExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("视频质量", selection: $viewModel.videoQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.menu)
                Toggle("移除音频", isOn: $viewModel.removeAudio)
            }
        }
    }

    private var documentSettings: some View {
        SettingsSection(title: "文档设置", icon: "doc.text", isExpanded: $documentExpanded) {
            documentScaleControl
        }
    }

    private var dependencySettings: some View {
        SettingsSection(title: "转换组件", icon: "wrench.and.screwdriver", isExpanded: $dependenciesExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(viewModel.externalToolStatuses) { status in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: status.isInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(status.isInstalled ? .green : .orange)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(status.displayName)
                                Spacer()
                                Text(status.isInstalled ? "已安装" : "未安装")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(status.purpose)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(status.executablePath ?? status.installHint)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                Button {
                    viewModel.refreshExternalToolStatuses()
                } label: {
                    Label("重新检测", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private var imageQualityControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("图片质量")
                Spacer()
                Text("\(Int(viewModel.imageQuality * 100))%")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $viewModel.imageQuality, in: 0.2...1.0)
        }
    }

    private var documentScaleControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PDF 图片倍率")
                Spacer()
                Text(String(format: "%.1fx", viewModel.documentImageScale))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $viewModel.documentImageScale, in: 1.0...4.0, step: 0.5)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    let content: Content

    init(title: String, icon: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.top, 12)
        } label: {
            Label(title, systemImage: icon)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AboutForConView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "开发版"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ForCon")
                        .font(.title2.weight(.semibold))
                    Text("版本 \(version)")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("可信声明")
                    .font(.headline)
                Label("文件仅在本机处理，不上传到云端或第三方服务器", systemImage: "lock.shield")
                Label("输出文件只写入用户选择的输出目录", systemImage: "folder")
                Label("仅检查或安装更新时访问 GitHub Releases", systemImage: "network")
                Label("下载的安装包会先进行 SHA-256 校验", systemImage: "checkmark.seal")
                Label("转换能力来自 macOS 系统框架和本机安装的转换工具", systemImage: "wrench.and.screwdriver")
            }
            .font(.callout)

            Text("本发行包为本地 ad-hoc 签名；没有 Apple Developer ID 公证。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 520)
    }
}
