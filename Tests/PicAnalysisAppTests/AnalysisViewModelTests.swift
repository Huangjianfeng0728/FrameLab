import AppKit
import Testing
@testable import PicAnalysisApp

@MainActor
@Suite
struct AnalysisViewModelTests {
    @Test
    func selectsNextAndPreviousPhotoWithKeyboardNavigation() {
        let viewModel = AnalysisViewModel(loadSavedProject: false)
        let first = makeDocument(name: "first.jpg", color: PicAnalysisApp.RGBColor(red: 10, green: 20, blue: 30))
        let second = makeDocument(name: "second.jpg", color: PicAnalysisApp.RGBColor(red: 40, green: 50, blue: 60))
        let third = makeDocument(name: "third.jpg", color: PicAnalysisApp.RGBColor(red: 70, green: 80, blue: 90))
        viewModel.documents = [first, second, third]
        viewModel.restoreSelection(documentID: first.id, pointID: Optional<UUID>.none)

        viewModel.selectNextPhoto()
        #expect(viewModel.selectedDocumentID == second.id)

        viewModel.selectNextPhoto()
        #expect(viewModel.selectedDocumentID == third.id)

        viewModel.selectNextPhoto()
        #expect(viewModel.selectedDocumentID == third.id)

        viewModel.selectPreviousPhoto()
        #expect(viewModel.selectedDocumentID == second.id)
    }

    @Test
    func togglesImmersiveViewingMode() {
        let viewModel = AnalysisViewModel(loadSavedProject: false)

        #expect(viewModel.isImmersiveMode == false)
        viewModel.toggleImmersiveMode()
        #expect(viewModel.isImmersiveMode == true)
        viewModel.toggleImmersiveMode()
        #expect(viewModel.isImmersiveMode == false)
    }

    @Test
    func togglesImmersiveSamplePointVisibility() {
        let viewModel = AnalysisViewModel(loadSavedProject: false)

        #expect(viewModel.showsImmersiveSamplePoints == true)
        viewModel.toggleImmersiveSamplePoints()
        #expect(viewModel.showsImmersiveSamplePoints == false)
        viewModel.toggleImmersiveSamplePoints()
        #expect(viewModel.showsImmersiveSamplePoints == true)
    }

    @Test
    func appTerminatesWhenLastWindowCloses() {
        let delegate = FrameLabAppDelegate()

        #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }

    @Test
    func savedProjectRestoresInBackgroundWithoutBlockingInitialization() async throws {
        let restored = makeDocument(name: "restored.jpg", color: PicAnalysisApp.RGBColor(red: 10, green: 20, blue: 30))
        let loadStarted = ThreadSafeFlag()
        let allowLoadToFinish = ThreadSafeFlag()

        let start = Date()
        let viewModel = AnalysisViewModel(loadSavedProject: true) { _ in
            loadStarted.set()
            while !allowLoadToFinish.isSet {
                Thread.sleep(forTimeInterval: 0.01)
            }
            return ([restored], restored.id)
        }
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 0.2)
        #expect(viewModel.isRestoringSavedProject)
        #expect(viewModel.documents.isEmpty)
        try await waitUntil(loadStarted.isSet)

        allowLoadToFinish.set()
        try await waitUntil(viewModel.documents.count == 1)

        #expect(viewModel.documents.map { $0.id } == [restored.id])
        #expect(viewModel.selectedDocumentID == restored.id)
        #expect(viewModel.isRestoringSavedProject == false)
    }

    @Test
    func savesAndLoadsSelectedPhotoNote() throws {
        let folder = try temporaryDirectory()
        let viewModel = AnalysisViewModel(loadSavedProject: false)
        var document = makeDocument(name: "note-photo.jpg", color: PicAnalysisApp.RGBColor(red: 10, green: 20, blue: 30))
        document.noteFolderPath = folder.path
        document.noteFileName = "note-photo.md"
        viewModel.documents = [document]
        viewModel.restoreSelection(documentID: document.id, pointID: Optional<UUID>.none)

        viewModel.updateSelectedNoteBody("这张照片的暗部很稳。")
        try viewModel.saveSelectedNoteImmediately()
        viewModel.updateSelectedNoteBody("")
        try viewModel.loadSelectedNote()

        #expect(viewModel.selectedNoteBody == "这张照片的暗部很稳。")
    }

    @Test
    func autosaveDoesNotChangeNoteStatusWhileTyping() throws {
        let folder = try temporaryDirectory()
        let viewModel = AnalysisViewModel(loadSavedProject: false)
        var document = makeDocument(name: "typing-photo.jpg", color: PicAnalysisApp.RGBColor(red: 10, green: 20, blue: 30))
        document.noteFolderPath = folder.path
        document.noteFileName = "typing-photo.md"
        viewModel.documents = [document]
        viewModel.restoreSelection(documentID: document.id, pointID: Optional<UUID>.none)

        viewModel.updateSelectedNoteBody("Xi")
        let statusBeforeAutosave = viewModel.noteStatusText
        try viewModel.saveSelectedNoteSilentlyForAutosave()

        #expect(statusBeforeAutosave == "未保存")
        #expect(viewModel.noteStatusText == "未保存")
        #expect(try PhotoNoteStore.loadBody(from: folder.appendingPathComponent("typing-photo.md")) == "Xi")
    }

    @Test
    func persistsCurrentWorkspaceSavesUnsavedNoteDraft() throws {
        let folder = try temporaryDirectory()
        let viewModel = AnalysisViewModel(loadSavedProject: false)
        var document = makeDocument(name: "quit-photo.jpg", color: PicAnalysisApp.RGBColor(red: 10, green: 20, blue: 30))
        document.noteFolderPath = folder.path
        document.noteFileName = "quit-photo.md"
        viewModel.documents = [document]
        viewModel.restoreSelection(documentID: document.id, pointID: Optional<UUID>.none)

        viewModel.updateSelectedNoteDraft("退出前还没自动保存的内容")
        viewModel.persistCurrentWorkspace()

        #expect(try PhotoNoteStore.loadBody(from: folder.appendingPathComponent("quit-photo.md")) == "退出前还没自动保存的内容")
    }

    @Test
    func persistedProjectSupportsSecurityScopedBookmarks() throws {
        let photoBookmark = Data([1, 2, 3])
        let noteFolderBookmark = Data([4, 5, 6])
        let project = PersistedProject(
            photos: [
                PersistedPhoto(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    path: "/photos/1.png",
                    bookmarkData: photoBookmark,
                    noteFolderPath: "/vault/notes",
                    noteFolderBookmarkData: noteFolderBookmark,
                    noteFileName: "1.md",
                    points: []
                )
            ],
            selectedPhotoID: nil
        )

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(PersistedProject.self, from: data)

        #expect(decoded.photos.first?.bookmarkData == photoBookmark)
        #expect(decoded.photos.first?.noteFolderBookmarkData == noteFolderBookmark)
    }

    @Test
    func switchingPhotosSavesCurrentNoteAndLoadsNextNote() throws {
        let folder = try temporaryDirectory()
        let viewModel = AnalysisViewModel(loadSavedProject: false)
        var first = makeDocument(name: "first-note.jpg", color: PicAnalysisApp.RGBColor(red: 10, green: 20, blue: 30))
        var second = makeDocument(name: "second-note.jpg", color: PicAnalysisApp.RGBColor(red: 40, green: 50, blue: 60))
        first.noteFolderPath = folder.path
        first.noteFileName = "first-note.md"
        second.noteFolderPath = folder.path
        second.noteFileName = "second-note.md"
        try PhotoNoteStore.saveNote(
            body: "第二张已有笔记",
            photoID: second.id,
            sourceURL: second.url,
            folderURL: folder,
            fileName: "second-note.md"
        )
        viewModel.documents = [first, second]
        viewModel.restoreSelection(documentID: first.id, pointID: Optional<UUID>.none)

        viewModel.updateSelectedNoteBody("第一张新笔记")
        viewModel.selectNextPhoto()

        let firstBody = try PhotoNoteStore.loadBody(from: folder.appendingPathComponent("first-note.md"))
        #expect(firstBody == "第一张新笔记")
        #expect(viewModel.selectedDocumentID == second.id)
        #expect(viewModel.selectedNoteBody == "第二张已有笔记")
    }

    private func makeDocument(name: String, color: PicAnalysisApp.RGBColor) -> PhotoAnalysisDocument {
        PhotoAnalysisDocument(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            image: NSImage(size: CGSize(width: 2, height: 2)),
            pixelBuffer: PixelBuffer(width: 2, height: 2, pixels: Array(repeating: color, count: 4)),
            defaultRadius: .singlePixel
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FrameLabViewModelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func waitUntil(_ condition: @autoclosure () -> Bool) async throws {
        for _ in 0..<30 {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(condition())
    }
}

private final class ThreadSafeFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.withLock {
            value
        }
    }

    func set() {
        lock.withLock {
            value = true
        }
    }
}
