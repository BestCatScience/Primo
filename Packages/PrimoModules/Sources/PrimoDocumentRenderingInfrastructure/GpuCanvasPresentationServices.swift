import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoBrushRuntimeContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import simd

public struct GpuCanvasPreviewRenderer: CanvasPreviewRendering, SelectionMaskProcessing {
    private let operations: DocumentCanvasPreviewRenderingOperations

    public init(operations: DocumentCanvasPreviewRenderingOperations) {
        self.operations = operations
    }

    public init(gpuOperations: DocumentGpuOperationGateway) {
        self.init(operations: gpuOperations.canvasPreviewRenderingOperations)
    }

    public func eyedropperLoupeSurface(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        guard let rgba = operations.eyedropperLoupeRGBA(
            sourcePixelData,
            canvasWidth,
            canvasHeight,
            centerX,
            centerY,
            gridSize,
            paperStyle,
            blendWithPaper
        ).value else {
            return nil
        }
        return DocumentCompositeSurface(unsafeUncheckedWidth: gridSize, height: gridSize, pixelData: rgba)
    }

    public func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        guard let rgba = operations.selectionOverlayRGBA(maskData, width, height).value else {
            return nil
        }
        return DocumentCompositeSurface(unsafeUncheckedWidth: width, height: height, pixelData: rgba)
    }

    public func compositePreviewImageData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        operations.compositedPreviewPixelData(snapshot, activeLayerIndex, adjustedActiveLayerPixels).value
    }

    public func paperCompositeSurface(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> DocumentCompositeSurface? {
        guard let rgba = operations.compositedPaperPreviewRGBA(pixelData, width, height, paperStyle).value else {
            return nil
        }
        return DocumentCompositeSurface(unsafeUncheckedWidth: width, height: height, pixelData: rgba)
    }

    public func shapePreviewSurface(
        stroke: Stroke,
        style: PreviewStrokeStyle,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        let samples = stroke.points.map(\.stylusSample)
        guard !samples.isEmpty else { return nil }
        return operations.shapePreviewSurface(
            samples,
            brushSettings(for: style),
            canvasWidth,
            canvasHeight
        ).value
    }

    public func transformedTextPreviewSurface(
        textLayer: TextLayerData,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        operations.textLayerSurface(
            textLayer,
            CGSize(width: canvasWidth, height: canvasHeight)
        ).value
    }

    public func transformedTextLayoutRect(textLayer: TextLayerData, canvasSize: CGSize) -> CGRect? {
        operations.textLayoutRect(textLayer, canvasSize)
    }

    private func brushSettings(for style: PreviewStrokeStyle) -> BrushRuntimeSettings {
        let color = rgbaComponents(for: style.color)
        return BrushRuntimeSettings(
            tipKind: style.tipKind,
            radius: Double(style.radius),
            opacity: Double(style.opacity),
            hardness: Double(style.hardness),
            roundness: Double(style.roundness),
            angle: Double(style.angle),
            angleMode: style.followsStrokeAngle ? .strokeDirection : .fixed,
            stampSpacing: 0.16,
            spacingJitter: 0,
            scatterLateral: 0,
            scatterLinear: 0,
            count: 1,
            countJitter: 0,
            angleJitter: 0,
            roundnessJitter: 0,
            textureMode: .off,
            textureStrength: 0,
            flow: Double(style.flow),
            customTip: style.customTip,
            pressureSensitivity: Double(style.pressureSensitivity),
            stabilization: Double(style.stabilization),
            red: color.red,
            green: color.green,
            blue: color.blue,
            isEraser: style.isEraser
        )
    }

    private func rgbaComponents(for color: CGColor) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let components = convertedRGBAComponents(for: color) ?? fallbackRGBAComponents(for: color)
        return (
            red: byte(from: components.red),
            green: byte(from: components.green),
            blue: byte(from: components.blue),
            alpha: byte(from: components.alpha)
        )
    }

    private func convertedRGBAComponents(for color: CGColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let converted = color.converted(to: colorSpace, intent: .defaultIntent, options: nil),
            let components = converted.components,
            components.count >= 3
        else {
            return nil
        }
        return (
            red: components[0],
            green: components[1],
            blue: components[2],
            alpha: components[safe: 3] ?? converted.alpha
        )
    }

    private func fallbackRGBAComponents(for color: CGColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        guard let components = color.components else {
            return (0, 0, 0, color.alpha)
        }
        switch components.count {
        case 2:
            return (components[0], components[0], components[0], components[1])
        case 3:
            return (components[0], components[1], components[2], color.alpha)
        default:
            return (
                components[safe: 0] ?? 0,
                components[safe: 1] ?? 0,
                components[safe: 2] ?? 0,
                components[safe: 3] ?? color.alpha
            )
        }
    }

    private func byte(from component: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, Int((component * 255.0).rounded()))))
    }
}

public struct GpuCanvasEyedropperSampler: CanvasEyedropperSampling {
    public init() {}

    public func sampledColor(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        source: EyedropperSamplingSource,
        point: CGPoint,
        paperStyle: CanvasPaperStyle
    ) -> SampledColor? {
        guard snapshot.width > 0, snapshot.height > 0 else { return nil }
        let x = min(max(Int(point.x.rounded()), 0), snapshot.width - 1)
        let y = min(max(Int(point.y.rounded()), 0), snapshot.height - 1)

        switch source {
        case .activeLayer:
            guard let layer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else {
                return nil
            }
            return samplePixel(in: layer.pixelData, width: snapshot.width, height: snapshot.height, x: x, y: y)

        case .canvas:
            guard let foreground = samplePixel(in: snapshot.compositePixelData, width: snapshot.width, height: snapshot.height, x: x, y: y) else {
                return nil
            }
            guard !paperStyle.isTransparent else { return foreground }
            return blend(foreground: foreground, paperStyle: paperStyle)
        }
    }

    private func samplePixel(in pixelData: Data, width: Int, height: Int, x: Int, y: Int) -> SampledColor? {
        guard width > 0, height > 0, pixelData.count == width * height * 4 else { return nil }
        let offset = ((y * width) + x) * 4
        return pixelData.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            return SampledColor(
                red: source[offset],
                green: source[offset + 1],
                blue: source[offset + 2],
                alpha: source[offset + 3]
            )
        }
    }

    private func blend(foreground: SampledColor, paperStyle: CanvasPaperStyle) -> SampledColor {
        let alpha = CGFloat(foreground.alpha) / 255.0
        let background = SampledColor(
            red: UInt8(max(0, min(255, Int((CGFloat(paperStyle.red) * 255.0).rounded())))),
            green: UInt8(max(0, min(255, Int((CGFloat(paperStyle.green) * 255.0).rounded())))),
            blue: UInt8(max(0, min(255, Int((CGFloat(paperStyle.blue) * 255.0).rounded())))),
            alpha: 255
        )
        return SampledColor(
            red: blendedChannel(source: foreground.red, background: background.red, alpha: alpha),
            green: blendedChannel(source: foreground.green, background: background.green, alpha: alpha),
            blue: blendedChannel(source: foreground.blue, background: background.blue, alpha: alpha),
            alpha: 255
        )
    }

    private func blendedChannel(source: UInt8, background: UInt8, alpha: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, Int((CGFloat(source) * alpha + CGFloat(background) * (1 - alpha)).rounded()))))
    }
}

public struct GpuLayerTransformProcessor: LayerTransformProcessing {
    private let layerTransformOperations: DocumentLayerTransformOperations
    private let selectionOperations: DocumentSelectionMaskOperations

    public init(
        layerTransformOperations: DocumentLayerTransformOperations,
        selectionOperations: DocumentSelectionMaskOperations
    ) {
        self.layerTransformOperations = layerTransformOperations
        self.selectionOperations = selectionOperations
    }

    public init(gpuOperations: DocumentGpuOperationGateway) {
        self.init(
            layerTransformOperations: gpuOperations.layerTransformOperations,
            selectionOperations: gpuOperations.selectionMaskOperations
        )
    }

    public func transformedLayerPixels(
        source: RgbaSurface,
        selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets
    ) -> Data? {
        transformedLayerPixels(
            source: source.data,
            canvasWidth: source.width,
            canvasHeight: source.height,
            selection: selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets
        )
    }

    package func transformedLayerPixels(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets
    ) -> Data? {
        guard
            translation != .zero ||
            abs(scaleX - 1.0) > 0.001 ||
            abs(scaleY - 1.0) > 0.001 ||
            abs(rotationDegrees) > 0.001 ||
            !quadOffsets.isZero
        else {
            return nil
        }

        let expectedCount = canvasWidth * canvasHeight * 4
        guard source.count == expectedCount else { return nil }

        let mask: [UInt8]?
        let bounds: CGRect
        if let selection {
            guard let expanded = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
                return nil
            }
            mask = expanded
            bounds = selection.bounds
        } else {
            guard
                let alphaMask = selectionOperations.alphaMask(source, canvasWidth, canvasHeight).value,
                let cropped = selectionOperations.croppedSelectionMask(alphaMask, canvasWidth, canvasHeight)
            else {
                return nil
            }
            mask = alphaMask
            bounds = cropped.bounds
        }

        let resolved = CanvasTransformGeometry.effectiveTransformQuad(
            bounds: bounds,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets
        )

        return layerTransformOperations.transformedLayerPixelData(
            TransformedLayerPixelDataRequest(
                source: source,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                expandedSelectionMask: mask,
                translation: translation,
                scaleX: scaleX,
                scaleY: scaleY,
                rotationDegrees: rotationDegrees,
                pivot: resolved.pivot,
                sourceQuad: resolved.source,
                destinationQuad: resolved.effective,
                usesFreeformQuad: mode == .freeform && !quadOffsets.isZero
            )
        ).value
    }

    public func transformationBounds(
        selection: CanvasSelection?,
        surface: RgbaSurface
    ) -> CGRect? {
        transformationBounds(
            selection: selection,
            pixelData: surface.data,
            canvasWidth: surface.width,
            canvasHeight: surface.height
        )
    }

    package func transformationBounds(
        selection: CanvasSelection?,
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CGRect? {
        if let selection, !selection.isEmpty {
            return selection.bounds
        }
        guard
            let alphaMask = selectionOperations.alphaMask(pixelData, canvasWidth, canvasHeight).value,
            let cropped = selectionOperations.croppedSelectionMask(alphaMask, canvasWidth, canvasHeight)
        else {
            return nil
        }
        return cropped.bounds
    }

    public func transformedSelection(
        _ selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets,
        canvasGeometry: PixelGeometry
    ) -> CanvasSelection? {
        guard let selection else { return nil }
        let canvasWidth = canvasGeometry.width
        let canvasHeight = canvasGeometry.height
        let selectionWorkflow = SelectionWorkflowService(operations: selectionOperations)
        guard let mask = selectionWorkflow.expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }
        let resolved = CanvasTransformGeometry.effectiveTransformQuad(
            bounds: selection.bounds,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets
        )
        guard let transformed = selectionOperations.transformedSelectionMask(
            TransformedSelectionMaskRequest(
                expandedSelectionMask: mask,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                translation: translation,
                scaleX: scaleX,
                scaleY: scaleY,
                rotationDegrees: rotationDegrees,
                pivot: resolved.pivot,
                sourceQuad: resolved.source,
                destinationQuad: resolved.effective,
                usesFreeformQuad: mode == .freeform && !quadOffsets.isZero
            )
        ).value else {
            return nil
        }

        return selectionWorkflow.croppedSelection(from: transformed, width: canvasWidth, height: canvasHeight, mode: selection.mode)
    }

    private func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8]? {
        SelectionWorkflowService(operations: selectionOperations)
            .expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
    }
}

private extension Array where Element == CGFloat {
    subscript(safe index: Int) -> CGFloat? {
        indices.contains(index) ? self[index] : nil
    }
}
