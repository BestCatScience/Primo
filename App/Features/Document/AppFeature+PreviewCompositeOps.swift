import CoreGraphics
import Foundation

extension AppFeature {
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
