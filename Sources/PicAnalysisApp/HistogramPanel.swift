import SwiftUI

struct HistogramPanel: View {
    let histogram: ImageHistogram
    let exposureAnalysis: ExposureAnalysis

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("影调直方图")
                        .font(.headline)
                    Spacer()
                    legend(color: Color(nsColor: .labelColor), label: "亮度")
                    legend(color: .red, label: "R")
                    legend(color: .green, label: "G")
                    legend(color: .blue, label: "B")
                }

                HistogramGraph(histogram: histogram)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .frame(minHeight: 150)

                ExposureAnalysisPanel(analysis: exposureAnalysis)
            }
            .padding(.vertical, 2)
        }
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

struct ExposureAnalysisPanel: View {
    let analysis: ExposureAnalysis

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 16) {
                exposureBar(
                    label: "阴影",
                    percentage: analysis.shadowPercentage,
                    color: Color(nsColor: .secondaryLabelColor)
                )

                exposureBar(
                    label: "中间调",
                    percentage: analysis.midtonePercentage,
                    color: Color(nsColor: .labelColor)
                )

                exposureBar(
                    label: "高光",
                    percentage: analysis.highlightPercentage,
                    color: Color(nsColor: .labelColor)
                )

                if analysis.clippedHighlightPercentage > 0.001 {
                    exposureBar(
                        label: "裁剪高光",
                        percentage: analysis.clippedHighlightPercentage,
                        color: .red
                    )
                }
                if analysis.crushedShadowPercentage > 0.001 {
                    exposureBar(
                        label: "挤压阴影",
                        percentage: analysis.crushedShadowPercentage,
                        color: .orange
                    )
                }
            }
            .padding(10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func exposureBar(label: String, percentage: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .systemGray).opacity(0.3))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, proxy.size.width * percentage))
                }
            }
            .frame(height: 8)

            Text(formatPercent(percentage))
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .frame(width: 80)
    }

    private func formatPercent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

struct HistogramGraph: View {
    let histogram: ImageHistogram

    var body: some View {
        GeometryReader { proxy in
            let lumaMaxValue = histogram.luma.max() ?? 1
            let rgbMaxValue = max(histogram.red.max() ?? 1, histogram.green.max() ?? 1, histogram.blue.max() ?? 1)

            ZStack {
                thresholdZones(size: proxy.size)
                toneZones(size: proxy.size)
                grid(size: proxy.size)

                channelPath(values: histogram.red, maxValue: rgbMaxValue, size: proxy.size)
                    .stroke(Color.red.opacity(0.42), lineWidth: 1)
                channelPath(values: histogram.green, maxValue: rgbMaxValue, size: proxy.size)
                    .stroke(Color.green.opacity(0.42), lineWidth: 1)
                channelPath(values: histogram.blue, maxValue: rgbMaxValue, size: proxy.size)
                    .stroke(Color.blue.opacity(0.42), lineWidth: 1)

                lumaFillPath(values: histogram.luma, maxValue: lumaMaxValue, size: proxy.size)
                    .fill(Color(nsColor: .labelColor).opacity(0.12))
                channelPath(values: histogram.luma, maxValue: lumaMaxValue, size: proxy.size)
                    .stroke(Color(nsColor: .labelColor).opacity(0.9), lineWidth: 1.8)

                thresholdLines(size: proxy.size)
            }
            .overlay(alignment: .bottom) {
                toneLabels
                    .padding(.horizontal, 8)
                    .padding(.bottom, 3)
            }
        }
    }

    private var toneLabels: some View {
        HStack {
            Text("阴影")
            Spacer()
            Text("中间调")
            Spacer()
            Text("高光")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(Color(nsColor: .secondaryLabelColor).opacity(0.7))
    }

    private func thresholdZones(size: CGSize) -> some View {
        HStack(spacing: 0) {
            Color.orange.opacity(0.15)
                .frame(width: size.width * ExposureThresholds.crushedShadow)
            Color.clear
                .frame(width: size.width * (ExposureThresholds.clippedHighlight - ExposureThresholds.crushedShadow))
            Color.red.opacity(0.15)
                .frame(width: size.width * (1 - ExposureThresholds.clippedHighlight))
        }
        .frame(width: size.width, height: size.height)
    }

    private func toneZones(size: CGSize) -> some View {
        HStack(spacing: 0) {
            Color.black.opacity(0.025)
            Color.clear
            Color.white.opacity(0.28)
        }
        .frame(width: size.width, height: size.height)
    }

    private func grid(size: CGSize) -> some View {
        Path { path in
            for fraction in [0.25, 0.5, 0.75] {
                let x = size.width * fraction
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            for fraction in [0.25, 0.5, 0.75] {
                let y = size.height * fraction
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.6)
    }

    private func thresholdLines(size: CGSize) -> some View {
        ZStack {
            Path { path in
                let shadowX = size.width * ExposureThresholds.crushedShadow
                path.move(to: CGPoint(x: shadowX, y: 0))
                path.addLine(to: CGPoint(x: shadowX, y: size.height))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 2]))
            .foregroundStyle(.orange.opacity(0.8))

            Path { path in
                let highlightX = size.width * ExposureThresholds.clippedHighlight
                path.move(to: CGPoint(x: highlightX, y: 0))
                path.addLine(to: CGPoint(x: highlightX, y: size.height))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 2]))
            .foregroundStyle(.red.opacity(0.8))

            VStack {
                Text("挤压阴影")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(width: size.width * ExposureThresholds.crushedShadow - 4, alignment: .trailing)
                    .padding(.top, 2)
                Spacer()
            }
            .frame(width: size.width, alignment: .leading)

            VStack {
                Text("裁剪高光")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 2)
                Spacer()
            }
            .frame(width: size.width, alignment: .trailing)
            .padding(.trailing, 4)
        }
    }

    private func lumaFillPath(values: [Int], maxValue: Int, size: CGSize) -> Path {
        var path = channelPath(values: values, maxValue: maxValue, size: size)
        let inset = 2.0
        let baseline = max(inset, size.height - inset)
        path.addLine(to: CGPoint(x: max(inset, size.width - inset), y: baseline))
        path.addLine(to: CGPoint(x: inset, y: baseline))
        path.closeSubpath()
        return path
    }

    private func channelPath(values: [Int], maxValue: Int, size: CGSize) -> Path {
        var path = Path()
        guard values.count > 1, maxValue > 0 else {
            return path
        }
        for index in values.indices {
            let inset = 2.0
            let plotWidth = max(1, size.width - inset * 2)
            let plotHeight = max(1, size.height - inset * 2)
            let x = inset + Double(index) / Double(values.count - 1) * plotWidth
            let y = inset + plotHeight - (Double(values[index]) / Double(maxValue) * plotHeight)
            let point = CGPoint(x: x, y: y)
            if index == values.startIndex {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
