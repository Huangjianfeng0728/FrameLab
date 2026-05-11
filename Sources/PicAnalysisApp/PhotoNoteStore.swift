import Foundation

enum PhotoNoteStoreError: Error {
    case invalidFolder
}

enum PhotoNoteStore {
    static func noteFileName(forPhotoID photoID: UUID, sourceURL: URL, in folderURL: URL) throws -> String {
        guard folderURL.hasDirectoryPath else {
            throw PhotoNoteStoreError.invalidFolder
        }

        let baseName = sanitizedBaseName(from: sourceURL)
        let defaultFileName = "\(baseName).md"
        let defaultURL = folderURL.appendingPathComponent(defaultFileName)

        guard FileManager.default.fileExists(atPath: defaultURL.path) else {
            return defaultFileName
        }

        return defaultFileName
    }

    static func saveNote(body: String, photoID: UUID, sourceURL: URL, folderURL: URL, fileName: String) throws {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let noteURL = folderURL.appendingPathComponent(fileName)
        let existing = try? String(contentsOf: noteURL, encoding: .utf8)
        let createdAt = frontmatterValue("created_at", in: existing) ?? ISO8601DateFormatter().string(from: Date())
        let updatedAt = ISO8601DateFormatter().string(from: Date())
        let markdown = """
        ---
        framelab_photo_id: \(photoID.uuidString)
        source_image: "\(sourceURL.path)"
        source_file: "\(sourceURL.lastPathComponent)"
        created_at: "\(createdAt)"
        updated_at: "\(updatedAt)"
        ---

        \(body)
        """

        try markdown.write(to: noteURL, atomically: true, encoding: .utf8)
    }

    static func loadBody(from noteURL: URL) throws -> String {
        let content = try String(contentsOf: noteURL, encoding: .utf8)
        guard content.hasPrefix("---\n") else {
            return content
        }
        let searchStart = content.index(content.startIndex, offsetBy: 4)
        guard let endRange = content.range(of: "\n---", range: searchStart..<content.endIndex) else {
            return content
        }
        var bodyStart = endRange.upperBound
        if content[bodyStart...].hasPrefix("\n\n") {
            bodyStart = content.index(bodyStart, offsetBy: 2)
        } else if content[bodyStart...].hasPrefix("\n") {
            bodyStart = content.index(after: bodyStart)
        }
        return String(content[bodyStart...])
    }

    private static func sanitizedBaseName(from sourceURL: URL) -> String {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let components = baseName.components(separatedBy: invalid)
        let sanitized = components.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "Untitled" : sanitized
    }

    private static func frontmatterValue(_ key: String, in content: String?) -> String? {
        guard let content else {
            return nil
        }
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let prefix = "\(key):"
            guard line.hasPrefix(prefix) else {
                continue
            }
            return line
                .dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return nil
    }
}
