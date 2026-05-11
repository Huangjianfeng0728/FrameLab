import CoreGraphics
import Testing
@testable import PicAnalysisApp

@Suite
struct ColorAnalysisTests {
    @Test
    func convertsPrimaryRedToHSL() {
        let hsl = ColorAnalyzer.hsl(from: RGBColor(red: 255, green: 0, blue: 0))

        #expect(abs(hsl.hue - 0) < 0.0001)
        #expect(abs(hsl.saturation - 1) < 0.0001)
        #expect(abs(hsl.lightness - 0.5) < 0.0001)
    }

    @Test
    func averagesPixelsInsideSamplingRadius() {
        let buffer = PixelBuffer(
            width: 3,
            height: 3,
            pixels: Array(repeating: RGBColor(red: 10, green: 20, blue: 30), count: 9)
        )

        let sample = ColorAnalyzer.sample(
            in: buffer,
            at: NormalizedPoint(x: 0.5, y: 0.5),
            radius: .threeByThree
        )

        #expect(sample.rgb == RGBColor(red: 10, green: 20, blue: 30))
        #expect(sample.hex == "#0A141E")
    }

    @Test
    func averagesOnlyRealPixelsAtImageEdges() {
        let buffer = PixelBuffer(
            width: 2,
            height: 2,
            pixels: [
                RGBColor(red: 100, green: 0, blue: 0),
                RGBColor(red: 0, green: 100, blue: 0),
                RGBColor(red: 0, green: 0, blue: 100),
                RGBColor(red: 100, green: 100, blue: 100)
            ]
        )

        let sample = ColorAnalyzer.sample(
            in: buffer,
            at: NormalizedPoint(x: 0, y: 0),
            radius: .threeByThree
        )

        #expect(sample.rgb == RGBColor(red: 50, green: 50, blue: 50))
    }

    @Test
    func reportsActualPixelsUsedForSampling() {
        let buffer = PixelBuffer(
            width: 4,
            height: 3,
            pixels: Array(repeating: RGBColor(red: 0, green: 0, blue: 0), count: 12)
        )

        let footprint = ColorAnalyzer.samplingFootprint(
            in: buffer,
            at: NormalizedPoint(x: 1, y: 0),
            radius: .threeByThree
        )

        #expect(footprint.centerX == 3)
        #expect(footprint.centerY == 0)
        #expect(footprint.minX == 2)
        #expect(footprint.maxX == 3)
        #expect(footprint.minY == 0)
        #expect(footprint.maxY == 1)
        #expect(footprint.coordinates == [
            PixelCoordinate(x: 2, y: 0),
            PixelCoordinate(x: 3, y: 0),
            PixelCoordinate(x: 2, y: 1),
            PixelCoordinate(x: 3, y: 1)
        ])
    }

    @Test
    func mapsNormalizedCoordinatesToExpectedPixels() {
        let buffer = PixelBuffer(
            width: 3,
            height: 1,
            pixels: [
                RGBColor(red: 255, green: 0, blue: 0),
                RGBColor(red: 0, green: 255, blue: 0),
                RGBColor(red: 0, green: 0, blue: 255)
            ]
        )

        #expect(ColorAnalyzer.sample(in: buffer, at: NormalizedPoint(x: 0, y: 0), radius: .singlePixel).rgb == RGBColor(red: 255, green: 0, blue: 0))
        #expect(ColorAnalyzer.sample(in: buffer, at: NormalizedPoint(x: 0.5, y: 0), radius: .singlePixel).rgb == RGBColor(red: 0, green: 255, blue: 0))
        #expect(ColorAnalyzer.sample(in: buffer, at: NormalizedPoint(x: 1, y: 0), radius: .singlePixel).rgb == RGBColor(red: 0, green: 0, blue: 255))
    }

    @Test
    func colorWheelPlacesRedAtTopAndCyanAtBottom() {
        let center = CGPoint(x: 100, y: 100)
        let redPosition = ColorWheelGeometry.position(hue: 0, saturation: 1, center: center, radius: 80)
        let cyanPosition = ColorWheelGeometry.position(hue: 180, saturation: 1, center: center, radius: 80)

        #expect(abs(redPosition.x - 100) < 0.0001)
        #expect(abs(redPosition.y - 20) < 0.0001)
        #expect(abs(cyanPosition.x - 100) < 0.0001)
        #expect(abs(cyanPosition.y - 180) < 0.0001)
    }

    @Test
    func buildsBrightnessAndRGBHistogram() {
        let buffer = PixelBuffer(
            width: 2,
            height: 1,
            pixels: [
                RGBColor(red: 0, green: 0, blue: 0),
                RGBColor(red: 255, green: 255, blue: 255)
            ]
        )

        let histogram = ColorAnalyzer.histogram(for: buffer, bucketCount: 4)

        #expect(histogram.luma == [1, 0, 0, 1])
        #expect(histogram.red == [1, 0, 0, 1])
        #expect(histogram.green == [1, 0, 0, 1])
        #expect(histogram.blue == [1, 0, 0, 1])
    }

    @Test
    func histogramUsesGammaAwarePerceptualLumaForMiddleGray() {
        let buffer = PixelBuffer(
            width: 1,
            height: 1,
            pixels: [
                RGBColor(red: 128, green: 128, blue: 128)
            ]
        )

        let histogram = ColorAnalyzer.histogram(for: buffer, bucketCount: 256)
        let lumaBucket = histogram.luma.firstIndex(of: 1)

        #expect(lumaBucket == 128)
    }

    @Test
    func histogramLumaOrdersPrimaryColorsByPerceivedBrightness() {
        let buffer = PixelBuffer(
            width: 3,
            height: 1,
            pixels: [
                RGBColor(red: 255, green: 0, blue: 0),
                RGBColor(red: 0, green: 255, blue: 0),
                RGBColor(red: 0, green: 0, blue: 255)
            ]
        )

        let histogram = ColorAnalyzer.histogram(for: buffer, bucketCount: 256)
        let buckets = histogram.luma.enumerated().compactMap { index, count in
            count > 0 ? index : nil
        }

        #expect(buckets == [76, 127, 220])
    }

    @Test
    func generatesTenDefaultPointsWithinBounds() {
        let pixels: [RGBColor] = (0..<100).map { value -> RGBColor in
            let channel = UInt8(value * 2)
            return RGBColor(red: channel, green: channel, blue: channel)
        }
        let buffer = PixelBuffer(width: 10, height: 10, pixels: pixels)

        let points = DefaultPointGenerator.generatePoints(in: buffer, count: 10)
        let allPointsAreInsideImage = points.allSatisfy { point in
            point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1
        }

        #expect(points.count == 10)
        #expect(allPointsAreInsideImage)
    }

    @Test
    func exposureAnalysisReportsFullDarkImageAsShadow() {
        let buffer = PixelBuffer(
            width: 10,
            height: 10,
            pixels: Array(repeating: RGBColor(red: 0, green: 0, blue: 0), count: 100)
        )

        let analysis = ColorAnalyzer.exposureAnalysis(for: buffer)

        #expect(abs(analysis.shadowPercentage - 1.0) < 0.0001)
        #expect(abs(analysis.midtonePercentage - 0.0) < 0.0001)
        #expect(abs(analysis.highlightPercentage - 0.0) < 0.0001)
    }

    @Test
    func exposureAnalysisReportsMiddleGrayAsMidtone() {
        let buffer = PixelBuffer(
            width: 10,
            height: 10,
            pixels: Array(repeating: RGBColor(red: 128, green: 128, blue: 128), count: 100)
        )

        let analysis = ColorAnalyzer.exposureAnalysis(for: buffer)

        #expect(abs(analysis.shadowPercentage - 0.0) < 0.0001)
        #expect(abs(analysis.midtonePercentage - 1.0) < 0.0001)
        #expect(abs(analysis.highlightPercentage - 0.0) < 0.0001)
    }

    @Test
    func exposureAnalysisReportsFullBrightImageAsHighlight() {
        let buffer = PixelBuffer(
            width: 10,
            height: 10,
            pixels: Array(repeating: RGBColor(red: 255, green: 255, blue: 255), count: 100)
        )

        let analysis = ColorAnalyzer.exposureAnalysis(for: buffer)

        #expect(abs(analysis.shadowPercentage - 0.0) < 0.0001)
        #expect(abs(analysis.midtonePercentage - 0.0) < 0.0001)
        #expect(abs(analysis.highlightPercentage - 1.0) < 0.0001)
    }

    @Test
    func exposureAnalysisReportsEqualPercentagesForMixedBuffer() {
        let pixels = [
            RGBColor(red: 0, green: 0, blue: 0),
            RGBColor(red: 128, green: 128, blue: 128),
            RGBColor(red: 255, green: 255, blue: 255)
        ]
        let buffer = PixelBuffer(width: 3, height: 1, pixels: pixels)

        let analysis = ColorAnalyzer.exposureAnalysis(for: buffer)

        #expect(abs(analysis.shadowPercentage - 1/3) < 0.0001)
        #expect(abs(analysis.midtonePercentage - 1/3) < 0.0001)
        #expect(abs(analysis.highlightPercentage - 1/3) < 0.0001)
    }

    @Test
    func clippedHighlightDetectionIdentifiesPureWhite() {
        let buffer = PixelBuffer(
            width: 10,
            height: 10,
            pixels: Array(repeating: RGBColor(red: 255, green: 255, blue: 255), count: 100)
        )

        let analysis = ColorAnalyzer.exposureAnalysis(for: buffer)

        #expect(abs(analysis.clippedHighlightPercentage - 1.0) < 0.0001)
    }

    @Test
    func clippedHighlightDetectionIdentifiesNearWhite() {
        let pixels = [
            RGBColor(red: 250, green: 250, blue: 250),
            RGBColor(red: 240, green: 240, blue: 240)
        ]
        let buffer = PixelBuffer(width: 2, height: 1, pixels: pixels)

        let analysis = ColorAnalyzer.exposureAnalysis(for: buffer)

        #expect(analysis.clippedHighlightPercentage > 0)
        #expect(analysis.clippedHighlightPercentage < 1.0)
    }

    @Test
    func clippedHighlightDetectionIgnoresMidtonePixels() {
        let buffer = PixelBuffer(
            width: 10,
            height: 10,
            pixels: Array(repeating: RGBColor(red: 128, green: 128, blue: 128), count: 100)
        )

        let analysis = ColorAnalyzer.exposureAnalysis(for: buffer)

        #expect(abs(analysis.clippedHighlightPercentage - 0.0) < 0.0001)
    }

    @Test
    func crushedShadowDetectionIdentifiesPureBlack() {
        let buffer = PixelBuffer(
            width: 10,
            height: 10,
            pixels: Array(repeating: RGBColor(red: 0, green: 0, blue: 0), count: 100)
        )

        let analysis = ColorAnalyzer.exposureAnalysis(for: buffer)

        #expect(abs(analysis.crushedShadowPercentage - 1.0) < 0.0001)
    }

    @Test
    func crushedShadowDetectionIdentifiesNearBlack() {
        let pixels = [
            RGBColor(red: 5, green: 5, blue: 5),
            RGBColor(red: 15, green: 15, blue: 15)
        ]
        let buffer = PixelBuffer(width: 2, height: 1, pixels: pixels)

        let analysis = ColorAnalyzer.exposureAnalysis(for: buffer)

        #expect(analysis.crushedShadowPercentage > 0)
        #expect(analysis.crushedShadowPercentage < 1.0)
    }

    @Test
    func crushedShadowDetectionIgnoresMidtonePixels() {
        let buffer = PixelBuffer(
            width: 10,
            height: 10,
            pixels: Array(repeating: RGBColor(red: 128, green: 128, blue: 128), count: 100)
        )

        let analysis = ColorAnalyzer.exposureAnalysis(for: buffer)

        #expect(abs(analysis.crushedShadowPercentage - 0.0) < 0.0001)
    }
}
