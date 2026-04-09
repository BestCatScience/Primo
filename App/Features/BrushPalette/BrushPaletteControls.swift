import SwiftUI
import UIKit

struct SpectrumColorControl: View {
    @Binding var color: Color
    @State private var activeRegion: ActiveRegion?

    private let ringWidth: CGFloat = 18
    private let gap: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let outerRect = CGRect(
                x: (geometry.size.width - size) / 2,
                y: (geometry.size.height - size) / 2,
                width: size,
                height: size
            )
            let squareSide = max(size - ((ringWidth + gap) * 2), 24)
            let squareRect = CGRect(
                x: outerRect.midX - (squareSide / 2),
                y: outerRect.midY - (squareSide / 2),
                width: squareSide,
                height: squareSide
            )
            let hsb = ColorHSB(color: color)
            let ringIndicator = ringIndicatorPoint(in: outerRect, hue: hsb.hue)
            let squareIndicator = CGPoint(
                x: squareRect.minX + (hsb.saturation * squareRect.width),
                y: squareRect.minY + ((1 - hsb.brightness) * squareRect.height)
            )

            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .red, .yellow, .green, .cyan, .blue, .purple, .red
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .frame(width: outerRect.width, height: outerRect.height)
                    .position(x: outerRect.midX, y: outerRect.midY)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hue: hsb.hue, saturation: 1, brightness: 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .frame(width: squareRect.width, height: squareRect.height)
                    .position(x: squareRect.midX, y: squareRect.midY)

                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.24), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .position(x: ringIndicator.x, y: ringIndicator.y)

                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .position(x: squareIndicator.x, y: squareIndicator.y)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if activeRegion == nil {
                            activeRegion = hitRegion(at: value.location, outerRect: outerRect, squareRect: squareRect)
                        }

                        switch activeRegion {
                        case .square:
                            updateSquare(at: value.location, within: squareRect, hue: hsb.hue)
                        case .ring:
                            updateRing(at: value.location, within: outerRect, current: hsb)
                        case .none:
                            break
                        }
                    }
                    .onEnded { _ in
                        activeRegion = nil
                    }
            )
        }
        .frame(height: 176)
    }

    private func hitRegion(at point: CGPoint, outerRect: CGRect, squareRect: CGRect) -> ActiveRegion? {
        if squareRect.contains(point) {
            return .square
        }

        let dx = point.x - outerRect.midX
        let dy = point.y - outerRect.midY
        let distance = sqrt((dx * dx) + (dy * dy))
        let outerRadius = outerRect.width / 2
        let innerRadius = outerRadius - ringWidth
        if distance >= innerRadius && distance <= outerRadius {
            return .ring
        }

        return nil
    }

    private func updateRing(at point: CGPoint, within rect: CGRect, current: ColorHSB) {
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        let angle = atan2(dy, dx) + (.pi / 2)
        let normalized = (angle < 0 ? angle + (.pi * 2) : angle) / (.pi * 2)
        color = Color(hue: normalized, saturation: current.saturation, brightness: current.brightness)
    }

    private func updateSquare(at point: CGPoint, within rect: CGRect, hue: Double) {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let saturation = (clampedX - rect.minX) / rect.width
        let brightness = 1 - ((clampedY - rect.minY) / rect.height)
        color = Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func ringIndicatorPoint(in rect: CGRect, hue: Double) -> CGPoint {
        let angle = (hue * .pi * 2) - (.pi / 2)
        let radius = (rect.width - ringWidth) / 2
        return CGPoint(
            x: rect.midX + (cos(angle) * radius),
            y: rect.midY + (sin(angle) * radius)
        )
    }

    private enum ActiveRegion {
        case ring
        case square
    }
}

struct SquareSliderColorPalette: View {
    @Binding var color: Color
    @State private var activeRegion: ActiveRegion?

    var body: some View {
        GeometryReader { geometry in
            let hsb = ColorHSB(color: color)
            let sliderWidth: CGFloat = 18
            let spacing: CGFloat = 12
            let squareSide = min(geometry.size.height, max(96, geometry.size.width - sliderWidth - spacing))
            let squareRect = CGRect(x: 0, y: 0, width: squareSide, height: squareSide)
            let sliderRect = CGRect(x: squareSide + spacing, y: 0, width: sliderWidth, height: squareSide)
            let squareIndicator = CGPoint(
                x: squareRect.minX + (hsb.saturation * squareRect.width),
                y: squareRect.minY + ((1 - hsb.brightness) * squareRect.height)
            )
            let hueIndicatorY = sliderRect.minY + ((1 - hsb.hue) * sliderRect.height)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hue: hsb.hue, saturation: 1, brightness: 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                    }
                    .frame(width: squareRect.width, height: squareRect.height)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: sliderRect.width, height: sliderRect.height)
                    .offset(x: sliderRect.minX, y: sliderRect.minY)

                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 2))
                    .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                    .position(x: squareIndicator.x, y: squareIndicator.y)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: sliderRect.width + 8, height: 10)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .offset(x: sliderRect.minX - 4, y: hueIndicatorY - 5)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if activeRegion == nil {
                            activeRegion = hitRegion(at: value.location, squareRect: squareRect, sliderRect: sliderRect)
                        }
                        switch activeRegion {
                        case .square:
                            updateSquare(at: value.location, within: squareRect, hue: hsb.hue)
                        case .slider:
                            updateHue(at: value.location, within: sliderRect, current: hsb)
                        case .none:
                            break
                        }
                    }
                    .onEnded { _ in
                        activeRegion = nil
                    }
            )
        }
        .frame(height: 148)
    }

    private func hitRegion(at point: CGPoint, squareRect: CGRect, sliderRect: CGRect) -> ActiveRegion? {
        if squareRect.contains(point) { return .square }
        if sliderRect.insetBy(dx: -8, dy: -8).contains(point) { return .slider }
        return nil
    }

    private func updateSquare(at point: CGPoint, within rect: CGRect, hue: Double) {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let saturation = (clampedX - rect.minX) / rect.width
        let brightness = 1 - ((clampedY - rect.minY) / rect.height)
        color = Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func updateHue(at point: CGPoint, within rect: CGRect, current: ColorHSB) {
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let hue = 1 - ((clampedY - rect.minY) / rect.height)
        color = Color(hue: hue, saturation: current.saturation, brightness: current.brightness)
    }

    private enum ActiveRegion {
        case square
        case slider
    }
}

struct VerticalValueSlider: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geometry in
            let normalized = min(max(value, 0.0), 1.0)
            let knobSize: CGFloat = 18
            let trackWidth: CGFloat = 6
            let travel = max(0, geometry.size.height - knobSize)
            let knobY = travel * CGFloat(1.0 - normalized)

            ZStack(alignment: .top) {
                Capsule(style: .continuous)
                    .fill(StudioTheme.Palette.cardFillStrong)
                    .frame(width: trackWidth)

                Capsule(style: .continuous)
                    .fill(StudioTheme.Palette.accentBright.opacity(0.95))
                    .frame(width: trackWidth, height: max(trackWidth, geometry.size.height - knobY - (knobSize / 2)))
                    .offset(y: knobY + (knobSize / 2))

                Circle()
                    .fill(Color.white.opacity(0.96))
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
                    .offset(y: knobY)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let clampedY = min(max(gesture.location.y - (knobSize / 2), 0), travel)
                        value = Double(1.0 - (clampedY / max(travel, 1)))
                    }
            )
        }
    }
}

struct ColorHSB {
    let hue: Double
    let saturation: Double
    let brightness: Double

    init(color: Color) {
        let resolved = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        resolved.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        self.hue = Double(hue)
        self.saturation = Double(saturation)
        self.brightness = Double(brightness)
    }
}

struct PaletteSwatch: Identifiable {
    let id: String
    let color: Color

    static let defaults: [PaletteSwatch] = [
        PaletteSwatch(id: "graphite", color: Color(red: 0.14, green: 0.15, blue: 0.18)),
        PaletteSwatch(id: "ruby", color: Color(red: 0.77, green: 0.23, blue: 0.26)),
        PaletteSwatch(id: "amber", color: Color(red: 0.89, green: 0.61, blue: 0.18)),
        PaletteSwatch(id: "moss", color: Color(red: 0.34, green: 0.55, blue: 0.29)),
        PaletteSwatch(id: "lagoon", color: Color(red: 0.19, green: 0.55, blue: 0.72)),
        PaletteSwatch(id: "violet", color: Color(red: 0.49, green: 0.37, blue: 0.76)),
        PaletteSwatch(id: "rose", color: Color(red: 0.86, green: 0.46, blue: 0.59))
    ]
}
