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
    let tipKind: BrushTipKind
    let color: Color
    let radius: Double
    let opacity: Double
    let hardness: Double
    let roundness: Double
    let angle: Double
    let followsStrokeAngle: Bool
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
    let flowPressureSensitivity: Double
    let opacityPressureSensitivity: Double
    let pressureSensitivity: Double
    let customTip: BrushTipRaster?

    init(
        tipKind: BrushTipKind,
        color: Color,
        radius: Double,
        opacity: Double,
        hardness: Double,
        roundness: Double,
        angle: Double,
        followsStrokeAngle: Bool,
        spacing: Double,
        scatterEnabled: Bool,
        scatterMode: BrushScatterMode,
        scatterLateral: Double,
        scatterLinear: Double,
        count: Int,
        countSizeJitter: Double,
        countOpacityJitter: Double,
        textureStrength: Double,
        flow: Double,
        flowPressureSensitivity: Double,
        opacityPressureSensitivity: Double,
        pressureSensitivity: Double,
        customTip: BrushTipRaster?
    ) {
        self.tipKind = tipKind
        self.color = color
        self.radius = radius
        self.opacity = opacity
        self.hardness = hardness
        self.roundness = roundness
        self.angle = angle
        self.followsStrokeAngle = followsStrokeAngle
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
        self.flowPressureSensitivity = flowPressureSensitivity
        self.opacityPressureSensitivity = opacityPressureSensitivity
        self.pressureSensitivity = pressureSensitivity
        self.customTip = customTip
    }

    init(preset: BrushPreset) {
        tipKind = preset.tipKind
        color = .white
        radius = preset.radius
        opacity = preset.opacity
        hardness = preset.hardness
        roundness = preset.roundness
        angle = preset.angle
        followsStrokeAngle = preset.angleMode == .strokeDirection
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
        flowPressureSensitivity = preset.flowPressureSensitivity
        opacityPressureSensitivity = preset.opacityPressureSensitivity
        pressureSensitivity = preset.pressureSensitivity
        customTip = preset.customTip
    }
}

struct BrushStrokePreview: View {
    let style: BrushPreviewStyle
    var compact = false

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let baseDiameter = previewBaseDiameter
                let points = previewPoints(in: size, baseDiameter: baseDiameter)

                for index in points.indices {
                    let point = points[index].0
                    let pressure = points[index].1
                    let pressureScale = max(0.35, 1.0 - style.pressureSensitivity + (style.pressureSensitivity * pressure))
                    let diameter = max(baseDiameter * pressureScale, 1.0)
                    let angle = previewStampAngle(for: points, at: index)
                    let clusterCount = max(1, style.scatterEnabled ? style.count : 1)
                    for clusterIndex in 0..<clusterCount {
                        let jitterSeed = Double(index * 13 + clusterIndex * 31 + 7)
                        let sizeJitter = 1.0 + signedNoise(jitterSeed * 0.17) * style.countSizeJitter * 0.55
                        let opacityJitter = 1.0 + signedNoise(jitterSeed * 0.11 + 0.3) * style.countOpacityJitter * 0.65
                        let scatter = scatterOffset(seed: jitterSeed, baseDiameter: diameter)
                        drawPreviewStamp(
                            in: &context,
                            center: CGPoint(x: point.x + scatter.width, y: point.y + scatter.height),
                            diameter: max(diameter * sizeJitter, 1.0),
                            angle: angle + signedNoise(jitterSeed * 0.07) * 0.18,
                            alpha: previewStampAlpha(pressure: pressure, opacityJitter: opacityJitter)
                        )
                    }
                }
            }
        }
    }

    private var previewBaseDiameter: Double {
        let scale = compact ? 0.74 : 0.82
        return max(style.radius * 2.0 * scale, 1.0)
    }

    private func previewPoints(in size: CGSize, baseDiameter: Double) -> [(CGPoint, Double)] {
        let start = CGPoint(x: size.width * 0.08, y: size.height * 0.68)
        let c1 = CGPoint(x: size.width * 0.28, y: size.height * 0.12)
        let c2 = CGPoint(x: size.width * 0.62, y: size.height * 0.92)
        let end = CGPoint(x: size.width * 0.92, y: size.height * 0.34)
        let steps = compact ? 96 : 160
        let densePoints = (0...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            return cubicPoint(start: start, c1: c1, c2: c2, end: end, t: t)
        }

        let targetSpacing = previewStampSpacing(baseDiameter: baseDiameter)
        var sampled: [(CGPoint, Double)] = [(densePoints[0], previewPressure(at: 0, total: densePoints.count))]
        var carriedDistance = 0.0

        for index in 1..<densePoints.count {
            let previous = densePoints[index - 1]
            let current = densePoints[index]
            carriedDistance += hypot(current.x - previous.x, current.y - previous.y)
            if carriedDistance >= targetSpacing {
                sampled.append((current, previewPressure(at: index, total: densePoints.count)))
                carriedDistance = 0.0
            }
        }

        if let lastPoint = densePoints.last, sampled.last?.0 != lastPoint {
            sampled.append((lastPoint, previewPressure(at: densePoints.count - 1, total: densePoints.count)))
        }

        return sampled
    }

    private func previewStampSpacing(baseDiameter: Double) -> Double {
        // The canvas renderer visually blends stamps more tightly than this simplified preview,
        // so we intentionally oversample here to avoid a dotted/stamped appearance.
        let spacingFactor = min(max(style.spacing * 0.35, 0.04), 0.16)
        let minimumSpacing = compact ? 0.28 : 0.4
        return max(baseDiameter * spacingFactor, minimumSpacing)
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

    private func previewStampAngle(for points: [(CGPoint, Double)], at index: Int) -> Double {
        guard style.followsStrokeAngle, points.count >= 2 else { return style.angle }

        let previous = points[max(index - 1, 0)].0
        let next = points[min(index + 1, points.count - 1)].0
        let deltaX = next.x - previous.x
        let deltaY = next.y - previous.y
        guard abs(deltaX) > 0.001 || abs(deltaY) > 0.001 else { return style.angle }
        return atan2(deltaY, deltaX) + style.angle
    }

    private func drawPreviewStamp(
        in context: inout GraphicsContext,
        center: CGPoint,
        diameter: Double,
        angle: Double,
        alpha: Double
    ) {
        let size = previewStampSize(for: diameter)
        let rect = CGRect(
            x: center.x - (size.width * 0.5),
            y: center.y - (size.height * 0.5),
            width: size.width,
            height: size.height
        )

        let path: Path = {
            switch style.tipKind {
            case .oil:
                return Path(roundedRect: rect, cornerRadius: rect.height * 0.22)
            case .airbrush, .ink, .pencil:
                return Path(ellipseIn: rect)
            }
        }()

        let transformed = path
            .applying(CGAffineTransform(translationX: -rect.midX, y: -rect.midY))
            .applying(CGAffineTransform(rotationAngle: angle))
            .applying(CGAffineTransform(translationX: rect.midX, y: rect.midY))

        if style.tipKind == .airbrush {
            let glowRect = rect.insetBy(dx: -diameter * 0.18, dy: -diameter * 0.18)
            let glowPath = Path(ellipseIn: glowRect)
                .applying(CGAffineTransform(translationX: -rect.midX, y: -rect.midY))
                .applying(CGAffineTransform(rotationAngle: angle))
                .applying(CGAffineTransform(translationX: rect.midX, y: rect.midY))
            context.fill(glowPath, with: .color(style.color.opacity(alpha * max(0.12, 1.0 - style.hardness) * 0.35)))
        }

        context.fill(transformed, with: .color(style.color.opacity(alpha)))
    }

    private func previewStampSize(for diameter: Double) -> CGSize {
        if let customTip = style.customTip, customTip.width > 0, customTip.height > 0 {
            let aspectRatio = Double(customTip.height) / Double(customTip.width)
            return CGSize(width: diameter, height: max(diameter * aspectRatio, 1.0))
        }
        return CGSize(width: diameter, height: max(diameter * style.roundness, diameter * 0.2))
    }

    private func scatterOffset(seed: Double, baseDiameter: Double) -> CGSize {
        guard style.scatterEnabled else { return .zero }
        let lateral = signedNoise(seed * 0.23 + 0.2) * style.scatterLateral * baseDiameter * 1.8
        let linear = signedNoise(seed * 0.19 + 1.1) * style.scatterLinear * baseDiameter * (style.scatterMode == .spray ? 1.8 : 1.0)
        if style.scatterMode == .spray {
            return CGSize(width: lateral, height: linear)
        }
        return CGSize(width: linear, height: lateral)
    }

    private func previewStampAlpha(pressure: Double, opacityJitter: Double) -> Double {
        let base = min(max(style.opacity, 0.04), 1.0)
        let flow = min(max(style.flow, 0.04), 1.0)
        let hardnessBias = 0.55 + (style.hardness * 0.45)
        let opacityPressure = max(0.2, 1.0 - style.opacityPressureSensitivity + (style.opacityPressureSensitivity * pressure))
        let flowPressure = max(0.2, 1.0 - style.flowPressureSensitivity + (style.flowPressureSensitivity * pressure))
        return min(max(base * flow * hardnessBias * 0.55 * opacityPressure * flowPressure * opacityJitter, 0.02), 1.0)
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
}
