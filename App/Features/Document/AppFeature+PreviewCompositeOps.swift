import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentApplication
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentRenderingInfrastructure

struct CanvasDocumentRenderingServiceBundle {
    let strokeExecutor: MetalStrokeExecutor
    let compositor: MetalCompositor
    let selectionExecutor: MetalSelectionService
    let layerMutationExecutor: MetalLayerMutationService
    let materializationGateway: SurfaceMaterializationGateway

    static let live = CanvasDocumentRenderingServiceBundle(
        strokeExecutor: MetalStrokeExecutor(),
        compositor: MetalCompositor(),
        selectionExecutor: MetalSelectionService(),
        layerMutationExecutor: MetalLayerMutationService(),
        materializationGateway: SurfaceMaterializationGateway()
    )

    func resetInteractiveStrokeState() {
        strokeExecutor.resetSession()
    }

    func rasterizedStrokePixelData(
        basePixelData: Data,
        baseBufferHandle: MetalBufferHandle? = nil,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        mode: MetalStrokeExecutionMode = .commit,
        snapshotRevision: Int? = nil,
        activeLayerIndex: Int? = nil
    ) -> Data? {
        strokeExecutor.rasterizedStrokePixelData(
            basePixelData: basePixelData,
            baseBufferHandle: baseBufferHandle,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            samples: samples,
            brush: brush,
            mode: mode,
            snapshotRevision: snapshotRevision,
            activeLayerIndex: activeLayerIndex
        )
    }

    func preservingExistingAlpha(source: Data, existing: Data, width: Int, height: Int) -> Data? {
        materializationGateway.preservingExistingAlpha(source: source, existing: existing, width: width, height: height)
    }

    func compositedPaperPreviewRGBA(pixelData: Data, width: Int, height: Int, paperStyle: CanvasPaperStyle) -> Data? {
        compositor.compositedPaperPreviewRGBA(pixelData: pixelData, width: width, height: height, paperStyle: paperStyle)
    }

    func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        compositor.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        compositor.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        )
    }

    func processedLayerPixelData(pixelData: Data, canvasWidth: Int, canvasHeight: Int, request: LayerProcessingRequest) -> Data? {
        layerMutationExecutor.processLayer(
            pixelData: pixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            request: request
        )?.fullPixelData
    }

    func alphaMask(pixelData: Data, width: Int, height: Int) -> [UInt8]? {
        selectionExecutor.alphaMask(pixelData: pixelData, width: width, height: height)
    }

    func croppedSelectionMask(mask: [UInt8], width: Int, height: Int) -> MetalCroppedSelectionMask? {
        selectionExecutor.croppedSelectionMask(mask: mask, width: width, height: height)
    }

    func combinedSelectionMask(base: [UInt8], incoming: [UInt8], mode: MetalSelectionCombineMode, width: Int, height: Int) -> [UInt8]? {
        selectionExecutor.combinedSelectionMask(base: base, incoming: incoming, mode: mode, width: width, height: height)
    }

    func expandedSelectionMask(maskData: Data, maskWidth: Int, maskHeight: Int, originX: Int, originY: Int, canvasWidth: Int, canvasHeight: Int) -> [UInt8]? {
        selectionExecutor.expandedSelectionMask(
            maskData: maskData,
            maskWidth: maskWidth,
            maskHeight: maskHeight,
            originX: originX,
            originY: originY,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }

    func lassoSelection(points: [CGPoint], canvasWidth: Int, canvasHeight: Int) -> [UInt8]? {
        selectionExecutor.lassoSelection(points: points, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
    }

    func autoSelection(
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        seedX: Int,
        seedY: Int,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> [UInt8]? {
        selectionExecutor.autoSelection(
            pixelData: pixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            seedX: seedX,
            seedY: seedY,
            thresholdMode: thresholdMode,
            opacityTolerance: opacityTolerance,
            colorTolerance: colorTolerance,
            expansion: expansion
        )
    }

    func colorRangeSelection(pixelData: Data, width: Int, height: Int, request: ColorRangeSelectionRequest) -> [UInt8]? {
        selectionExecutor.colorRangeSelection(pixelData: pixelData, width: width, height: height, request: request)
    }

    func expandedMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8]? {
        selectionExecutor.expandedMask(source, width: width, height: height, expansion: expansion)
    }

    func contractedMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8]? {
        selectionExecutor.contractedMask(source, width: width, height: height, contraction: contraction)
    }

    func featheredMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8]? {
        selectionExecutor.featheredMask(source, width: width, height: height, radius: radius)
    }

    func invertMask(_ source: [UInt8]) -> [UInt8]? {
        selectionExecutor.invertMask(source)
    }

    func transformedSelectionMask(
        expandedSelectionMask: [UInt8],
        canvasWidth: Int,
        canvasHeight: Int,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint,
        sourceQuad: TransformQuad,
        destinationQuad: TransformQuad,
        usesFreeformQuad: Bool
    ) -> [UInt8]? {
        selectionExecutor.transformedSelectionMask(
            expandedSelectionMask: expandedSelectionMask,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            sourceQuad: sourceQuad,
            destinationQuad: destinationQuad,
            usesFreeformQuad: usesFreeformQuad
        )
    }

    func transformedLayerPixelData(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        expandedSelectionMask: [UInt8]?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint,
        sourceQuad: TransformQuad,
        destinationQuad: TransformQuad,
        usesFreeformQuad: Bool
    ) -> Data? {
        layerMutationExecutor.transformedLayerPixelData(
            source: source,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            expandedSelectionMask: expandedSelectionMask,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            sourceQuad: sourceQuad,
            destinationQuad: destinationQuad,
            usesFreeformQuad: usesFreeformQuad
        )
    }

    func strokePreviewDirtyRect(
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
            let pressureFactor = max(0.1, 1.0 + ((sample.pressure - 1.0) * CGFloat(brush.pressureSensitivity)))
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
}

enum CanvasDocumentRenderingServices {
    static let live = CanvasDocumentRenderingServiceBundle.live
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
