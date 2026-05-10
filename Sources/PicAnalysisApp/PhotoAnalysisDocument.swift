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
    var samplePoints: [SamplePoint]
    var histogram: ImageHistogram

    init(id: UUID = UUID(), url: URL, image: NSImage, pixelBuffer: PixelBuffer, defaultRadius: SamplingRadius) {
        self.id = id
        self.url = url
        self.fileName = url.lastPathComponent
        self.image = image
        self.pixelBuffer = pixelBuffer
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

    init(loadSavedProject: Bool = true) {
        if loadSavedProject {
            let restored = ProjectPersistence.load(defaultRadius: defaultRadius)
            documents = restored.documents
            selectedDocumentID = restored.selectedPhotoID ?? restored.documents.first?.id
            selectedPointID = selectedDocument?.samplePoints.first?.id
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

    func importPhotos(from urls: [URL]) {
        guard !urls.isEmpty, !isImporting else {
            return
        }

        isImporting = true
        importStatusText = "准备导入 \(urls.count) 张照片"
        let radius = defaultRadius

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
                            defaultRadius: radius
                        )

                        DispatchQueue.main.async {
                            guard let self else {
                                return
                            }
                            self.documents.append(document)
                            if self.selectedDocumentID == nil {
                                self.selectedDocumentID = document.id
                                self.selectedPointID = document.samplePoints.first?.id
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
        selectedDocumentID = document.id
        selectedPointID = document.samplePoints.first?.id
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
        selectedDocumentID = document.id
        if let pointID, document.samplePoints.contains(where: { $0.id == pointID }) {
            selectedPointID = pointID
        } else {
            selectedPointID = document.samplePoints.first?.id
        }
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

    private func saveProject() {
        ProjectPersistence.save(documents: documents, selectedPhotoID: selectedDocumentID)
    }
}
