import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure

struct DocumentRuntimeGpuServices: Sendable {
    var release: @Sendable (MetalBufferHandle?) -> Void
    var _materializedPixelData: @Sendable (MetalBufferHandle) -> Data?
    var _scaledPixelData: @Sendable (Data, Int, Int, Int, Int) -> Data?
    var _scaledMaskData: @Sendable (Data, Int, Int, Int, Int) -> Data?
    var _translatedPixelData: @Sendable (Data, Int, Int, Int, Int, Int, Int) -> Data?
    var _translatedMaskData: @Sendable (Data, Int, Int, Int, Int, Int, Int) -> Data?
    var _applyLayerMask: @Sendable (Data, Data, Int, Int) -> Data?
    var _processLayer: @Sendable (Data, Int, Int, LayerProcessingRequest) -> DocumentLayerMutationPayload?
    var _mergeLayers: @Sendable (Data, Data, Data?, Int, Int, Float, LayerBlendMode) -> Data?
    var _rasterizeTextLayer: @Sendable (TextLayerData, CGSize) -> DocumentLayerMutationPayload?
    var _blurPixels: @Sendable (Data, MetalBufferHandle?, Int, Int, [StylusSample], BrushRuntimeSettings) -> DocumentLayerMutationPayload?
    var _fillPixels: @Sendable (Data, MetalBufferHandle?, Int, Int, StylusSample, BrushRuntimeSettings) -> DocumentLayerMutationPayload?
    var _commitStrokeMutation: @Sendable (Data, MetalBufferHandle?, Int, Int, [StylusSample], BrushRuntimeSettings, Int, Int) -> PrimoMetalStrokeMutationResult?
    var _preservingExistingAlphaBufferHandle: @Sendable (MetalBufferHandle, MetalBufferHandle?, Data, Int, Int) -> MetalBufferHandle?
    var _compositedPaperPreviewRGBA: @Sendable (Data, Int, Int, CanvasPaperStyle) -> Data?
    var _compositedIncrementalUpdate: @Sendable (MetalDocumentSnapshot, (originX: Int, originY: Int, width: Int, height: Int)) -> IncrementalLayerUpdate?
    var _compositeDocumentSurface: @Sendable (MetalDocumentSnapshot) -> DocumentCompositeSurface?
    var _compositeDocumentBufferHandle: @Sendable (MetalDocumentSnapshot) -> MetalBufferHandle?

    func materializedPixelData(for handle: MetalBufferHandle) -> Data? { _materializedPixelData(handle) }
    func scaledPixelData(_ data: Data, sourceWidth: Int, sourceHeight: Int, targetWidth: Int, targetHeight: Int) -> Data? { _scaledPixelData(data, sourceWidth, sourceHeight, targetWidth, targetHeight) }
    func scaledMaskData(_ data: Data, sourceWidth: Int, sourceHeight: Int, targetWidth: Int, targetHeight: Int) -> Data? { _scaledMaskData(data, sourceWidth, sourceHeight, targetWidth, targetHeight) }
    func translatedPixelData(_ data: Data, sourceWidth: Int, sourceHeight: Int, targetWidth: Int, targetHeight: Int, offsetX: Int, offsetY: Int) -> Data? { _translatedPixelData(data, sourceWidth, sourceHeight, targetWidth, targetHeight, offsetX, offsetY) }
    func translatedMaskData(_ data: Data, sourceWidth: Int, sourceHeight: Int, targetWidth: Int, targetHeight: Int, offsetX: Int, offsetY: Int) -> Data? { _translatedMaskData(data, sourceWidth, sourceHeight, targetWidth, targetHeight, offsetX, offsetY) }
    func applyLayerMask(pixelData: Data, maskData: Data, width: Int, height: Int) -> Data? { _applyLayerMask(pixelData, maskData, width, height) }
    func processLayer(pixelData: Data, canvasWidth: Int, canvasHeight: Int, request: LayerProcessingRequest) -> DocumentLayerMutationPayload? { _processLayer(pixelData, canvasWidth, canvasHeight, request) }
    func mergeLayers(lowerPixelData: Data, upperPixelData: Data, upperMaskData: Data?, canvasWidth: Int, canvasHeight: Int, upperOpacity: Float, upperBlendMode: LayerBlendMode) -> Data? { _mergeLayers(lowerPixelData, upperPixelData, upperMaskData, canvasWidth, canvasHeight, upperOpacity, upperBlendMode) }
    func rasterizeTextLayer(_ textLayer: TextLayerData, canvasSize: CGSize) -> DocumentLayerMutationPayload? { _rasterizeTextLayer(textLayer, canvasSize) }
    func blurPixels(pixelData: Data, sourceBufferHandle: MetalBufferHandle?, canvasWidth: Int, canvasHeight: Int, samples: [StylusSample], brush: BrushRuntimeSettings) -> DocumentLayerMutationPayload? { _blurPixels(pixelData, sourceBufferHandle, canvasWidth, canvasHeight, samples, brush) }
    func fillPixels(pixelData: Data, sourceBufferHandle: MetalBufferHandle?, canvasWidth: Int, canvasHeight: Int, sample: StylusSample, brush: BrushRuntimeSettings) -> DocumentLayerMutationPayload? { _fillPixels(pixelData, sourceBufferHandle, canvasWidth, canvasHeight, sample, brush) }
    func commitStrokeMutation(
        basePixelData: Data,
        baseBufferHandle: MetalBufferHandle?,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        snapshotRevision: Int,
        activeLayerIndex: Int
    ) -> PrimoMetalStrokeMutationResult? {
        _commitStrokeMutation(basePixelData, baseBufferHandle, canvasWidth, canvasHeight, samples, brush, snapshotRevision, activeLayerIndex)
    }
    func preservingExistingAlphaBufferHandle(sourceHandle: MetalBufferHandle, existingHandle: MetalBufferHandle?, existingPixelData: Data, width: Int, height: Int) -> MetalBufferHandle? { _preservingExistingAlphaBufferHandle(sourceHandle, existingHandle, existingPixelData, width, height) }
    func compositedPaperPreviewRGBA(pixelData: Data, width: Int, height: Int, paperStyle: CanvasPaperStyle) -> Data? { _compositedPaperPreviewRGBA(pixelData, width, height, paperStyle) }
    func compositedIncrementalUpdate(snapshot: MetalDocumentSnapshot, dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)) -> IncrementalLayerUpdate? { _compositedIncrementalUpdate(snapshot, dirtyRect) }
    func compositeDocumentSurface(snapshot: MetalDocumentSnapshot) -> DocumentCompositeSurface? { _compositeDocumentSurface(snapshot) }
    func compositeDocumentBufferHandle(snapshot: MetalDocumentSnapshot) -> MetalBufferHandle? { _compositeDocumentBufferHandle(snapshot) }
}

enum DocumentRuntimeGpuServicesFactory {
    static func live() -> DocumentRuntimeGpuServices {
        let resources = MetalResourceStore()
        let strokes = MetalStrokeExecutionService()
        let composites = MetalCompositingService()
        let layers = MetalLayerMutationService()
        let text = MetalTextService()

        return DocumentRuntimeGpuServices(
            release: { resources.release($0) },
            _materializedPixelData: { resources.materializedPixelData(for: $0) },
            _scaledPixelData: { layers.scaledPixelData($0, sourceWidth: $1, sourceHeight: $2, targetWidth: $3, targetHeight: $4) },
            _scaledMaskData: { layers.scaledMaskData($0, sourceWidth: $1, sourceHeight: $2, targetWidth: $3, targetHeight: $4) },
            _translatedPixelData: { layers.translatedPixelData($0, sourceWidth: $1, sourceHeight: $2, targetWidth: $3, targetHeight: $4, offsetX: $5, offsetY: $6) },
            _translatedMaskData: { layers.translatedMaskData($0, sourceWidth: $1, sourceHeight: $2, targetWidth: $3, targetHeight: $4, offsetX: $5, offsetY: $6) },
            _applyLayerMask: { layers.applyLayerMask(pixelData: $0, maskData: $1, width: $2, height: $3) },
            _processLayer: { layers.processLayer(pixelData: $0, canvasWidth: $1, canvasHeight: $2, request: $3) },
            _mergeLayers: { layers.mergeLayers(lowerPixelData: $0, upperPixelData: $1, upperMaskData: $2, canvasWidth: $3, canvasHeight: $4, upperOpacity: $5, upperBlendMode: $6) },
            _rasterizeTextLayer: { text.rasterizeTextLayer($0, canvasSize: $1) },
            _blurPixels: { layers.blurPixels(pixelData: $0, sourceBufferHandle: $1, canvasWidth: $2, canvasHeight: $3, samples: $4, brush: $5) },
            _fillPixels: { layers.fillPixels(pixelData: $0, sourceBufferHandle: $1, canvasWidth: $2, canvasHeight: $3, sample: $4, brush: $5) },
            _commitStrokeMutation: {
                strokes.executeStrokeMutation(
                    PrimoMetalStrokeExecutionRequest(
                        basePixelData: $0,
                        baseBufferHandle: $1,
                        canvasWidth: $2,
                        canvasHeight: $3,
                        samples: $4,
                        brush: $5,
                        mode: .commit,
                        snapshotRevision: $6,
                        activeLayerIndex: $7
                    )
                )
            },
            _preservingExistingAlphaBufferHandle: { layers.preservingExistingAlphaBufferHandle(sourceHandle: $0, existingHandle: $1, existingPixelData: $2, width: $3, height: $4) },
            _compositedPaperPreviewRGBA: { composites.compositedPaperPreviewRGBA(pixelData: $0, width: $1, height: $2, paperStyle: $3) },
            _compositedIncrementalUpdate: { composites.compositedIncrementalUpdate(snapshot: $0, dirtyRect: $1) },
            _compositeDocumentSurface: { composites.compositeDocumentSurface(snapshot: $0) },
            _compositeDocumentBufferHandle: { composites.compositeDocumentBufferHandle(snapshot: $0) }
        )
    }
}
