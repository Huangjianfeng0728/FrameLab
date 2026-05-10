import SwiftUI

enum ColorWheelGeometry {
    static func position(hue: Double, saturation: Double, center: CGPoint, radius: Double) -> CGPoint {
        let radians = (hue - 90) * .pi / 180
        let distance = min(1, max(0, saturation)) * radius
        return CGPoint(
            x: center.x + cos(radians) * distance,
            y: center.y + sin(radians) * distance
        )
    }
}

struct ColorWheelView: View {
    let samplePoints: [SamplePoint]
    var selectedPointID: UUID?
    var showLabels = true

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let radius = side / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                .red,
                                .yellow,
                                .green,
                                .cyan,
                                .blue,
                                .purple,
                                .red
                            ],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        )
                    )
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white, .white.opacity(0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: radius
                                )
                            )
                    )
                    .overlay(Circle().stroke(Color.primary.opacity(0.16), lineWidth: 1))
                    .frame(width: side, height: side)
                    .position(center)

                ForEach(Array(samplePoints.enumerated()), id: \.element.id) { index, samplePoint in
                    let markerPosition = position(for: samplePoint, center: center, radius: radius * 0.92)
                    ColorWheelMarker(
                        number: index + 1,
                        color: Color(
                            red: Double(samplePoint.sample.rgb.red) / 255,
                            green: Double(samplePoint.sample.rgb.green) / 255,
                            blue: Double(samplePoint.sample.rgb.blue) / 255
                        ),
                        isSelected: samplePoint.id == selectedPointID,
                        showLabel: showLabels
                    )
                    .position(markerPosition)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func position(for samplePoint: SamplePoint, center: CGPoint, radius: Double) -> CGPoint {
        ColorWheelGeometry.position(
            hue: samplePoint.sample.hsl.hue,
            saturation: samplePoint.sample.hsl.saturation,
            center: center,
            radius: radius
        )
    }
}

private struct ColorWheelMarker: View {
    let number: Int
    let color: Color
    let isSelected: Bool
    let showLabel: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
            Circle()
                .stroke(isSelected ? Color.black : Color.white, lineWidth: isSelected ? 3 : 2)
            if showLabel {
                Text("\(number)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 1)
            }
        }
        .frame(width: isSelected ? 24 : 18, height: isSelected ? 24 : 18)
        .shadow(radius: 2)
    }
}
