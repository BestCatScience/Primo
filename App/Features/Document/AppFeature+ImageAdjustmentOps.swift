import Foundation
import PrimoDocumentContracts

extension AppFeature {
    struct GradientMapStop {
        var position: Double
        var red: UInt8
        var green: UInt8
        var blue: UInt8
    }

    static func gradientMappedLayerPixels(source: Data, preset: GradientMapPreset) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        let stops = gradientMapStops(for: preset)
        return gradientMappedLayerPixels(source: source, stops: stops)
    }

    static func gradientMappedLayerPixels(source: Data, settings: GradientMapSettings) -> Data? {
        gradientMappedLayerPixels(source: source, stops: gradientMapStops(for: settings))
    }

    static func gradientMappedLayerPixels(source: Data, stops: [GradientMapStop]) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        guard stops.count >= 2 else { return nil }

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

    static func hueSaturationBrightnessAdjustedLayerPixels(source: Data, settings: HueSaturationBrightnessSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        var output = [UInt8](source)
        let hueShift = settings.hueDegrees / 360.0
        let saturationScale = max(0, settings.saturation)
        let brightnessOffset = settings.brightness

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            let alpha = output[pixelOffset + 3]
            guard alpha > 0 else { continue }

            var red = Double(output[pixelOffset]) / 255.0
            var green = Double(output[pixelOffset + 1]) / 255.0
            var blue = Double(output[pixelOffset + 2]) / 255.0

            var hsv = rgbToHSV(red: red, green: green, blue: blue)
            hsv.hue.formTruncatingRemainder(dividingBy: 1.0)
            hsv.hue = hsv.hue + hueShift
            if hsv.hue < 0 {
                hsv.hue += 1
            } else if hsv.hue > 1 {
                hsv.hue -= floor(hsv.hue)
            }
            hsv.saturation = min(max(hsv.saturation * saturationScale, 0), 1)
            hsv.value = min(max(hsv.value + brightnessOffset, 0), 1)

            let rgb = hsvToRGB(hue: hsv.hue, saturation: hsv.saturation, value: hsv.value)
            red = rgb.red
            green = rgb.green
            blue = rgb.blue

            output[pixelOffset] = UInt8(max(0, min(255, Int((min(max(red, 0), 1) * 255.0).rounded()))))
            output[pixelOffset + 1] = UInt8(max(0, min(255, Int((min(max(green, 0), 1) * 255.0).rounded()))))
            output[pixelOffset + 2] = UInt8(max(0, min(255, Int((min(max(blue, 0), 1) * 255.0).rounded()))))
        }

        return Data(output)
    }

    static func brightnessContrastAdjustedLayerPixels(source: Data, settings: BrightnessContrastSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        var output = [UInt8](source)
        let contrast = max(0, settings.contrast)
        let brightnessOffset = settings.brightness

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            let alpha = output[pixelOffset + 3]
            guard alpha > 0 else { continue }

            var red = Double(output[pixelOffset]) / 255.0
            var green = Double(output[pixelOffset + 1]) / 255.0
            var blue = Double(output[pixelOffset + 2]) / 255.0

            red = (((red - 0.5) * contrast) + 0.5) + brightnessOffset
            green = (((green - 0.5) * contrast) + 0.5) + brightnessOffset
            blue = (((blue - 0.5) * contrast) + 0.5) + brightnessOffset

            output[pixelOffset] = UInt8(max(0, min(255, Int((min(max(red, 0), 1) * 255.0).rounded()))))
            output[pixelOffset + 1] = UInt8(max(0, min(255, Int((min(max(green, 0), 1) * 255.0).rounded()))))
            output[pixelOffset + 2] = UInt8(max(0, min(255, Int((min(max(blue, 0), 1) * 255.0).rounded()))))
        }

        return Data(output)
    }

    static func levelsAdjustedLayerPixels(source: Data, settings: LevelsAdjustmentSettings) -> Data? {
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
            return UInt8(max(0, min(255, Int((remapped * 255.0).rounded()))))
        }

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }
            output[pixelOffset] = map(Double(output[pixelOffset]) / 255.0)
            output[pixelOffset + 1] = map(Double(output[pixelOffset + 1]) / 255.0)
            output[pixelOffset + 2] = map(Double(output[pixelOffset + 2]) / 255.0)
        }

        return Data(output)
    }

    static func toneCurveAdjustedLayerPixels(source: Data, settings: ToneCurveSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        var output = [UInt8](source)

        func map(_ value: Double) -> UInt8 {
            let shadowWeight = pow(1.0 - value, 2.0)
            let highlightWeight = pow(value, 2.0)
            let midtoneWeight = max(0, 1.0 - abs((value * 2.0) - 1.0))
            let offset = (settings.shadows * shadowWeight) + (settings.midtones * midtoneWeight) + (settings.highlights * highlightWeight)
            let adjusted = min(max(value + (offset * 0.35), 0), 1)
            return UInt8(max(0, min(255, Int((adjusted * 255.0).rounded()))))
        }

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }
            output[pixelOffset] = map(Double(output[pixelOffset]) / 255.0)
            output[pixelOffset + 1] = map(Double(output[pixelOffset + 1]) / 255.0)
            output[pixelOffset + 2] = map(Double(output[pixelOffset + 2]) / 255.0)
        }

        return Data(output)
    }

    static func colorBalanceAdjustedLayerPixels(source: Data, settings: ColorBalanceSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        var output = [UInt8](source)
        let redOffset = settings.redCyan * 0.4
        let greenOffset = settings.greenMagenta * 0.4
        let blueOffset = settings.blueYellow * 0.4

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }

            let red = min(max((Double(output[pixelOffset]) / 255.0) + redOffset, 0), 1)
            let green = min(max((Double(output[pixelOffset + 1]) / 255.0) + greenOffset, 0), 1)
            let blue = min(max((Double(output[pixelOffset + 2]) / 255.0) + blueOffset, 0), 1)

            output[pixelOffset] = UInt8((red * 255.0).rounded())
            output[pixelOffset + 1] = UInt8((green * 255.0).rounded())
            output[pixelOffset + 2] = UInt8((blue * 255.0).rounded())
        }

        return Data(output)
    }

    static func thresholdAdjustedLayerPixels(source: Data, settings: ThresholdSettings) -> Data? {
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

    static func posterizedLayerPixels(source: Data, settings: PosterizeSettings) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        let steps = max(Int(settings.levels.rounded()), 2)
        let denominator = Double(steps - 1)
        var output = [UInt8](source)

        func map(_ value: UInt8) -> UInt8 {
            let normalized = Double(value) / 255.0
            let quantized = (normalized * denominator).rounded() / denominator
            return UInt8(max(0, min(255, Int((quantized * 255.0).rounded()))))
        }

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            guard output[pixelOffset + 3] > 0 else { continue }
            output[pixelOffset] = map(output[pixelOffset])
            output[pixelOffset + 1] = map(output[pixelOffset + 1])
            output[pixelOffset + 2] = map(output[pixelOffset + 2])
        }

        return Data(output)
    }

    static func luminanceToAlphaLayerPixels(source: Data) -> Data? {
        guard source.count.isMultiple(of: 4) else { return nil }
        var output = [UInt8](source)

        for pixelOffset in stride(from: 0, to: output.count, by: 4) {
            let existingAlpha = Double(output[pixelOffset + 3]) / 255.0
            guard existingAlpha > 0 else { continue }

            let red = Double(output[pixelOffset]) / 255.0
            let green = Double(output[pixelOffset + 1]) / 255.0
            let blue = Double(output[pixelOffset + 2]) / 255.0
            let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
            let alpha = existingAlpha * (1.0 - luminance)

            output[pixelOffset] = 0
            output[pixelOffset + 1] = 0
            output[pixelOffset + 2] = 0
            output[pixelOffset + 3] = UInt8(max(0, min(255, Int((alpha * 255.0).rounded()))))
        }

        return Data(output)
    }

    static func gradientMapStops(for preset: GradientMapPreset) -> [GradientMapStop] {
        switch preset {
        case .graphite:
            return [
                GradientMapStop(position: 0.0, red: 17, green: 21, blue: 27),
                GradientMapStop(position: 0.38, red: 84, green: 93, blue: 108),
                GradientMapStop(position: 1.0, red: 243, green: 244, blue: 246)
            ]
        case .sepia:
            return [
                GradientMapStop(position: 0.0, red: 28, green: 17, blue: 12),
                GradientMapStop(position: 0.42, red: 123, green: 74, blue: 40),
                GradientMapStop(position: 1.0, red: 241, green: 220, blue: 184)
            ]
        case .ocean:
            return [
                GradientMapStop(position: 0.0, red: 8, green: 19, blue: 44),
                GradientMapStop(position: 0.45, red: 27, green: 110, blue: 171),
                GradientMapStop(position: 1.0, red: 192, green: 241, blue: 255)
            ]
        case .sunset:
            return [
                GradientMapStop(position: 0.0, red: 36, green: 11, blue: 54),
                GradientMapStop(position: 0.4, red: 173, green: 58, blue: 91),
                GradientMapStop(position: 0.72, red: 244, green: 142, blue: 68),
                GradientMapStop(position: 1.0, red: 255, green: 223, blue: 128)
            ]
        case .toxic:
            return [
                GradientMapStop(position: 0.0, red: 4, green: 23, blue: 18),
                GradientMapStop(position: 0.44, red: 35, green: 172, blue: 106),
                GradientMapStop(position: 1.0, red: 227, green: 255, blue: 111)
            ]
        }
    }

    static func gradientMapStops(for settings: GradientMapSettings) -> [GradientMapStop] {
        normalizeGradientMapSettings(settings).stops.map {
            GradientMapStop(
                position: $0.position,
                red: $0.red,
                green: $0.green,
                blue: $0.blue
            )
        }
    }

    static func gradientMapSettings(for preset: GradientMapPreset) -> GradientMapSettings {
        let stops = gradientMapStops(for: preset)
        return GradientMapSettings(
            stops: stops.map {
                GradientMapStopSettings(
                    position: $0.position,
                    red: $0.red,
                    green: $0.green,
                    blue: $0.blue
                )
            }
        )
    }

    static func normalizeGradientMapSettings(_ settings: GradientMapSettings) -> GradientMapSettings {
        var sortedStops = settings.stops.sorted { $0.position < $1.position }

        if sortedStops.count < 2 {
            sortedStops = [
                GradientMapStopSettings(position: 0.0, red: 0, green: 0, blue: 0),
                GradientMapStopSettings(position: 1.0, red: 255, green: 255, blue: 255)
            ]
        }

        for index in sortedStops.indices {
            sortedStops[index].position = min(max(sortedStops[index].position, 0.0), 1.0)
        }

        sortedStops[0].position = 0.0
        sortedStops[sortedStops.count - 1].position = 1.0

        if sortedStops.count > 2 {
            for index in 1..<(sortedStops.count - 1) {
                let lowerBound = sortedStops[index - 1].position + 0.01
                let upperBound = sortedStops[index + 1].position - 0.01
                sortedStops[index].position = min(max(sortedStops[index].position, lowerBound), upperBound)
            }
        }

        return GradientMapSettings(stops: sortedStops)
    }

    static func mappedGradientColor(for value: Double, stops: [GradientMapStop]) -> (red: UInt8, green: UInt8, blue: UInt8) {
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
            UInt8(max(0, min(255, Int((Double(a) + ((Double(b) - Double(a)) * t)).rounded()))))
        }

        return (
            red: mix(lower.red, upper.red),
            green: mix(lower.green, upper.green),
            blue: mix(lower.blue, upper.blue)
        )
    }

    static func rgbToHSV(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double, value: Double) {
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

    static func hsvToRGB(hue: Double, saturation: Double, value: Double) -> (red: Double, green: Double, blue: Double) {
        guard saturation > 0.000001 else {
            return (value, value, value)
        }

        let scaledHue = (hue - floor(hue)) * 6.0
        let sector = Int(floor(scaledHue))
        let fraction = scaledHue - Double(sector)
        let p = value * (1 - saturation)
        let q = value * (1 - (saturation * fraction))
        let t = value * (1 - (saturation * (1 - fraction)))

        switch sector {
        case 0:
            return (value, t, p)
        case 1:
            return (q, value, p)
        case 2:
            return (p, value, t)
        case 3:
            return (p, q, value)
        case 4:
            return (t, p, value)
        default:
            return (value, p, q)
        }
    }
}
