import AppKit
import Foundation

struct SamplePoint: Identifiable, Equatable {
    let id: UUID
    var point: NormalizedPoint
    var radius: SamplingRadius
    var sample: ColorSample

    init(id: UUID = UUID(), point: NormalizedPoint, radius: SamplingRadius, buffer: PixelBuffer) {
        self.id = id
        self.point = point
        self.radius = radius
        self.sample = ColorAnalyzer.sample(in: buffer, at: point, radius: radius)
    }

    mutating func update(point: NormalizedPoint, radius: SamplingRadius, buffer: PixelBuffer) {
        self.point = point
        self.radius = radius
        self.sample = ColorAnalyzer.sample(in: buffer, at: point, radius: radius)
    }
}

struct PhotoAnalysisDocument: Identifiable {
    let id: UUID
    let url: URL
    let fileName: String
    let image: NSImage
    let pixelBuffer: PixelBuffer
    var bookmarkData: Data?
    var noteFolderPath: String?
    var noteFolderBookmarkData: Data?
    var noteFileName: String?
    var samplePoints: [SamplePoint]
    var histogram: ImageHistogram

    init(
        id: UUID = UUID(),
        url: URL,
        image: NSImage,
        pixelBuffer: PixelBuffer,
        defaultRadius: SamplingRadius,
        bookmarkData: Data? = nil,
        noteFolderPath: String? = nil,
        noteFolderBookmarkData: Data? = nil,
        noteFileName: String? = nil
    ) {
        self.id = id
        self.url = url
        self.fileName = url.lastPathComponent
        self.image = image
        self.pixelBuffer = pixelBuffer
        self.bookmarkData = bookmarkData
        self.noteFolderPath = noteFolderPath
        self.noteFolderBookmarkData = noteFolderBookmarkData
        self.noteFileName = noteFileName
        self.histogram = ColorAnalyzer.histogram(for: pixelBuffer)
        self.samplePoints = DefaultPointGenerator.generatePoints(in: pixelBuffer, count: 10).map {
            SamplePoint(point: $0, radius: defaultRadius, buffer: pixelBuffer)
        }
    }

    var pixelSizeText: String {
        "\(pixelBuffer.width)x\(pixelBuffer.height)"
    }
}

@MainActor
final class AnalysisViewModel: ObservableObject {
    typealias ProjectLoader = (SamplingRadius) -> (documents: [PhotoAnalysisDocument], selectedPhotoID: UUID?)

    @Published var documents: [PhotoAnalysisDocument] = []
    @Published var selectedDocumentID: UUID?
    @Published var selectedPointID: UUID?
    @Published var defaultRadius: SamplingRadius = .fiveByFive
    @Published var importError: String?
    @Published var isAddingPoint = false
    @Published var isImporting = false
    @Published var importStatusText: String?
    @Published var isImmersiveMode = false
    @Published var showsImmersiveSamplePoints = true
    @Published var selectedNoteBody = ""
    @Published var noteStatusText: String?
    @Published var isRestoringSavedProject = false
    private var noteAutosaveWorkItem: DispatchWorkItem?
    private var noteDrafts: [UUID: String] = [:]

    init(
        loadSavedProject: Bool = true,
        projectLoader: @escaping ProjectLoader = ProjectPersistence.load(defaultRadius:)
    ) {
        if loadSavedProject {
            restoreSavedProjectInBackground(projectLoader: projectLoader)
        }
    }

    var selectedDocument: PhotoAnalysisDocument? {
        document(for: selectedDocumentID)
    }

    var selectedDocumentIndex: Int? {
        guard let selectedDocumentID else {
            return nil
        }
        return documents.firstIndex { $0.id == selectedDocumentID }
    }

    var selectedPoint: SamplePoint? {
        guard let selectedPointID, let document = selectedDocument else {
            return nil
        }
        return document.samplePoints.first { $0.id == selectedPointID }
    }

    func importPhotos(from urls: [URL], noteFolderURL: URL? = nil) {
        guard !urls.isEmpty, !isImporting, !isRestoringSavedProject else {
            return
        }

        isImporting = true
        importStatusText = "准备导入 \(urls.count) 张照片"
        let radius = defaultRadius
        let noteFolderBookmarkData = noteFolderURL.flatMap { SecurityScopedResource.bookmarkData(for: $0) }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var failures: [String] = []

            for (index, url) in urls.enumerated() {
                autoreleasepool {
                    let didStartAccessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if didStartAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    do {
                        let imageData = try ImageLoader.loadImageAndPixels(from: url)
                        let document = PhotoAnalysisDocument(
                            url: url,
                            image: imageData.image,
                            pixelBuffer: imageData.pixelBuffer,
                            defaultRadius: radius,
                            bookmarkData: SecurityScopedResource.bookmarkData(for: url)
                        )
                        var documentWithNote = document
                        if let noteFolderURL {
                            documentWithNote.noteFolderPath = noteFolderURL.path
                            documentWithNote.noteFolderBookmarkData = noteFolderBookmarkData
                            documentWithNote.noteFileName = try? PhotoNoteStore.noteFileName(
                                forPhotoID: documentWithNote.id,
                                sourceURL: url,
                                in: noteFolderURL
                            )
                        }

                        DispatchQueue.main.async {
                            guard let self else {
                                return
                            }
                            self.documents.append(documentWithNote)
                            if self.selectedDocumentID == nil {
                                self.selectedDocumentID = documentWithNote.id
                                self.selectedPointID = documentWithNote.samplePoints.first?.id
                                try? self.loadSelectedNote()
                            }
                            self.importStatusText = "已导入 \(index + 1)/\(urls.count)"
                        }
                    } catch {
                        failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self?.importStatusText = "已导入 \(index + 1)/\(urls.count)"
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.isImporting = false
                self.importStatusText = nil
                if !failures.isEmpty {
                    self.importError = failures.prefix(3).joined(separator: "\n")
                }
                self.saveProject()
            }
        }
    }

    func select(document: PhotoAnalysisDocument) {
        try? saveSelectedNoteImmediately()
        selectedDocumentID = document.id
        selectedPointID = document.samplePoints.first?.id
        try? loadSelectedNote()
        saveProject()
    }

    func document(for id: UUID?) -> PhotoAnalysisDocument? {
        guard let id else {
            return nil
        }
        return documents.first { $0.id == id }
    }

    func restoreSelection(documentID: UUID?, pointID: UUID?) {
        guard let document = document(for: documentID) else {
            return
        }
        try? saveSelectedNoteImmediately()
        selectedDocumentID = document.id
        if let pointID, document.samplePoints.contains(where: { $0.id == pointID }) {
            selectedPointID = pointID
        } else {
            selectedPointID = document.samplePoints.first?.id
        }
        try? loadSelectedNote()
    }

    func selectNextPhoto() {
        guard let currentIndex = selectedDocumentIndex else {
            if let first = documents.first {
                select(document: first)
            }
            return
        }
        let nextIndex = min(documents.count - 1, currentIndex + 1)
        guard nextIndex != currentIndex else {
            return
        }
        select(document: documents[nextIndex])
    }

    func selectPreviousPhoto() {
        guard let currentIndex = selectedDocumentIndex else {
            if let first = documents.first {
                select(document: first)
            }
            return
        }
        let previousIndex = max(0, currentIndex - 1)
        guard previousIndex != currentIndex else {
            return
        }
        select(document: documents[previousIndex])
    }

    func toggleImmersiveMode() {
        isImmersiveMode.toggle()
    }

    func exitImmersiveMode() {
        isImmersiveMode = false
    }

    func toggleImmersiveSamplePoints() {
        showsImmersiveSamplePoints.toggle()
    }

    func updateSelectedNoteBody(_ body: String) {
        selectedNoteBody = body
        noteStatusText = "未保存"
    }

    func updateSelectedNoteDraft(_ body: String) {
        guard let selectedDocumentID else {
            return
        }
        noteDrafts[selectedDocumentID] = body
    }

    func scheduleSelectedNoteAutosave() {
        scheduleSelectedNoteAutosave(body: noteBodyForSaving())
    }

    func scheduleSelectedNoteAutosave(body: String) {
        noteAutosaveWorkItem?.cancel()
        guard let document = selectedDocument,
              let noteFolderPath = document.noteFolderPath,
              let noteFileName = document.noteFileName else {
            return
        }

        let noteFolderBookmarkData = document.noteFolderBookmarkData
        let documentID = document.id
        let sourceURL = document.url
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                let resolvedFolder = SecurityScopedResource.resolve(
                    bookmarkData: noteFolderBookmarkData,
                    fallbackPath: noteFolderPath,
                    isDirectory: true
                )
                defer {
                    resolvedFolder.stopAccessing()
                }
                try? PhotoNoteStore.saveNote(
                    body: body,
                    photoID: documentID,
                    sourceURL: sourceURL,
                    folderURL: resolvedFolder.url,
                    fileName: noteFileName
                )
                self?.noteDrafts[documentID] = body
            }
        }
        noteAutosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    func loadSelectedNote() throws {
        noteAutosaveWorkItem?.cancel()
        guard let document = selectedDocument,
              let noteFolderPath = document.noteFolderPath,
              let noteFileName = document.noteFileName else {
            selectedNoteBody = ""
            noteStatusText = selectedDocument == nil ? nil : "未绑定 Obsidian 文件夹"
            return
        }

        let resolvedFolder = SecurityScopedResource.resolve(
            bookmarkData: document.noteFolderBookmarkData,
            fallbackPath: noteFolderPath,
            isDirectory: true
        )
        defer {
            resolvedFolder.stopAccessing()
        }
        let noteURL = resolvedFolder.url.appendingPathComponent(noteFileName)
        if FileManager.default.fileExists(atPath: noteURL.path) {
            selectedNoteBody = try PhotoNoteStore.loadBody(from: noteURL)
            noteDrafts[document.id] = nil
            noteStatusText = "已加载 \(noteFileName)"
        } else {
            selectedNoteBody = ""
            noteDrafts[document.id] = nil
            noteStatusText = "将创建 \(noteFileName)"
        }
    }

    func saveSelectedNoteImmediately() throws {
        noteAutosaveWorkItem?.cancel()
        try saveSelectedNote(updateStatus: true)
    }

    func saveSelectedNoteSilentlyForAutosave() throws {
        try saveSelectedNote(updateStatus: false)
    }

    private func saveSelectedNote(updateStatus: Bool) throws {
        guard let document = selectedDocument,
              let noteFolderPath = document.noteFolderPath,
              let noteFileName = document.noteFileName else {
            return
        }

        let resolvedFolder = SecurityScopedResource.resolve(
            bookmarkData: document.noteFolderBookmarkData,
            fallbackPath: noteFolderPath,
            isDirectory: true
        )
        defer {
            resolvedFolder.stopAccessing()
        }
        try PhotoNoteStore.saveNote(
            body: noteBodyForSaving(),
            photoID: document.id,
            sourceURL: document.url,
            folderURL: resolvedFolder.url,
            fileName: noteFileName
        )
        if let selectedDocumentID {
            noteDrafts[selectedDocumentID] = nil
        }
        if updateStatus {
            noteStatusText = "已保存 \(noteFileName)"
        }
    }

    private func noteBodyForSaving() -> String {
        guard let selectedDocumentID else {
            return selectedNoteBody
        }
        return noteDrafts[selectedDocumentID] ?? selectedNoteBody
    }

    func bindSelectedDocumentToNoteFolder(_ folderURL: URL) throws {
        guard let documentIndex = selectedDocumentIndex else {
            return
        }
        let document = documents[documentIndex]
        let noteFileName = try PhotoNoteStore.noteFileName(
            forPhotoID: document.id,
            sourceURL: document.url,
            in: folderURL
        )
        documents[documentIndex].noteFolderPath = folderURL.path
        documents[documentIndex].noteFolderBookmarkData = SecurityScopedResource.bookmarkData(for: folderURL)
        documents[documentIndex].noteFileName = noteFileName
        saveProject()
        try loadSelectedNote()
    }

    func addPoint(_ point: NormalizedPoint) {
        guard let index = selectedDocumentIndex else {
            return
        }
        let samplePoint = SamplePoint(point: point, radius: defaultRadius, buffer: documents[index].pixelBuffer)
        documents[index].samplePoints.append(samplePoint)
        selectedPointID = samplePoint.id
        isAddingPoint = false
        saveProject()
    }

    func movePoint(id: UUID, to point: NormalizedPoint) {
        guard let documentIndex = selectedDocumentIndex,
              let pointIndex = documents[documentIndex].samplePoints.firstIndex(where: { $0.id == id }) else {
            return
        }
        let radius = documents[documentIndex].samplePoints[pointIndex].radius
        documents[documentIndex].samplePoints[pointIndex].update(
            point: point,
            radius: radius,
            buffer: documents[documentIndex].pixelBuffer
        )
        saveProject()
    }

    func deleteSelectedPoint() {
        guard let documentIndex = selectedDocumentIndex, let selectedPointID else {
            return
        }
        documents[documentIndex].samplePoints.removeAll { $0.id == selectedPointID }
        self.selectedPointID = documents[documentIndex].samplePoints.first?.id
        saveProject()
    }

    func regenerateDefaultPoints() {
        guard let documentIndex = selectedDocumentIndex else {
            return
        }
        let buffer = documents[documentIndex].pixelBuffer
        documents[documentIndex].samplePoints = DefaultPointGenerator.generatePoints(in: buffer, count: 10).map {
            SamplePoint(point: $0, radius: defaultRadius, buffer: buffer)
        }
        selectedPointID = documents[documentIndex].samplePoints.first?.id
        saveProject()
    }

    func applyDefaultRadiusToSelectedPoint() {
        guard let documentIndex = selectedDocumentIndex,
              let selectedPointID,
              let pointIndex = documents[documentIndex].samplePoints.firstIndex(where: { $0.id == selectedPointID }) else {
            return
        }
        let point = documents[documentIndex].samplePoints[pointIndex].point
        documents[documentIndex].samplePoints[pointIndex].update(
            point: point,
            radius: defaultRadius,
            buffer: documents[documentIndex].pixelBuffer
        )
        saveProject()
    }

    func persistCurrentWorkspace() {
        guard !isRestoringSavedProject else {
            return
        }
        noteAutosaveWorkItem?.cancel()
        try? saveSelectedNote(updateStatus: false)
        saveProject()
    }

    private func restoreSavedProjectInBackground(projectLoader: @escaping ProjectLoader) {
        isRestoringSavedProject = true
        let radius = defaultRadius

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let restored = projectLoader(radius)

            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.documents = restored.documents
                if let selectedPhotoID = restored.selectedPhotoID,
                   restored.documents.contains(where: { $0.id == selectedPhotoID }) {
                    self.selectedDocumentID = selectedPhotoID
                } else {
                    self.selectedDocumentID = restored.documents.first?.id
                }
                self.selectedPointID = self.selectedDocument?.samplePoints.first?.id
                try? self.loadSelectedNote()
                self.isRestoringSavedProject = false
            }
        }
    }

    private func saveProject() {
        guard !isRestoringSavedProject else {
            return
        }
        ProjectPersistence.save(documents: documents, selectedPhotoID: selectedDocumentID)
    }
}
