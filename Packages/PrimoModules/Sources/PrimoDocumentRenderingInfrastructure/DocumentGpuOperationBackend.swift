import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain

struct DocumentGpuOperationBackend: Sendable {
    let compositedPaperPreviewRGBA: @Sendable (Data, Int, Int, CanvasPaperStyle) -> Data?
    let compositedPreviewPixelData: @Sendable (MetalDocumentSnapshot, Int, Data) -> Data?
    let compositedPreviewIncrementalUpdate: @Sendable (MetalDocumentSnapshot, Int, Data, LayerPixelRect) -> IncrementalLayerUpdate?
    let selectionOverlayRGBA: @Sendable (Data, Int, Int) -> Data?
    let eyedropperLoupeRGBA: @Sendable (Data, Int, Int, Int, Int, Int, CanvasPaperStyle, Bool) -> Data?
    let shapePreviewSurface: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Int) -> DocumentCompositeSurface?
    let textLayerSurface: @Sendable (TextLayerData, CGSize) -> DocumentCompositeSurface?
    let textLayoutRect: @Sendable (TextLayerData, CGSize) -> CGRect?
    let processedLayerPixelData: @Sendable (Data, Int, Int, LayerProcessingRequest) -> Data?
    let alphaMask: @Sendable (Data, Int, Int) -> [UInt8]?
    let croppedSelectionMask: @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?
    let combinedSelectionMask: @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> [UInt8]?
    let expandedSelectionMask: @Sendable (ExpandedSelectionMaskRequest) -> [UInt8]?
    let lassoSelection: @Sendable ([CGPoint], Int, Int) -> [UInt8]?
    let autoSelection: @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> [UInt8]?
    let colorRangeSelection: @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> [UInt8]?
    let expandedMask: @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?
    let contractedMask: @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?
    let featheredMask: @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?
    let invertMask: @Sendable ([UInt8]) -> [UInt8]?
    let transformedSelectionMask: @Sendable (TransformedSelectionMaskRequest) -> [UInt8]?
    let transformedLayerPixelData: @Sendable (TransformedLayerPixelDataRequest) -> Data?
    let scaledPixelData: @Sendable (Data, Int, Int, Int, Int) -> Data?
    let translatedPixelData: @Sendable (Data, Int, Int, Int, Int, Int, Int) -> Data?
    let releaseSurfaceHandle: @Sendable (MetalBufferHandle?) -> Void
}
