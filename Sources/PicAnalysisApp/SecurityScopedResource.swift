import Foundation

struct SecurityScopedResolvedURL {
    let url: URL
    private let didStartAccessing: Bool

    init(url: URL, didStartAccessing: Bool) {
        self.url = url
        self.didStartAccessing = didStartAccessing
    }

    func stopAccessing() {
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

enum SecurityScopedResource {
    static func bookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func resolve(bookmarkData: Data?, fallbackPath: String, isDirectory: Bool) -> SecurityScopedResolvedURL {
        if let bookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return SecurityScopedResolvedURL(
                    url: url,
                    didStartAccessing: url.startAccessingSecurityScopedResource()
                )
            }
        }

        return SecurityScopedResolvedURL(
            url: URL(fileURLWithPath: fallbackPath, isDirectory: isDirectory),
            didStartAccessing: false
        )
    }
}
