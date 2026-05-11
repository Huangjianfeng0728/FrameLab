import SwiftUI

struct SampleInspectorView: View {
    @ObservedObject var viewModel: AnalysisViewModel

    private var selectedPointColor: Color {
        guard let point = viewModel.selectedPoint else {
            return Color(nsColor: .tertiaryLabelColor)
        }
        return color(from: point.sample.rgb)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    selectedPointSummary
                    colorWheelSection
                    sampleTable
                }
                .padding(14)
            }

            controls
        }
        .foregroundStyle(Color(nsColor: .labelColor))
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("采样分析")
                    .font(.headline.weight(.semibold))
                Text("HSL / Color Wheel")
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(selectedPointColor)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                Text(viewModel.selectedPoint?.sample.hex ?? "--")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            Text("\(viewModel.selectedDocument?.samplePoints.count ?? 0) 点")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }

    private var selectedPointSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("选中点")

            if let point = viewModel.selectedPoint {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color(from: point.sample.rgb))
                        .frame(width: 54, height: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(point.sample.hex)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        Text("RGB \(point.sample.rgb.red), \(point.sample.rgb.green), \(point.sample.rgb.blue)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        Text("采样半径 \(point.radius.title)")
                            .font(.caption)
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    metricTile("H", "\(Int(point.sample.hsl.hue.rounded()))°")
                    metricTile("S", percent(point.sample.hsl.saturation))
                    metricTile("L", percent(point.sample.hsl.lightness))
                }
            } else {
                emptyMessage("未选择采样点")
            }
        }
        .padding(12)
        .background(sectionBackground)
    }

    private var colorWheelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Color Wheel")
            if let document = viewModel.selectedDocument {
                ColorWheelView(
                    samplePoints: document.samplePoints,
                    selectedPointID: viewModel.selectedPointID
                )
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .padding(.vertical, 4)
            } else {
                emptyMessage("导入照片后显示采样点色相位置")
                    .frame(height: 170)
            }
        }
        .padding(12)
        .background(sectionBackground)
    }

    private var sampleTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("采样点")

            VStack(spacing: 0) {
                tableHeader
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if let document = viewModel.selectedDocument {
                            ForEach(Array(document.samplePoints.enumerated()), id: \.element.id) { index, samplePoint in
                                sampleRow(index: index, samplePoint: samplePoint)
                            }
                        }
                    }
                }
                .frame(minHeight: 130, maxHeight: 190)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        .padding(12)
        .background(sectionBackground)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            tableLabel("#", width: 42, alignment: .center)
            tableLabel("H", width: 54)
            tableLabel("S", width: 50)
            tableLabel("L", width: 50)
            tableLabel("Hex", width: nil)
        }
    }

    private func sampleRow(index: Int, samplePoint: SamplePoint) -> some View {
        let isSelected = samplePoint.id == viewModel.selectedPointID

        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color(from: samplePoint.sample.rgb))
                    .frame(width: 9, height: 9)
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            .frame(width: 42)

            Text("\(Int(samplePoint.sample.hsl.hue.rounded()))°")
                .frame(width: 54, alignment: .leading)
            Text(percent(samplePoint.sample.hsl.saturation))
                .frame(width: 50, alignment: .leading)
            Text(percent(samplePoint.sample.hsl.lightness))
                .frame(width: 50, alignment: .leading)
            Text(samplePoint.sample.hex)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(isSelected ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.yellow.opacity(0.18) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedPointID = samplePoint.id
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.55))
                .frame(height: 1)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.isAddingPoint.toggle()
            } label: {
                Label(viewModel.isAddingPoint ? "取消" : "新增点", systemImage: viewModel.isAddingPoint ? "xmark.circle" : "plus.circle")
            }
            .disabled(viewModel.selectedDocument == nil)

            Button {
                viewModel.deleteSelectedPoint()
            } label: {
                Label("删除", systemImage: "trash")
            }
            .disabled(viewModel.selectedPointID == nil)

            Button {
                viewModel.regenerateDefaultPoints()
            } label: {
                Label("重算10点", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(viewModel.selectedDocument == nil)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
    }

    private func metricTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func tableLabel(_ title: String, width: CGFloat?, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .frame(width: width, alignment: alignment)
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func color(from color: RGBColor) -> Color {
        Color(
            red: Double(color.red) / 255,
            green: Double(color.green) / 255,
            blue: Double(color.blue) / 255
        )
    }
}
