import CoreGraphics
import Foundation
import PrimoDocumentContracts

public enum SwiftDocumentLayerProcessing {
    struct GradientStop {
        let position: Double
        let red: UInt8
        let green: UInt8
        let blue: UInt8
    }

    public static func apply(
        _ request: LayerProcessingRequest,
        to source: Data,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> Data? {
        switch request {
        case let .gradientMap(preset):
            return gradientMappedLayerPixels(source: source, preset: preset)
        case let .hueSaturationBrightness(settings):
            return hueSaturationBrightnessAdjustedLayerPixels(source: source, settings: settings)
        case let .brightnessContrast(settings):
            return brightnessContrastAdjustedLayerPixels(source: source, settings: settings)
        case let .levels(settings):
            return levelsAdjustedLayerPixels(source: source, settings: settings)
        case let .toneCurve(settings):
            return toneCurveAdjustedLayerPixels(source: source, settings: settings)
        case let .colorBalance(settings):
            return colorBalanceAdjustedLayerPixels(source: source, settings: settings)
        case let .threshold(settings):
            return thresholdAdjustedLayerPixels(source: source, settings: settings)
        case let .posterize(settings):
            return posterizedLayerPixels(source: source, settings: settings)
        case let .transform(translation, scale, rotationDegrees, selection):
            return transformedLayerPixels(
                source: source,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                translation: translation,
                scale: scale,
                rotationDegrees: rotationDegrees,
                selection: selection
            )
        }
    }

    private static func gradientMappedLayerPixels(source: Data, preset: GradientMapPreset) -> Data? {
        gradientMappedLayerPixels(source: source, stops: gradientMapStops(for: preset))
    }

    private static func gradientMappedLayerPixels(source: Data, stops: [GradientStop]) -> Data? {
        guard source.count.isMultiple(of: 4), stops.count >= 2 else { return nil }
        var output = [UInt8](source)
        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            let alpha = output[pixelOffset + 3]
            guard alpha > 0 else { continue }
            let red = Double(output[pixelOffset]) / 255.0
            let green = Double(output[pixelOffset + 1]) / 255.0
            let blue = Double(output[pixelOffset + 2]) / 255.0
            let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
            let mapped = mappedGradientColor(for: luminance, stops: stops)
            output[pixelOffset] = mapped.red
            output[pixelOffset + 1] = mapped.green
            output[pixelOffset + 2] = mapped.blue
        }
        return Data(output)
    }

    private static func hueSaturationBrightnessAdjustedLayerPixels(source: Data, settings: HueSaturationBrightnessSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        var output = [UInt8](source)
        let hueShift = settings.hueDegrees / 360.0
        let saturationScale = max(0, settings.saturation)
        let brightnessOffset = settings.brightness

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }
            var hsv = rgbToHSV(
                red: Double(output[pixelOffset]) / 255.0,
                green: Double(output[pixelOffset + 1]) / 255.0,
                blue: Double(output[pixelOffset + 2]) / 255.0
            )
            hsv.hue.formTruncatingRemainder(dividingBy: 1.0)
            hsv.hue += hueShift
            if hsv.hue < 0 {
                hsv.hue += 1
            } else if hsv.hue > 1 {
                hsv.hue -= floor(hsv.hue)
            }
            hsv.saturation = min(max(hsv.saturation * saturationScale, 0), 1)
            hsv.value = min(max(hsv.value + brightnessOffset, 0), 1)
            let rgb = hsvToRGB(hue: hsv.hue, saturation: hsv.saturation, value: hsv.value)
            output[pixelOffset] = UInt8(clamp255(rgb.red * 255.0))
            output[pixelOffset + 1] = UInt8(clamp255(rgb.green * 255.0))
            output[pixelOffset + 2] = UInt8(clamp255(rgb.blue * 255.0))
        }

        return Data(output)
    }

    private static func brightnessContrastAdjustedLayerPixels(source: Data, settings: BrightnessContrastSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        var output = [UInt8](source)
        let contrast = max(0, settings.contrast)
        let brightnessOffset = settings.brightness

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }
            let red = ((((Double(output[pixelOffset]) / 255.0) - 0.5) * contrast) + 0.5) + brightnessOffset
            let green = ((((Double(output[pixelOffset + 1]) / 255.0) - 0.5) * contrast) + 0.5) + brightnessOffset
            let blue = ((((Double(output[pixelOffset + 2]) / 255.0) - 0.5) * contrast) + 0.5) + brightnessOffset
            output[pixelOffset] = UInt8(clamp255(red * 255.0))
            output[pixelOffset + 1] = UInt8(clamp255(green * 255.0))
            output[pixelOffset + 2] = UInt8(clamp255(blue * 255.0))
        }

        return Data(output)
    }

    private static func levelsAdjustedLayerPixels(source: Data, settings: LevelsAdjustmentSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        let inputBlack = min(max(settings.inputBlack, 0), 1)
        let inputWhite = max(min(settings.inputWhite, 1), inputBlack + 0.001)
        let gamma = max(settings.gamma, 0.01)
        let outputBlack = min(max(settings.outputBlack, 0), 1)
        let outputWhite = max(min(settings.outputWhite, 1), outputBlack)
        var output = [UInt8](source)

        func map(_ value: Double) -> UInt8 {
            let normalized = min(max((value - inputBlack) / (inputWhite - inputBlack), 0), 1)
            let gammaCorrected = pow(normalized, 1.0 / gamma)
            let remapped = outputBlack + ((outputWhite - outputBlack) * gammaCorrected)
            return UInt8(clamp255(remapped * 255.0))
        }

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }
            output[pixelOffset] = map(Double(output[pixelOffset]) / 255.0)
            output[pixelOffset + 1] = map(Double(output[pixelOffset + 1]) / 255.0)
            output[pixelOffset + 2] = map(Double(output[pixelOffset + 2]) / 255.0)
        }
        return Data(output)
    }

    private static func toneCurveAdjustedLayerPixels(source: Data, settings: ToneCurveSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        var output = [UInt8](source)

        func map(_ value: Double) -> UInt8 {
            let shadowWeight = pow(1.0 - value, 2.0)
            let highlightWeight = pow(value, 2.0)
            let midtoneWeight = max(0, 1.0 - abs((value * 2.0) - 1.0))
            let offset = (settings.shadows * shadowWeight) + (settings.midtones * midtoneWeight) + (settings.highlights * highlightWeight)
            let adjusted = min(max(value + (offset * 0.35), 0), 1)
            return UInt8(clamp255(adjusted * 255.0))
        }

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }
            output[pixelOffset] = map(Double(output[pixelOffset]) / 255.0)
            output[pixelOffset + 1] = map(Double(output[pixelOffset + 1]) / 255.0)
            output[pixelOffset + 2] = map(Double(output[pixelOffset + 2]) / 255.0)
        }
        return Data(output)
    }

    private static func colorBalanceAdjustedLayerPixels(source: Data, settings: ColorBalanceSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        var output = [UInt8](source)
        let redOffset = settings.redCyan * 0.4
        let greenOffset = settings.greenMagenta * 0.4
        let blueOffset = settings.blueYellow * 0.4

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }
            output[pixelOffset] = UInt8(clamp255((min(max((Double(output[pixelOffset]) / 255.0) + redOffset, 0), 1)) * 255.0))
            output[pixelOffset + 1] = UInt8(clamp255((min(max((Double(output[pixelOffset + 1]) / 255.0) + greenOffset, 0), 1)) * 255.0))
            output[pixelOffset + 2] = UInt8(clamp255((min(max((Double(output[pixelOffset + 2]) / 255.0) + blueOffset, 0), 1)) * 255.0))
        }
        return Data(output)
    }

    private static func thresholdAdjustedLayerPixels(source: Data, settings: ThresholdSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        let threshold = min(max(settings.threshold, 0), 1)
        var output = [UInt8](source)
        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }
            let red = Double(output[pixelOffset]) / 255.0
            let green = Double(output[pixelOffset + 1]) / 255.0
            let blue = Double(output[pixelOffset + 2]) / 255.0
            let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
            let mapped: UInt8 = luminance >= threshold ? 255 : 0
            output[pixelOffset] = mapped
            output[pixelOffset + 1] = mapped
            output[pixelOffset + 2] = mapped
        }
        return Data(output)
    }

    private static func posterizedLayerPixels(source: Data, settings: PosterizeSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        let steps = max(Int(settings.levels.rounded()), 2)
        let denominator = Double(steps - 1)
        var output = [UInt8](source)

        func map(_ value: UInt8) -> UInt8 {
            let normalized = Double(value) / 255.0
            let quantized = (normalized * denominator).rounded() / denominator
            return UInt8(clamp255(quantized * 255.0))
        }

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }
            output[pixelOffset] = map(output[pixelOffset])
            output[pixelOffset + 1] = map(output[pixelOffset + 1])
            output[pixelOffset + 2] = map(output[pixelOffset + 2])
        }
        return Data(output)
    }

    private static func transformedLayerPixels(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        translation: CGSize,
        scale: CGFloat,
        rotationDegrees: Double,
        selection: CanvasSelection?
    ) -> Data? {
        guard source.count == canvasWidth * canvasHeight * 4 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let sourceImage = cgImage(from: source, width: canvasWidth, height: canvasHeight) else { return nil }

        var outputBytes = selection == nil ? [UInt8](repeating: 0, count: source.count) : [UInt8](source)
        if let selection,
           selection.maskWidth == canvasWidth,
           selection.maskHeight == canvasHeight,
           !selection.maskData.isEmpty {
            selection.maskData.withUnsafeBytes { maskBytes in
                guard let maskBase = maskBytes.bindMemory(to: UInt8.self).baseAddress else { return }
                for pixelIndex in 0..<(canvasWidth * canvasHeight) where maskBase[pixelIndex] > 0 {
                    let offset = pixelIndex * 4
                    outputBytes[offset] = 0
                    outputBytes[offset + 1] = 0
                    outputBytes[offset + 2] = 0
                    outputBytes[offset + 3] = 0
                }
            }
        }

        guard let context = CGContext(
            data: &outputBytes,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: canvasWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        let pivot = selection?.bounds.center ?? CGPoint(x: CGFloat(canvasWidth) * 0.5, y: CGFloat(canvasHeight) * 0.5)
        context.saveGState()
        context.translateBy(x: pivot.x + translation.width, y: pivot.y + translation.height)
        context.scaleBy(x: scale, y: scale)
        context.rotate(by: CGFloat(rotationDegrees * .pi / 180.0))
        context.translateBy(x: -pivot.x, y: -pivot.y)
        if let selection,
           let maskImage = maskImage(from: selection.maskData, width: selection.maskWidth, height: selection.maskHeight) {
            context.clip(to: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight), mask: maskImage)
        }
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        context.restoreGState()
        return Data(outputBytes)
    }

    private static func cgImage(from pixelData: Data, width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: pixelData as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static func maskImage(from data: Data, width: Int, height: Int) -> CGImage? {
        guard data.count == width * height else { return nil }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            maskWidth: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            provider: provider,
            decode: nil,
            shouldInterpolate: false
        )
    }

    private static func gradientMapStops(for preset: GradientMapPreset) -> [GradientStop] {
        switch preset {
        case .graphite:
            return [
                GradientStop(position: 0.0, red: 17, green: 21, blue: 27),
                GradientStop(position: 0.38, red: 84, green: 93, blue: 108),
                GradientStop(position: 1.0, red: 243, green: 244, blue: 246)
            ]
        case .sepia:
            return [
                GradientStop(position: 0.0, red: 28, green: 17, blue: 12),
                GradientStop(position: 0.42, red: 123, green: 74, blue: 40),
                GradientStop(position: 1.0, red: 241, green: 220, blue: 184)
            ]
        case .ocean:
            return [
                GradientStop(position: 0.0, red: 8, green: 19, blue: 44),
                GradientStop(position: 0.45, red: 27, green: 110, blue: 171),
                GradientStop(position: 1.0, red: 192, green: 241, blue: 255)
            ]
        case .sunset:
            return [
                GradientStop(position: 0.0, red: 36, green: 11, blue: 54),
                GradientStop(position: 0.4, red: 173, green: 58, blue: 91),
                GradientStop(position: 0.72, red: 244, green: 142, blue: 68),
                GradientStop(position: 1.0, red: 255, green: 223, blue: 128)
            ]
        case .toxic:
            return [
                GradientStop(position: 0.0, red: 4, green: 23, blue: 18),
                GradientStop(position: 0.44, red: 35, green: 172, blue: 106),
                GradientStop(position: 1.0, red: 227, green: 255, blue: 111)
            ]
        }
    }

    private static func mappedGradientColor(for value: Double, stops: [GradientStop]) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let clampedValue = min(max(value, 0.0), 1.0)
        guard let upperIndex = stops.firstIndex(where: { clampedValue <= $0.position }) else {
            let last = stops[stops.count - 1]
            return (last.red, last.green, last.blue)
        }
        if upperIndex == 0 {
            let first = stops[0]
            return (first.red, first.green, first.blue)
        }

        let lower = stops[upperIndex - 1]
        let upper = stops[upperIndex]
        let span = max(upper.position - lower.position, 0.0001)
        let t = (clampedValue - lower.position) / span

        func mix(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8(clamp255(Double(a) + ((Double(b) - Double(a)) * t)))
        }

        return (
            red: mix(lower.red, upper.red),
            green: mix(lower.green, upper.green),
            blue: mix(lower.blue, upper.blue)
        )
    }

    private static func rgbToHSV(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double, value: Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue

        let hue: Double
        if delta < 0.000001 {
            hue = 0
        } else if maxValue == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6.0) / 6.0
        } else if maxValue == green {
            hue = (((blue - red) / delta) + 2.0) / 6.0
        } else {
            hue = (((red - green) / delta) + 4.0) / 6.0
        }

        let normalizedHue = hue < 0 ? hue + 1.0 : hue
        let saturation = maxValue <= 0 ? 0 : delta / maxValue
        return (normalizedHue, saturation, maxValue)
    }

    private static func hsvToRGB(hue: Double, saturation: Double, value: Double) -> (red: Double, green: Double, blue: Double) {
        guard saturation > 0.000001 else { return (value, value, value) }
        let scaledHue = (hue - floor(hue)) * 6.0
        let sector = Int(floor(scaledHue))
        let fraction = scaledHue - Double(sector)
        let p = value * (1 - saturation)
        let q = value * (1 - (saturation * fraction))
        let t = value * (1 - (saturation * (1 - fraction)))

        switch sector {
        case 0: return (value, t, p)
        case 1: return (q, value, p)
        case 2: return (p, value, t)
        case 3: return (p, q, value)
        case 4: return (t, p, value)
        default: return (value, p, q)
        }
    }

    private static func clamp255(_ value: Double) -> Int {
        max(0, min(255, Int(value.rounded())))
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
