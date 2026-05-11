import Foundation
import Testing
@testable import PicAnalysisApp

@Suite
struct PhotoNoteStoreTests {
    @Test
    func createsMarkdownNoteWithFrontmatterAndBody() throws {
        let folder = try temporaryDirectory()
        let photoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let sourceURL = URL(fileURLWithPath: "/photos/IMG_1234.jpg")

        let noteFileName = try PhotoNoteStore.noteFileName(
            forPhotoID: photoID,
            sourceURL: sourceURL,
            in: folder
        )

        try PhotoNoteStore.saveNote(
            body: "观察高光层次。",
            photoID: photoID,
            sourceURL: sourceURL,
            folderURL: folder,
            fileName: noteFileName
        )

        let noteURL = folder.appendingPathComponent("IMG_1234.md")
        let content = try String(contentsOf: noteURL, encoding: .utf8)

        #expect(noteFileName == "IMG_1234.md")
        #expect(content.contains("framelab_photo_id: 00000000-0000-0000-0000-000000000001"))
        #expect(content.contains("source_image: \"/photos/IMG_1234.jpg\""))
        #expect(content.contains("source_file: \"IMG_1234.jpg\""))
        #expect(content.hasSuffix("\n观察高光层次。"))
    }

    @Test
    func reusesExistingMarkdownWhenPhotoIDMatches() throws {
        let folder = try temporaryDirectory()
        let photoID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let sourceURL = URL(fileURLWithPath: "/photos/IMG_2000.jpg")
        let noteURL = folder.appendingPathComponent("IMG_2000.md")
        try """
        ---
        framelab_photo_id: 00000000-0000-0000-0000-000000000002
        ---

        旧笔记
        """.write(to: noteURL, atomically: true, encoding: .utf8)

        let noteFileName = try PhotoNoteStore.noteFileName(
            forPhotoID: photoID,
            sourceURL: sourceURL,
            in: folder
        )

        #expect(noteFileName == "IMG_2000.md")
        #expect(try PhotoNoteStore.loadBody(from: noteURL) == "旧笔记")
    }

    @Test
    func reusesExistingMarkdownByPhotoFileNameEvenWhenPhotoIDDiffers() throws {
        let folder = try temporaryDirectory()
        let photoID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AB")!
        let sourceURL = URL(fileURLWithPath: "/photos/IMG_3000.jpg")
        let noteURL = folder.appendingPathComponent("IMG_3000.md")
        try """
        ---
        framelab_photo_id: 00000000-0000-0000-0000-000000000099
        ---

        其他照片
        """.write(to: noteURL, atomically: true, encoding: .utf8)

        let noteFileName = try PhotoNoteStore.noteFileName(
            forPhotoID: photoID,
            sourceURL: sourceURL,
            in: folder
        )

        #expect(noteFileName == "IMG_3000.md")
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FrameLabTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
