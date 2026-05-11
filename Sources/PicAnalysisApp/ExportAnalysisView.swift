import SwiftUI

struct ExportAnalysisView: View {
    let document: PhotoAnalysisDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            exportPhoto
            HStack(alignment: .top, spacing: 24) {
                sampleTable
                VStack(alignment: .leading, spacing: 10) {
                    Text("Color Wheel")
                        .font(.system(size: 18, weight: .semibold))
                    ColorWheelView(samplePoints: document.samplePoints, showLabels: true)
                        .frame(width: 260, height: 260)
                }
                .padding(18)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HistogramPanel(
                histogram: document.histogram,
                exposureAnalysis: document.exposureAnalysis
            )
            .frame(height: 220)
        }
        .padding(42)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(document.fileName)
                .font(.system(size: 34, weight: .bold))
            HStack(spacing: 18) {
                Text("尺寸 \(document.pixelSizeText)")
                Text("采样点 \(document.samplePoints.count)")
                Text("导出日期 \(Date.now.formatted(date: .numeric, time: .shortened))")
            }
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
        }
    }

    private var exportPhoto: some View {
        GeometryReader { proxy in
            let imageRect = fittedImageRect(imageSize: document.image.size, containerSize: proxy.size)
            ZStack {
                Image(nsImage: document.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                ForEach(Array(document.samplePoints.enumerated()), id: \.element.id) { index, point in
                    SampleMarkerView(number: index + 1, isSelected: false)
                        .position(position(for: point.point, in: imageRect))
                }
            }
        }
        .frame(height: 840)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sampleTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
            GridRow {
                tableHeader("#")
                tableHeader("半径")
                tableHeader("H")
                tableHeader("S")
                tableHeader("L")
                tableHeader("RGB")
                tableHeader("Hex")
            }

            ForEach(Array(document.samplePoints.enumerated()), id: \.element.id) { index, point in
                GridRow {
                    Text("\(index + 1)")
                    Text(point.radius.title)
                    Text("\(Int(point.sample.hsl.hue.rounded()))")
                    Text(percent(point.sample.hsl.saturation))
                    Text(percent(point.sample.hsl.lightness))
                    Text("\(point.sample.rgb.red), \(point.sample.rgb.green), \(point.sample.rgb.blue)")
                    Text(point.sample.hex)
                }
                .font(.system(size: 15, design: .monospaced))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func tableHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func fittedImageRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func position(for point: NormalizedPoint, in imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: imageRect.minX + point.x * imageRect.width,
            y: imageRect.minY + point.y * imageRect.height
        )
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
