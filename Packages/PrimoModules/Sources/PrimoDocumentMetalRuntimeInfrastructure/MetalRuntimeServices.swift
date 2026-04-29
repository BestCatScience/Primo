import CoreGraphics
import Foundation
import Metal
import PrimoBrushDomain
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain

public struct MetalResourceStore: Sendable {
    private let client: PrimoMetalDocumentProcessingClient

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        self.client = client
    }

    public var isAvailable: Bool {
        client.isAvailable
    }

    public func release(_ handle: MetalBufferHandle?) {
        client.releaseBufferHandle(handle)
    }

    public func retain(_ handle: MetalBufferHandle?) -> Bool {
        client.retainBufferHandle(handle)
    }

    public func materializedPixelData(for handle: MetalBufferHandle) -> Data? {
        client.materializedPixelData(for: handle)
    }

    public func populateTexture(
        _ texture: MTLTexture,
        from handle: MetalBufferHandle,
        sourceOriginX: Int = 0,
        sourceOriginY: Int = 0,
        destinationOriginX: Int = 0,
        destinationOriginY: Int = 0,
        width: Int? = nil,
        height: Int? = nil
    ) -> Bool {
        client.populateTexture(
            texture,
            from: handle,
            sourceOriginX: sourceOriginX,
            sourceOriginY: sourceOriginY,
            destinationOriginX: destinationOriginX,
            destinationOriginY: destinationOriginY,
            width: width,
            height: height
        )
    }

    public func makeBufferHandle(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        buffer: MTLBuffer
    ) -> MetalBufferHandle {
        client.makeBufferHandle(
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            buffer: buffer
        )
    }
}

public struct MetalStrokeExecutionService: Sendable {
    private let client: PrimoMetalDocumentProcessingClient

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        self.client = client
    }

    public func resetSession() {
        client.resetStrokeExecutionSession()
    }

    public func executeStroke(
        _ request: PrimoMetalStrokeExecutionRequest
    ) -> PrimoMetalStrokeExecutionResult? {
        client.executeStroke(request)
    }

    public func executeStrokeMutation(
        _ request: PrimoMetalStrokeExecutionRequest
    ) -> PrimoMetalStrokeMutationResult? {
        client.executeStrokeMutation(request)
    }

    public func rasterizedStrokePixelData(
        basePixelData: Data,
        baseBufferHandle: MetalBufferHandle? = nil,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        mode: PrimoMetalStrokeExecutionMode = .commit,
        snapshotRevision: Int? = nil,
        activeLayerIndex: Int? = nil
    ) -> Data? {
        client.rasterizedStrokePixelData(
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
}

public struct MetalCompositingService: Sendable {
    private let client: PrimoMetalDocumentProcessingClient

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        self.client = client
    }

    public func compositedPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int?,
        adjustedActiveLayerPixels: Data?,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)? = nil
    ) -> Data? {
        client.compositedPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        )
    }

    public func compositedBufferHandle(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int?,
        adjustedActiveLayerPixels: Data?,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)? = nil
    ) -> MetalBufferHandle? {
        client.compositedBufferHandle(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        )
    }

    public func compositedBufferHandle(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int?,
        adjustedActiveLayerBufferHandle: MetalBufferHandle?,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)? = nil
    ) -> MetalBufferHandle? {
        client.compositedBufferHandle(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerBufferHandle: adjustedActiveLayerBufferHandle,
            dirtyRect: dirtyRect
        )
    }

    public func compositeDocument(snapshot: MetalDocumentSnapshot) -> Data? {
        client.compositeDocument(snapshot: snapshot)
    }

    public func compositeDocumentBufferHandle(snapshot: MetalDocumentSnapshot) -> MetalBufferHandle? {
        client.compositeDocumentBufferHandle(snapshot: snapshot)
    }

    public func compositedIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        client.compositedIncrementalUpdate(snapshot: snapshot, dirtyRect: dirtyRect)
    }

    public func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        client.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        )
    }

    public func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerBufferHandle: MetalBufferHandle,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        client.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerBufferHandle: adjustedActiveLayerBufferHandle,
            dirtyRect: dirtyRect
        )
    }

    public func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        client.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    public func compositedPaperPreviewRGBA(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> Data? {
        client.compositedPaperPreviewRGBA(
            pixelData: pixelData,
            width: width,
            height: height,
            paperStyle: paperStyle
        )
    }

    public func compositeDocumentSurface(snapshot: MetalDocumentSnapshot) -> DocumentCompositeSurface? {
        client.compositeDocumentSurface(snapshot: snapshot)
    }
}

public struct MetalSelectionService: Sendable {
    private let client: PrimoMetalDocumentProcessingClient

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        self.client = client
    }

    public func autoSelection(
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
        client.autoSelection(
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

    public func invertMask(_ source: [UInt8]) -> [UInt8]? {
        client.invertMask(source)
    }

    public func expandedMask(
        _ source: [UInt8],
        width: Int,
        height: Int,
        expansion: Int
    ) -> [UInt8]? {
        client.expandedMask(source, width: width, height: height, expansion: expansion)
    }

    public func contractedMask(
        _ source: [UInt8],
        width: Int,
        height: Int,
        contraction: Int
    ) -> [UInt8]? {
        client.contractedMask(source, width: width, height: height, contraction: contraction)
    }

    public func featheredMask(
        _ source: [UInt8],
        width: Int,
        height: Int,
        radius: Int
    ) -> [UInt8]? {
        client.featheredMask(source, width: width, height: height, radius: radius)
    }

    public func colorRangeSelection(
        pixelData: Data,
        width: Int,
        height: Int,
        request: ColorRangeSelectionRequest
    ) -> [UInt8]? {
        client.colorRangeSelection(
            pixelData: pixelData,
            width: width,
            height: height,
            request: request
        )
    }

    public func lassoSelection(
        points: [CGPoint],
        canvasWidth: Int,
        canvasHeight: Int
    ) -> [UInt8]? {
        client.lassoSelection(
            points: points,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }

    public func expandedSelectionMask(
        maskData: Data,
        maskWidth: Int,
        maskHeight: Int,
        originX: Int,
        originY: Int,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> [UInt8]? {
        client.expandedSelectionMask(
            maskData: maskData,
            maskWidth: maskWidth,
            maskHeight: maskHeight,
            originX: originX,
            originY: originY,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }

    public func combinedSelectionMask(
        base: [UInt8],
        incoming: [UInt8],
        mode: PrimoMetalSelectionCombineMode,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        client.combinedSelectionMask(
            base: base,
            incoming: incoming,
            mode: mode,
            width: width,
            height: height
        )
    }

    public func croppedSelectionMask(
        mask: [UInt8],
        width: Int,
        height: Int
    ) -> PrimoMetalCroppedSelectionMask? {
        client.croppedSelectionMask(mask: mask, width: width, height: height)
    }

    public func alphaMask(
        pixelData: Data,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        client.alphaMask(pixelData: pixelData, width: width, height: height)
    }

    public func transformedSelectionMask(
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
        client.transformedSelectionMask(
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
}

public struct MetalLayerMutationService: Sendable {
    private let client: PrimoMetalDocumentProcessingClient

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        self.client = client
    }

    public func processLayer(
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        request: LayerProcessingRequest
    ) -> DocumentLayerMutationPayload? {
        client.processLayer(
            pixelData: pixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            request: request
        )
    }

    public func blurPixels(
        pixelData: Data,
        sourceBufferHandle: MetalBufferHandle? = nil,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> DocumentLayerMutationPayload? {
        client.blurPixels(
            pixelData: pixelData,
            sourceBufferHandle: sourceBufferHandle,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            samples: samples,
            brush: brush
        )
    }

    public func fillPixels(
        pixelData: Data,
        sourceBufferHandle: MetalBufferHandle? = nil,
        canvasWidth: Int,
        canvasHeight: Int,
        sample: StylusSample,
        brush: BrushRuntimeSettings
    ) -> DocumentLayerMutationPayload? {
        client.fillPixels(
            pixelData: pixelData,
            sourceBufferHandle: sourceBufferHandle,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            sample: sample,
            brush: brush
        )
    }

    public func preservingExistingAlpha(
        source: Data,
        existing: Data,
        width: Int,
        height: Int
    ) -> Data? {
        client.preservingExistingAlpha(
            source: source,
            existing: existing,
            width: width,
            height: height
        )
    }

    public func preservingExistingAlphaBufferHandle(
        sourceHandle: MetalBufferHandle,
        existingHandle: MetalBufferHandle?,
        existingPixelData: Data,
        width: Int,
        height: Int
    ) -> MetalBufferHandle? {
        client.preservingExistingAlphaBufferHandle(
            sourceHandle: sourceHandle,
            existingHandle: existingHandle,
            existingPixelData: existingPixelData,
            width: width,
            height: height
        )
    }

    public func applyLayerMask(
        pixelData: Data,
        maskData: Data,
        width: Int,
        height: Int
    ) -> Data? {
        client.applyLayerMask(
            pixelData: pixelData,
            maskData: maskData,
            width: width,
            height: height
        )
    }

    public func mergeLayers(
        lowerPixelData: Data,
        upperPixelData: Data,
        upperMaskData: Data?,
        canvasWidth: Int,
        canvasHeight: Int,
        upperOpacity: Float,
        upperBlendMode: LayerBlendMode
    ) -> Data? {
        client.mergeLayers(
            lowerPixelData: lowerPixelData,
            upperPixelData: upperPixelData,
            upperMaskData: upperMaskData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            upperOpacity: upperOpacity,
            upperBlendMode: upperBlendMode
        )
    }

    public func scaledPixelData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int
    ) -> Data? {
        client.scaledPixelData(
            source,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            targetWidth: targetWidth,
            targetHeight: targetHeight
        )
    }

    public func scaledMaskData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int
    ) -> Data? {
        client.scaledMaskData(
            source,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            targetWidth: targetWidth,
            targetHeight: targetHeight
        )
    }

    public func translatedMaskData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int,
        offsetX: Int,
        offsetY: Int
    ) -> Data? {
        client.translatedMaskData(
            source,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            offsetX: offsetX,
            offsetY: offsetY
        )
    }

    public func translatedPixelData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int,
        offsetX: Int,
        offsetY: Int
    ) -> Data? {
        client.translatedPixelData(
            source,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            offsetX: offsetX,
            offsetY: offsetY
        )
    }

    public func transformedLayerPixelData(
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
        client.transformedLayerPixelData(
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

    public func inpaintCropPayload(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selectionBounds: CGRect,
        expandedMask: [UInt8],
        padding: Int
    ) -> PrimoMetalInpaintCropPayload? {
        client.inpaintCropPayload(
            source: source,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            selectionBounds: selectionBounds,
            expandedMask: expandedMask,
            padding: padding
        )
    }

    public func applyInpaintCrop(
        editedCropPixelData: Data,
        to baseLayerPixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        cropWidth: Int,
        cropHeight: Int,
        originX: Int,
        originY: Int,
        selectionMask: [UInt8],
        featherRadius: Int
    ) -> Data? {
        client.applyInpaintCrop(
            editedCropPixelData: editedCropPixelData,
            to: baseLayerPixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            cropWidth: cropWidth,
            cropHeight: cropHeight,
            originX: originX,
            originY: originY,
            selectionMask: selectionMask,
            featherRadius: featherRadius
        )
    }
}

public struct MetalTextService: Sendable {
    private let client: PrimoMetalDocumentProcessingClient

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        self.client = client
    }

    public func rasterizeTextLayer(
        _ textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> DocumentLayerMutationPayload? {
        client.rasterizeTextLayer(textLayer, canvasSize: canvasSize)
    }

    public func textLayoutRect(
        for textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> CGRect? {
        client.textLayoutRect(for: textLayer, canvasSize: canvasSize)
    }
}
