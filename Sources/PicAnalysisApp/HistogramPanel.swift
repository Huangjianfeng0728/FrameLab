import SwiftUI

struct HistogramPanel: View {
    let histogram: ImageHistogram

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("影调直方图")
                    .font(.headline)
                Spacer()
                legend(color: .white, label: "亮度")
                legend(color: .red, label: "R")
                legend(color: .green, label: "G")
                legend(color: .blue, label: "B")
            }

            HistogramGraph(histogram: histogram)
                .padding(8)
                .background(Color.black.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(minHeight: 150)
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

struct HistogramGraph: View {
    let histogram: ImageHistogram

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(
                histogram.luma.max() ?? 1,
                histogram.red.max() ?? 1,
                histogram.green.max() ?? 1,
                histogram.blue.max() ?? 1
            )

            ZStack {
                channelPath(values: histogram.red, maxValue: maxValue, size: proxy.size)
                    .stroke(Color.red.opacity(0.7), lineWidth: 1)
                channelPath(values: histogram.green, maxValue: maxValue, size: proxy.size)
                    .stroke(Color.green.opacity(0.7), lineWidth: 1)
                channelPath(values: histogram.blue, maxValue: maxValue, size: proxy.size)
                    .stroke(Color.blue.opacity(0.7), lineWidth: 1)
                channelPath(values: histogram.luma, maxValue: maxValue, size: proxy.size)
                    .stroke(Color.white.opacity(0.92), lineWidth: 1.5)
            }
        }
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
