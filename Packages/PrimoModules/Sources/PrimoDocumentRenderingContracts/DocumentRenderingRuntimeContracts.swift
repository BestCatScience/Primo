import CoreGraphics
import Foundation
@_exported import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
@_exported import PrimoDocumentMutationContracts
@_exported import PrimoDocumentPresentationContracts

public struct DocumentQueryGateway: Sendable {
    public var lightweightPresentation: @Sendable () -> PaintDocumentPresentation
    public var presentation: @Sendable () -> PaintDocumentPresentation
    /// Legacy convenience retained for callers that still expect raw bytes.
    /// Live query paths should prefer `compositeSurface`.
    public var compositePixelData: @Sendable () -> Data
    public var compositeSurface: @Sendable () -> DocumentCompositeSurface
    public var pixelDataForLayer: @Sendable (Int) -> Data
    public var consumeDirtyUpdate: @Sendable () -> IncrementalLayerUpdate?

    public init(
        lightweightPresentation: @escaping @Sendable () -> PaintDocumentPresentation,
        presentation: @escaping @Sendable () -> PaintDocumentPresentation,
        compositePixelData: @escaping @Sendable () -> Data,
        compositeSurface: @escaping @Sendable () -> DocumentCompositeSurface,
        pixelDataForLayer: @escaping @Sendable (Int) -> Data,
        consumeDirtyUpdate: @escaping @Sendable () -> IncrementalLayerUpdate?
    ) {
        self.lightweightPresentation = lightweightPresentation
        self.presentation = presentation
        self.compositePixelData = compositePixelData
        self.compositeSurface = compositeSurface
        self.pixelDataForLayer = pixelDataForLayer
        self.consumeDirtyUpdate = consumeDirtyUpdate
    }
}

public enum DocumentSelectionCombineMode: Sendable {
    case add
    case subtract
}

public struct DocumentCroppedSelectionMask: Sendable, Equatable {
    public let bounds: CGRect
    public let maskData: Data
    public let maskWidth: Int
    public let maskHeight: Int

    public init(bounds: CGRect, maskData: Data, maskWidth: Int, maskHeight: Int) {
        self.bounds = bounds
        self.maskData = maskData
        self.maskWidth = maskWidth
        self.maskHeight = maskHeight
    }
}

public struct ExpandedSelectionMaskRequest: Sendable, Equatable {
    public let maskData: Data
    public let maskWidth: Int
    public let maskHeight: Int
    public let originX: Int
    public let originY: Int
    public let canvasWidth: Int
    public let canvasHeight: Int

    public init(
        maskData: Data,
        maskWidth: Int,
        maskHeight: Int,
        originX: Int,
        originY: Int,
        canvasWidth: Int,
        canvasHeight: Int
    ) {
        self.maskData = maskData
        self.maskWidth = maskWidth
        self.maskHeight = maskHeight
        self.originX = originX
        self.originY = originY
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }
}

public struct TransformedSelectionMaskRequest: Sendable, Equatable {
    public let expandedSelectionMask: [UInt8]
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let translation: CGSize
    public let scaleX: CGFloat
    public let scaleY: CGFloat
    public let rotationDegrees: Double
    public let pivot: CGPoint
    public let sourceQuad: TransformQuad
    public let destinationQuad: TransformQuad
    public let usesFreeformQuad: Bool

    public init(
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
    ) {
        self.expandedSelectionMask = expandedSelectionMask
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.translation = translation
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotationDegrees = rotationDegrees
        self.pivot = pivot
        self.sourceQuad = sourceQuad
        self.destinationQuad = destinationQuad
        self.usesFreeformQuad = usesFreeformQuad
    }
}

public struct TransformedLayerPixelDataRequest: Sendable, Equatable {
    public let source: Data
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let expandedSelectionMask: [UInt8]?
    public let translation: CGSize
    public let scaleX: CGFloat
    public let scaleY: CGFloat
    public let rotationDegrees: Double
    public let pivot: CGPoint
    public let sourceQuad: TransformQuad
    public let destinationQuad: TransformQuad
    public let usesFreeformQuad: Bool

    public init(
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
    ) {
        self.source = source
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.expandedSelectionMask = expandedSelectionMask
        self.translation = translation
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotationDegrees = rotationDegrees
        self.pivot = pivot
        self.sourceQuad = sourceQuad
        self.destinationQuad = destinationQuad
        self.usesFreeformQuad = usesFreeformQuad
    }
}

public struct DocumentGpuOperationGateway: Sendable {
    public var compositedPaperPreviewRGBA: @Sendable (Data, Int, Int, CanvasPaperStyle) -> Data?
    public var compositedPreviewPixelData: @Sendable (MetalDocumentSnapshot, Int, Data) -> Data?
    public var compositedPreviewIncrementalUpdate: @Sendable (MetalDocumentSnapshot, Int, Data, LayerPixelRect) -> IncrementalLayerUpdate?
    public var selectionOverlayRGBA: @Sendable (Data, Int, Int) -> Data?
    public var eyedropperLoupeRGBA: @Sendable (Data, Int, Int, Int, Int, Int, CanvasPaperStyle, Bool) -> Data?
    public var shapePreviewSurface: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Int) -> DocumentCompositeSurface?
    public var textLayerSurface: @Sendable (TextLayerData, CGSize) -> DocumentCompositeSurface?
    public var textLayoutRect: @Sendable (TextLayerData, CGSize) -> CGRect?
    public var processedLayerPixelData: @Sendable (Data, Int, Int, LayerProcessingRequest) -> Data?
    public var alphaMask: @Sendable (Data, Int, Int) -> [UInt8]?
    public var croppedSelectionMask: @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?
    public var combinedSelectionMask: @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> [UInt8]?
    public var expandedSelectionMask: @Sendable (ExpandedSelectionMaskRequest) -> [UInt8]?
    public var lassoSelection: @Sendable ([CGPoint], Int, Int) -> [UInt8]?
    public var autoSelection: @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> [UInt8]?
    public var colorRangeSelection: @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> [UInt8]?
    public var expandedMask: @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?
    public var contractedMask: @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?
    public var featheredMask: @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?
    public var invertMask: @Sendable ([UInt8]) -> [UInt8]?
    public var transformedSelectionMask: @Sendable (TransformedSelectionMaskRequest) -> [UInt8]?
    public var transformedLayerPixelData: @Sendable (TransformedLayerPixelDataRequest) -> Data?
    public var scaledPixelData: @Sendable (Data, Int, Int, Int, Int) -> Data?
    public var translatedPixelData: @Sendable (Data, Int, Int, Int, Int, Int, Int) -> Data?
    public var releaseSurfaceHandle: @Sendable (MetalBufferHandle?) -> Void

    public init(
        compositedPaperPreviewRGBA: @escaping @Sendable (Data, Int, Int, CanvasPaperStyle) -> Data?,
        compositedPreviewPixelData: @escaping @Sendable (MetalDocumentSnapshot, Int, Data) -> Data?,
        compositedPreviewIncrementalUpdate: @escaping @Sendable (MetalDocumentSnapshot, Int, Data, LayerPixelRect) -> IncrementalLayerUpdate?,
        selectionOverlayRGBA: @escaping @Sendable (Data, Int, Int) -> Data?,
        eyedropperLoupeRGBA: @escaping @Sendable (Data, Int, Int, Int, Int, Int, CanvasPaperStyle, Bool) -> Data?,
        shapePreviewSurface: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int, Int) -> DocumentCompositeSurface?,
        textLayerSurface: @escaping @Sendable (TextLayerData, CGSize) -> DocumentCompositeSurface?,
        textLayoutRect: @escaping @Sendable (TextLayerData, CGSize) -> CGRect?,
        processedLayerPixelData: @escaping @Sendable (Data, Int, Int, LayerProcessingRequest) -> Data?,
        alphaMask: @escaping @Sendable (Data, Int, Int) -> [UInt8]?,
        croppedSelectionMask: @escaping @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?,
        combinedSelectionMask: @escaping @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> [UInt8]?,
        expandedSelectionMask: @escaping @Sendable (ExpandedSelectionMaskRequest) -> [UInt8]?,
        lassoSelection: @escaping @Sendable ([CGPoint], Int, Int) -> [UInt8]?,
        autoSelection: @escaping @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> [UInt8]?,
        colorRangeSelection: @escaping @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> [UInt8]?,
        expandedMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?,
        contractedMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?,
        featheredMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> [UInt8]?,
        invertMask: @escaping @Sendable ([UInt8]) -> [UInt8]?,
        transformedSelectionMask: @escaping @Sendable (TransformedSelectionMaskRequest) -> [UInt8]?,
        transformedLayerPixelData: @escaping @Sendable (TransformedLayerPixelDataRequest) -> Data?,
        scaledPixelData: @escaping @Sendable (Data, Int, Int, Int, Int) -> Data?,
        translatedPixelData: @escaping @Sendable (Data, Int, Int, Int, Int, Int, Int) -> Data?,
        releaseSurfaceHandle: @escaping @Sendable (MetalBufferHandle?) -> Void
    ) {
        self.compositedPaperPreviewRGBA = compositedPaperPreviewRGBA
        self.compositedPreviewPixelData = compositedPreviewPixelData
        self.compositedPreviewIncrementalUpdate = compositedPreviewIncrementalUpdate
        self.selectionOverlayRGBA = selectionOverlayRGBA
        self.eyedropperLoupeRGBA = eyedropperLoupeRGBA
        self.shapePreviewSurface = shapePreviewSurface
        self.textLayerSurface = textLayerSurface
        self.textLayoutRect = textLayoutRect
        self.processedLayerPixelData = processedLayerPixelData
        self.alphaMask = alphaMask
        self.croppedSelectionMask = croppedSelectionMask
        self.combinedSelectionMask = combinedSelectionMask
        self.expandedSelectionMask = expandedSelectionMask
        self.lassoSelection = lassoSelection
        self.autoSelection = autoSelection
        self.colorRangeSelection = colorRangeSelection
        self.expandedMask = expandedMask
        self.contractedMask = contractedMask
        self.featheredMask = featheredMask
        self.invertMask = invertMask
        self.transformedSelectionMask = transformedSelectionMask
        self.transformedLayerPixelData = transformedLayerPixelData
        self.scaledPixelData = scaledPixelData
        self.translatedPixelData = translatedPixelData
        self.releaseSurfaceHandle = releaseSurfaceHandle
    }
}
