import Foundation

struct PersistedProject: Codable {
    var photos: [PersistedPhoto]
    var selectedPhotoID: UUID?
}

struct PersistedPhoto: Codable {
    var id: UUID
    var path: String
    var bookmarkData: Data?
    var noteFolderPath: String?
    var noteFolderBookmarkData: Data?
    var noteFileName: String?
    var points: [PersistedSamplePoint]
}

struct PersistedSamplePoint: Codable {
    var id: UUID
    var x: Double
    var y: Double
    var radius: Int
}

enum ProjectPersistence {
    static var projectURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FrameLab", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("project.json")
    }

    static func save(documents: [PhotoAnalysisDocument], selectedPhotoID: UUID?) {
        let project = PersistedProject(
            photos: documents.map { document in
                PersistedPhoto(
                    id: document.id,
                    path: document.url.path,
                    bookmarkData: document.bookmarkData,
                    noteFolderPath: document.noteFolderPath,
                    noteFolderBookmarkData: document.noteFolderBookmarkData,
                    noteFileName: document.noteFileName,
                    points: document.samplePoints.map { point in
                        PersistedSamplePoint(
                            id: point.id,
                            x: point.point.x,
                            y: point.point.y,
                            radius: point.radius.rawValue
                        )
                    }
                )
            },
            selectedPhotoID: selectedPhotoID
        )

        guard let data = try? JSONEncoder().encode(project) else {
            return
        }
        try? data.write(to: projectURL, options: .atomic)
    }

    static func load(defaultRadius: SamplingRadius) -> (documents: [PhotoAnalysisDocument], selectedPhotoID: UUID?) {
        guard let data = try? Data(contentsOf: projectURL),
              let project = try? JSONDecoder().decode(PersistedProject.self, from: data) else {
            return ([], nil)
        }

        let documents = project.photos.compactMap { persistedPhoto -> PhotoAnalysisDocument? in
            let resolvedPhoto = SecurityScopedResource.resolve(
                bookmarkData: persistedPhoto.bookmarkData,
                fallbackPath: persistedPhoto.path,
                isDirectory: false
            )
            let url = resolvedPhoto.url
            defer {
                resolvedPhoto.stopAccessing()
            }

            guard let loaded = try? ImageLoader.loadImageAndPixels(from: url) else {
                return nil
            }
            var document = PhotoAnalysisDocument(
                id: persistedPhoto.id,
                url: url,
                image: loaded.image,
                pixelBuffer: loaded.pixelBuffer,
                defaultRadius: defaultRadius,
                bookmarkData: persistedPhoto.bookmarkData,
                noteFolderPath: persistedPhoto.noteFolderPath,
                noteFolderBookmarkData: persistedPhoto.noteFolderBookmarkData,
                noteFileName: persistedPhoto.noteFileName
            )
            document.samplePoints = persistedPhoto.points.map { persistedPoint in
                let radius = SamplingRadius(rawValue: persistedPoint.radius) ?? defaultRadius
                return SamplePoint(
                    id: persistedPoint.id,
                    point: NormalizedPoint(x: persistedPoint.x, y: persistedPoint.y),
                    radius: radius,
                    buffer: loaded.pixelBuffer
                )
            }
            return document
        }

        return (documents, project.selectedPhotoID)
    }
}
