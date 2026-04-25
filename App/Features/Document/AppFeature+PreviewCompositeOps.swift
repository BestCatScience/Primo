import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentApplication
import PrimoDocumentRenderingInfrastructure

enum CanvasDocumentRenderingServices {
    static let live = DocumentRenderingClient.live
}

extension AppFeature {
    static func renderedCompositeSurface(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle
    ) -> DocumentCompositeSurface {
        let pixelData = CanvasDocumentRenderingServices.live.compositedPaperPreviewRGBA(
            pixelData: snapshot.compositePixelData,
            width: snapshot.width,
            height: snapshot.height,
            paperStyle: paperStyle
        ) ?? snapshot.compositePixelData

        return DocumentCompositeSurface(
            width: snapshot.width,
            height: snapshot.height,
            pixelData: pixelData
        )
    }

    static func renderedCompositePNGData(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle
    ) -> Data? {
        DocumentRasterImageService.pngData(
            from: renderedCompositeSurface(snapshot: snapshot, paperStyle: paperStyle)
        )
    }

    static func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        CanvasDocumentRenderingServices.live.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    static func strokePreviewDirtyRect(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (originX: Int, originY: Int, width: Int, height: Int)? {
        CanvasDocumentRenderingServices.live.strokePreviewDirtyRect(
            samples: samples,
            brush: brush,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }

    static func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        CanvasDocumentRenderingServices.live.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
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
}
