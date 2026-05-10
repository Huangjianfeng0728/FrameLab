import SwiftUI

struct SampleInspectorView: View {
    @ObservedObject var viewModel: AnalysisViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sampleTable
                        .frame(height: 180)
                    Divider()
                    selectedPointDetails
                    Divider()
                    colorWheel
                    Divider()
                    controls
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text("采样点信息")
                .font(.headline)
            Spacer()
            Text("\(viewModel.selectedDocument?.samplePoints.count ?? 0) 点")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var sampleTable: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("#")
                    Text("H")
                    Text("S")
                    Text("L")
                    Text("Hex")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                if let document = viewModel.selectedDocument {
                    ForEach(Array(document.samplePoints.enumerated()), id: \.element.id) { index, samplePoint in
                        GridRow {
                            Text("\(index + 1)")
                            Text("\(Int(samplePoint.sample.hsl.hue.rounded()))°")
                            Text(percent(samplePoint.sample.hsl.saturation))
                            Text(percent(samplePoint.sample.hsl.lightness))
                            Text(samplePoint.sample.hex)
                        }
                        .font(.caption.monospacedDigit())
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .foregroundStyle(samplePoint.id == viewModel.selectedPointID ? .primary : .secondary)
                        .onTapGesture {
                            viewModel.selectedPointID = samplePoint.id
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var selectedPointDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选中点详细信息")
                .font(.subheadline.weight(.semibold))
            if let point = viewModel.selectedPoint {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        detailCell("H", "\(Int(point.sample.hsl.hue.rounded()))°")
                        detailCell("S", percent(point.sample.hsl.saturation))
                    }
                    GridRow {
                        detailCell("L", percent(point.sample.hsl.lightness))
                        detailCell("半径", point.radius.title)
                    }
                    GridRow {
                        detailCell("RGB", "\(point.sample.rgb.red), \(point.sample.rgb.green), \(point.sample.rgb.blue)")
                        detailCell("Hex", point.sample.hex)
                    }
                }
            } else {
                Text("未选择采样点")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var colorWheel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Wheel")
                .font(.subheadline.weight(.semibold))
            if let document = viewModel.selectedDocument {
                ColorWheelView(
                    samplePoints: document.samplePoints,
                    selectedPointID: viewModel.selectedPointID
                )
                .frame(maxWidth: .infinity)
                .frame(height: 170)
            } else {
                Text("导入照片后显示采样点色相位置")
                    .foregroundStyle(.secondary)
                    .frame(height: 170)
            }
        }
        .padding(12)
    }

    private var controls: some View {
        HStack {
            Button {
                viewModel.isAddingPoint.toggle()
            } label: {
                Label(viewModel.isAddingPoint ? "取消新增" : "新增点", systemImage: viewModel.isAddingPoint ? "xmark.circle" : "plus.circle")
            }
            .disabled(viewModel.selectedDocument == nil)

            Button("删除点") {
                viewModel.deleteSelectedPoint()
            }
            .disabled(viewModel.selectedPointID == nil)

            Button("重算10点") {
                viewModel.regenerateDefaultPoints()
            }
            .disabled(viewModel.selectedDocument == nil)
        }
        .padding(12)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func detailCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
