import Foundation

public struct RGBColor: Equatable, Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct HSLColor: Equatable, Sendable {
    public let hue: Double
    public let saturation: Double
    public let lightness: Double
}

public struct NormalizedPoint: Equatable, Hashable, Identifiable, Sendable {
    public var id: String { "\(x)-\(y)" }
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = min(1, max(0, x))
        self.y = min(1, max(0, y))
    }
}

public enum SamplingRadius: Int, CaseIterable, Identifiable, Sendable {
    case singlePixel = 1
    case threeByThree = 3
    case fiveByFive = 5
    case nineByNine = 9

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .singlePixel:
            return "单像素"
        case .threeByThree:
            return "3x3"
        case .fiveByFive:
            return "5x5"
        case .nineByNine:
            return "9x9"
        }
    }
}

public struct PixelBuffer: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [RGBColor]

    public init(width: Int, height: Int, pixels: [RGBColor]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public func pixel(x: Int, y: Int) -> RGBColor {
        let clampedX = min(width - 1, max(0, x))
        let clampedY = min(height - 1, max(0, y))
        return pixels[clampedY * width + clampedX]
    }
}

public struct PixelCoordinate: Equatable, Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct SamplingFootprint: Equatable, Sendable {
    public let centerX: Int
    public let centerY: Int
    public let minX: Int
    public let maxX: Int
    public let minY: Int
    public let maxY: Int
    public let coordinates: [PixelCoordinate]
}

public struct ColorSample: Equatable, Sendable {
    public let point: NormalizedPoint
    public let radius: SamplingRadius
    public let rgb: RGBColor
    public let hsl: HSLColor
    public let hex: String
}

public struct ImageHistogram: Equatable, Sendable {
    public let luma: [Int]
    public let red: [Int]
    public let green: [Int]
    public let blue: [Int]
}

public enum ColorAnalyzer {
    public static func hsl(from color: RGBColor) -> HSLColor {
        let red = Double(color.red) / 255
        let green = Double(color.green) / 255
        let blue = Double(color.blue) / 255
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        let lightness = (maxValue + minValue) / 2

        guard delta > 0 else {
            return HSLColor(hue: 0, saturation: 0, lightness: lightness)
        }

        let saturation = delta / (1 - abs(2 * lightness - 1))
        let hue: Double
        if maxValue == red {
            hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxValue == green {
            hue = 60 * (((blue - red) / delta) + 2)
        } else {
            hue = 60 * (((red - green) / delta) + 4)
        }

        return HSLColor(hue: hue < 0 ? hue + 360 : hue, saturation: saturation, lightness: lightness)
    }

    public static func sample(in buffer: PixelBuffer, at point: NormalizedPoint, radius: SamplingRadius) -> ColorSample {
        let footprint = samplingFootprint(in: buffer, at: point, radius: radius)
        var redTotal = 0
        var greenTotal = 0
        var blueTotal = 0

        for coordinate in footprint.coordinates {
            let pixel = buffer.pixel(x: coordinate.x, y: coordinate.y)
            redTotal += Int(pixel.red)
            greenTotal += Int(pixel.green)
            blueTotal += Int(pixel.blue)
        }

        let count = max(1, footprint.coordinates.count)
        let rgb = RGBColor(
            red: UInt8(redTotal / count),
            green: UInt8(greenTotal / count),
            blue: UInt8(blueTotal / count)
        )
        return ColorSample(
            point: point,
            radius: radius,
            rgb: rgb,
            hsl: hsl(from: rgb),
            hex: hex(from: rgb)
        )
    }

    public static func samplingFootprint(in buffer: PixelBuffer, at point: NormalizedPoint, radius: SamplingRadius) -> SamplingFootprint {
        let centerX = Int((point.x * Double(buffer.width - 1)).rounded())
        let centerY = Int((point.y * Double(buffer.height - 1)).rounded())
        let offset = radius.rawValue / 2
        let minX = max(0, centerX - offset)
        let maxX = min(buffer.width - 1, centerX + offset)
        let minY = max(0, centerY - offset)
        let maxY = min(buffer.height - 1, centerY + offset)
        var coordinates: [PixelCoordinate] = []

        for y in minY...maxY {
            for x in minX...maxX {
                coordinates.append(PixelCoordinate(x: x, y: y))
            }
        }

        return SamplingFootprint(
            centerX: centerX,
            centerY: centerY,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            coordinates: coordinates
        )
    }

    public static func histogram(for buffer: PixelBuffer, bucketCount: Int = 256) -> ImageHistogram {
        var luma = Array(repeating: 0, count: bucketCount)
        var red = Array(repeating: 0, count: bucketCount)
        var green = Array(repeating: 0, count: bucketCount)
        var blue = Array(repeating: 0, count: bucketCount)

        for pixel in buffer.pixels {
            luma[bucketIndex(lumaValue(for: pixel), bucketCount: bucketCount)] += 1
            red[bucketIndex(Double(pixel.red) / 255, bucketCount: bucketCount)] += 1
            green[bucketIndex(Double(pixel.green) / 255, bucketCount: bucketCount)] += 1
            blue[bucketIndex(Double(pixel.blue) / 255, bucketCount: bucketCount)] += 1
        }

        return ImageHistogram(luma: luma, red: red, green: green, blue: blue)
    }

    public static func lumaValue(for color: RGBColor) -> Double {
        (0.2126 * Double(color.red) + 0.7152 * Double(color.green) + 0.0722 * Double(color.blue)) / 255
    }

    public static func hex(from color: RGBColor) -> String {
        String(format: "#%02X%02X%02X", color.red, color.green, color.blue)
    }

    private static func bucketIndex(_ value: Double, bucketCount: Int) -> Int {
        min(bucketCount - 1, max(0, Int((value * Double(bucketCount)).rounded(.down))))
    }
}

public enum DefaultPointGenerator {
    public static func generatePoints(in buffer: PixelBuffer, count: Int = 10) -> [NormalizedPoint] {
        guard count > 0, buffer.width > 0, buffer.height > 0 else {
            return []
        }

        let candidates = buffer.pixels.enumerated().map { index, color in
            let x = index % buffer.width
            let y = index / buffer.width
            return Candidate(
                point: NormalizedPoint(
                    x: buffer.width == 1 ? 0 : Double(x) / Double(buffer.width - 1),
                    y: buffer.height == 1 ? 0 : Double(y) / Double(buffer.height - 1)
                ),
                luma: ColorAnalyzer.lumaValue(for: color),
                color: color
            )
        }

        var selected: [NormalizedPoint] = []
        let sortedByLuma = candidates.sorted { $0.luma < $1.luma }
        let step = max(1, sortedByLuma.count / count)

        for index in stride(from: 0, to: sortedByLuma.count, by: step) where selected.count < count {
            let candidate = sortedByLuma[index].point
            if isFarEnough(candidate, from: selected, minimumDistance: 0.12) {
                selected.append(candidate)
            }
        }

        for candidate in candidates where selected.count < count {
            if isFarEnough(candidate.point, from: selected, minimumDistance: 0.08) {
                selected.append(candidate.point)
            }
        }

        return Array(selected.prefix(count))
    }

    private static func isFarEnough(_ point: NormalizedPoint, from selected: [NormalizedPoint], minimumDistance: Double) -> Bool {
        selected.allSatisfy { existing in
            let dx = existing.x - point.x
            let dy = existing.y - point.y
            return sqrt(dx * dx + dy * dy) >= minimumDistance
        }
    }

    private struct Candidate {
        let point: NormalizedPoint
        let luma: Double
        let color: RGBColor
    }
}
