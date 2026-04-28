import CoreGraphics
import Foundation
import PrimoBrushDomain
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain

public struct MetalRuntimeContext: Sendable {
    public let pipelineRegistry: MetalPipelineRegistry
    public let surfaceStore: MetalSurfaceStore
    public let strokeExecutor: MetalStrokeExecutor
    public let compositor: MetalCompositor
    public let selectionExecutor: MetalSelectionExecutor
    public let layerMutationExecutor: MetalLayerMutationExecutor
    public let overlayExecutor: MetalOverlayExecutor
    public let textExecutor: MetalTextService

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        pipelineRegistry = MetalPipelineRegistry(client: client)
        surfaceStore = MetalSurfaceStore(client: client)
        strokeExecutor = MetalStrokeExecutor(client: client)
        compositor = MetalCompositor(client: client)
        selectionExecutor = MetalSelectionExecutor(client: client)
        layerMutationExecutor = MetalLayerMutationExecutor(client: client)
        overlayExecutor = MetalOverlayExecutor(client: client)
        textExecutor = MetalTextService(client: client)
    }
}

public struct MetalPipelineRegistry: Sendable {
    private let client: PrimoMetalDocumentProcessingClient

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        self.client = client
    }

    public var isAvailable: Bool {
        client.isAvailable
    }
}

public struct MetalSurfaceStore: Sendable {
    private let store: MetalResourceStore

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        store = MetalResourceStore(client: client)
    }

    public var isAvailable: Bool {
        store.isAvailable
    }

    public func release(_ handle: MetalBufferHandle?) {
        store.release(handle)
    }

    public func materializedPixelData(for handle: MetalBufferHandle) -> Data? {
        store.materializedPixelData(for: handle)
    }
}

public struct MetalStrokeExecutor: Sendable {
    private let service: MetalStrokeExecutionService

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        service = MetalStrokeExecutionService(client: client)
    }

    public func resetSession() {
        service.resetSession()
    }

    public func executeStroke(_ request: PrimoMetalStrokeExecutionRequest) -> PrimoMetalStrokeExecutionResult? {
        service.executeStroke(request)
    }

    public func executeStrokeMutation(_ request: PrimoMetalStrokeExecutionRequest) -> PrimoMetalStrokeMutationResult? {
        service.executeStrokeMutation(request)
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
        service.rasterizedStrokePixelData(
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

public struct MetalCompositor: Sendable {
    private let service: MetalCompositingService

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        service = MetalCompositingService(client: client)
    }

    public func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        service.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    public func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        service.compositedPreviewIncrementalUpdate(
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
        service.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerBufferHandle: adjustedActiveLayerBufferHandle,
            dirtyRect: dirtyRect
        )
    }

    public func compositedPaperPreviewRGBA(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> Data? {
        service.compositedPaperPreviewRGBA(
            pixelData: pixelData,
            width: width,
            height: height,
            paperStyle: paperStyle
        )
    }
}

public struct MetalSelectionExecutor: Sendable {
    private let service: MetalSelectionService

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        service = MetalSelectionService(client: client)
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
        service.autoSelection(
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

    public func combinedSelectionMask(
        base: [UInt8],
        incoming: [UInt8],
        mode: PrimoMetalSelectionCombineMode,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        service.combinedSelectionMask(base: base, incoming: incoming, mode: mode, width: width, height: height)
    }

    public func croppedSelectionMask(mask: [UInt8], width: Int, height: Int) -> PrimoMetalCroppedSelectionMask? {
        service.croppedSelectionMask(mask: mask, width: width, height: height)
    }
}

public struct MetalLayerMutationExecutor: Sendable {
    private let service: MetalLayerMutationService

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        service = MetalLayerMutationService(client: client)
    }

    public func processLayer(
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        request: LayerProcessingRequest
    ) -> DocumentLayerMutationPayload? {
        service.processLayer(pixelData: pixelData, canvasWidth: canvasWidth, canvasHeight: canvasHeight, request: request)
    }

    public func preservingExistingAlpha(source: Data, existing: Data, width: Int, height: Int) -> Data? {
        service.preservingExistingAlpha(source: source, existing: existing, width: width, height: height)
    }

    public func preservingExistingAlphaBufferHandle(
        sourceHandle: MetalBufferHandle,
        existingHandle: MetalBufferHandle?,
        existingPixelData: Data,
        width: Int,
        height: Int
    ) -> MetalBufferHandle? {
        service.preservingExistingAlphaBufferHandle(
            sourceHandle: sourceHandle,
            existingHandle: existingHandle,
            existingPixelData: existingPixelData,
            width: width,
            height: height
        )
    }
}

public struct MetalOverlayExecutor: Sendable {
    private let client: PrimoMetalDocumentProcessingClient

    public init(client: PrimoMetalDocumentProcessingClient = .shared) {
        self.client = client
    }

    public func selectionOverlayRGBA(
        maskData: Data,
        width: Int,
        height: Int,
        red: UInt8 = 91,
        green: UInt8 = 181,
        blue: UInt8 = 255,
        maximumAlpha: Float = 96.0 / 255.0
    ) -> Data? {
        client.selectionOverlayRGBA(
            maskData: maskData,
            width: width,
            height: height,
            red: red,
            green: green,
            blue: blue,
            maximumAlpha: maximumAlpha
        )
    }

    public func eyedropperLoupeRGBA(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> Data? {
        client.eyedropperLoupeRGBA(
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
}
