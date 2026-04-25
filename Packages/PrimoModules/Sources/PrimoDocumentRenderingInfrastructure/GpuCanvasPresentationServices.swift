import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentContracts
import PrimoDocumentDomain
import simd

public struct GpuCanvasPreviewRenderer: CanvasPreviewRendering {
    private let gpuOperations: DocumentGpuOperationGateway

    public init(gpuOperations: DocumentGpuOperationGateway = DocumentGpuOperationGatewayFactory.live()) {
        self.gpuOperations = gpuOperations
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
        guard let rgba = gpuOperations.eyedropperLoupeRGBA(
            sourcePixelData,
            canvasWidth,
            canvasHeight,
            centerX,
            centerY,
            gridSize,
            paperStyle,
            blendWithPaper
        ) else {
            return nil
        }
        return DocumentCompositeSurface(width: gridSize, height: gridSize, pixelData: rgba)
    }

    public func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        guard let rgba = gpuOperations.selectionOverlayRGBA(maskData, width, height) else {
            return nil
        }
        return DocumentCompositeSurface(width: width, height: height, pixelData: rgba)
    }

    public func compositePreviewImageData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        gpuOperations.compositedPreviewPixelData(snapshot, activeLayerIndex, adjustedActiveLayerPixels)
    }

    public func paperCompositeSurface(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> DocumentCompositeSurface? {
        guard let rgba = gpuOperations.compositedPaperPreviewRGBA(pixelData, width, height, paperStyle) else {
            return nil
        }
        return DocumentCompositeSurface(width: width, height: height, pixelData: rgba)
    }

    public func shapePreviewSurface(
        stroke: Stroke,
        style: PreviewStrokeStyle,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        let samples = stroke.points.map(\.stylusSample)
        guard !samples.isEmpty else { return nil }
        return gpuOperations.shapePreviewSurface(
            samples,
            brushSettings(for: style),
            canvasWidth,
            canvasHeight
        )
    }

    public func transformedTextPreviewSurface(
        textLayer: TextLayerData,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        gpuOperations.textLayerSurface(
            textLayer,
            CGSize(width: canvasWidth, height: canvasHeight)
        )
    }

    public func transformedTextLayoutRect(textLayer: TextLayerData, canvasSize: CGSize) -> CGRect? {
        gpuOperations.textLayoutRect(textLayer, canvasSize)
    }

    private func brushSettings(for style: PreviewStrokeStyle) -> BrushRuntimeSettings {
        let components = style.color.components ?? [0, 0, 0, 1]
        let red = UInt8(max(0, min(255, Int((components[safe: 0] ?? 0) * 255.0))))
        let green = UInt8(max(0, min(255, Int((components[safe: 1] ?? 0) * 255.0))))
        let blue = UInt8(max(0, min(255, Int((components[safe: 2] ?? 0) * 255.0))))
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
            red: red,
            green: green,
            blue: blue,
            isEraser: style.isEraser
        )
    }
}

public struct GpuLayerTransformProcessor: LayerTransformProcessing {
    private let gpuOperations: DocumentGpuOperationGateway

    public init(gpuOperations: DocumentGpuOperationGateway = DocumentGpuOperationGatewayFactory.live()) {
        self.gpuOperations = gpuOperations
    }

    public func transformedLayerPixels(
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
                let alphaMask = gpuOperations.alphaMask(source, canvasWidth, canvasHeight),
                let cropped = gpuOperations.croppedSelectionMask(alphaMask, canvasWidth, canvasHeight)
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

        return gpuOperations.transformedLayerPixelData(
            source,
            canvasWidth,
            canvasHeight,
            mask,
            translation,
            scaleX,
            scaleY,
            rotationDegrees,
            resolved.pivot,
            resolved.source,
            resolved.effective,
            mode == .freeform && !quadOffsets.isZero
        )
    }

    public func transformationBounds(
        selection: CanvasSelection?,
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CGRect? {
        if let selection, !selection.isEmpty {
            return selection.bounds
        }
        guard
            let alphaMask = gpuOperations.alphaMask(pixelData, canvasWidth, canvasHeight),
            let cropped = gpuOperations.croppedSelectionMask(alphaMask, canvasWidth, canvasHeight)
        else {
            return nil
        }
        return cropped.bounds
    }

    private func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8]? {
        guard selection.maskWidth > 0, selection.maskHeight > 0 else { return nil }
        if selection.maskWidth == canvasWidth,
           selection.maskHeight == canvasHeight,
           selection.bounds.origin == .zero {
            return [UInt8](selection.maskData)
        }
        return gpuOperations.expandedSelectionMask(
            selection.maskData,
            selection.maskWidth,
            selection.maskHeight,
            canvasWidth,
            canvasHeight,
            Int(selection.bounds.origin.x.rounded(.down)),
            Int(selection.bounds.origin.y.rounded(.down))
        )
    }
}

private extension Array where Element == CGFloat {
    subscript(safe index: Int) -> CGFloat? {
        indices.contains(index) ? self[index] : nil
    }
}
