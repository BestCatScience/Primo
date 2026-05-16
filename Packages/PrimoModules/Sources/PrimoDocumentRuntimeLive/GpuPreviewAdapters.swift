import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRenderingInfrastructure

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
        canvasGeometry: PixelGeometry
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
            canvasGeometry: canvasGeometry
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
