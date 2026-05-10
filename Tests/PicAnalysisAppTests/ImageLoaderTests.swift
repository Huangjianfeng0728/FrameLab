import CoreGraphics
import Foundation
import Testing
@testable import PicAnalysisApp

@Suite
struct ImageLoaderTests {
    @Test
    func preservesRGBAChannelOrderWhenBuildingPixelBuffer() throws {
        let bytes: [UInt8] = [
            255, 0, 0, 255,
            0, 0, 255, 255
        ]
        let data = Data(bytes)
        let provider = CGDataProvider(data: data as CFData)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            .union(.byteOrder32Big)

        let image = CGImage(
            width: 2,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 8,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: bitmapInfo,
            provider: provider!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        let buffer = try ImageLoader.pixelBuffer(from: image)

        #expect(buffer.pixel(x: 0, y: 0) == RGBColor(red: 255, green: 0, blue: 0))
        #expect(buffer.pixel(x: 1, y: 0) == RGBColor(red: 0, green: 0, blue: 255))
    }
}
