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

    private func makeDocument(name: String, color: PicAnalysisApp.RGBColor) -> PhotoAnalysisDocument {
        PhotoAnalysisDocument(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            image: NSImage(size: CGSize(width: 2, height: 2)),
            pixelBuffer: PixelBuffer(width: 2, height: 2, pixels: Array(repeating: color, count: 4)),
            defaultRadius: .singlePixel
        )
    }
}
