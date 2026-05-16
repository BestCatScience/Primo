import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRenderingInfrastructure

package struct GpuCanvasPreviewRenderer: CanvasPreviewRendering, SelectionMaskProcessing {
    private let renderer: PrimoDocumentRenderingInfrastructure.GpuCanvasPreviewRenderer

    package init(operations: DocumentCanvasPreviewRenderingOperations) {
        self.renderer = PrimoDocumentRenderingInfrastructure.GpuCanvasPreviewRenderer(operations: operations)
    }

    package init(gpuOperations: DocumentGpuOperationGateway) {
        self.init(operations: gpuOperations.canvasPreviewRenderingOperations)
    }

    package func eyedropperLoupeSurface(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        renderer.eyedropperLoupeSurface(
            sourcePixelData: sourcePixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: centerX,
            centerY: centerY,
            gridSize: gridSize,
            paperStyle: paperStyle,
            blendWithPaper: blendWithPaper
        )
    }

    package func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        renderer.selectionOverlaySurface(maskData: maskData, width: width, height: height)
    }

    package func compositePreviewImageData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        renderer.compositePreviewImageData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    package func paperCompositeSurface(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> DocumentCompositeSurface? {
        renderer.paperCompositeSurface(pixelData: pixelData, width: width, height: height, paperStyle: paperStyle)
    }

    package func shapePreviewSurface(
        stroke: Stroke,
        style: PreviewStrokeStyle,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        renderer.shapePreviewSurface(stroke: stroke, style: style, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
    }

    package func transformedTextPreviewSurface(
        textLayer: TextLayerData,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        renderer.transformedTextPreviewSurface(textLayer: textLayer, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
    }

    package func transformedTextLayoutRect(textLayer: TextLayerData, canvasSize: CGSize) -> CGRect? {
        renderer.transformedTextLayoutRect(textLayer: textLayer, canvasSize: canvasSize)
    }
}

package struct GpuCanvasEyedropperSampler: CanvasEyedropperSampling {
    private let sampler = PrimoDocumentRenderingInfrastructure.GpuCanvasEyedropperSampler()

    package init() {}

    package func sampledColor(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        source: EyedropperSamplingSource,
        point: CGPoint,
        paperStyle: CanvasPaperStyle
    ) -> SampledColor? {
        sampler.sampledColor(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            source: source,
            point: point,
            paperStyle: paperStyle
        )
    }
}

package struct GpuLayerTransformProcessor: LayerTransformProcessing {
    private let processor: PrimoDocumentRenderingInfrastructure.GpuLayerTransformProcessor

    package init(
        layerTransformOperations: DocumentLayerTransformOperations,
        selectionOperations: DocumentSelectionMaskOperations
    ) {
        self.processor = PrimoDocumentRenderingInfrastructure.GpuLayerTransformProcessor(
            layerTransformOperations: layerTransformOperations,
            selectionOperations: selectionOperations
        )
    }

    package init(gpuOperations: DocumentGpuOperationGateway) {
        self.init(
            layerTransformOperations: gpuOperations.layerTransformOperations,
            selectionOperations: gpuOperations.selectionMaskOperations
        )
    }

    package func transformedLayerPixels(
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
        processor.transformedLayerPixels(
            source: source,
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

    package func transformedSelection(
        _ selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets,
        canvasSize: CGSize
    ) -> CanvasSelection? {
        processor.transformedSelection(
            selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets,
            canvasSize: canvasSize
        )
    }

    package func transformationBounds(
        selection: CanvasSelection?,
        surface: RgbaSurface
    ) -> CGRect? {
        processor.transformationBounds(
            selection: selection,
            surface: surface
        )
    }
}
