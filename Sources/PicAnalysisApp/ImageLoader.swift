import AppKit
import CoreGraphics
import Foundation

enum ImageLoaderError: LocalizedError {
    case cannotReadImage
    case cannotCreateBitmap
    case invalidPixelBuffer

    var errorDescription: String? {
        switch self {
        case .cannotReadImage:
            return "无法读取图片"
        case .cannotCreateBitmap:
            return "无法创建 sRGB 像素缓冲"
        case .invalidPixelBuffer:
            return "图片像素数据无效"
        }
    }
}

struct LoadedImageData {
    let image: NSImage
    let pixelBuffer: PixelBuffer
}

enum ImageLoader {
    static func loadImageAndPixels(from url: URL) throws -> LoadedImageData {
        guard let image = NSImage(contentsOf: url) else {
            throw ImageLoaderError.cannotReadImage
        }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageLoaderError.cannotReadImage
        }
        return LoadedImageData(image: image, pixelBuffer: try pixelBuffer(from: cgImage))
    }

    static func pixelBuffer(from cgImage: CGImage) throws -> PixelBuffer {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            throw ImageLoaderError.invalidPixelBuffer
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &rawData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ImageLoaderError.cannotCreateBitmap
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [RGBColor] = []
        pixels.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels.append(RGBColor(red: rawData[offset], green: rawData[offset + 1], blue: rawData[offset + 2]))
            }
        }

        return PixelBuffer(width: width, height: height, pixels: pixels)
    }
}
