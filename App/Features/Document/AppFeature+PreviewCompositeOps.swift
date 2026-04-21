import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentRenderingInfrastructure

typealias MetalStrokeExecutionMode = PrimoDocumentRenderingInfrastructure.MetalStrokeExecutionMode
typealias MetalStrokeExecutionRequest = PrimoDocumentRenderingInfrastructure.MetalStrokeExecutionRequest
typealias MetalStrokeExecutionResult = PrimoDocumentRenderingInfrastructure.MetalStrokeExecutionResult

enum MetalDocumentProcessingClient {
    static let shared = DocumentRenderingClient.live
}

extension AppFeature {
    static func renderedCompositePNGData(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle
    ) -> Data? {
        MetalDocumentProcessingClient.shared.renderedCompositePNGData(
            snapshot: snapshot,
            paperStyle: paperStyle
        )
    }

    static func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        MetalDocumentProcessingClient.shared.compositedPreviewPixelData(
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
        MetalDocumentProcessingClient.shared.strokePreviewDirtyRect(
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
        MetalDocumentProcessingClient.shared.compositedPreviewIncrementalUpdate(
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
