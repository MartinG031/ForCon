import AppKit
import FormatConverterCore
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()
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
        .sheet(isPresented: Binding(
            get: { !startupPermissionsCompleted },
            set: { if !$0 { startupPermissionsCompleted = true } }
        )) {
            StartupPermissionView(viewModel: viewModel) {
                startupPermissionsCompleted = true
            }
            .interactiveDismissDisabled(true)
        }
    }

    private var sidebar: some View {
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
                settingsPanel

                Divider()

                Button {
                    viewModel.pickFiles()
                } label: {
                    Label("添加文件", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Button {
                    viewModel.pickOutputDirectory()
                } label: {
                    Label("选择输出目录", systemImage: "folder")
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

                Button {
                    Task { await viewModel.checkForUpdates() }
                } label: {
                    Label(viewModel.isCheckingForUpdate ? "检查中..." : "自动更新", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(viewModel.isCheckingForUpdate)

                if let updateMessage = viewModel.updateMessage {
                    Text(updateMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                outputPathView
            }
            .padding(20)
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

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch viewModel.category {
            case .image:
                imageSettings
            case .video:
                videoSettings
            case .document:
                documentSettings
            case .automatic:
                DisclosureGroup("常用设置") {
                    VStack(alignment: .leading, spacing: 14) {
                        imageQualityControl
                        videoQualityControl
                        documentScaleControl
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var imageSettings: some View {
        DisclosureGroup("图片设置") {
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
            .padding(.top, 8)
        }
    }

    private var videoSettings: some View {
        DisclosureGroup("视频设置") {
            VStack(alignment: .leading, spacing: 14) {
                videoQualityControl
                Toggle("移除音频", isOn: $viewModel.removeAudio)
            }
            .padding(.top, 8)
        }
    }

    private var documentSettings: some View {
        DisclosureGroup("文档设置") {
            VStack(alignment: .leading, spacing: 14) {
                documentScaleControl
            }
            .padding(.top, 8)
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

    private var videoQualityControl: some View {
        Picker("视频质量", selection: $viewModel.videoQuality) {
            ForEach(VideoQuality.allCases) { quality in
                Text(quality.displayName).tag(quality)
            }
        }
        .pickerStyle(.menu)
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

    private var outputPathView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("输出目录")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.outputDirectory.path)
                .font(.caption)
                .lineLimit(3)
                .textSelection(.enabled)
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
                    detail: "仅点击自动更新时访问 GitHub Releases"
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
                Label("仅点击自动更新时检查 GitHub Releases 更新源", systemImage: "network")
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
