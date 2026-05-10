import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconDirectory = root.appendingPathComponent("assets/icon", isDirectory: true)
let iconsetDirectory = iconDirectory.appendingPathComponent("FrameLab.iconset", isDirectory: true)

try? FileManager.default.removeItem(at: iconsetDirectory)
try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in specs {
    let image = drawIcon(size: CGFloat(size))
    let url = iconsetDirectory.appendingPathComponent(name)
    try writePNG(image: image, to: url)
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: CGSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 1024
    let cornerRadius = 220 * scale

    let background = NSBezierPath(roundedRect: rect.insetBy(dx: 24 * scale, dy: 24 * scale), xRadius: cornerRadius, yRadius: cornerRadius)
    let bgGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1),
        NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.23, alpha: 1)
    ])
    bgGradient?.draw(in: background, angle: -35)

    drawPhotoFrame(scale: scale, size: size)
    drawHistogram(scale: scale, size: size)
    drawColorWheel(scale: scale, size: size)
    drawSamplePins(scale: scale, size: size)

    return image
}

func drawPhotoFrame(scale: CGFloat, size: CGFloat) {
    let frameRect = CGRect(x: 170 * scale, y: 275 * scale, width: 620 * scale, height: 500 * scale)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28 * scale
    shadow.shadowOffset = CGSize(width: 0, height: -16 * scale)
    shadow.set()

    let outer = NSBezierPath(roundedRect: frameRect, xRadius: 54 * scale, yRadius: 54 * scale)
    NSColor(calibratedRed: 0.92, green: 0.94, blue: 0.95, alpha: 1).setFill()
    outer.fill()
    NSShadow().set()

    let imageRect = frameRect.insetBy(dx: 36 * scale, dy: 36 * scale)
    let imagePath = NSBezierPath(roundedRect: imageRect, xRadius: 34 * scale, yRadius: 34 * scale)
    let imageGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.18, green: 0.24, blue: 0.29, alpha: 1),
        NSColor(calibratedRed: 0.49, green: 0.61, blue: 0.58, alpha: 1)
    ])
    imageGradient?.draw(in: imagePath, angle: 35)

    NSColor.white.withAlphaComponent(0.32).setStroke()
    let grid = NSBezierPath()
    for fraction in [1.0 / 3.0, 2.0 / 3.0] {
        let x = imageRect.minX + imageRect.width * fraction
        grid.move(to: CGPoint(x: x, y: imageRect.minY))
        grid.line(to: CGPoint(x: x, y: imageRect.maxY))
        let y = imageRect.minY + imageRect.height * fraction
        grid.move(to: CGPoint(x: imageRect.minX, y: y))
        grid.line(to: CGPoint(x: imageRect.maxX, y: y))
    }
    grid.lineWidth = 4 * scale
    grid.stroke()
}

func drawHistogram(scale: CGFloat, size: CGFloat) {
    let baseX = 185 * scale
    let baseY = 165 * scale
    let barWidth = 34 * scale
    let gap = 14 * scale
    let heights: [CGFloat] = [90, 135, 72, 170, 120, 210, 155, 82, 118]
    for (index, height) in heights.enumerated() {
        let x = baseX + CGFloat(index) * (barWidth + gap)
        let rect = CGRect(x: x, y: baseY, width: barWidth, height: height * scale)
        let path = NSBezierPath(roundedRect: rect, xRadius: 12 * scale, yRadius: 12 * scale)
        NSColor.white.withAlphaComponent(index == 5 ? 0.92 : 0.55).setFill()
        path.fill()
    }
}

func drawColorWheel(scale: CGFloat, size: CGFloat) {
    let center = CGPoint(x: 735 * scale, y: 255 * scale)
    let radius = 148 * scale
    let segments = 96
    for index in 0..<segments {
        let start = CGFloat(index) / CGFloat(segments) * 360
        let end = CGFloat(index + 1) / CGFloat(segments) * 360
        let path = NSBezierPath()
        path.move(to: center)
        path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
        path.close()
        NSColor(calibratedHue: start / 360, saturation: 0.88, brightness: 1, alpha: 1).setFill()
        path.fill()
    }

    let inner = NSBezierPath(ovalIn: CGRect(x: center.x - 62 * scale, y: center.y - 62 * scale, width: 124 * scale, height: 124 * scale))
    NSColor.white.withAlphaComponent(0.88).setFill()
    inner.fill()

    let stroke = NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    NSColor.white.withAlphaComponent(0.7).setStroke()
    stroke.lineWidth = 7 * scale
    stroke.stroke()
}

func drawSamplePins(scale: CGFloat, size: CGFloat) {
    let pins: [(CGPoint, NSColor)] = [
        (CGPoint(x: 345 * scale, y: 610 * scale), NSColor(calibratedRed: 1, green: 0.18, blue: 0.16, alpha: 1)),
        (CGPoint(x: 535 * scale, y: 510 * scale), NSColor(calibratedRed: 0.0, green: 0.78, blue: 0.90, alpha: 1)),
        (CGPoint(x: 660 * scale, y: 640 * scale), NSColor(calibratedRed: 1, green: 0.82, blue: 0.18, alpha: 1))
    ]
    for (point, color) in pins {
        let outer = NSBezierPath(ovalIn: CGRect(x: point.x - 34 * scale, y: point.y - 34 * scale, width: 68 * scale, height: 68 * scale))
        NSColor.white.setFill()
        outer.fill()
        let inner = NSBezierPath(ovalIn: CGRect(x: point.x - 23 * scale, y: point.y - 23 * scale, width: 46 * scale, height: 46 * scale))
        color.setFill()
        inner.fill()
    }
}

func writePNG(image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "FrameLabIcon", code: 1)
    }
    try data.write(to: url)
}
