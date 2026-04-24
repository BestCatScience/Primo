import CoreGraphics
import Foundation
import Metal
import PrimoBrushDomain
import PrimoDocumentContracts
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

    public func featheredMask(
        _ source: [UInt8],
        width: Int,
        height: Int,
        radius: Int
    ) -> [UInt8]? {
        client.featheredMask(source, width: width, height: height, radius: radius)
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
