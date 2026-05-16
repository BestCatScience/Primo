import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication

private struct CanvasPreviewRuntimeRenderer: CanvasPreviewRendering {
    let runtime: CanvasPreviewRuntime

    func eyedropperLoupeSurface(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        guard let source = RgbaSurface(width: canvasWidth, height: canvasHeight, data: sourcePixelData) else {
            return nil
        }
        return runtime.eyedropperLoupeSurface(
            source: source,
            centerX: centerX,
            centerY: centerY,
            gridSize: gridSize,
            paperStyle: paperStyle,
            blendWithPaper: blendWithPaper
        )
    }

    func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        guard let mask = MaskSurface(width: width, height: height, data: maskData) else {
            return nil
        }
        return runtime.selectionOverlaySurface(mask)
    }

    func compositePreviewImageData(snapshot: MetalDocumentSnapshot, activeLayerIndex: Int, adjustedActiveLayerPixels: Data) -> Data? {
        guard
            let geometry = PixelGeometry(width: snapshot.width, height: snapshot.height),
            let layerIndex = DocumentLayerMutationContext(
                revision: DocumentRevision(snapshot.revision),
                layerIndexes: snapshot.layers.map(\.index),
                folderIDs: [],
                isLayerLocked: { _ in false }
            ).existingLayerIndex(activeLayerIndex),
            let surface = RgbaSurface(geometry: geometry, data: adjustedActiveLayerPixels)
        else {
            return nil
        }
        return runtime.compositePreviewImageData(
            snapshot: snapshot,
            activeLayerIndex: layerIndex,
            adjustedActiveLayerPixels: surface
        )
    }

    func paperCompositeSurface(pixelData: Data, width: Int, height: Int, paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface? {
        guard let surface = RgbaSurface(width: width, height: height, data: pixelData) else {
            return nil
        }
        return runtime.paperCompositeSurface(surface, paperStyle: paperStyle)
    }

    func shapePreviewSurface(stroke: Stroke, style: PreviewStrokeStyle, canvasWidth: Int, canvasHeight: Int) -> DocumentCompositeSurface? {
        guard let canvasGeometry = PixelGeometry(width: canvasWidth, height: canvasHeight) else { return nil }
        return runtime.shapePreviewSurface(stroke: stroke, style: style, canvasGeometry: canvasGeometry)
    }

    func transformedTextPreviewSurface(textLayer: TextLayerData, canvasWidth: Int, canvasHeight: Int) -> DocumentCompositeSurface? {
        guard let canvasGeometry = PixelGeometry(width: canvasWidth, height: canvasHeight) else { return nil }
        return runtime.transformedTextPreviewSurface(textLayer: textLayer, canvasGeometry: canvasGeometry)
    }

    func transformedTextLayoutRect(textLayer: TextLayerData, canvasSize: CGSize) -> CGRect? {
        runtime.transformedTextLayoutRect(textLayer: textLayer, canvasSize: canvasSize)
    }
}

private struct CanvasPreviewRuntimeEyedropperSampler: CanvasEyedropperSampling {
    let runtime: CanvasPreviewRuntime

    func sampledColor(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        source: EyedropperSamplingSource,
        point: CGPoint,
        paperStyle: CanvasPaperStyle
    ) -> SampledColor? {
        guard let layerIndex = DocumentLayerMutationContext(
            revision: DocumentRevision(snapshot.revision),
            layerIndexes: snapshot.layers.map(\.index),
            folderIDs: [],
            isLayerLocked: { _ in false }
        ).existingLayerIndex(activeLayerIndex) else {
            return nil
        }
        return runtime.sampledColor(
            snapshot: snapshot,
            activeLayerIndex: layerIndex,
            source: source,
            point: point,
            paperStyle: paperStyle
        )
    }
}

private struct CanvasPreviewRuntimeSelectionMaskProcessor: SelectionMaskProcessing {
    let runtime: CanvasPreviewRuntime

    func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        guard let mask = MaskSurface(width: width, height: height, data: maskData) else {
            return nil
        }
        return runtime.selectionOverlaySurface(mask)
    }
}

extension DocumentPreviewRenderingCapability {
    var canvasPreviewRenderer: any CanvasPreviewRendering {
        CanvasPreviewRuntimeRenderer(runtime: previewRuntime)
    }

    var canvasEyedropperSampler: any CanvasEyedropperSampling {
        CanvasPreviewRuntimeEyedropperSampler(runtime: previewRuntime)
    }

    var selectionMaskProcessor: any SelectionMaskProcessing {
        CanvasPreviewRuntimeSelectionMaskProcessor(runtime: previewRuntime)
    }

    var canvasPresentationEnvironment: CanvasPresentationEnvironment {
        previewRuntime.presentationEnvironment()
    }
}
