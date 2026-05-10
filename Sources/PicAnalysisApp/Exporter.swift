import AppKit
import SwiftUI

@MainActor
enum Exporter {
    static func export(document: PhotoAnalysisDocument?) {
        guard let document else {
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(document.url.deletingPathExtension().lastPathComponent)-analysis.png"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let view = ExportAnalysisView(document: document)
            .frame(width: 1400, height: 1800)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let nsImage = renderer.nsImage,
              let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        try? pngData.write(to: url)
    }
}
