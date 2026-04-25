import PrimoDocumentContracts
import PrimoDocumentDomain
import UIKit

final class CanvasTransformPreviewView: UIView {
    private let compositePreviewSurfaceView = CanvasPixelSurfaceView()
    private let shapePreviewSurfaceView = CanvasPixelSurfaceView()
    private let canvasImageRenderer: CanvasImageRenderer

    init(canvasImageRenderer: CanvasImageRenderer) {
        self.canvasImageRenderer = canvasImageRenderer
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        compositePreviewSurfaceView.alpha = 1.0
        compositePreviewSurfaceView.isHidden = true
        addSubview(compositePreviewSurfaceView)
        shapePreviewSurfaceView.alpha = 1.0
        shapePreviewSurfaceView.isHidden = true
        addSubview(shapePreviewSurfaceView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        activeStroke: Stroke?,
        strokePreviewCompositePixelData: Data?,
        adjustmentPreviewPixelData: Data?,
        selection: CanvasSelection?,
        paperStyle: CanvasPaperStyle,
        previewStyle: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        transformPreviewOffset: CGSize,
        transformPreviewScaleX: CGFloat,
        transformPreviewScaleY: CGFloat,
        transformPreviewRotationDegrees: Double,
        transformPivot: CGPoint?,
        transformMode: CanvasTransformMode,
        transformQuadOffsets: TransformQuadOffsets,
        activeTextLayer: TextLayerData?,
        geometry viewport: CanvasViewportGeometry,
        renderSurfaceView: CanvasRenderSurfaceView
    ) {
        frame = viewport.bounds
        updateStrokePreview(
            activeStroke,
            style: previewStyle,
            currentTool: currentTool,
            snapshot: snapshot,
            geometry: viewport
        )
        updateTransformPreview(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            strokePreviewCompositePixelData: strokePreviewCompositePixelData,
            adjustmentPreviewPixelData: adjustmentPreviewPixelData,
            selection: selection,
            paperStyle: paperStyle,
            currentTool: currentTool,
            transformPreviewOffset: transformPreviewOffset,
            transformPreviewScaleX: transformPreviewScaleX,
            transformPreviewScaleY: transformPreviewScaleY,
            transformPreviewRotationDegrees: transformPreviewRotationDegrees,
            transformPivot: transformPivot,
            transformMode: transformMode,
            transformQuadOffsets: transformQuadOffsets,
            activeTextLayer: activeTextLayer,
            geometry: viewport,
            renderSurfaceView: renderSurfaceView
        )
    }

    private func updateStrokePreview(
        _ stroke: Stroke?,
        style: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        snapshot: MetalDocumentSnapshot?,
        geometry viewport: CanvasViewportGeometry
    ) {
        guard let stroke, currentTool == .shape, stroke.points.count >= 2 else {
            shapePreviewSurfaceView.update(surface: nil)
            return
        }
        guard let snapshot,
              let surface = canvasImageRenderer.shapePreviewSurface(
                stroke: stroke,
                style: style,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height
              ) else {
            shapePreviewSurfaceView.update(surface: nil)
            return
        }
        shapePreviewSurfaceView.update(surface: surface)
        shapePreviewSurfaceView.frame = viewport.contentRect
    }

    private func updateTransformPreview(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        strokePreviewCompositePixelData: Data?,
        adjustmentPreviewPixelData: Data?,
        selection: CanvasSelection?,
        paperStyle: CanvasPaperStyle,
        currentTool: StudioToolKind,
        transformPreviewOffset: CGSize,
        transformPreviewScaleX: CGFloat,
        transformPreviewScaleY: CGFloat,
        transformPreviewRotationDegrees: Double,
        transformPivot: CGPoint?,
        transformMode: CanvasTransformMode,
        transformQuadOffsets: TransformQuadOffsets,
        activeTextLayer: TextLayerData?,
        geometry viewport: CanvasViewportGeometry,
        renderSurfaceView: CanvasRenderSurfaceView
    ) {
        guard
            currentTool == .move,
            transformPreviewOffset != .zero ||
            abs(transformPreviewScaleX - 1.0) > 0.001 ||
            abs(transformPreviewScaleY - 1.0) > 0.001 ||
            abs(transformPreviewRotationDegrees) > 0.001 ||
            !transformQuadOffsets.isZero,
            let snapshot
        else {
            if
                let snapshot,
                let strokePreviewCompositePixelData,
                let surface = canvasImageRenderer.paperCompositeSurface(
                    pixelData: strokePreviewCompositePixelData,
                    width: snapshot.width,
                    height: snapshot.height,
                    paperStyle: paperStyle
                )
            {
                compositePreviewSurfaceView.update(surface: surface)
                compositePreviewSurfaceView.frame = viewport.contentRect
                renderSurfaceView.isHidden = true
                return
            }

            if
                let snapshot,
                let adjustmentPreviewPixelData,
                let surface = canvasImageRenderer.paperCompositeSurface(
                    pixelData: adjustmentPreviewPixelData,
                    width: snapshot.width,
                    height: snapshot.height,
                    paperStyle: paperStyle
                )
            {
                compositePreviewSurfaceView.update(surface: surface)
                compositePreviewSurfaceView.frame = viewport.contentRect
                renderSurfaceView.isHidden = true
                return
            }

            compositePreviewSurfaceView.update(surface: nil)
            compositePreviewSurfaceView.frame = .zero
            renderSurfaceView.isHidden = false
            return
        }

        guard let surface = makeCompositePreviewSurface(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            selection: selection,
            paperStyle: paperStyle,
            transformPreviewOffset: transformPreviewOffset,
            transformPreviewScaleX: transformPreviewScaleX,
            transformPreviewScaleY: transformPreviewScaleY,
            transformPreviewRotationDegrees: transformPreviewRotationDegrees,
            transformPivot: transformPivot,
            transformMode: transformMode,
            transformQuadOffsets: transformQuadOffsets,
            activeTextLayer: activeTextLayer
        ) else {
            compositePreviewSurfaceView.update(surface: nil)
            compositePreviewSurfaceView.frame = .zero
            renderSurfaceView.isHidden = false
            return
        }

        compositePreviewSurfaceView.update(surface: surface)
        compositePreviewSurfaceView.frame = viewport.contentRect
        renderSurfaceView.isHidden = true
    }

    private func makeCompositePreviewSurface(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        selection: CanvasSelection?,
        paperStyle: CanvasPaperStyle,
        transformPreviewOffset: CGSize,
        transformPreviewScaleX: CGFloat,
        transformPreviewScaleY: CGFloat,
        transformPreviewRotationDegrees: Double,
        transformPivot: CGPoint?,
        transformMode: CanvasTransformMode,
        transformQuadOffsets: TransformQuadOffsets,
        activeTextLayer: TextLayerData?
    ) -> DocumentCompositeSurface? {
        guard let activeLayer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else {
            return nil
        }

        let transformedLayerData: Data?
        if let activeTextLayer, selection == nil {
            transformedLayerData = makeTransformedTextLayerPreview(
                textLayer: activeTextLayer,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                transformPreviewOffset: transformPreviewOffset,
                transformPreviewScaleX: transformPreviewScaleX,
                transformPreviewScaleY: transformPreviewScaleY,
                transformPreviewRotationDegrees: transformPreviewRotationDegrees
            )
        } else {
            transformedLayerData = AppFeature.transformedLayerPixels(
                source: activeLayer.pixelData,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                selection: selection,
                translation: transformPreviewOffset,
                scaleX: transformPreviewScaleX,
                scaleY: transformPreviewScaleY,
                rotationDegrees: transformPreviewRotationDegrees,
                pivot: transformPivot,
                mode: .freeform,
                quadOffsets: activeTextLayer == nil ? transformQuadOffsets : .zero
            ) ?? activeLayer.pixelData
        }
        guard let transformedLayerData else { return nil }

        let composite = canvasImageRenderer.compositePreviewImageData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: transformedLayerData
        ) ?? fallbackComposite(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            transformedLayerData: transformedLayerData
        )

        return canvasImageRenderer.paperCompositeSurface(
            pixelData: composite,
            width: snapshot.width,
            height: snapshot.height,
            paperStyle: paperStyle
        )
    }

    private func makeTransformedTextLayerPreview(
        textLayer: TextLayerData,
        canvasWidth: Int,
        canvasHeight: Int,
        transformPreviewOffset: CGSize,
        transformPreviewScaleX: CGFloat,
        transformPreviewScaleY: CGFloat,
        transformPreviewRotationDegrees: Double
    ) -> Data? {
        var transformed = textLayer
        transformed.position = CGPoint(
            x: transformed.position.x + transformPreviewOffset.width,
            y: transformed.position.y + transformPreviewOffset.height
        )
        transformed.scale = min(max(transformed.scale * Double((transformPreviewScaleX + transformPreviewScaleY) * 0.5), 0.2), 6.0)
        transformed.rotationDegrees += transformPreviewRotationDegrees
        return canvasImageRenderer.transformedTextPreviewSurface(
            textLayer: transformed,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )?.pixelData
    }

    private func fallbackComposite(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        transformedLayerData: Data
    ) -> Data {
        var composite = Data(count: snapshot.width * snapshot.height * 4)
        var clipMask = [CGFloat](repeating: 0, count: snapshot.width * snapshot.height)
        composite.withUnsafeMutableBytes { destinationBytes in
            guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for layer in snapshot.layers.sorted(by: { $0.index < $1.index }) where layer.visible {
                let sourceData = layer.index == activeLayerIndex ? transformedLayerData : layer.pixelData
                sourceData.withUnsafeBytes { sourceBytes in
                    guard let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    for pixelIndex in 0..<(snapshot.width * snapshot.height) {
                        let offset = pixelIndex * 4
                        let alphaOffset = offset + 3
                        let baseAlpha = (CGFloat(source[alphaOffset]) / 255.0) * CGFloat(layer.opacity)
                        let effectiveAlpha = layer.isClipped ? (baseAlpha * clipMask[pixelIndex]) : baseAlpha
                        if !layer.isClipped {
                            clipMask[pixelIndex] = baseAlpha
                        }
                        blendPixel(
                            destination: destination + offset,
                            source: source + offset,
                            opacity: effectiveAlpha,
                            blendMode: layer.blendMode
                        )
                    }
                }
            }
        }
        return composite
    }

    private func blendPixel(
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
        let blended = blendColor(backdrop: (dstR, dstG, dstB), source: (srcR, srcG, srcB), blendMode: blendMode)

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

    private func blendColor(
        backdrop: (r: CGFloat, g: CGFloat, b: CGFloat),
        source: (r: CGFloat, g: CGFloat, b: CGFloat),
        blendMode: LayerBlendMode
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        if blendMode == .darkerColor {
            return luminosity(source) < luminosity(backdrop) ? source : backdrop
        }
        if blendMode == .lighterColor {
            return luminosity(source) > luminosity(backdrop) ? source : backdrop
        }
        if blendMode == .hue {
            var output = source
            output = setSaturation(output, saturation(backdrop))
            output = setLuminosity(output, luminosity(backdrop))
            return (r: max(0, min(1, output.r)), g: max(0, min(1, output.g)), b: max(0, min(1, output.b)))
        }
        if blendMode == .saturation {
            var output = backdrop
            output = setSaturation(output, saturation(source))
            output = setLuminosity(output, luminosity(backdrop))
            return (r: max(0, min(1, output.r)), g: max(0, min(1, output.g)), b: max(0, min(1, output.b)))
        }
        if blendMode == .color {
            var output = source
            output = setSaturation(output, saturation(source))
            output = setLuminosity(output, luminosity(backdrop))
            return (r: max(0, min(1, output.r)), g: max(0, min(1, output.g)), b: max(0, min(1, output.b)))
        }
        if blendMode == .luminosity {
            var output = backdrop
            output = setLuminosity(output, luminosity(source))
            return (r: max(0, min(1, output.r)), g: max(0, min(1, output.g)), b: max(0, min(1, output.b)))
        }
        return (
            r: max(0, min(1, blendChannel(backdrop: backdrop.r, source: source.r, blendMode: blendMode))),
            g: max(0, min(1, blendChannel(backdrop: backdrop.g, source: source.g, blendMode: blendMode))),
            b: max(0, min(1, blendChannel(backdrop: backdrop.b, source: source.b, blendMode: blendMode)))
        )
    }

    private func blendChannel(backdrop: CGFloat, source: CGFloat, blendMode: LayerBlendMode) -> CGFloat {
        switch blendMode {
        case .normal: return source
        case .darken: return min(backdrop, source)
        case .multiply: return backdrop * source
        case .colorBurn: return source <= 0 ? 0 : max(0, 1 - ((1 - backdrop) / max(0.001, source)))
        case .linearBurn: return max(0, backdrop + source - 1)
        case .subtract: return max(0, backdrop - source)
        case .lighten: return max(backdrop, source)
        case .screen: return 1 - ((1 - backdrop) * (1 - source))
        case .add: return min(1, backdrop + source)
        case .colorDodge: return source >= 1 ? 1 : min(1, backdrop / max(0.001, 1 - source))
        case .glowDodge: return source >= 1 ? 1 : min(1, backdrop / max(0.0005, 1 - (source * 0.92)))
        case .overlay: return backdrop <= 0.5 ? (2 * backdrop * source) : (1 - 2 * (1 - backdrop) * (1 - source))
        case .softLight:
            return source <= 0.5
                ? (backdrop - ((1 - 2 * source) * backdrop * (1 - backdrop)))
                : (backdrop + ((2 * source - 1) * ((backdrop <= 0.25)
                    ? ((((16 * backdrop - 12) * backdrop) + 4) * backdrop)
                    : sqrt(backdrop)) - backdrop))
        case .hardLight: return source <= 0.5 ? (2 * backdrop * source) : (1 - 2 * (1 - backdrop) * (1 - source))
        case .difference: return abs(backdrop - source)
        case .vividLight:
            return source <= 0.5
                ? blendChannel(backdrop: backdrop, source: 2 * source, blendMode: .colorBurn)
                : blendChannel(backdrop: backdrop, source: 2 * (source - 0.5), blendMode: .colorDodge)
        case .linearLight: return max(0, min(1, backdrop + 2 * source - 1))
        case .pinLight: return source <= 0.5 ? min(backdrop, 2 * source) : max(backdrop, 2 * (source - 0.5))
        case .hardMix: return blendChannel(backdrop: backdrop, source: source, blendMode: .vividLight) < 0.5 ? 0 : 1
        case .exclusion: return backdrop + source - (2 * backdrop * source)
        case .darkerColor, .lighterColor, .hue, .saturation, .color, .luminosity: return source
        case .divide: return min(1, backdrop / max(0.001, source))
        case .addGlow: return min(1, backdrop + source * 1.35)
        }
    }

    private func luminosity(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        (0.3 * color.r) + (0.59 * color.g) + (0.11 * color.b)
    }

    private func saturation(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        max(color.r, color.g, color.b) - min(color.r, color.g, color.b)
    }

    private func clipColor(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let lum = luminosity(color)
        let minimum = min(color.r, color.g, color.b)
        let maximum = max(color.r, color.g, color.b)
        var output = color

        if minimum < 0 {
            let scale = lum / max(0.001, lum - minimum)
            output = (
                r: lum + ((output.r - lum) * scale),
                g: lum + ((output.g - lum) * scale),
                b: lum + ((output.b - lum) * scale)
            )
        }

        if maximum > 1 {
            let adjustedMaximum = max(output.r, output.g, output.b)
            let scale = (1 - lum) / max(0.001, adjustedMaximum - lum)
            output = (
                r: lum + ((output.r - lum) * scale),
                g: lum + ((output.g - lum) * scale),
                b: lum + ((output.b - lum) * scale)
            )
        }

        return output
    }

    private func setLuminosity(_ color: (r: CGFloat, g: CGFloat, b: CGFloat), _ lum: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let delta = lum - luminosity(color)
        return clipColor((r: color.r + delta, g: color.g + delta, b: color.b + delta))
    }

    private func setSaturation(_ color: (r: CGFloat, g: CGFloat, b: CGFloat), _ sat: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let original = [color.r, color.g, color.b]
        var components = original
        var minIndex = 0
        var midIndex = 1
        var maxIndex = 2

        if original[minIndex] > original[midIndex] { swap(&minIndex, &midIndex) }
        if original[midIndex] > original[maxIndex] { swap(&midIndex, &maxIndex) }
        if original[minIndex] > original[midIndex] { swap(&minIndex, &midIndex) }

        if original[maxIndex] > original[minIndex] {
            components[midIndex] = ((original[midIndex] - original[minIndex]) * sat) / (original[maxIndex] - original[minIndex])
            components[maxIndex] = sat
        } else {
            components[midIndex] = 0
            components[maxIndex] = 0
        }
        components[minIndex] = 0

        return (r: components[0], g: components[1], b: components[2])
    }
}
