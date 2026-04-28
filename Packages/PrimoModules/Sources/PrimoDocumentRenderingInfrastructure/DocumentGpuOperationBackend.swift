import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain

struct DocumentGpuOperationBackend: Sendable {
    var compositedPaperPreviewRGBA: @Sendable (Data, Int, Int, CanvasPaperStyle) -> Data?
    var compositedPreviewPixelData: @Sendable (MetalDocumentSnapshot, Int, Data) -> Data?
    var compositedPreviewIncrementalUpdate: @Sendable (MetalDocumentSnapshot, Int, Data, LayerPixelRect) -> IncrementalLayerUpdate?
    var selectionOverlayRGBA: @Sendable (Data, Int, Int) -> Data?
    var eyedropperLoupeRGBA: @Sendable (Data, Int, Int, Int, Int, Int, CanvasPaperStyle, Bool) -> Data?
    var shapePreviewSurface: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Int) -> DocumentCompositeSurface?
    var textLayerSurface: @Sendable (TextLayerData, CGSize) -> DocumentCompositeSurface?
    var textLayoutRect: @Sendable (TextLayerData, CGSize) -> CGRect?
    var processedLayerPixelData: @Sendable (Data, Int, Int, LayerProcessingRequest) -> Data?
    var alphaMask: @Sendable (Data, Int, Int) -> [UInt8]?
    var croppedSelectionMask: @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?
    var combinedSelectionMask: @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> [UInt8]?
    var expandedSelectionMask: @Sendable (ExpandedSelectionMaskRequest) -> [UInt8]?
    var lassoSelection: @Sendable ([CGPoint], Int, Int) -> [UInt8]?
    var autoSelection: @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> [UInt8]?
    var colorRangeSelection: @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> [UInt8]?
    var expandedMask: @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?
    var contractedMask: @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?
    var featheredMask: @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?
    var invertMask: @Sendable ([UInt8]) -> [UInt8]?
    var transformedSelectionMask: @Sendable (TransformedSelectionMaskRequest) -> [UInt8]?
    var transformedLayerPixelData: @Sendable (TransformedLayerPixelDataRequest) -> Data?
    var scaledPixelData: @Sendable (Data, Int, Int, Int, Int) -> Data?
    var translatedPixelData: @Sendable (Data, Int, Int, Int, Int, Int, Int) -> Data?
    var releaseSurfaceHandle: @Sendable (MetalBufferHandle?) -> Void
}
