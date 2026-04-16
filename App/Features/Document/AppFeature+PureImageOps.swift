import ComposableArchitecture
import CoreGraphics
import Foundation
import SwiftUI
import UIKit

extension AppFeature {
    struct InpaintCrop: Sendable {
        let pixelData: Data
        let width: Int
        let height: Int
        let originX: Int
        let originY: Int
        let selectionMask: [UInt8]
    }

    struct GradientMapStop {
        var position: Double
        var red: UInt8
        var green: UInt8
        var blue: UInt8
    }

    private struct RasterizedSmudgeSample {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
        var alpha: CGFloat
    }

    static func clampUnit(_ value: CGFloat) -> CGFloat {
        max(0, min(1, value))
    }

    static func interpolate(_ from: CGFloat, _ to: CGFloat, amount: CGFloat) -> CGFloat {
        from + ((to - from) * amount)
    }

    static func rasterizedLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }

    static func color(from sampledColor: SampledColor) -> Color {
        Color(
            red: Double(sampledColor.red) / 255.0,
            green: Double(sampledColor.green) / 255.0,
            blue: Double(sampledColor.blue) / 255.0,
            opacity: Double(sampledColor.alpha) / 255.0
        )
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

    static func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        guard adjustedActiveLayerPixels.count == snapshot.width * snapshot.height * 4 else { return nil }

        var composite = Data(count: snapshot.width * snapshot.height * 4)
        var clipMask = [CGFloat](repeating: 0, count: snapshot.width * snapshot.height)
        composite.withUnsafeMutableBytes { destinationBytes in
            guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for layer in snapshot.layers.sorted(by: { $0.index < $1.index }) where layer.visible {
                let sourceData = layer.index == activeLayerIndex ? adjustedActiveLayerPixels : layer.pixelData
                sourceData.withUnsafeBytes { sourceBytes in
                    guard let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    for pixelIndex in 0..<(snapshot.width * snapshot.height) {
                        let offset = pixelIndex * 4
                        let baseAlpha = (CGFloat(source[offset + 3]) / 255.0) * CGFloat(layer.opacity)
                        let effectiveOpacity = layer.isClipped
                            ? (CGFloat(layer.opacity) * clipMask[pixelIndex])
                            : CGFloat(layer.opacity)
                        if !layer.isClipped {
                            clipMask[pixelIndex] = baseAlpha
                        }
                        blendPreviewPixel(
                            destination: destination + offset,
                            source: source + offset,
                            opacity: effectiveOpacity,
                            blendMode: layer.blendMode
                        )
                    }
                }
            }
        }
        return composite
    }

    static func strokePreviewDirtyRect(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (originX: Int, originY: Int, width: Int, height: Int)? {
        guard !samples.isEmpty, canvasWidth > 0, canvasHeight > 0 else { return nil }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        let scatterExtent = brush.scatterEnabled ? max(CGFloat(brush.scatterLateral), CGFloat(brush.scatterLinear)) : 0
        let softness = max(0, 1.0 - CGFloat(brush.hardness))
        let featherPadding = max(
            brush.tipKind == .airbrush ? CGFloat(brush.radius) * (0.9 + softness * 0.6) : CGFloat(brush.radius) * (0.35 + softness * 0.75),
            brush.tipKind == .airbrush ? 18.0 : 10.0
        )

        for sample in samples {
            let pressureFactor = max(
                0.1,
                1.0 + ((sample.pressure - 1.0) * CGFloat(brush.pressureSensitivity))
            )
            let radiusPadding = max(CGFloat(brush.radius) * pressureFactor, 1.5)
                + (scatterExtent * CGFloat(brush.radius))
                + featherPadding
                + 6.0
            minX = min(minX, sample.point.x - radiusPadding)
            minY = min(minY, sample.point.y - radiusPadding)
            maxX = max(maxX, sample.point.x + radiusPadding)
            maxY = max(maxY, sample.point.y + radiusPadding)
        }

        guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite else { return nil }
        let originX = max(0, Int(floor(minX)))
        let originY = max(0, Int(floor(minY)))
        let maxRectX = min(canvasWidth - 1, Int(ceil(maxX)))
        let maxRectY = min(canvasHeight - 1, Int(ceil(maxY)))
        guard maxRectX >= originX, maxRectY >= originY else { return nil }
        return (
            originX: originX,
            originY: originY,
            width: maxRectX - originX + 1,
            height: maxRectY - originY + 1
        )
    }

    static func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        guard adjustedActiveLayerPixels.count == snapshot.width * snapshot.height * 4 else { return nil }
        guard dirtyRect.width > 0, dirtyRect.height > 0 else { return nil }

        let rectDataCount = dirtyRect.width * dirtyRect.height * 4
        var composite = Data(count: rectDataCount)
        var clipMask = [CGFloat](repeating: 0, count: dirtyRect.width * dirtyRect.height)
        composite.withUnsafeMutableBytes { destinationBytes in
            guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for layer in snapshot.layers.sorted(by: { $0.index < $1.index }) {
                let isActiveLayer = layer.index == activeLayerIndex
                guard isActiveLayer || layer.visible else { continue }
                let sourceData = isActiveLayer ? adjustedActiveLayerPixels : layer.pixelData
                sourceData.withUnsafeBytes { sourceBytes in
                    guard let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    for localY in 0..<dirtyRect.height {
                        let sourceY = dirtyRect.originY + localY
                        for localX in 0..<dirtyRect.width {
                            let sourceX = dirtyRect.originX + localX
                            let sourceOffset = ((sourceY * snapshot.width) + sourceX) * 4
                            let destinationOffset = ((localY * dirtyRect.width) + localX) * 4
                            let maskIndex = (localY * dirtyRect.width) + localX
                            let baseAlpha = (CGFloat(source[sourceOffset + 3]) / 255.0) * CGFloat(layer.opacity)
                            let effectiveOpacity = layer.isClipped
                                ? (CGFloat(layer.opacity) * clipMask[maskIndex])
                                : CGFloat(layer.opacity)
                            if !layer.isClipped {
                                clipMask[maskIndex] = baseAlpha
                            }
                            blendPreviewPixel(
                                destination: destination + destinationOffset,
                                source: source + sourceOffset,
                                opacity: effectiveOpacity,
                                blendMode: layer.blendMode
                            )
                        }
                    }
                }
            }
        }

        return IncrementalLayerUpdate(
            layerIndex: -1,
            originX: dirtyRect.originX,
            originY: dirtyRect.originY,
            width: dirtyRect.width,
            height: dirtyRect.height,
            pixelData: composite
        )
    }

    static func shouldUseIncrementalPreviewUpdate(for brush: BrushRuntimeSettings) -> Bool {
        let scatterExtent = brush.scatterEnabled ? max(CGFloat(brush.scatterLateral), CGFloat(brush.scatterLinear)) : 0
        let effectiveDiameter = (CGFloat(brush.radius) * 2.0) * (1.0 + scatterExtent)
        let softness = 1.0 - CGFloat(brush.hardness)

        if brush.tipKind == .airbrush && effectiveDiameter >= 42 {
            return false
        }
        if softness >= 0.34 && effectiveDiameter >= 56 {
            return false
        }
        return true
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

    static func normalizedCommittedStrokeSamples(
        _ samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> [StylusSample] {
        var normalized = samples.map { sample in
            StylusSample(
                point: CGPoint(
                    x: sample.point.x.isFinite ? sample.point.x : 0,
                    y: sample.point.y.isFinite ? sample.point.y : 0
                ),
                pressure: sample.pressure.isFinite ? sample.pressure : 1.0,
                altitude: sample.altitude.isFinite ? sample.altitude : .pi / 2,
                azimuth: sample.azimuth.isFinite ? sample.azimuth : 0,
                timestamp: sample.timestamp.isFinite ? sample.timestamp : 0
            )
        }
        guard normalized.count > 1 else { return normalized }

        let jumpThreshold = max(CGFloat(brush.radius) * 8.0, 24.0)
        while normalized.count > 1 {
            let last = normalized[normalized.count - 1]
            let previous = normalized[normalized.count - 2]
            let dx = last.point.x - previous.point.x
            let dy = last.point.y - previous.point.y
            let distance = sqrt((dx * dx) + (dy * dy))
            let pressureDropThreshold = max(0.08, previous.pressure * 0.5)
            let isTrailingJump = distance > jumpThreshold && last.pressure < pressureDropThreshold
            if !isTrailingJump {
                break
            }
            normalized.removeLast()
        }

        var deduplicated: [StylusSample] = []
        deduplicated.reserveCapacity(normalized.count)
        for sample in normalized {
            if let previous = deduplicated.last {
                let dx = sample.point.x - previous.point.x
                let dy = sample.point.y - previous.point.y
                let distance = sqrt((dx * dx) + (dy * dy))
                let pressureDelta = abs(sample.pressure - previous.pressure)
                if distance < 0.001, pressureDelta < 0.001 {
                    continue
                }
            }
            deduplicated.append(sample)
        }
        guard deduplicated.count > 1 else { return deduplicated }

        return deduplicated
    }

    static func strokeTaperScale(progress: CGFloat, taperIn: CGFloat, taperOut: CGFloat) -> CGFloat {
        func easedRamp(_ progress: CGFloat, length: CGFloat) -> CGFloat {
            guard length > 0.001 else { return 1.0 }
            let t = max(0.0, min(1.0, progress / length))
            let eased = t * t * (3.0 - (2.0 * t))
            return 0.08 + (0.92 * eased)
        }

        let entry = easedRamp(progress, length: taperIn)
        let exit = easedRamp(1.0 - progress, length: taperOut)
        return min(entry, exit)
    }

    static func strokeProgressTable(_ samples: [StylusSample]) -> [CGFloat] {
        guard !samples.isEmpty else { return [] }
        guard samples.count > 1 else { return [0] }

        var cumulative: [CGFloat] = [0]
        cumulative.reserveCapacity(samples.count)
        var totalLength: CGFloat = 0
        for pair in zip(samples, samples.dropFirst()) {
            let dx = pair.1.point.x - pair.0.point.x
            let dy = pair.1.point.y - pair.0.point.y
            totalLength += sqrt((dx * dx) + (dy * dy))
            cumulative.append(totalLength)
        }

        guard totalLength > 0.001 else {
            return Array(repeating: 0, count: samples.count)
        }

        return cumulative.map { $0 / totalLength }
    }

    static func layerPixelDataByApplyingCommittedShortStroke(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool = false
    ) -> Data? {
        guard shouldRasterizeCommittedShortStroke(samples, brush: brush) else { return nil }
        guard
            let snapshot,
            let layer = snapshot.layers.first(where: { $0.index == activeLayerIndex })
        else {
            return nil
        }

        let expectedCount = snapshot.width * snapshot.height * 4
        guard layer.pixelData.count == expectedCount else { return nil }

        let committedSamples = normalizedCommittedStrokeSamples(samples, brush: brush)
        guard !committedSamples.isEmpty else { return nil }
        let progressTable = strokeProgressTable(committedSamples)

        var output = layer.pixelData
        let didRasterize = output.withUnsafeMutableBytes { rawBytes in
            guard let baseAddress = rawBytes.bindMemory(to: UInt8.self).baseAddress else { return false }
            let pixels = UnsafeMutableBufferPointer(start: baseAddress, count: expectedCount)
            if committedSamples.count == 1 {
                rasterizeShortStrokeStamp(
                    into: pixels,
                    canvasWidth: snapshot.width,
                    canvasHeight: snapshot.height,
                    sample: committedSamples[0],
                    progress: progressTable[0],
                    brush: brush
                )
                return true
            }

            for (index, pair) in zip(committedSamples.indices, zip(committedSamples, committedSamples.dropFirst())) {
                rasterizeShortStrokeSegment(
                    into: pixels,
                    canvasWidth: snapshot.width,
                    canvasHeight: snapshot.height,
                    start: pair.0,
                    end: pair.1,
                    startProgress: progressTable[index],
                    endProgress: progressTable[index + 1],
                    brush: brush
                )
            }
            return true
        }

        guard didRasterize else { return nil }
        return preserveAlphaLockedPixels
            ? pixelDataByPreservingExistingAlpha(source: output, existing: layer.pixelData)
            : output
    }

    static func layerPixelDataByApplyingCommittedStroke(
        basePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool = false
    ) -> Data? {
        let expectedCount = canvasWidth * canvasHeight * 4
        guard basePixelData.count == expectedCount else { return nil }

        let committedSamples = normalizedCommittedStrokeSamples(samples, brush: brush)
        guard !committedSamples.isEmpty else { return nil }
        let progressTable = strokeProgressTable(committedSamples)

        var output = basePixelData
        let didRasterize = output.withUnsafeMutableBytes { rawBytes in
            guard let baseAddress = rawBytes.bindMemory(to: UInt8.self).baseAddress else { return false }
            let pixels = UnsafeMutableBufferPointer(start: baseAddress, count: expectedCount)
            if committedSamples.count == 1 {
                rasterizeShortStrokeStamp(
                    into: pixels,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    sample: committedSamples[0],
                    progress: progressTable[0],
                    brush: brush
                )
                return true
            }

            for (index, pair) in zip(committedSamples.indices, zip(committedSamples, committedSamples.dropFirst())) {
                rasterizeShortStrokeSegment(
                    into: pixels,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    start: pair.0,
                    end: pair.1,
                    startProgress: progressTable[index],
                    endProgress: progressTable[index + 1],
                    brush: brush
                )
            }
            return true
        }

        guard didRasterize else { return nil }
        return preserveAlphaLockedPixels
            ? pixelDataByPreservingExistingAlpha(source: output, existing: basePixelData)
            : output
    }

    static func pixelDataByPreservingExistingAlpha(source: Data, existing: Data) -> Data {
        guard source.count == existing.count else { return source }
        var output = source
        output.withUnsafeMutableBytes { outputBytes in
            existing.withUnsafeBytes { existingBytes in
                guard let dst = outputBytes.bindMemory(to: UInt8.self).baseAddress,
                      let src = existingBytes.bindMemory(to: UInt8.self).baseAddress
                else { return }
                for offset in stride(from: 0, to: source.count, by: 4) {
                    let alpha = src[offset + 3]
                    if alpha == 0 {
                        dst[offset] = 0
                        dst[offset + 1] = 0
                        dst[offset + 2] = 0
                        dst[offset + 3] = 0
                    } else {
                        dst[offset + 3] = alpha
                    }
                }
            }
        }
        return output
    }

    static func shouldRasterizeCommittedShortStroke(
        _ samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> Bool {
        guard !samples.isEmpty else { return false }
        if samples.count == 1 {
            return true
        }

        let visualThreshold = max(CGFloat(brush.radius) * 6.0, 18.0)
        let endpointDistance = strokeEndpointDistance(samples)
        let pathLength = strokePathLength(samples)
        if endpointDistance <= visualThreshold * 0.75 {
            return true
        }
        if endpointDistance <= visualThreshold * 1.5 && pathLength >= max(endpointDistance * 3.0, visualThreshold * 2.0) {
            return true
        }
        return strokeVisualSpan(samples) <= visualThreshold
    }

    static func strokePathLength(_ samples: [StylusSample]) -> CGFloat {
        zip(samples, samples.dropFirst()).reduce(.zero) { partial, pair in
            let dx = pair.1.point.x - pair.0.point.x
            let dy = pair.1.point.y - pair.0.point.y
            return partial + sqrt((dx * dx) + (dy * dy))
        }
    }

    static func strokeEndpointDistance(_ samples: [StylusSample]) -> CGFloat {
        guard let first = samples.first, let last = samples.last else { return .zero }
        let dx = last.point.x - first.point.x
        let dy = last.point.y - first.point.y
        return sqrt((dx * dx) + (dy * dy))
    }

    static func strokeVisualSpan(_ samples: [StylusSample]) -> CGFloat {
        guard let first = samples.first, let last = samples.last else { return .zero }
        var minX = first.point.x
        var maxX = first.point.x
        var minY = first.point.y
        var maxY = first.point.y

        for sample in samples.dropFirst() {
            minX = min(minX, sample.point.x)
            maxX = max(maxX, sample.point.x)
            minY = min(minY, sample.point.y)
            maxY = max(maxY, sample.point.y)
        }

        let width = maxX - minX
        let height = maxY - minY
        let endpointDX = last.point.x - first.point.x
        let endpointDY = last.point.y - first.point.y
        let endpointDistance = sqrt((endpointDX * endpointDX) + (endpointDY * endpointDY))
        return max(width, height, endpointDistance)
    }

    static func averagedStylusSample(_ samples: [StylusSample]) -> StylusSample {
        guard let first = samples.first else {
            return StylusSample(
                point: .zero,
                pressure: 1.0,
                altitude: .pi / 2,
                azimuth: 0,
                timestamp: 0
            )
        }
        let count = CGFloat(samples.count)
        let summed = samples.reduce(
            (x: CGFloat.zero, y: CGFloat.zero, pressure: CGFloat.zero, altitude: CGFloat.zero, azimuth: CGFloat.zero, timestamp: TimeInterval.zero)
        ) { partial, sample in
            (
                x: partial.x + sample.point.x,
                y: partial.y + sample.point.y,
                pressure: partial.pressure + sample.pressure,
                altitude: partial.altitude + sample.altitude,
                azimuth: partial.azimuth + sample.azimuth,
                timestamp: partial.timestamp + sample.timestamp
            )
        }
        return StylusSample(
            point: CGPoint(x: summed.x / count, y: summed.y / count),
            pressure: summed.pressure / count,
            altitude: summed.altitude / count,
            azimuth: summed.azimuth / count,
            timestamp: summed.timestamp / Double(samples.count)
        )
    }

    static func rasterizeShortStrokeSegment(
        into pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        start: StylusSample,
        end: StylusSample,
        startProgress: CGFloat,
        endProgress: CGFloat,
        brush: BrushRuntimeSettings
    ) {
        let dx = end.point.x - start.point.x
        let dy = end.point.y - start.point.y
        let lengthSquared = max((dx * dx) + (dy * dy), 0.0001)
        let length = max(sqrt(lengthSquared), 0.0001)
        let tangentX = dx / length
        let tangentY = dy / length
        let normalX = -tangentY
        let normalY = tangentX
        let maxRadius = max(
            resolvedStrokeRadius(for: start, progress: startProgress, brush: brush),
            resolvedStrokeRadius(for: end, progress: endProgress, brush: brush)
        )

        let minX = max(Int(floor(min(start.point.x, end.point.x) - maxRadius)), 0)
        let maxX = min(Int(ceil(max(start.point.x, end.point.x) + maxRadius)), canvasWidth - 1)
        let minY = max(Int(floor(min(start.point.y, end.point.y) - maxRadius)), 0)
        let maxY = min(Int(ceil(max(start.point.y, end.point.y) + maxRadius)), canvasHeight - 1)
        guard minX <= maxX, minY <= maxY else { return }

        for y in minY...maxY {
            for x in minX...maxX {
                let sampleX = CGFloat(x) + 0.5
                let sampleY = CGFloat(y) + 0.5
                let projection = (((sampleX - start.point.x) * dx) + ((sampleY - start.point.y) * dy)) / lengthSquared
                let t = max(0, min(1, projection))
                let interpolatedSample = interpolatedStylusSample(from: start, to: end, progress: t)
                let progress = startProgress + ((endProgress - startProgress) * t)
                let radius = resolvedStrokeRadius(for: interpolatedSample, progress: progress, brush: brush)
                let centerX = start.point.x + (dx * t)
                let centerY = start.point.y + (dy * t)
                let distanceToCenter = sqrt(pow(sampleX - centerX, 2) + pow(sampleY - centerY, 2))
                guard distanceToCenter <= radius else { continue }
                let sourceAlpha = sourceAlphaForRasterizedSample(
                    interpolatedSample,
                    brush: brush,
                    progress: progress,
                    radius: radius,
                    sampleX: sampleX,
                    sampleY: sampleY
                )
                guard sourceAlpha > 0.001 else { continue }
                let clampedPressure = max(0.08, min(interpolatedSample.pressure, 1.0))
                blendRasterizedPixel(
                    into: pixels,
                    offset: ((y * canvasWidth) + x) * 4,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    x: x,
                    y: y,
                    radius: radius,
                    sourceAlpha: sourceAlpha,
                    pressure: clampedPressure,
                    tangentX: tangentX,
                    tangentY: tangentY,
                    normalX: normalX,
                    normalY: normalY,
                    brush: brush
                )
            }
        }
    }

    static func rasterizeShortStrokeStamp(
        into pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        sample: StylusSample,
        progress: CGFloat,
        brush: BrushRuntimeSettings
    ) {
        let radius = resolvedStrokeRadius(for: sample, progress: progress, brush: brush)
        let minX = max(Int(floor(sample.point.x - radius)), 0)
        let maxX = min(Int(ceil(sample.point.x + radius)), canvasWidth - 1)
        let minY = max(Int(floor(sample.point.y - radius)), 0)
        let maxY = min(Int(ceil(sample.point.y + radius)), canvasHeight - 1)
        guard minX <= maxX, minY <= maxY else { return }
        let tangentX: CGFloat = 1.0
        let tangentY: CGFloat = 0.0
        let normalX: CGFloat = 0.0
        let normalY: CGFloat = 1.0

        for y in minY...maxY {
            for x in minX...maxX {
                let sampleX = CGFloat(x) + 0.5
                let sampleY = CGFloat(y) + 0.5
                let sourceAlpha = sourceAlphaForRasterizedSample(
                    sample,
                    brush: brush,
                    progress: progress,
                    radius: radius,
                    sampleX: sampleX,
                    sampleY: sampleY
                )
                guard sourceAlpha > 0.001 else { continue }
                let clampedPressure = max(0.08, min(sample.pressure, 1.0))
                blendRasterizedPixel(
                    into: pixels,
                    offset: ((y * canvasWidth) + x) * 4,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    x: x,
                    y: y,
                    radius: radius,
                    sourceAlpha: sourceAlpha,
                    pressure: clampedPressure,
                    tangentX: tangentX,
                    tangentY: tangentY,
                    normalX: normalX,
                    normalY: normalY,
                    brush: brush
                )
            }
        }
    }

    static func interpolatedStylusSample(from start: StylusSample, to end: StylusSample, progress t: CGFloat) -> StylusSample {
        StylusSample(
            point: CGPoint(
                x: start.point.x + ((end.point.x - start.point.x) * t),
                y: start.point.y + ((end.point.y - start.point.y) * t)
            ),
            pressure: start.pressure + ((end.pressure - start.pressure) * t),
            altitude: start.altitude + ((end.altitude - start.altitude) * t),
            azimuth: start.azimuth + ((end.azimuth - start.azimuth) * t),
            timestamp: start.timestamp + ((end.timestamp - start.timestamp) * Double(t))
        )
    }

    static func sourceAlphaForRasterizedSample(
        _ sample: StylusSample,
        brush: BrushRuntimeSettings,
        progress: CGFloat,
        radius: CGFloat,
        sampleX: CGFloat,
        sampleY: CGFloat
    ) -> CGFloat {
        let pressureOpacity = max(
            0.05,
            1.0 + ((sample.pressure - 1.0) * CGFloat(brush.opacityPressureSensitivity))
        )
        let flowOpacity = max(
            0.05,
            1.0 + ((sample.pressure - 1.0) * CGFloat(brush.flowPressureSensitivity))
        )
        let clampedOpacity = clampUnit(CGFloat(brush.opacity))
        let clampedFlow = clampUnit(CGFloat(brush.flow))
        let pigmentAlpha = clampUnit(
            clampedOpacity *
            clampedFlow *
            pressureOpacity *
            flowOpacity
        )
        let mixingCoverageAlpha = clampUnit(clampedOpacity * pressureOpacity)
        let baseAlpha =
            brush.colorMixingMode != .off &&
            clampedFlow <= 0.001 &&
            !brush.isEraser
            ? mixingCoverageAlpha
            : pigmentAlpha
        guard baseAlpha > 0.001 else { return 0 }

        let dx = sampleX - sample.point.x
        let dy = sampleY - sample.point.y
        let normalizedDistance = sqrt((dx * dx) + (dy * dy)) / max(radius, 0.001)
        guard normalizedDistance <= 1 else { return 0 }

        let hardness = max(0, min(1, CGFloat(brush.hardness)))
        let isPencil = brush.tipKind == .pencil
        let hardCore = isPencil
            ? min(0.78, pow(hardness, 4.8) * 0.72)
            : (hardness >= 0.995 ? 1.0 : pow(hardness, 3.2))

        let falloff: CGFloat
        if hardCore >= 0.999 || normalizedDistance <= hardCore {
            falloff = 1
        } else {
            let span = max(0.001, 1.0 - hardCore)
            let softened = max(0, min(1, (normalizedDistance - hardCore) / span))
            falloff = isPencil ? pow(1.0 - softened, 1.6) : (1.0 - softened)
        }

        let textureAlpha: CGFloat
        if isPencil {
            let grainNoise = previewNoise(
                x: sampleX * max(CGFloat(brush.grainScale), 0.6),
                y: sampleY * max(CGFloat(brush.grainScale), 0.6)
            )
            let paperNoise = previewNoise(
                x: sampleX * max(CGFloat(brush.paperScale) * 24.0, 1.0),
                y: sampleY * max(CGFloat(brush.paperScale) * 24.0, 1.0)
            )
            let grainContrast = max(0.35, CGFloat(brush.grainContrast))
            let contrastedGrain = max(0.0, min(1.0, ((grainNoise - 0.5) * grainContrast) + 0.5))
            let grainStrength = min(max(CGFloat(brush.textureStrength), 0), 1) * 0.55
            let paperStrength = min(max(CGFloat(brush.paperStrength), 0), 1) * 0.45
            let grainMask = max(0.14, 1.0 - grainStrength + (contrastedGrain * grainStrength))
            let paperThreshold = min(max(CGFloat(brush.paperThreshold), 0), 1)
            let paperMask = max(
                0.18,
                1.0 - paperStrength + (max(0.0, min(1.0, (paperNoise - paperThreshold + 1.0) * 0.75)) * paperStrength)
            )
            textureAlpha = grainMask * paperMask
        } else {
            textureAlpha = 1.0
        }

        return baseAlpha * falloff * textureAlpha
    }

    private static func rasterizedPixelSample(
        from pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        x: Int,
        y: Int
    ) -> RasterizedSmudgeSample {
        guard canvasWidth > 0, canvasHeight > 0 else {
            return RasterizedSmudgeSample(red: 0, green: 0, blue: 0, alpha: 0)
        }
        let clampedX = min(max(x, 0), canvasWidth - 1)
        let clampedY = min(max(y, 0), canvasHeight - 1)
        let offset = ((clampedY * canvasWidth) + clampedX) * 4
        let alpha = CGFloat(pixels[offset + 3]) / 255.0
        return RasterizedSmudgeSample(
            red: (CGFloat(pixels[offset]) / 255.0) * alpha,
            green: (CGFloat(pixels[offset + 1]) / 255.0) * alpha,
            blue: (CGFloat(pixels[offset + 2]) / 255.0) * alpha,
            alpha: alpha
        )
    }

    private static func sampleRasterizedNeighborhood(
        from pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        tangentX: CGFloat,
        tangentY: CGFloat,
        normalX: CGFloat,
        normalY: CGFloat,
        extent: CGFloat,
        taps: [(dx: CGFloat, dy: CGFloat, weight: CGFloat)]
    ) -> RasterizedSmudgeSample {
        var accumulatedRed: CGFloat = 0
        var accumulatedGreen: CGFloat = 0
        var accumulatedBlue: CGFloat = 0
        var accumulatedAlpha: CGFloat = 0
        var accumulatedWeight: CGFloat = 0

        for tap in taps {
            let offsetX = ((tangentX * tap.dx) + (normalX * tap.dy)) * extent
            let offsetY = ((tangentY * tap.dx) + (normalY * tap.dy)) * extent
            let sample = rasterizedPixelSample(
                from: pixels,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                x: Int((CGFloat(centerX) + offsetX).rounded()),
                y: Int((CGFloat(centerY) + offsetY).rounded())
            )
            accumulatedRed += sample.red * tap.weight
            accumulatedGreen += sample.green * tap.weight
            accumulatedBlue += sample.blue * tap.weight
            accumulatedAlpha += sample.alpha * tap.weight
            accumulatedWeight += tap.weight
        }

        guard accumulatedWeight > 0.001 else {
            return RasterizedSmudgeSample(red: 0, green: 0, blue: 0, alpha: 0)
        }

        let inverseWeight = 1.0 / accumulatedWeight
        return RasterizedSmudgeSample(
            red: accumulatedRed * inverseWeight,
            green: accumulatedGreen * inverseWeight,
            blue: accumulatedBlue * inverseWeight,
            alpha: accumulatedAlpha * inverseWeight
        )
    }

    private static func sampleRasterizedSmearingColor(
        from pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        x: Int,
        y: Int,
        tangentX: CGFloat,
        tangentY: CGFloat,
        normalX: CGFloat,
        normalY: CGFloat,
        radius: CGFloat,
        brush: BrushRuntimeSettings
    ) -> RasterizedSmudgeSample {
        let bleedRadius = clampUnit(CGFloat(brush.smudgeRadius))
        let wetness = clampUnit(CGFloat(brush.wetness))
        let oilBias: CGFloat = brush.tipKind == .oil ? 0.30 : 0.0
        let extent = max(1.0, radius * (0.36 + max(bleedRadius, oilBias) * 1.88 + wetness * 0.28))
        let taps: [(dx: CGFloat, dy: CGFloat, weight: CGFloat)] = [
            (-0.18, 0.00, 0.08),
            (-0.52, 0.00, 0.20),
            (-0.92, 0.00, 0.22),
            (-1.34, 0.00, 0.18),
            (-1.74, 0.00, 0.10),
            (-0.64, 0.42, 0.07),
            (-0.64, -0.42, 0.07),
            (-1.08, 0.76, 0.04),
            (-1.08, -0.76, 0.04)
        ]
        return sampleRasterizedNeighborhood(
            from: pixels,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: x,
            centerY: y,
            tangentX: tangentX,
            tangentY: tangentY,
            normalX: normalX,
            normalY: normalY,
            extent: extent,
            taps: taps
        )
    }

    private static func sampleRasterizedDullingColor(
        from pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        x: Int,
        y: Int,
        tangentX: CGFloat,
        tangentY: CGFloat,
        normalX: CGFloat,
        normalY: CGFloat,
        radius: CGFloat,
        brush: BrushRuntimeSettings
    ) -> RasterizedSmudgeSample {
        let bleedRadius = clampUnit(CGFloat(brush.smudgeRadius))
        let wetness = clampUnit(CGFloat(brush.wetness))
        let mixStrength = clampUnit(CGFloat(brush.colorMixStrength))
        let oilBias: CGFloat = brush.tipKind == .oil ? 0.18 : 0.0
        let extent = max(1.0, radius * (0.28 + max(bleedRadius, oilBias) * 1.58 + mixStrength * 0.34 + wetness * 0.12))
        let taps: [(dx: CGFloat, dy: CGFloat, weight: CGFloat)] = [
            (0.00, 0.00, 0.20),
            (-0.46, 0.00, 0.12),
            (0.46, 0.00, 0.12),
            (0.00, 0.46, 0.12),
            (0.00, -0.46, 0.12),
            (-0.34, 0.34, 0.08),
            (-0.34, -0.34, 0.08),
            (0.34, 0.34, 0.08),
            (0.34, -0.34, 0.08)
        ]
        return sampleRasterizedNeighborhood(
            from: pixels,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: x,
            centerY: y,
            tangentX: tangentX,
            tangentY: tangentY,
            normalX: normalX,
            normalY: normalY,
            extent: extent,
            taps: taps
        )
    }

    private static func sampleRasterizedBlurColor(
        from pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        x: Int,
        y: Int,
        tangentX: CGFloat,
        tangentY: CGFloat,
        normalX: CGFloat,
        normalY: CGFloat,
        radius: CGFloat,
        brush: BrushRuntimeSettings
    ) -> RasterizedSmudgeSample {
        let blurAmount = clampUnit(CGFloat(brush.smudgeBleed))
        let blurRadius = clampUnit(CGFloat(brush.smudgeRadius))
        let mixStrength = clampUnit(CGFloat(brush.colorMixStrength))
        let oilBias: CGFloat = brush.tipKind == .oil ? 0.24 : 0.0
        let extent = max(1.0, radius * (0.34 + max(blurRadius, oilBias) * 1.92 + blurAmount * 0.40 + mixStrength * 0.18))
        let taps: [(dx: CGFloat, dy: CGFloat, weight: CGFloat)] = [
            (0.00, 0.00, 0.16),
            (-0.72, 0.00, 0.09),
            (0.72, 0.00, 0.09),
            (0.00, 0.72, 0.09),
            (0.00, -0.72, 0.09),
            (-0.52, 0.52, 0.07),
            (-0.52, -0.52, 0.07),
            (0.52, 0.52, 0.07),
            (0.52, -0.52, 0.07),
            (-1.08, 0.00, 0.05),
            (1.08, 0.00, 0.05),
            (0.00, 1.08, 0.05),
            (0.00, -1.08, 0.05)
        ]
        return sampleRasterizedNeighborhood(
            from: pixels,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: x,
            centerY: y,
            tangentX: tangentX,
            tangentY: tangentY,
            normalX: normalX,
            normalY: normalY,
            extent: extent,
            taps: taps
        )
    }

    static func blendRasterizedPixel(
        into pixels: UnsafeMutableBufferPointer<UInt8>,
        offset: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        x: Int,
        y: Int,
        radius: CGFloat,
        sourceAlpha: CGFloat,
        pressure: CGFloat,
        tangentX: CGFloat,
        tangentY: CGFloat,
        normalX: CGFloat,
        normalY: CGFloat,
        brush: BrushRuntimeSettings
    ) {
        let destinationAlpha = CGFloat(pixels[offset + 3]) / 255.0

        if brush.isEraser {
            let outAlpha = destinationAlpha * (1.0 - sourceAlpha)
            pixels[offset + 3] = UInt8(max(0, min(255, Int((outAlpha * 255.0).rounded()))))
            return
        }

        let sourceRed = CGFloat(brush.red) / 255.0
        let sourceGreen = CGFloat(brush.green) / 255.0
        let sourceBlue = CGFloat(brush.blue) / 255.0
        let destinationRed = CGFloat(pixels[offset]) / 255.0
        let destinationGreen = CGFloat(pixels[offset + 1]) / 255.0
        let destinationBlue = CGFloat(pixels[offset + 2]) / 255.0
        let destinationPremulRed = destinationRed * destinationAlpha
        let destinationPremulGreen = destinationGreen * destinationAlpha
        let destinationPremulBlue = destinationBlue * destinationAlpha
        let mode = brush.colorMixingMode
        let configuredColorStretch = min(max(CGFloat(brush.wetness), 0), 1)
        let configuredUndercoatMix = min(max(CGFloat(brush.colorMixStrength), 0), 1)
        let configuredBlurAmount = min(max(CGFloat(brush.smudgeBleed), 0), 1)
        let configuredBlurRadius = min(max(CGFloat(brush.smudgeRadius), 0), 1)
        let pigmentDensity = clampUnit(CGFloat(brush.flow))
        var colorStretch: CGFloat
        var undercoatMix: CGFloat
        var blurAmount: CGFloat
        var blurRadius: CGFloat
        var blurEnabled: Bool
        switch mode {
        case .off:
            colorStretch = 0
            undercoatMix = 0
            blurAmount = 0
            blurRadius = 0
            blurEnabled = false
        case .blend:
            colorStretch = configuredColorStretch
            undercoatMix = max(configuredUndercoatMix, 0.72)
            blurAmount = 0
            blurRadius = 0
            blurEnabled = false
        case .runningColor:
            colorStretch = configuredColorStretch
            undercoatMix = max(configuredUndercoatMix, 0.84)
            blurAmount = max(configuredBlurAmount, 0.18)
            blurRadius = max(configuredBlurRadius, 0.18)
            blurEnabled = brush.smudgeBlurEnabled
        case .smear:
            colorStretch = configuredColorStretch
            undercoatMix = 0
            blurAmount = 0
            blurRadius = 0
            blurEnabled = false
        }
        if mode != .off &&
            pigmentDensity <= 0.001 &&
            colorStretch <= 0.001 &&
            undercoatMix <= 0.001 &&
            blurAmount <= 0.001 &&
            blurRadius <= 0.001 {
            undercoatMix = 0.58
            blurAmount = 0.44
            blurRadius = 0.36
            blurEnabled = true
        }
        let clampedPressure = clampUnit(max(0.08, min(pressure, 1.0)))
        let lowPressureMix = clampUnit((1.0 - clampedPressure) / 0.92)
        let activeBlurAmount = blurEnabled ? blurAmount : 0
        let activeBlurRadius = blurEnabled ? blurRadius : 0
        let effectiveColorStretch = clampUnit(colorStretch * (0.74 + (lowPressureMix * 0.82)))
        let effectiveUndercoatMix = clampUnit(undercoatMix * (0.78 + (lowPressureMix * 0.72)))
        let effectiveBlurAmount = clampUnit(activeBlurAmount * (0.72 + (lowPressureMix * 0.88)))
        let effectiveBlurRadius = clampUnit(activeBlurRadius * (0.84 + (lowPressureMix * 0.44)))
        let spacingFactor = min(max((CGFloat(brush.stampSpacing) - 0.02) / 0.38, 0), 1)
        let smudgeOpacityGate = clampUnit((sourceAlpha - 0.04) / 0.86)
        let mixActivation = clampUnit(smudgeOpacityGate + (lowPressureMix * 0.42))
        let edgeColorGuard = clampUnit((sourceAlpha - 0.10) / 0.36)
        let contourFade = clampUnit((sourceAlpha - 0.20) / 0.44)
        let corePresence = clampUnit((sourceAlpha - 0.46) / 0.34)
        let edgeMixGuard = clampUnit(edgeColorGuard + (lowPressureMix * 0.20)) * (0.18 + (contourFade * 0.82))
        let edgeAlphaGuard = clampUnit((max(destinationAlpha, sourceAlpha) - 0.02) / 0.16)
        let colorRate = clampUnit(CGFloat(brush.paintLoad))
        let effectiveColorRate = clampUnit(colorRate * (0.24 + (clampedPressure * 0.76)))
        let effectivePigmentDensity = clampUnit(pigmentDensity * (0.16 + (clampedPressure * 0.84)))
        let smudgeEnabled =
            mode != .off &&
            (
                effectiveColorStretch > 0.001 ||
                effectiveUndercoatMix > 0.001 ||
                effectiveBlurAmount > 0.001 ||
                effectiveBlurRadius > 0.001 ||
                effectiveColorRate < 0.999 ||
                pigmentDensity <= 0.001
            )

        var resolvedSourceRed = sourceRed
        var resolvedSourceGreen = sourceGreen
        var resolvedSourceBlue = sourceBlue
        var resolvedSourceAlpha = sourceAlpha
        if smudgeEnabled {
            let smearSample = sampleRasterizedSmearingColor(
                from: pixels,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                x: x,
                y: y,
                tangentX: tangentX,
                tangentY: tangentY,
                normalX: normalX,
                normalY: normalY,
                radius: radius,
                brush: brush
            )
            let dullSample = undercoatMix > 0.001
                ? sampleRasterizedDullingColor(
                    from: pixels,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    x: x,
                    y: y,
                    tangentX: tangentX,
                    tangentY: tangentY,
                    normalX: normalX,
                    normalY: normalY,
                    radius: radius,
                    brush: brush
                )
                : RasterizedSmudgeSample(red: destinationPremulRed, green: destinationPremulGreen, blue: destinationPremulBlue, alpha: destinationAlpha)
            let blurSample = blurEnabled
                ? sampleRasterizedBlurColor(
                    from: pixels,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    x: x,
                    y: y,
                    tangentX: tangentX,
                    tangentY: tangentY,
                    normalX: normalX,
                    normalY: normalY,
                    radius: radius,
                    brush: brush
                )
                : RasterizedSmudgeSample(red: destinationPremulRed, green: destinationPremulGreen, blue: destinationPremulBlue, alpha: destinationAlpha)
            let transparentSurface =
                destinationAlpha <= 0.02 &&
                smearSample.alpha <= 0.02 &&
                dullSample.alpha <= 0.02 &&
                blurSample.alpha <= 0.02
            if !transparentSurface {
                let smearStrength = clampUnit(
                    mixActivation *
                    (0.14 + (effectiveColorStretch * 0.98) + ((1.0 - spacingFactor) * 0.10))
                )
                let dullStrength = clampUnit(
                    mixActivation *
                    (0.04 + (effectiveUndercoatMix * 0.94) + (effectiveBlurAmount * 0.10))
                )
                var mixedPremulRed = interpolate(destinationPremulRed, smearSample.red, amount: smearStrength)
                var mixedPremulGreen = interpolate(destinationPremulGreen, smearSample.green, amount: smearStrength)
                var mixedPremulBlue = interpolate(destinationPremulBlue, smearSample.blue, amount: smearStrength)
                var mixedAlpha = interpolate(destinationAlpha, smearSample.alpha, amount: smearStrength)
                mixedPremulRed = interpolate(mixedPremulRed, dullSample.red, amount: dullStrength)
                mixedPremulGreen = interpolate(mixedPremulGreen, dullSample.green, amount: dullStrength)
                mixedPremulBlue = interpolate(mixedPremulBlue, dullSample.blue, amount: dullStrength)
                mixedAlpha = interpolate(mixedAlpha, dullSample.alpha, amount: dullStrength)

                if blurEnabled && (effectiveBlurAmount > 0.001 || effectiveBlurRadius > 0.001) {
                    let blurStrength = clampUnit(
                        mixActivation *
                        (
                            0.02 +
                            (effectiveUndercoatMix * 0.26) +
                            (effectiveBlurAmount * 0.86) +
                            (effectiveBlurRadius * 0.32)
                        )
                    )
                    let blurRed = (blurSample.red * 0.86) + (mixedPremulRed * 0.14)
                    let blurGreen = (blurSample.green * 0.86) + (mixedPremulGreen * 0.14)
                    let blurBlue = (blurSample.blue * 0.86) + (mixedPremulBlue * 0.14)
                    let blurAlpha = (blurSample.alpha * 0.82) + (mixedAlpha * 0.18)
                    mixedPremulRed = interpolate(mixedPremulRed, blurRed, amount: blurStrength)
                    mixedPremulGreen = interpolate(mixedPremulGreen, blurGreen, amount: blurStrength)
                    mixedPremulBlue = interpolate(mixedPremulBlue, blurBlue, amount: blurStrength)
                    mixedAlpha = interpolate(mixedAlpha, blurAlpha, amount: blurStrength)
                }

                let mixedColorAlpha = max(mixedAlpha, 0.0001)
                let mixedRed = mixedPremulRed / mixedColorAlpha
                let mixedGreen = mixedPremulGreen / mixedColorAlpha
                let mixedBlue = mixedPremulBlue / mixedColorAlpha
                let mixedLuminance = rasterizedLuminance(red: mixedRed, green: mixedGreen, blue: mixedBlue)
                let pigmentLuminance = rasterizedLuminance(red: sourceRed, green: sourceGreen, blue: sourceBlue)
                let luminanceSimilarity = clampUnit(1.0 - abs(mixedLuminance - pigmentLuminance) * 0.38)
                let undercoatBlend = clampUnit(edgeMixGuard * (0.18 + (effectiveUndercoatMix * 0.82)) * luminanceSimilarity * (1.0 - (corePresence * 0.18)))
                let baseBlend = (mode == .smear ? edgeMixGuard : undercoatBlend) * (1.0 - (corePresence * 0.12))
                let centerPigmentRetention = clampUnit(effectivePigmentDensity * (1.0 + (corePresence * 0.30)))
                let brushBaseRed = interpolate(mixedRed, sourceRed, amount: centerPigmentRetention)
                let brushBaseGreen = interpolate(mixedGreen, sourceGreen, amount: centerPigmentRetention)
                let brushBaseBlue = interpolate(mixedBlue, sourceBlue, amount: centerPigmentRetention)
                let smudgedRed = interpolate(brushBaseRed, mixedRed, amount: baseBlend)
                let smudgedGreen = interpolate(brushBaseGreen, mixedGreen, amount: baseBlend)
                let smudgedBlue = interpolate(brushBaseBlue, mixedBlue, amount: baseBlend)
                let pigmentInfluence = clampUnit(
                    ((mode == .smear ? min(effectiveColorRate, 0.28) : effectiveColorRate) * 0.96) +
                    ((1.0 - edgeAlphaGuard) * 0.04)
                ) * centerPigmentRetention
                resolvedSourceRed = interpolate(smudgedRed, sourceRed, amount: pigmentInfluence)
                resolvedSourceGreen = interpolate(smudgedGreen, sourceGreen, amount: pigmentInfluence)
                resolvedSourceBlue = interpolate(smudgedBlue, sourceBlue, amount: pigmentInfluence)

                let smudgedCoverage = clampUnit((smearSample.alpha * 0.44) + (dullSample.alpha * 0.26) + (blurSample.alpha * 0.30))
                let coverageInfluence = clampUnit((1.0 - effectiveColorRate) * (0.24 + (effectiveColorStretch * 0.40) + (effectiveUndercoatMix * 0.22) + (lowPressureMix * 0.14)) * (0.92 + ((1.0 - contourFade) * 0.52)) * (1.0 - (corePresence * 0.42)))
                let coverageFloor = min(0.92, interpolate(0.02 + (effectiveColorRate * 0.06), 0.24 + (effectiveColorRate * 0.26) + (corePresence * (0.10 + (effectiveColorRate * 0.08))), amount: contourFade))
                let coverage = max(coverageFloor, interpolate(1.0, smudgedCoverage, amount: coverageInfluence))
                resolvedSourceAlpha = sourceAlpha * coverage * (0.60 + (contourFade * 0.40))
            }
        }
        let outAlpha = destinationAlpha + (resolvedSourceAlpha * (1.0 - destinationAlpha))
        guard outAlpha > 0.001 else { return }

        let outRed = ((resolvedSourceRed * resolvedSourceAlpha) + (destinationRed * destinationAlpha * (1.0 - resolvedSourceAlpha))) / outAlpha
        let outGreen = ((resolvedSourceGreen * resolvedSourceAlpha) + (destinationGreen * destinationAlpha * (1.0 - resolvedSourceAlpha))) / outAlpha
        let outBlue = ((resolvedSourceBlue * resolvedSourceAlpha) + (destinationBlue * destinationAlpha * (1.0 - resolvedSourceAlpha))) / outAlpha

        pixels[offset] = UInt8(max(0, min(255, Int((outRed * 255.0).rounded()))))
        pixels[offset + 1] = UInt8(max(0, min(255, Int((outGreen * 255.0).rounded()))))
        pixels[offset + 2] = UInt8(max(0, min(255, Int((outBlue * 255.0).rounded()))))
        pixels[offset + 3] = UInt8(max(0, min(255, Int((outAlpha * 255.0).rounded()))))
    }

    static func resolvedStrokeRadius(for sample: StylusSample, progress: CGFloat = 0, brush: BrushRuntimeSettings) -> CGFloat {
        let clampedPressure = max(0.08, min(sample.pressure, 1.0))
        let pressureFactor = max(
            0.1,
            1.0 + ((clampedPressure - 1.0) * CGFloat(brush.pressureSensitivity))
        )
        let taperScale = strokeTaperScale(
            progress: progress,
            taperIn: CGFloat(brush.taperIn),
            taperOut: CGFloat(brush.taperOut)
        )
        return max(CGFloat(brush.radius) * pressureFactor * taperScale, 1.5)
    }

    static func previewNoise(x: CGFloat, y: CGFloat) -> CGFloat {
        let value = sin((x * 12.9898) + (y * 78.233)) * 43758.5453
        return value - floor(value)
    }

    static func pngData(fromLayerPixelData pixelData: Data, width: Int, height: Int) -> Data? {
        guard width > 0, height > 0, pixelData.count == width * height * 4 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: pixelData as CFData) else { return nil }
        guard let image = CGImage(
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
        ) else {
            return nil
        }
        return UIImage(cgImage: image).pngData()
    }

    static func inpaintCrop(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection,
        padding: Int = 64
    ) -> InpaintCrop? {
        let expectedCount = canvasWidth * canvasHeight * 4
        guard source.count == expectedCount else { return nil }

        let minX = max(Int(selection.bounds.minX.rounded(.down)) - padding, 0)
        let minY = max(Int(selection.bounds.minY.rounded(.down)) - padding, 0)
        let maxX = min(Int(selection.bounds.maxX.rounded(.up)) + padding, canvasWidth)
        let maxY = min(Int(selection.bounds.maxY.rounded(.up)) + padding, canvasHeight)
        let cropWidth = maxX - minX
        let cropHeight = maxY - minY
        guard cropWidth > 0, cropHeight > 0 else { return nil }

        let expandedSelectionMask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        let sourceBytes = [UInt8](source)
        var cropBytes = [UInt8](repeating: 0, count: cropWidth * cropHeight * 4)
        var cropSelectionMask = [UInt8](repeating: 0, count: cropWidth * cropHeight)

        for y in 0..<cropHeight {
            for x in 0..<cropWidth {
                let canvasX = minX + x
                let canvasY = minY + y
                let canvasIndex = (canvasY * canvasWidth) + canvasX
                let cropIndex = (y * cropWidth) + x
                let sourceOffset = canvasIndex * 4
                let cropOffset = cropIndex * 4

                cropBytes[cropOffset] = sourceBytes[sourceOffset]
                cropBytes[cropOffset + 1] = sourceBytes[sourceOffset + 1]
                cropBytes[cropOffset + 2] = sourceBytes[sourceOffset + 2]
                cropBytes[cropOffset + 3] = sourceBytes[sourceOffset + 3]
                cropSelectionMask[cropIndex] = expandedSelectionMask[canvasIndex]
            }
        }

        return InpaintCrop(
            pixelData: Data(cropBytes),
            width: cropWidth,
            height: cropHeight,
            originX: minX,
            originY: minY,
            selectionMask: cropSelectionMask
        )
    }

    static func applyingInpaintCrop(
        _ editedCropPixelData: Data,
        to baseLayerPixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        crop: InpaintCrop,
        featherRadius: Int = 10
    ) -> Data? {
        guard baseLayerPixelData.count == canvasWidth * canvasHeight * 4 else { return nil }
        guard editedCropPixelData.count == crop.width * crop.height * 4 else { return nil }

        let editedBytes = [UInt8](editedCropPixelData)
        let baseBytes = [UInt8](baseLayerPixelData)
        var outputBytes = baseBytes
        let blendMask = featheredBlendMask(
            selectionMask: crop.selectionMask,
            width: crop.width,
            height: crop.height,
            radius: featherRadius
        )

        for y in 0..<crop.height {
            for x in 0..<crop.width {
                let cropIndex = (y * crop.width) + x
                let blendAlpha = blendMask[cropIndex]
                guard blendAlpha > 0 else { continue }

                let canvasX = crop.originX + x
                let canvasY = crop.originY + y
                guard canvasX >= 0, canvasX < canvasWidth, canvasY >= 0, canvasY < canvasHeight else { continue }

                let canvasOffset = ((canvasY * canvasWidth) + canvasX) * 4
                let cropOffset = cropIndex * 4

                if blendAlpha >= 0.999 {
                    outputBytes[canvasOffset] = editedBytes[cropOffset]
                    outputBytes[canvasOffset + 1] = editedBytes[cropOffset + 1]
                    outputBytes[canvasOffset + 2] = editedBytes[cropOffset + 2]
                    outputBytes[canvasOffset + 3] = editedBytes[cropOffset + 3]
                    continue
                }

                for channel in 0..<4 {
                    let baseValue = Double(baseBytes[canvasOffset + channel])
                    let editedValue = Double(editedBytes[cropOffset + channel])
                    let blendedValue = (baseValue * (1.0 - blendAlpha)) + (editedValue * blendAlpha)
                    outputBytes[canvasOffset + channel] = UInt8(max(0, min(255, Int(blendedValue.rounded()))))
                }
            }
        }

        return Data(outputBytes)
    }

    private static func featheredBlendMask(
        selectionMask: [UInt8],
        width: Int,
        height: Int,
        radius: Int
    ) -> [Double] {
        guard width > 0, height > 0 else { return [] }
        guard radius > 0 else {
            return selectionMask.map { $0 == 0 ? 0 : 1 }
        }

        let radiusSquared = radius * radius
        var result = [Double](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width) + x
                if selectionMask[index] != 0 {
                    result[index] = 1
                    continue
                }

                var nearestDistanceSquared: Int?
                let minSearchY = max(0, y - radius)
                let maxSearchY = min(height - 1, y + radius)
                let minSearchX = max(0, x - radius)
                let maxSearchX = min(width - 1, x + radius)

                for searchY in minSearchY...maxSearchY {
                    for searchX in minSearchX...maxSearchX {
                        let searchIndex = (searchY * width) + searchX
                        guard selectionMask[searchIndex] != 0 else { continue }

                        let dx = searchX - x
                        let dy = searchY - y
                        let distanceSquared = (dx * dx) + (dy * dy)
                        guard distanceSquared <= radiusSquared else { continue }

                        if let currentNearestDistanceSquared = nearestDistanceSquared {
                            if distanceSquared < currentNearestDistanceSquared {
                                nearestDistanceSquared = distanceSquared
                            }
                        } else {
                            nearestDistanceSquared = distanceSquared
                        }
                    }
                }

                guard let nearestDistanceSquared else { continue }
                let distance = sqrt(Double(nearestDistanceSquared))
                let normalized = max(0, min(1, 1 - (distance / Double(radius))))
                result[index] = normalized
            }
        }

        return result
    }

    static func rawLayerPixelData(fromPNGData pngData: Data, width: Int, height: Int) -> Data? {
        guard width > 0, height > 0, let image = UIImage(data: pngData)?.cgImage else { return nil }

        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Data(buffer)
    }

    static func fittedLayerPixelData(fromImageData imageData: Data, canvasSize: CGSize) -> Data? {
        guard
            canvasSize.width > 0,
            canvasSize.height > 0,
            let sourceImage = UIImage(data: imageData)
        else {
            return nil
        }

        let width = Int(canvasSize.width.rounded())
        let height = Int(canvasSize.height.rounded())
        guard width > 0, height > 0 else { return nil }

        let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)
        let imageSize = resolvedPixelSize(for: sourceImage)
        let scale = min(canvasRect.width / imageSize.width, canvasRect.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: (canvasRect.width - fittedSize.width) * 0.5,
            y: (canvasRect.height - fittedSize.height) * 0.5,
            width: fittedSize.width,
            height: fittedSize.height
        )

        let renderer = UIGraphicsImageRenderer(size: canvasRect.size)
        let renderedImage = renderer.image { _ in
            UIColor.clear.setFill()
            UIRectFill(canvasRect)
            sourceImage.draw(in: drawRect)
        }
        guard let renderedCGImage = renderedImage.cgImage else {
            return nil
        }
        return PaintDocumentSession.pixelData(from: renderedCGImage, size: canvasRect.size)
    }

    struct ImportedCanvasImage {
        let width: Int
        let height: Int
        let pixelData: Data
    }

    static func importedCanvasImage(from imageData: Data) -> ImportedCanvasImage? {
        guard let sourceImage = UIImage(data: imageData) else {
            return nil
        }

        let imageSize = resolvedPixelSize(for: sourceImage)
        let width = Int(imageSize.width.rounded())
        let height = Int(imageSize.height.rounded())
        guard width > 0, height > 0 else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let renderedImage = renderer.image { _ in
            UIColor.clear.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: width, height: height))
            sourceImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        guard let renderedCGImage = renderedImage.cgImage,
              let pixelData = PaintDocumentSession.pixelData(from: renderedCGImage, size: CGSize(width: width, height: height)) else {
            return nil
        }

        return ImportedCanvasImage(width: width, height: height, pixelData: pixelData)
    }

    private static func resolvedPixelSize(for image: UIImage) -> CGSize {
        let pixelWidth = max((image.size.width * image.scale).rounded(), 1)
        let pixelHeight = max((image.size.height * image.scale).rounded(), 1)
        return CGSize(width: pixelWidth, height: pixelHeight)
    }

    static func blendPreviewPixel(
        destination: UnsafeMutablePointer<UInt8>,
        source: UnsafePointer<UInt8>,
        opacity: CGFloat,
        blendMode: LayerBlendMode
    ) {
        let srcAlpha = (CGFloat(source[3]) / 255.0) * opacity
        guard srcAlpha > 0.001 else { return }
        let dstAlpha = CGFloat(destination[3]) / 255.0
        let outAlpha = srcAlpha + (dstAlpha * (1 - srcAlpha))
        guard outAlpha > 0.001 else { return }

        let srcR = CGFloat(source[0]) / 255.0
        let srcG = CGFloat(source[1]) / 255.0
        let srcB = CGFloat(source[2]) / 255.0
        let dstR = CGFloat(destination[0]) / 255.0
        let dstG = CGFloat(destination[1]) / 255.0
        let dstB = CGFloat(destination[2]) / 255.0
        let blended = blendedPreviewColor(
            backdrop: (dstR, dstG, dstB),
            source: (srcR, srcG, srcB),
            blendMode: blendMode
        )

        let outR = (
            srcAlpha * ((1 - dstAlpha) * srcR + (dstAlpha * blended.r)) +
            (dstAlpha * (1 - srcAlpha) * dstR)
        ) / outAlpha
        let outG = (
            srcAlpha * ((1 - dstAlpha) * srcG + (dstAlpha * blended.g)) +
            (dstAlpha * (1 - srcAlpha) * dstG)
        ) / outAlpha
        let outB = (
            srcAlpha * ((1 - dstAlpha) * srcB + (dstAlpha * blended.b)) +
            (dstAlpha * (1 - srcAlpha) * dstB)
        ) / outAlpha

        destination[0] = UInt8(max(0, min(255, Int((outR * 255.0).rounded()))))
        destination[1] = UInt8(max(0, min(255, Int((outG * 255.0).rounded()))))
        destination[2] = UInt8(max(0, min(255, Int((outB * 255.0).rounded()))))
        destination[3] = UInt8(max(0, min(255, Int((outAlpha * 255.0).rounded()))))
    }

    static func blendedPreviewColor(
        backdrop: (r: CGFloat, g: CGFloat, b: CGFloat),
        source: (r: CGFloat, g: CGFloat, b: CGFloat),
        blendMode: LayerBlendMode
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        if blendMode == .darkerColor {
            return previewLuminosity(source) < previewLuminosity(backdrop) ? source : backdrop
        }
        if blendMode == .lighterColor {
            return previewLuminosity(source) > previewLuminosity(backdrop) ? source : backdrop
        }
        if blendMode == .hue {
            var output = source
            output = previewSetSaturation(output, previewSaturation(backdrop))
            output = previewSetLuminosity(output, previewLuminosity(backdrop))
            return previewClamped(output)
        }
        if blendMode == .saturation {
            var output = backdrop
            output = previewSetSaturation(output, previewSaturation(source))
            output = previewSetLuminosity(output, previewLuminosity(backdrop))
            return previewClamped(output)
        }
        if blendMode == .color {
            var output = source
            output = previewSetSaturation(output, previewSaturation(source))
            output = previewSetLuminosity(output, previewLuminosity(backdrop))
            return previewClamped(output)
        }
        if blendMode == .luminosity {
            var output = backdrop
            output = previewSetLuminosity(output, previewLuminosity(source))
            return previewClamped(output)
        }

        return (
            r: max(0, min(1, previewBlendChannel(backdrop: backdrop.r, source: source.r, blendMode: blendMode))),
            g: max(0, min(1, previewBlendChannel(backdrop: backdrop.g, source: source.g, blendMode: blendMode))),
            b: max(0, min(1, previewBlendChannel(backdrop: backdrop.b, source: source.b, blendMode: blendMode)))
        )
    }

    static func previewBlendChannel(backdrop: CGFloat, source: CGFloat, blendMode: LayerBlendMode) -> CGFloat {
        switch blendMode {
        case .normal:
            return source
        case .darken:
            return min(backdrop, source)
        case .multiply:
            return backdrop * source
        case .colorBurn:
            return source <= 0 ? 0 : max(0, 1 - ((1 - backdrop) / max(0.001, source)))
        case .linearBurn:
            return max(0, backdrop + source - 1)
        case .subtract:
            return max(0, backdrop - source)
        case .lighten:
            return max(backdrop, source)
        case .screen:
            return 1 - ((1 - backdrop) * (1 - source))
        case .add:
            return min(1, backdrop + source)
        case .colorDodge:
            return source >= 1 ? 1 : min(1, backdrop / max(0.001, 1 - source))
        case .glowDodge:
            return source >= 1 ? 1 : min(1, backdrop / max(0.0005, 1 - (source * 0.92)))
        case .overlay:
            return backdrop <= 0.5 ? (2 * backdrop * source) : (1 - 2 * (1 - backdrop) * (1 - source))
        case .softLight:
            return source <= 0.5
                ? (backdrop - ((1 - 2 * source) * backdrop * (1 - backdrop)))
                : (backdrop + ((2 * source - 1) * ((backdrop <= 0.25)
                    ? ((((16 * backdrop - 12) * backdrop) + 4) * backdrop)
                    : sqrt(backdrop)) - backdrop))
        case .hardLight:
            return source <= 0.5 ? (2 * backdrop * source) : (1 - 2 * (1 - backdrop) * (1 - source))
        case .difference:
            return abs(backdrop - source)
        case .vividLight:
            return source <= 0.5
                ? (1 - ((1 - backdrop) / max(0.001, 2 * source)))
                : (backdrop / max(0.001, 2 * (1 - source)))
        case .linearLight:
            return max(0, min(1, backdrop + (2 * source) - 1))
        case .pinLight:
            return source > 0.5 ? max(backdrop, 2 * (source - 0.5)) : min(backdrop, 2 * source)
        case .hardMix:
            return previewBlendChannel(backdrop: backdrop, source: source, blendMode: .vividLight) < 0.5 ? 0 : 1
        case .exclusion:
            return backdrop + source - (2 * backdrop * source)
        case .divide:
            return source <= 0.001 ? 1 : min(1, backdrop / source)
        case .addGlow:
            return min(1, backdrop + (source * 1.15))
        case .darkerColor, .lighterColor, .hue, .saturation, .color, .luminosity:
            return source
        }
    }

    static func previewLuminosity(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        (0.3 * color.r) + (0.59 * color.g) + (0.11 * color.b)
    }

    static func previewSaturation(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b))
    }

    static func previewSetLuminosity(_ color: (r: CGFloat, g: CGFloat, b: CGFloat), _ luminosity: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let delta = luminosity - previewLuminosity(color)
        return previewClipColor((color.r + delta, color.g + delta, color.b + delta))
    }

    static func previewSetSaturation(_ color: (r: CGFloat, g: CGFloat, b: CGFloat), _ saturation: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var components = [color.r, color.g, color.b]
        let minValue = components.min() ?? 0
        let maxValue = components.max() ?? 0
        guard maxValue > minValue else { return (0, 0, 0) }

        for index in components.indices {
            components[index] = ((components[index] - minValue) * saturation) / (maxValue - minValue)
        }

        let updatedMin = components.min() ?? 0
        let updatedMax = components.max() ?? 1
        guard updatedMax > updatedMin else { return (0, 0, 0) }

        for index in components.indices {
            components[index] = (components[index] - updatedMin) / (updatedMax - updatedMin) * saturation
        }

        return previewClipColor((components[0], components[1], components[2]))
    }

    static func previewClipColor(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let luminosity = previewLuminosity(color)
        let minValue = min(color.r, min(color.g, color.b))
        let maxValue = max(color.r, max(color.g, color.b))
        var result = color

        if minValue < 0 {
            result.r = luminosity + (((result.r - luminosity) * luminosity) / (luminosity - minValue))
            result.g = luminosity + (((result.g - luminosity) * luminosity) / (luminosity - minValue))
            result.b = luminosity + (((result.b - luminosity) * luminosity) / (luminosity - minValue))
        }
        if maxValue > 1 {
            result.r = luminosity + (((result.r - luminosity) * (1 - luminosity)) / (maxValue - luminosity))
            result.g = luminosity + (((result.g - luminosity) * (1 - luminosity)) / (maxValue - luminosity))
            result.b = luminosity + (((result.b - luminosity) * (1 - luminosity)) / (maxValue - luminosity))
        }

        return previewClamped(result)
    }

    static func previewClamped(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        (
            r: max(0, min(1, color.r)),
            g: max(0, min(1, color.g)),
            b: max(0, min(1, color.b))
        )
    }

    static func localizedNanoBananaErrorMessage(_ message: String, language: AppLanguage) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return language.localized("Nano Banana edit failed")
        }

        let normalized = trimmed.lowercased()
        if normalized.contains("invalid response") {
            return language.localized("Nano Banana returned an invalid response")
        }
        if normalized.contains("invalid endpoint") {
            return language.localized("Nano Banana endpoint is invalid")
        }
        if normalized.contains("missing image")
            || normalized.contains("did not return decodable image")
            || normalized.contains("returned text instead of an image")
        {
            return language.localized("Nano Banana did not return an image")
        }

        return trimmed
    }
}
