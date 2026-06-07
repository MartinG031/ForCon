import AppKit
import FormatConverterCore
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            mainPanel
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

                trustStatement
                outputPathView
            }
            .padding(20)
        }
        .frame(minWidth: 280)
    }

    private var trustStatement: some View {
        DisclosureGroup("可信声明") {
            VStack(alignment: .leading, spacing: 8) {
                Label("文件仅在本机处理", systemImage: "lock.shield")
                Label("不会上传到云端或服务器", systemImage: "icloud.slash")
                Label("输出只写入所选目录", systemImage: "folder")
                Label("仅点击自动更新时检查更新源", systemImage: "network")
                Label("转换组件来自 macOS 与本机工具", systemImage: "checkmark.seal")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
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
                ProgressView(value: viewModel.progress)
                    .frame(width: 180)
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
