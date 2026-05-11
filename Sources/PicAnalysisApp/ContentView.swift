import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AnalysisViewModel()
    @State private var pendingImportPhotoURLs: [URL] = []

    var body: some View {
        GeometryReader { proxy in
            let layout = WorkspaceLayout(size: proxy.size)

            rootContent(layout: layout, size: proxy.size)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(minWidth: 1100, minHeight: 720)
        .background(
            KeyboardEventView { event in
                handleKeyDown(event)
            }
            .frame(width: 0, height: 0)
        )
            .alert("导入失败", isPresented: Binding(
                get: { viewModel.importError != nil },
                set: { if !$0 { viewModel.importError = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.importError ?? "")
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active {
                    viewModel.persistCurrentWorkspace()
                }
            }
    }

    @ViewBuilder
    private func rootContent(layout: WorkspaceLayout, size: CGSize) -> some View {
        if viewModel.documents.isEmpty {
            ImportHomeView(
                isBusy: viewModel.isImporting || viewModel.isRestoringSavedProject,
                statusText: viewModel.isRestoringSavedProject ? "正在恢复上次导入的照片" : viewModel.importStatusText
            ) {
                presentPhotoImportPanel()
            }
            .frame(width: size.width, height: size.height)
        } else if viewModel.isImmersiveMode {
            immersiveContent
                .frame(width: size.width, height: size.height)
        } else {
            VStack(spacing: 0) {
                toolbar
                    .frame(height: layout.headerHeight)
                    .clipped()
                    .layoutPriority(3)

                Divider()

                workspaceContent
                    .frame(height: layout.contentHeight)
                    .clipped()
                    .layoutPriority(2)

                Divider()

                bottomContent
                    .frame(height: layout.histogramHeight)
                    .clipped()
                    .layoutPriority(1)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Button {
                    presentPhotoImportPanel()
                } label: {
                    Label("导入照片", systemImage: "photo.badge.plus")
                }
                .disabled(viewModel.isImporting || viewModel.isRestoringSavedProject)

                Button {
                    exportSelectedDocument()
                } label: {
                    Label("导出分析图", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.selectedDocument == nil || viewModel.isImporting)

                Button {
                    viewModel.toggleImmersiveMode()
                } label: {
                    Label("沉浸看图", systemImage: "rectangle.expand.vertical")
                }
                .disabled(viewModel.selectedDocument == nil)

                Button {
                    viewModel.showsClippedHighlightOverlay.toggle()
                } label: {
                    Label(
                        viewModel.showsClippedHighlightOverlay ? "隐藏高光裁剪" : "显示高光裁剪",
                        systemImage: "sun.max"
                    )
                }
                .disabled(viewModel.selectedDocument == nil)
                .tint(viewModel.showsClippedHighlightOverlay ? .red : nil)

                Button {
                    viewModel.showsCrushedShadowOverlay.toggle()
                } label: {
                    Label(
                        viewModel.showsCrushedShadowOverlay ? "隐藏阴影挤压" : "显示阴影挤压",
                        systemImage: "moon.stars"
                    )
                }
                .disabled(viewModel.selectedDocument == nil)
                .tint(viewModel.showsCrushedShadowOverlay ? .orange : nil)
            }
            .frame(minWidth: 320, alignment: .leading)
            .layoutPriority(2)

            VStack(spacing: 2) {
                Text(viewModel.selectedDocument?.fileName ?? "未选择照片")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)

                if let status = viewModel.importStatusText {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 160, maxWidth: .infinity)
            .layoutPriority(1)

            HStack(spacing: 8) {
                if viewModel.isImporting {
                    ProgressView()
                        .scaleEffect(0.72)
                        .frame(width: 18, height: 18)
                }

                Picker("采样半径", selection: $viewModel.defaultRadius) {
                    ForEach(SamplingRadius.allCases) { radius in
                        Text(radius.title).tag(radius)
                    }
                }
                .frame(width: 160)
                .onChange(of: viewModel.defaultRadius) { _ in
                    viewModel.applyDefaultRadiusToSelectedPoint()
                }
            }
            .frame(minWidth: 190, alignment: .trailing)
            .layoutPriority(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
    }

    private func exportSelectedDocument() {
        let documentID = viewModel.selectedDocumentID
        let pointID = viewModel.selectedPointID
        let document = viewModel.document(for: documentID)
        Exporter.export(document: document)
        viewModel.restoreSelection(documentID: documentID, pointID: pointID)
        DispatchQueue.main.async {
            viewModel.restoreSelection(documentID: documentID, pointID: pointID)
        }
    }

    private func presentPhotoImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "选择要导入的照片"
        panel.message = "请选择 JPG、PNG 或 HEIC 照片。下一步会选择 Obsidian 笔记文件夹。"
        panel.prompt = "选择照片"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.jpeg, .png, .heic]

        guard panel.runModal() == .OK else {
            return
        }

        pendingImportPhotoURLs = panel.urls
        presentImportNoteFolderPicker()
    }

    private func presentImportNoteFolderPicker() {
        guard !pendingImportPhotoURLs.isEmpty else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = "选择 Obsidian 笔记文件夹"
        panel.message = "FrameLab 会在该文件夹下为每张照片生成同名 Markdown 笔记。"
        panel.prompt = "选择笔记文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        let response = panel.runModal()
        let photoURLs = pendingImportPhotoURLs
        pendingImportPhotoURLs = []

        guard response == .OK, let folderURL = panel.url else {
            return
        }
        viewModel.importPhotos(from: photoURLs, noteFolderURL: folderURL)
    }

    private var workspaceContent: some View {
        HSplitView {
            PhotoListView(viewModel: viewModel)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            PhotoCanvasView(viewModel: viewModel)
                .frame(minWidth: 520)

            SampleInspectorView(viewModel: viewModel)
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
        }
    }

    private var immersiveContent: some View {
        ZStack {
            if viewModel.showsImmersiveSamplePoints, let document = viewModel.selectedDocument {
                HStack(spacing: 0) {
                    PhotoCanvasView(
                        viewModel: viewModel,
                        showsSamplePoints: true
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()
                        .background(Color.white.opacity(0.18))

                    ImmersiveSampleInfoPanel(
                        document: document,
                        selectedPointID: viewModel.selectedPointID
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                PhotoCanvasView(
                    viewModel: viewModel,
                    showsSamplePoints: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            immersiveToolbar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .background(Color.black.opacity(0.92))
    }

    private var immersiveToolbar: some View {
        HStack(spacing: 10) {
            if let document = viewModel.selectedDocument {
                Text(document.fileName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button {
                viewModel.toggleImmersiveSamplePoints()
            } label: {
                Label(
                    viewModel.showsImmersiveSamplePoints ? "隐藏采样点" : "显示采样点",
                    systemImage: viewModel.showsImmersiveSamplePoints ? "eye.slash" : "eye"
                )
            }

            Button {
                viewModel.exitImmersiveMode()
            } label: {
                Label("退出", systemImage: "xmark")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(14)
    }

    private var bottomContent: some View {
        GeometryReader { proxy in
            let histogramWidth = max(320, proxy.size.width * 0.4)

            HStack(spacing: 12) {
                Group {
                    if let document = viewModel.selectedDocument {
                        HistogramPanel(
                            histogram: document.histogram,
                            exposureAnalysis: document.exposureAnalysis
                        )
                    } else {
                        Text("导入照片后会在这里显示亮度和 RGB 直方图")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: histogramWidth, height: proxy.size.height)

                Divider()

                PhotoNoteEditorView(viewModel: viewModel)
                    .frame(width: max(0, proxy.size.width - histogramWidth - 13), height: proxy.size.height)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 125:
            viewModel.selectNextPhoto()
            return true
        case 126:
            viewModel.selectPreviousPhoto()
            return true
        case 53:
            viewModel.exitImmersiveMode()
            return true
        default:
            return false
        }
    }
}

private struct ImportHomeView: View {
    let isBusy: Bool
    let statusText: String?
    let onImport: () -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 72, height: 72)

                VStack(spacing: 8) {
                    Text("FrameLab")
                        .font(.system(size: 36, weight: .semibold))
                    Text("照片学习与分析工具箱")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Button {
                    onImport()
                } label: {
                    Label("导入照片并选择笔记文件夹", systemImage: "photo.badge.plus")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isBusy)
                .padding(.top, 8)

                if isBusy {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.75)
                        Text(statusText ?? "正在处理照片")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 24)
                }

                VStack(spacing: 5) {
                    Text("支持 JPG / PNG / HEIC")
                    Text("每张照片会在 Obsidian 文件夹中生成同名 Markdown 笔记")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 520)
            .padding(32)
        }
    }
}

private struct PhotoNoteEditorView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    @State private var noteDraft = ""
    @State private var loadedDocumentID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("照片笔记")
                        .font(.headline)
                    Text(noteSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button {
                    chooseNoteFolderForSelectedDocument()
                } label: {
                    Label("绑定文件夹", systemImage: "folder.badge.plus")
                }
                .disabled(viewModel.selectedDocument == nil)

                Button {
                    viewModel.updateSelectedNoteDraft(noteDraft)
                    try? viewModel.saveSelectedNoteImmediately()
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
                .disabled(!canEditNote)
            }

            TextEditor(text: Binding(
                get: { noteDraft },
                set: { newValue in
                    noteDraft = newValue
                    viewModel.updateSelectedNoteDraft(newValue)
                    viewModel.scheduleSelectedNoteAutosave(body: newValue)
                }
            ))
            .font(.body)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .disabled(!canEditNote)
            .overlay {
                if viewModel.selectedDocument != nil && !canEditNote {
                    Text("为当前照片绑定 Obsidian 文件夹后开始记录笔记")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
        .onAppear {
            syncDraftFromViewModelIfNeeded(force: true)
        }
        .onChange(of: viewModel.selectedDocumentID) { _ in
            syncDraftFromViewModelIfNeeded(force: true)
        }
        .onChange(of: viewModel.selectedNoteBody) { _ in
            syncDraftFromViewModelIfNeeded(force: false)
        }
    }

    private var canEditNote: Bool {
        viewModel.selectedDocument?.noteFolderPath != nil && viewModel.selectedDocument?.noteFileName != nil
    }

    private var noteSubtitle: String {
        guard let document = viewModel.selectedDocument else {
            return "未选择照片"
        }
        if let status = viewModel.noteStatusText {
            return status
        }
        if let noteFileName = document.noteFileName {
            return noteFileName
        }
        return "未绑定 Obsidian 文件夹"
    }

    private func chooseNoteFolderForSelectedDocument() {
        let panel = NSOpenPanel()
        panel.title = "选择当前照片的 Obsidian 保存文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            return
        }
        try? viewModel.bindSelectedDocumentToNoteFolder(folderURL)
        syncDraftFromViewModelIfNeeded(force: true)
    }

    private func syncDraftFromViewModelIfNeeded(force: Bool) {
        let documentID = viewModel.selectedDocumentID
        guard force || loadedDocumentID != documentID else {
            return
        }
        loadedDocumentID = documentID
        noteDraft = viewModel.selectedNoteBody
    }
}

private struct WorkspaceLayout {
    let headerHeight: CGFloat
    let histogramHeight: CGFloat
    let contentHeight: CGFloat

    init(size: CGSize) {
        headerHeight = 56
        let dividerHeight: CGFloat = 2
        let availableHeight = max(0, size.height - headerHeight - dividerHeight)
        histogramHeight = min(260, max(180, availableHeight * 0.24))
        contentHeight = max(360, availableHeight - histogramHeight)
    }
}

private struct ImmersiveSampleInfoPanel: View {
    let document: PhotoAnalysisDocument
    var selectedPointID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("采样点信息")
                        .font(.title2.weight(.semibold))
                    Text("HSL / Color Wheel")
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }
                Spacer()
                Text("\(document.samplePoints.count) 点")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            ColorWheelView(
                samplePoints: document.samplePoints,
                selectedPointID: selectedPointID
            )
            .frame(maxWidth: .infinity)
            .frame(height: 390)
            .padding(.vertical, 4)

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)

            sampleTable
        }
        .foregroundStyle(Color(nsColor: .labelColor))
        .padding(30)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
        }
    }

    private var sampleTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tableHeader("#", width: 42, alignment: .center)
                tableHeader("H", width: 70)
                tableHeader("S", width: 70)
                tableHeader("L", width: 70)
                tableHeader("Hex", width: nil)
            }
            .padding(.vertical, 9)
            .background(Color(nsColor: .controlBackgroundColor))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(document.samplePoints.enumerated()), id: \.element.id) { index, point in
                        HStack(spacing: 0) {
                            Text("\(index + 1)")
                                .frame(width: 42)
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                            Text("\(Int(point.sample.hsl.hue.rounded()))°")
                                .frame(width: 70, alignment: .leading)
                            Text(percent(point.sample.hsl.saturation))
                                .frame(width: 70, alignment: .leading)
                            Text(percent(point.sample.hsl.lightness))
                                .frame(width: 70, alignment: .leading)
                            Text(point.sample.hex)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.system(size: 15, weight: point.id == selectedPointID ? .semibold : .regular, design: .monospaced))
                        .foregroundStyle(point.id == selectedPointID ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
                        .padding(.vertical, 10)
                        .background(point.id == selectedPointID ? Color.yellow.opacity(0.18) : Color.clear)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color(nsColor: .separatorColor).opacity(0.55))
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func tableHeader(_ title: String, width: CGFloat?, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .frame(width: width, alignment: alignment)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
