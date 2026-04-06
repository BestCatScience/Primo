import SwiftUI

enum PhotoshopDynamicControl: String, CaseIterable, Identifiable {
    case off
    case pressure
    case tilt
    case speed
    case random

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .off:
            return StudioStrings.dynamicControlOff(language)
        case .pressure:
            return StudioStrings.dynamicControlPressure(language)
        case .tilt:
            return StudioStrings.dynamicControlTilt(language)
        case .speed:
            return StudioStrings.dynamicControlSpeed(language)
        case .random:
            return StudioStrings.dynamicControlRandom(language)
        }
    }
}

enum BrushSettingsCategory: String, CaseIterable, Identifiable {
    case tip
    case scatter
    case stroke
    case texture

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .tip:
            return StudioStrings.brushSettingsCategoryTip(language)
        case .scatter:
            return StudioStrings.brushSettingsCategoryScatter(language)
        case .stroke:
            return StudioStrings.brushSettingsCategoryStroke(language)
        case .texture:
            return StudioStrings.brushSettingsCategoryTexture(language)
        }
    }

    var systemImage: String {
        switch self {
        case .tip:
            return "pencil.tip"
        case .scatter:
            return "sparkles"
        case .stroke:
            return "slider.horizontal.3"
        case .texture:
            return "square.grid.3x3.fill"
        }
    }
}

struct BrushPreviewStyle {
    let color: Color
    let radius: Double
    let opacity: Double
    let roundness: Double
    let angle: Double
    let spacing: Double
    let scatterEnabled: Bool
    let scatterMode: BrushScatterMode
    let scatterLateral: Double
    let scatterLinear: Double
    let count: Int
    let countSizeJitter: Double
    let countOpacityJitter: Double
    let textureStrength: Double
    let flow: Double

    init(
        color: Color,
        radius: Double,
        opacity: Double,
        roundness: Double,
        angle: Double,
        spacing: Double,
        scatterEnabled: Bool,
        scatterMode: BrushScatterMode,
        scatterLateral: Double,
        scatterLinear: Double,
        count: Int,
        countSizeJitter: Double,
        countOpacityJitter: Double,
        textureStrength: Double,
        flow: Double
    ) {
        self.color = color
        self.radius = radius
        self.opacity = opacity
        self.roundness = roundness
        self.angle = angle
        self.spacing = spacing
        self.scatterEnabled = scatterEnabled
        self.scatterMode = scatterMode
        self.scatterLateral = scatterLateral
        self.scatterLinear = scatterLinear
        self.count = count
        self.countSizeJitter = countSizeJitter
        self.countOpacityJitter = countOpacityJitter
        self.textureStrength = textureStrength
        self.flow = flow
    }

    init(preset: BrushPreset) {
        color = .white
        radius = preset.radius
        opacity = preset.opacity
        roundness = preset.roundness
        angle = preset.angle
        spacing = preset.spacing
        scatterEnabled = preset.scatterEnabled
        scatterMode = preset.scatterMode
        scatterLateral = preset.scatterLateral
        scatterLinear = preset.scatterLinear
        count = preset.count
        countSizeJitter = preset.countSizeJitter
        countOpacityJitter = preset.countOpacityJitter
        textureStrength = preset.textureStrength
        flow = preset.flow
    }
}

struct BrushStrokePreview: View {
    let style: BrushPreviewStyle
    var compact = false

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let points = previewPoints(in: size)
                let baseWidth = max(compact ? 2.2 : 3.8, min(size.width, size.height) * (compact ? 0.072 : 0.094) * style.radius / 6.0)
                let baseAlpha = max(0.18, min(0.96, style.opacity * (0.7 + style.flow * 0.3)))

                for index in 0..<points.count {
                    let point = points[index]
                    let pressure = previewPressure(at: index, total: points.count)
                    let clusterCount = max(1, style.scatterEnabled ? style.count : 1)
                    for clusterIndex in 0..<clusterCount {
                        let jitterSeed = Double(index * 13 + clusterIndex * 31 + 7)
                        let sizeJitter = 1.0 + signedNoise(jitterSeed * 0.17) * style.countSizeJitter * 0.55
                        let opacityJitter = 1.0 + signedNoise(jitterSeed * 0.11 + 0.3) * style.countOpacityJitter * 0.65
                        let scatter = scatterOffset(seed: jitterSeed, baseWidth: baseWidth)
                        let pressureWidth = lerp(0.52, 1.0, pressure)
                        let pressureOpacity = lerp(0.38, 1.0, pressure)
                        let rect = CGRect(
                            x: point.x + scatter.width - (baseWidth * sizeJitter * pressureWidth),
                            y: point.y + scatter.height - (baseWidth * sizeJitter * pressureWidth * max(0.28, style.roundness)),
                            width: baseWidth * 2.0 * sizeJitter * pressureWidth,
                            height: baseWidth * 2.0 * sizeJitter * pressureWidth * max(0.28, style.roundness)
                        )
                        let rotation = Angle(radians: style.angle + signedNoise(jitterSeed * 0.07) * 0.18)
                        let path = Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.55)
                        let transformed = path.applying(CGAffineTransform(translationX: -rect.midX, y: -rect.midY))
                            .applying(CGAffineTransform(rotationAngle: rotation.radians))
                            .applying(CGAffineTransform(translationX: rect.midX, y: rect.midY))
                        context.fill(
                            transformed,
                            with: .color(style.color.opacity(max(0.08, min(1.0, baseAlpha * pressureOpacity * opacityJitter))))
                        )
                    }
                }
            }
        }
    }

    private func previewPoints(in size: CGSize) -> [CGPoint] {
        let start = CGPoint(x: size.width * 0.08, y: size.height * 0.68)
        let c1 = CGPoint(x: size.width * 0.28, y: size.height * 0.12)
        let c2 = CGPoint(x: size.width * 0.62, y: size.height * 0.92)
        let end = CGPoint(x: size.width * 0.92, y: size.height * 0.34)
        let steps = compact ? 28 : 54
        return (0...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            let spacingWarp = 1.0 + CGFloat(style.spacing * 0.45)
            let warped = min(1.0, pow(t, 1.0 / spacingWarp))
            return cubicPoint(start: start, c1: c1, c2: c2, end: end, t: warped)
        }
    }

    private func cubicPoint(start: CGPoint, c1: CGPoint, c2: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let x =
            mt * mt * mt * start.x +
            3 * mt * mt * t * c1.x +
            3 * mt * t * t * c2.x +
            t * t * t * end.x
        let y =
            mt * mt * mt * start.y +
            3 * mt * mt * t * c1.y +
            3 * mt * t * t * c2.y +
            t * t * t * end.y
        return CGPoint(x: x, y: y)
    }

    private func scatterOffset(seed: Double, baseWidth: Double) -> CGSize {
        guard style.scatterEnabled else { return .zero }
        let lateral = signedNoise(seed * 0.23 + 0.2) * style.scatterLateral * baseWidth * 1.8
        let linear = signedNoise(seed * 0.19 + 1.1) * style.scatterLinear * baseWidth * (style.scatterMode == .spray ? 1.8 : 1.0)
        if style.scatterMode == .spray {
            return CGSize(width: lateral, height: linear)
        }
        return CGSize(width: linear, height: lateral)
    }

    private func previewPressure(at index: Int, total: Int) -> Double {
        guard total > 1 else { return 0.85 }
        let t = Double(index) / Double(total - 1)
        let envelope = sin(t * .pi)
        let pulse = 0.72 + (0.28 * sin((t * .pi * 2.4) - 0.6))
        return max(0.18, min(1.0, envelope * pulse + 0.18))
    }

    private func signedNoise(_ seed: Double) -> Double {
        let value = sin(seed * 91.37 + 17.0) * 43758.5453
        return (value - floor(value)) * 2.0 - 1.0
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + ((b - a) * t)
    }
}
