import SwiftUI

struct PhotoCanvasView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    var showsSamplePoints = true
    @State private var draggingSampleID: UUID?

    var body: some View {
        ZStack {
            if let document = viewModel.selectedDocument {
                GeometryReader { proxy in
                    let imageRect = fittedImageRect(imageSize: document.image.size, containerSize: proxy.size)

                    ZStack {
                        Image(nsImage: document.image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)

                        if viewModel.showsClippedHighlightOverlay {
                            ClippedHighlightOverlay(buffer: document.pixelBuffer)
                                .frame(width: imageRect.width, height: imageRect.height)
                                .position(x: imageRect.midX, y: imageRect.midY)
                        }

                        if viewModel.showsCrushedShadowOverlay {
                            CrushedShadowOverlay(buffer: document.pixelBuffer)
                                .frame(width: imageRect.width, height: imageRect.height)
                                .position(x: imageRect.midX, y: imageRect.midY)
                        }

                        if showsSamplePoints {
                            ForEach(Array(document.samplePoints.enumerated()), id: \.element.id) { index, samplePoint in
                                SampleMarkerView(
                                    number: index + 1,
                                    isSelected: samplePoint.id == viewModel.selectedPointID,
                                    isDragging: samplePoint.id == draggingSampleID
                                )
                                .position(position(for: samplePoint.point, in: imageRect))
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            viewModel.selectedPointID = samplePoint.id
                                            draggingSampleID = samplePoint.id
                                            viewModel.movePoint(id: samplePoint.id, to: normalizedPoint(from: value.location, in: imageRect))
                                        }
                                        .onEnded { _ in
                                            draggingSampleID = nil
                                        }
                                )
                            }

                            if let draggingSamplePoint = draggingSamplePoint(in: document) {
                                let samplePosition = position(for: draggingSamplePoint.point, in: imageRect)
                                PixelMagnifierView(
                                    buffer: document.pixelBuffer,
                                    point: draggingSamplePoint.point,
                                    radius: draggingSamplePoint.radius
                                )
                                .frame(width: 228, height: 266)
                                .position(magnifierPosition(near: samplePosition, in: proxy.size))
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        TapGesture()
                            .onEnded {}
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard imageRect.contains(value.location) else {
                                    return
                                }
                                let didClick = abs(value.translation.width) < 2 && abs(value.translation.height) < 2
                                let point = normalizedPoint(from: value.location, in: imageRect)
                                if showsSamplePoints && viewModel.isAddingPoint && didClick && !isNearExistingPoint(point, in: document) {
                                    viewModel.addPoint(point)
                                }
                            }
                    )
                    .overlay(alignment: .top) {
                        if showsSamplePoints && viewModel.isAddingPoint {
                            Text("点击照片任意位置新增采样点")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(.top, 12)
                        }
                    }
                }
                .padding(18)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 54))
                        .foregroundStyle(.secondary)
                    Text("批量导入 JPG、PNG 或 HEIC 照片开始分析")
                        .font(.headline)
                    Text("照片、采样点信息和直方图会显示在同一个页面")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

    private func normalizedPoint(from location: CGPoint, in imageRect: CGRect) -> NormalizedPoint {
        guard imageRect.width > 0, imageRect.height > 0 else {
            return NormalizedPoint(x: 0, y: 0)
        }
        return NormalizedPoint(
            x: (location.x - imageRect.minX) / imageRect.width,
            y: (location.y - imageRect.minY) / imageRect.height
        )
    }

    private func isNearExistingPoint(_ point: NormalizedPoint, in document: PhotoAnalysisDocument) -> Bool {
        document.samplePoints.contains { samplePoint in
            let dx = samplePoint.point.x - point.x
            let dy = samplePoint.point.y - point.y
            return sqrt(dx * dx + dy * dy) < 0.035
        }
    }

    private func draggingSamplePoint(in document: PhotoAnalysisDocument) -> SamplePoint? {
        guard let draggingSampleID else {
            return nil
        }
        return document.samplePoints.first { $0.id == draggingSampleID }
    }

    private func magnifierPosition(near point: CGPoint, in containerSize: CGSize) -> CGPoint {
        let size = CGSize(width: 228, height: 266)
        let horizontalOffset: CGFloat = 150
        let verticalOffset: CGFloat = -18
        let proposedX = point.x + (point.x < containerSize.width * 0.62 ? horizontalOffset : -horizontalOffset)
        let proposedY = point.y + verticalOffset

        return CGPoint(
            x: min(containerSize.width - size.width / 2, max(size.width / 2, proposedX)),
            y: min(containerSize.height - size.height / 2, max(size.height / 2, proposedY))
        )
    }
}

struct SampleMarkerView: View {
    let number: Int
    let isSelected: Bool
    var isDragging = false

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold))
            .foregroundStyle(isSelected ? .black : .white)
            .frame(width: 24, height: 24)
            .background(markerFill)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(isDragging ? 0.78 : 1), lineWidth: 1.5))
            .shadow(radius: 3)
            .opacity(isDragging ? 0.38 : 1)
    }

    private var markerFill: Color {
        if isDragging {
            return isSelected ? Color.yellow.opacity(0.58) : Color.black.opacity(0.28)
        }
        return isSelected ? Color.yellow : Color.black.opacity(0.74)
    }
}

struct PixelMagnifierView: View {
    let buffer: PixelBuffer
    let point: NormalizedPoint
    let radius: SamplingRadius

    private var footprint: SamplingFootprint {
        ColorAnalyzer.samplingFootprint(in: buffer, at: point, radius: radius)
    }

    var body: some View {
        let footprint = footprint

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("采样像素")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(radius.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.yellow)
                    .clipShape(Capsule())
            }

            PixelGridView(buffer: buffer, footprint: footprint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("中心: x\(footprint.centerX), y\(footprint.centerY)")
                Text("范围: x\(footprint.minX)-\(footprint.maxX), y\(footprint.minY)-\(footprint.maxY) · \(footprint.coordinates.count) px")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.72))
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.84))
                .shadow(color: .black.opacity(0.36), radius: 18, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct PixelGridView: View {
    let buffer: PixelBuffer
    let footprint: SamplingFootprint

    var body: some View {
        Canvas { context, size in
            let columnCount = max(1, footprint.maxX - footprint.minX + 1)
            let rowCount = max(1, footprint.maxY - footprint.minY + 1)
            let cellSize = min(size.width / CGFloat(columnCount), size.height / CGFloat(rowCount))
            let gridWidth = CGFloat(columnCount) * cellSize
            let gridHeight = CGFloat(rowCount) * cellSize
            let origin = CGPoint(
                x: (size.width - gridWidth) / 2,
                y: (size.height - gridHeight) / 2
            )

            for y in footprint.minY...footprint.maxY {
                for x in footprint.minX...footprint.maxX {
                    let pixel = buffer.pixel(x: x, y: y)
                    let rect = CGRect(
                        x: origin.x + CGFloat(x - footprint.minX) * cellSize,
                        y: origin.y + CGFloat(y - footprint.minY) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )

                    context.fill(Path(rect), with: .color(color(from: pixel)))
                    context.stroke(Path(rect), with: .color(.black.opacity(0.42)), lineWidth: 0.7)

                    if x == footprint.centerX && y == footprint.centerY {
                        context.stroke(Path(rect.insetBy(dx: 1.4, dy: 1.4)), with: .color(.white), lineWidth: 2)
                    }
                }
            }
        }
        .background(Color.black.opacity(0.36))
    }

    private func color(from pixel: RGBColor) -> Color {
        Color(
            red: Double(pixel.red) / 255,
            green: Double(pixel.green) / 255,
            blue: Double(pixel.blue) / 255
        )
    }
}

struct ClippedHighlightOverlay: View {
    let buffer: PixelBuffer

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / CGFloat(buffer.width)
            let scaleY = size.height / CGFloat(buffer.height)

            for y in 0..<buffer.height {
                for x in 0..<buffer.width {
                    let pixel = buffer.pixel(x: x, y: y)
                    let luma = ColorAnalyzer.lumaValue(for: pixel)

                    if luma >= ExposureThresholds.clippedHighlight {
                        let rect = CGRect(
                            x: CGFloat(x) * scaleX,
                            y: CGFloat(y) * scaleY,
                            width: scaleX,
                            height: scaleY
                        )
                        context.fill(Path(rect), with: .color(.red.opacity(0.45)))
                    }
                }
            }
        }
    }
}

struct CrushedShadowOverlay: View {
    let buffer: PixelBuffer

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / CGFloat(buffer.width)
            let scaleY = size.height / CGFloat(buffer.height)

            for y in 0..<buffer.height {
                for x in 0..<buffer.width {
                    let pixel = buffer.pixel(x: x, y: y)
                    let luma = ColorAnalyzer.lumaValue(for: pixel)

                    if luma <= ExposureThresholds.crushedShadow {
                        let rect = CGRect(
                            x: CGFloat(x) * scaleX,
                            y: CGFloat(y) * scaleY,
                            width: scaleX,
                            height: scaleY
                        )
                        context.fill(Path(rect), with: .color(.orange.opacity(0.55)))
                    }
                }
            }
        }
    }
}
