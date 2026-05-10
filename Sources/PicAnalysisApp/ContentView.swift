import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = AnalysisViewModel()
    @State private var isShowingImporter = false

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
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.jpeg, .png, .heic],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    viewModel.importPhotos(from: urls)
                case .failure(let error):
                    viewModel.importError = error.localizedDescription
                }
            }
            .alert("导入失败", isPresented: Binding(
                get: { viewModel.importError != nil },
                set: { if !$0 { viewModel.importError = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.importError ?? "")
            }
    }

    @ViewBuilder
    private func rootContent(layout: WorkspaceLayout, size: CGSize) -> some View {
        if viewModel.isImmersiveMode {
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

                histogramContent
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
                    isShowingImporter = true
                } label: {
                    Label("导入照片", systemImage: "photo.badge.plus")
                }
                .disabled(viewModel.isImporting)

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

    private var histogramContent: some View {
        Group {
            if let document = viewModel.selectedDocument {
                HistogramPanel(histogram: document.histogram)
            } else {
                Text("导入照片后会在这里显示亮度和 RGB 直方图")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Text("\(document.samplePoints.count) 点")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
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
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)

            sampleTable
        }
        .foregroundStyle(.white)
        .padding(30)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.095, blue: 0.11),
                    Color(red: 0.055, green: 0.065, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
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
            .background(Color.white.opacity(0.08))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(document.samplePoints.enumerated()), id: \.element.id) { index, point in
                        HStack(spacing: 0) {
                            Text("\(index + 1)")
                                .frame(width: 42)
                                .foregroundStyle(.white.opacity(0.9))
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
                        .foregroundStyle(point.id == selectedPointID ? .white : .white.opacity(0.7))
                        .padding(.vertical, 10)
                        .background(point.id == selectedPointID ? Color.white.opacity(0.11) : Color.clear)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }

    private func tableHeader(_ title: String, width: CGFloat?, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.58))
            .frame(width: width, alignment: alignment)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
