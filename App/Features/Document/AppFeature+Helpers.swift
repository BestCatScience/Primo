import ComposableArchitecture
import CoreGraphics
import Foundation
import SwiftUI

extension AppFeature {
    struct GradientMapStop {
        var position: Double
        var red: UInt8
        var green: UInt8
        var blue: UInt8
    }

    func applyTransform(state: inout State) -> Effect<Action> {
        let translation = CGSize(
            width: state.canvas.transformPreviewOffset.width.rounded(),
            height: state.canvas.transformPreviewOffset.height.rounded()
        )
        let scale = state.canvas.transformPreviewScale
        guard translation != .zero || abs(scale - 1.0) > 0.001 else { return .none }
        guard paintDocumentClient.applyLayerProcessing(
            state.canvas.activeLayerIndex,
            .transform(translation: translation, scale: scale, selection: state.canvas.selection)
        ) else {
            state.canvas.transformPreviewOffset = .zero
            state.canvas.transformPreviewScale = 1.0
            return .none
        }
        if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
            state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
            state.canvas.localBufferRevision += 1
        }
        state.canvas.selection = Self.transformedSelection(
            state.canvas.selection,
            translation: translation,
            scale: scale,
            canvasSize: state.canvas.canvasSize
        )
        state.canvas.transformPreviewOffset = .zero
        state.canvas.transformPreviewScale = 1.0
        state.applyPresentation(paintDocumentClient.presentation())
        return .none
    }

    static func combinedSelection(
        existing: CanvasSelection?,
        incoming: CanvasSelection?,
        mode: SelectionCombineMode,
        canvasSize: CGSize
    ) -> CanvasSelection? {
        switch mode {
        case .replace:
            return incoming
        case .add, .subtract:
            guard let incoming else { return existing }
            guard let existing else {
                return mode == .add ? incoming : nil
            }

            let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
            let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
            var baseMask = expandedMask(from: existing, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
            let incomingMask = expandedMask(from: incoming, canvasWidth: canvasWidth, canvasHeight: canvasHeight)

            for index in 0..<baseMask.count {
                switch mode {
                case .replace:
                    break
                case .add:
                    baseMask[index] = max(baseMask[index], incomingMask[index])
                case .subtract:
                    if incomingMask[index] != 0 {
                        baseMask[index] = 0
                    }
                }
            }

            return croppedSelection(from: baseMask, width: canvasWidth, height: canvasHeight, mode: incoming.mode)
        }
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

    static func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        guard adjustedActiveLayerPixels.count == snapshot.width * snapshot.height * 4 else { return nil }

        var composite = Data(count: snapshot.width * snapshot.height * 4)
        composite.withUnsafeMutableBytes { destinationBytes in
            guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for layer in snapshot.layers.sorted(by: { $0.index < $1.index }) where layer.visible {
                let sourceData = layer.index == activeLayerIndex ? adjustedActiveLayerPixels : layer.pixelData
                sourceData.withUnsafeBytes { sourceBytes in
                    guard let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    for pixelIndex in 0..<(snapshot.width * snapshot.height) {
                        let offset = pixelIndex * 4
                        blendPreviewPixel(
                            destination: destination + offset,
                            source: source + offset,
                            opacity: CGFloat(layer.opacity),
                            blendMode: layer.blendMode
                        )
                    }
                }
            }
        }
        return composite
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

    static func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        let originX = max(Int(selection.bounds.minX.rounded(.down)), 0)
        let originY = max(Int(selection.bounds.minY.rounded(.down)), 0)
        let width = min(selection.maskWidth, canvasWidth - originX)
        let height = min(selection.maskHeight, canvasHeight - originY)
        guard width > 0, height > 0 else { return result }

        selection.maskData.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let sourceIndex = (y * selection.maskWidth) + x
                    let destinationIndex = ((originY + y) * canvasWidth) + (originX + x)
                    result[destinationIndex] = source[sourceIndex]
                }
            }
        }
        return result
    }

    static func transformedLayerPixels(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection?,
        translation: CGSize,
        scale: CGFloat
    ) -> Data? {
        let dx = Int(translation.width.rounded())
        let dy = Int(translation.height.rounded())
        let clampedScale = min(max(scale, 0.2), 6.0)
        guard dx != 0 || dy != 0 || abs(clampedScale - 1.0) > 0.001 else { return nil }

        let expectedCount = canvasWidth * canvasHeight * 4
        guard source.count == expectedCount else { return nil }

        let sourceBytes = [UInt8](source)
        let mask = selection.map { expandedMask(from: $0, canvasWidth: canvasWidth, canvasHeight: canvasHeight) }
            ?? Self.alphaMask(from: sourceBytes, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        guard let bounds = Self.transformationBounds(selection: selection, sourceBytes: sourceBytes, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }

        var destination = sourceBytes
        for index in 0..<(canvasWidth * canvasHeight) where mask[index] != 0 {
            let pixelOffset = index * 4
            destination[pixelOffset] = 0
            destination[pixelOffset + 1] = 0
            destination[pixelOffset + 2] = 0
            destination[pixelOffset + 3] = 0
        }

        let anchor = CGPoint(x: bounds.midX, y: bounds.midY)
        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                let destinationPoint = CGPoint(
                    x: CGFloat(x) - translation.width,
                    y: CGFloat(y) - translation.height
                )
                let sourceX = ((destinationPoint.x - anchor.x) / clampedScale) + anchor.x
                let sourceY = ((destinationPoint.y - anchor.y) / clampedScale) + anchor.y
                let sourcePixelX = Int(sourceX.rounded())
                let sourcePixelY = Int(sourceY.rounded())
                guard sourcePixelX >= 0, sourcePixelX < canvasWidth, sourcePixelY >= 0, sourcePixelY < canvasHeight else {
                    continue
                }

                let sourceIndex = (sourcePixelY * canvasWidth) + sourcePixelX
                guard mask[sourceIndex] != 0 else { continue }
                let sourceOffset = sourceIndex * 4
                guard sourceBytes[sourceOffset + 3] != 0 else { continue }

                let destinationOffset = ((y * canvasWidth) + x) * 4
                destination[destinationOffset] = sourceBytes[sourceOffset]
                destination[destinationOffset + 1] = sourceBytes[sourceOffset + 1]
                destination[destinationOffset + 2] = sourceBytes[sourceOffset + 2]
                destination[destinationOffset + 3] = sourceBytes[sourceOffset + 3]
            }
        }

        return Data(destination)
    }

    static func transformedSelection(_ selection: CanvasSelection?, translation: CGSize, scale: CGFloat, canvasSize: CGSize) -> CanvasSelection? {
        guard let selection else { return nil }
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        let mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        let bounds = selection.bounds
        let anchor = CGPoint(x: bounds.midX, y: bounds.midY)
        let clampedScale = min(max(scale, 0.2), 6.0)
        var transformed = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)

        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                let destinationPoint = CGPoint(
                    x: CGFloat(x) - translation.width,
                    y: CGFloat(y) - translation.height
                )
                let sourceX = ((destinationPoint.x - anchor.x) / clampedScale) + anchor.x
                let sourceY = ((destinationPoint.y - anchor.y) / clampedScale) + anchor.y
                let sourcePixelX = Int(sourceX.rounded())
                let sourcePixelY = Int(sourceY.rounded())
                guard sourcePixelX >= 0, sourcePixelX < canvasWidth, sourcePixelY >= 0, sourcePixelY < canvasHeight else {
                    continue
                }

                let sourceIndex = (sourcePixelY * canvasWidth) + sourcePixelX
                guard mask[sourceIndex] != 0 else { continue }
                transformed[(y * canvasWidth) + x] = 255
            }
        }

        return croppedSelection(from: transformed, width: canvasWidth, height: canvasHeight, mode: selection.mode)
    }

    static func alphaMask(from sourceBytes: [UInt8], canvasWidth: Int, canvasHeight: Int) -> [UInt8] {
        var mask = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        for index in 0..<(canvasWidth * canvasHeight) {
            if sourceBytes[index * 4 + 3] != 0 {
                mask[index] = 255
            }
        }
        return mask
    }

    static func transformationBounds(
        selection: CanvasSelection?,
        sourceBytes: [UInt8],
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CGRect? {
        if let selection, !selection.isEmpty {
            return selection.bounds
        }

        var minX = canvasWidth
        var minY = canvasHeight
        var maxX = -1
        var maxY = -1
        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                if sourceBytes[((y * canvasWidth) + x) * 4 + 3] == 0 { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    static func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize) -> CanvasSelection? {
        guard points.count >= 3 else { return nil }

        let polygon = closedPolygon(points, canvasSize: canvasSize)
        guard polygon.count >= 3 else { return nil }

        let path = CGMutablePath()
        path.addLines(between: polygon)
        path.closeSubpath()
        let bounds = path.boundingBoxOfPath.integral
        guard !bounds.isNull, !bounds.isEmpty else { return nil }

        let minX = max(0, Int(bounds.minX.rounded(.down)))
        let minY = max(0, Int(bounds.minY.rounded(.down)))
        let maxX = max(minX + 1, Int(bounds.maxX.rounded(.up)))
        let maxY = max(minY + 1, Int(bounds.maxY.rounded(.up)))
        let width = maxX - minX
        let height = maxY - minY
        guard width > 0, height > 0 else { return nil }

        var mask = Data(count: width * height)
        mask.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let samplePoint = CGPoint(x: CGFloat(minX + x) + 0.5, y: CGFloat(minY + y) + 0.5)
                    if path.contains(samplePoint) {
                        base[(y * width) + x] = 255
                    }
                }
            }
        }

        let bytes = [UInt8](mask)
        return croppedSelection(from: bytes, width: width, height: height, mode: .lasso).map {
            CanvasSelection(
                bounds: CGRect(
                    x: CGFloat(minX) + $0.bounds.minX,
                    y: CGFloat(minY) + $0.bounds.minY,
                    width: $0.bounds.width,
                    height: $0.bounds.height
                ),
                maskWidth: $0.maskWidth,
                maskHeight: $0.maskHeight,
                maskData: $0.maskData,
                mode: .lasso
            )
        }
    }

    static func makeAutoSelection(
        at point: CGPoint,
        snapshot: MetalDocumentSnapshot?,
        layerIndex: Int,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> CanvasSelection? {
        guard
            let snapshot,
            let layer = snapshot.layers.first(where: { $0.index == layerIndex })
        else {
            return nil
        }

        let width = snapshot.width
        let height = snapshot.height
        guard width > 0, height > 0 else { return nil }

        let startX = min(max(Int(point.x.rounded()), 0), width - 1)
        let startY = min(max(Int(point.y.rounded()), 0), height - 1)
        let expectedCount = width * height * 4
        guard layer.pixelData.count == expectedCount else { return nil }

        var selected = [UInt8](repeating: 0, count: width * height)
        var queue: [(Int, Int)] = [(startX, startY)]
        var head = 0
        var minX = startX
        var minY = startY
        var maxX = startX
        var maxY = startY

        layer.pixelData.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let startOffset = ((startY * width) + startX) * 4
            let targetR = base[startOffset]
            let targetG = base[startOffset + 1]
            let targetB = base[startOffset + 2]
            let targetA = base[startOffset + 3]

            func matches(_ x: Int, _ y: Int) -> Bool {
                let offset = ((y * width) + x) * 4
                if thresholdMode == .color {
                    let dr = (Double(base[offset]) - Double(targetR)) / 255.0
                    let dg = (Double(base[offset + 1]) - Double(targetG)) / 255.0
                    let db = (Double(base[offset + 2]) - Double(targetB)) / 255.0
                    let distance = sqrt((dr * dr) + (dg * dg) + (db * db)) / sqrt(3.0)
                    return distance <= min(max(colorTolerance, 0.0), 1.0)
                }
                let sameColor =
                    base[offset] == targetR &&
                    base[offset + 1] == targetG &&
                    base[offset + 2] == targetB
                let alphaDistance = abs(Double(base[offset + 3]) - Double(targetA)) / 255.0
                return sameColor && alphaDistance <= min(max(opacityTolerance, 0.0), 1.0)
            }

            while head < queue.count {
                let (x, y) = queue[head]
                head += 1
                guard x >= 0, x < width, y >= 0, y < height else { continue }
                let index = (y * width) + x
                guard selected[index] == 0, matches(x, y) else { continue }

                selected[index] = 255
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)

                queue.append((x - 1, y))
                queue.append((x + 1, y))
                queue.append((x, y - 1))
                queue.append((x, y + 1))
            }
        }

        guard minX <= maxX, minY <= maxY else { return nil }
        let expandedMask = expandedSelectionMask(
            selected,
            width: width,
            height: height,
            expansion: max(0, expansion)
        )
        return croppedSelection(
            from: expandedMask,
            width: width,
            height: height,
            mode: .auto
        )
    }

    static func expandedSelectionMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8] {
        guard expansion > 0 else { return source }
        var result = source
        let selectedPoints = source.enumerated().compactMap { index, value -> (Int, Int)? in
            guard value != 0 else { return nil }
            return (index % width, index / width)
        }

        for (seedX, seedY) in selectedPoints {
            for dy in -expansion...expansion {
                for dx in -expansion...expansion {
                    guard abs(dx) + abs(dy) <= expansion else { continue }
                    let x = seedX + dx
                    let y = seedY + dy
                    guard x >= 0, x < width, y >= 0, y < height else { continue }
                    result[(y * width) + x] = 255
                }
            }
        }
        return result
    }

    static func croppedSelection(from source: [UInt8], width: Int, height: Int, mode: SelectionToolMode) -> CanvasSelection? {
        guard let first = source.firstIndex(where: { $0 != 0 }) else { return nil }
        var minX = first % width
        var maxX = minX
        var minY = first / width
        var maxY = minY

        for index in source.indices where source[index] != 0 {
            let x = index % width
            let y = index / width
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        let croppedWidth = (maxX - minX) + 1
        let croppedHeight = (maxY - minY) + 1
        guard croppedWidth > 0, croppedHeight > 0 else { return nil }

        var cropped = Data(count: croppedWidth * croppedHeight)
        cropped.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<croppedHeight {
                for x in 0..<croppedWidth {
                    let sourceIndex = ((minY + y) * width) + (minX + x)
                    base[(y * croppedWidth) + x] = source[sourceIndex]
                }
            }
        }

        return CanvasSelection(
            bounds: CGRect(x: minX, y: minY, width: croppedWidth, height: croppedHeight),
            maskWidth: croppedWidth,
            maskHeight: croppedHeight,
            maskData: cropped,
            mode: mode
        )
    }

    static func closedPolygon(_ points: [CGPoint], canvasSize: CGSize) -> [CGPoint] {
        let clamped = points.map {
            CGPoint(
                x: min(max($0.x, 0), max(canvasSize.width - 1, 0)),
                y: min(max($0.y, 0), max(canvasSize.height - 1, 0))
            )
        }
        guard let first = clamped.first, let last = clamped.last else { return [] }
        if hypot(first.x - last.x, first.y - last.y) <= 4 {
            return clamped
        }
        return clamped + [first]
    }

    static func writePNGToDocuments(data: Data) throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsDirectory = documentsDirectory.appendingPathComponent("atelierprime", isDirectory: true)
        try FileManager.default.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)
        let url = exportsDirectory.appendingPathComponent(exportFilename())
        try data.write(to: url, options: .atomic)
        return url
    }

    static func writePNGToTemporaryDirectory(data: Data) throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("atelierprime-export", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let url = temporaryDirectory.appendingPathComponent(exportFilename())
        try data.write(to: url, options: .atomic)
        return url
    }

    static func timelapseTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("atelierprime-export", isDirectory: true)
            .appendingPathComponent("timelapse", isDirectory: true)
    }

    static func appProjectsDirectory() throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documentsDirectory
            .appendingPathComponent("atelierprime-projects", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func projectURLInDocuments() throws -> URL {
        try appProjectsDirectory().appendingPathComponent(projectFilename(), isDirectory: true)
    }

    static func savedProjects() throws -> [SavedProjectSummary] {
        let fileManager = FileManager.default
        let directory = try appProjectsDirectory()
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try urls
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            }
            .map { url -> SavedProjectSummary in
                let loaded = try PaintDocumentSession.loadProject(from: url)
                let presentation = loaded.presentation()
                let previewData = loaded.compositePNGData(paperStyle: loaded.currentPaperStyle)
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                return SavedProjectSummary(
                    url: url,
                    name: url.deletingPathExtension().lastPathComponent,
                    modifiedAt: values?.contentModificationDate ?? .distantPast,
                    canvasSize: presentation.canvasSize,
                    layerCount: presentation.layerRows.count,
                    previewImageData: previewData
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    static func exportFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "atelierprime-\(formatter.string(from: Date())).png"
    }

    static func projectFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "atelierprime-\(formatter.string(from: Date())).atelier"
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
}
