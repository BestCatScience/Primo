import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts

public struct DocumentReadGateway: Sendable {
    package let lightweightPresentation: @Sendable () -> PaintDocumentPresentation
    package let presentation: @Sendable () -> PaintDocumentPresentation

    public init(
        lightweightPresentation: @escaping @Sendable () -> PaintDocumentPresentation,
        presentation: @escaping @Sendable () -> PaintDocumentPresentation
    ) {
        self.lightweightPresentation = lightweightPresentation
        self.presentation = presentation
    }
}

public typealias DocumentQueryGateway = DocumentReadGateway

public struct DocumentRenderGateway: Sendable {
    /// Legacy convenience retained for callers that still expect raw bytes.
    /// Live query paths should prefer `compositeSurface`.
    package let compositePixelData: @Sendable () -> Data
    package let compositeSurface: @Sendable () -> DocumentCompositeSurface
    package let pixelDataForLayer: @Sendable (Int) -> Data

    public init(
        compositePixelData: @escaping @Sendable () -> Data,
        compositeSurface: @escaping @Sendable () -> DocumentCompositeSurface,
        pixelDataForLayer: @escaping @Sendable (Int) -> Data
    ) {
        self.compositePixelData = compositePixelData
        self.compositeSurface = compositeSurface
        self.pixelDataForLayer = pixelDataForLayer
    }
}

public struct DocumentDirtyUpdateQueue: Sendable {
    package let consumeDirtyUpdate: @Sendable () -> IncrementalLayerUpdate?

    public init(
        consumeDirtyUpdate: @escaping @Sendable () -> IncrementalLayerUpdate?
    ) {
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

public enum DocumentRenderingFailure: Error, Equatable, Sendable {
    case gpuUnavailable(operation: String)
    case invalidGeometry(operation: String)
    case invalidPayloadSize(operation: String, expected: Int, actual: Int)
    case resourceHandleInvalid(operation: String)
    case kernelFailed(operation: String)
    case encodingFailed(operation: String)
    case unsupportedOperation(operation: String)
}

public typealias DocumentRenderingResult<Success> = Result<Success, DocumentRenderingFailure>

public extension Result where Failure == DocumentRenderingFailure {
    var value: Success? {
        switch self {
        case let .success(value):
            return value
        case .failure:
            return nil
        }
    }
}

public struct DocumentGpuOperationGateway: Sendable {
    package let compositedPaperPreviewRGBA: @Sendable (Data, Int, Int, CanvasPaperStyle) -> DocumentRenderingResult<Data>
    package let compositedPreviewPixelData: @Sendable (MetalDocumentSnapshot, Int, Data) -> DocumentRenderingResult<Data>
    package let compositedPreviewIncrementalUpdate: @Sendable (MetalDocumentSnapshot, Int, Data, LayerPixelRect) -> DocumentRenderingResult<IncrementalLayerUpdate>
    package let selectionOverlayRGBA: @Sendable (Data, Int, Int) -> DocumentRenderingResult<Data>
    package let eyedropperLoupeRGBA: @Sendable (Data, Int, Int, Int, Int, Int, CanvasPaperStyle, Bool) -> DocumentRenderingResult<Data>
    package let shapePreviewSurface: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Int) -> DocumentRenderingResult<DocumentCompositeSurface>
    package let textLayerSurface: @Sendable (TextLayerData, CGSize) -> DocumentRenderingResult<DocumentCompositeSurface>
    package let textLayoutRect: @Sendable (TextLayerData, CGSize) -> CGRect?
    package let processedLayerPixelData: @Sendable (Data, Int, Int, LayerProcessingRequest) -> DocumentRenderingResult<Data>
    package let alphaMask: @Sendable (Data, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let croppedSelectionMask: @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?
    package let combinedSelectionMask: @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let expandedSelectionMask: @Sendable (ExpandedSelectionMaskRequest) -> DocumentRenderingResult<[UInt8]>
    package let lassoSelection: @Sendable ([CGPoint], Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let autoSelection: @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> DocumentRenderingResult<[UInt8]>
    package let colorRangeSelection: @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> DocumentRenderingResult<[UInt8]>
    package let expandedMask: @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let contractedMask: @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let featheredMask: @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let invertMask: @Sendable ([UInt8]) -> DocumentRenderingResult<[UInt8]>
    package let transformedSelectionMask: @Sendable (TransformedSelectionMaskRequest) -> DocumentRenderingResult<[UInt8]>
    package let transformedLayerPixelData: @Sendable (TransformedLayerPixelDataRequest) -> DocumentRenderingResult<Data>
    package let scaledPixelData: @Sendable (Data, Int, Int, Int, Int) -> DocumentRenderingResult<Data>
    package let translatedPixelData: @Sendable (Data, Int, Int, Int, Int, Int, Int) -> DocumentRenderingResult<Data>
    package let releaseSurfaceHandle: @Sendable (MetalBufferHandle?) -> Void

    public init(
        compositedPaperPreviewRGBA: @escaping @Sendable (Data, Int, Int, CanvasPaperStyle) -> DocumentRenderingResult<Data>,
        compositedPreviewPixelData: @escaping @Sendable (MetalDocumentSnapshot, Int, Data) -> DocumentRenderingResult<Data>,
        compositedPreviewIncrementalUpdate: @escaping @Sendable (MetalDocumentSnapshot, Int, Data, LayerPixelRect) -> DocumentRenderingResult<IncrementalLayerUpdate>,
        selectionOverlayRGBA: @escaping @Sendable (Data, Int, Int) -> DocumentRenderingResult<Data>,
        eyedropperLoupeRGBA: @escaping @Sendable (Data, Int, Int, Int, Int, Int, CanvasPaperStyle, Bool) -> DocumentRenderingResult<Data>,
        shapePreviewSurface: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int, Int) -> DocumentRenderingResult<DocumentCompositeSurface>,
        textLayerSurface: @escaping @Sendable (TextLayerData, CGSize) -> DocumentRenderingResult<DocumentCompositeSurface>,
        textLayoutRect: @escaping @Sendable (TextLayerData, CGSize) -> CGRect?,
        processedLayerPixelData: @escaping @Sendable (Data, Int, Int, LayerProcessingRequest) -> DocumentRenderingResult<Data>,
        alphaMask: @escaping @Sendable (Data, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        croppedSelectionMask: @escaping @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?,
        combinedSelectionMask: @escaping @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        expandedSelectionMask: @escaping @Sendable (ExpandedSelectionMaskRequest) -> DocumentRenderingResult<[UInt8]>,
        lassoSelection: @escaping @Sendable ([CGPoint], Int, Int) -> DocumentRenderingResult<[UInt8]>,
        autoSelection: @escaping @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> DocumentRenderingResult<[UInt8]>,
        colorRangeSelection: @escaping @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> DocumentRenderingResult<[UInt8]>,
        expandedMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        contractedMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        featheredMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        invertMask: @escaping @Sendable ([UInt8]) -> DocumentRenderingResult<[UInt8]>,
        transformedSelectionMask: @escaping @Sendable (TransformedSelectionMaskRequest) -> DocumentRenderingResult<[UInt8]>,
        transformedLayerPixelData: @escaping @Sendable (TransformedLayerPixelDataRequest) -> DocumentRenderingResult<Data>,
        scaledPixelData: @escaping @Sendable (Data, Int, Int, Int, Int) -> DocumentRenderingResult<Data>,
        translatedPixelData: @escaping @Sendable (Data, Int, Int, Int, Int, Int, Int) -> DocumentRenderingResult<Data>,
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

public struct DocumentCanvasPreviewRenderingOperations: Sendable {
    package let compositedPaperPreviewRGBA: @Sendable (Data, Int, Int, CanvasPaperStyle) -> DocumentRenderingResult<Data>
    package let compositedPreviewPixelData: @Sendable (MetalDocumentSnapshot, Int, Data) -> DocumentRenderingResult<Data>
    package let selectionOverlayRGBA: @Sendable (Data, Int, Int) -> DocumentRenderingResult<Data>
    package let eyedropperLoupeRGBA: @Sendable (Data, Int, Int, Int, Int, Int, CanvasPaperStyle, Bool) -> DocumentRenderingResult<Data>
    package let shapePreviewSurface: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Int) -> DocumentRenderingResult<DocumentCompositeSurface>
    package let textLayerSurface: @Sendable (TextLayerData, CGSize) -> DocumentRenderingResult<DocumentCompositeSurface>
    package let textLayoutRect: @Sendable (TextLayerData, CGSize) -> CGRect?

    public init(
        compositedPaperPreviewRGBA: @escaping @Sendable (Data, Int, Int, CanvasPaperStyle) -> DocumentRenderingResult<Data>,
        compositedPreviewPixelData: @escaping @Sendable (MetalDocumentSnapshot, Int, Data) -> DocumentRenderingResult<Data>,
        selectionOverlayRGBA: @escaping @Sendable (Data, Int, Int) -> DocumentRenderingResult<Data>,
        eyedropperLoupeRGBA: @escaping @Sendable (Data, Int, Int, Int, Int, Int, CanvasPaperStyle, Bool) -> DocumentRenderingResult<Data>,
        shapePreviewSurface: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int, Int) -> DocumentRenderingResult<DocumentCompositeSurface>,
        textLayerSurface: @escaping @Sendable (TextLayerData, CGSize) -> DocumentRenderingResult<DocumentCompositeSurface>,
        textLayoutRect: @escaping @Sendable (TextLayerData, CGSize) -> CGRect?
    ) {
        self.compositedPaperPreviewRGBA = compositedPaperPreviewRGBA
        self.compositedPreviewPixelData = compositedPreviewPixelData
        self.selectionOverlayRGBA = selectionOverlayRGBA
        self.eyedropperLoupeRGBA = eyedropperLoupeRGBA
        self.shapePreviewSurface = shapePreviewSurface
        self.textLayerSurface = textLayerSurface
        self.textLayoutRect = textLayoutRect
    }
}

public struct DocumentSelectionMaskOperations: Sendable {
    package let alphaMask: @Sendable (Data, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let croppedSelectionMask: @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?
    package let combinedSelectionMask: @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let expandedSelectionMask: @Sendable (ExpandedSelectionMaskRequest) -> DocumentRenderingResult<[UInt8]>
    package let lassoSelection: @Sendable ([CGPoint], Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let autoSelection: @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> DocumentRenderingResult<[UInt8]>
    package let colorRangeSelection: @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> DocumentRenderingResult<[UInt8]>
    package let expandedMask: @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let contractedMask: @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let featheredMask: @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let invertMask: @Sendable ([UInt8]) -> DocumentRenderingResult<[UInt8]>
    package let transformedSelectionMask: @Sendable (TransformedSelectionMaskRequest) -> DocumentRenderingResult<[UInt8]>

    public init(
        alphaMask: @escaping @Sendable (Data, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        croppedSelectionMask: @escaping @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?,
        combinedSelectionMask: @escaping @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        expandedSelectionMask: @escaping @Sendable (ExpandedSelectionMaskRequest) -> DocumentRenderingResult<[UInt8]>,
        lassoSelection: @escaping @Sendable ([CGPoint], Int, Int) -> DocumentRenderingResult<[UInt8]>,
        autoSelection: @escaping @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> DocumentRenderingResult<[UInt8]>,
        colorRangeSelection: @escaping @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> DocumentRenderingResult<[UInt8]>,
        expandedMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        contractedMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        featheredMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        invertMask: @escaping @Sendable ([UInt8]) -> DocumentRenderingResult<[UInt8]>,
        transformedSelectionMask: @escaping @Sendable (TransformedSelectionMaskRequest) -> DocumentRenderingResult<[UInt8]>
    ) {
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
    }
}

public struct DocumentLayerTransformOperations: Sendable {
    package let transformedLayerPixelData: @Sendable (TransformedLayerPixelDataRequest) -> DocumentRenderingResult<Data>

    public init(
        transformedLayerPixelData: @escaping @Sendable (TransformedLayerPixelDataRequest) -> DocumentRenderingResult<Data>
    ) {
        self.transformedLayerPixelData = transformedLayerPixelData
    }
}

public struct DocumentRenderingOperations: Sendable {
    package let compositedPaperPreviewRGBA: @Sendable (Data, Int, Int, CanvasPaperStyle) -> DocumentRenderingResult<Data>
    package let compositedPreviewPixelData: @Sendable (MetalDocumentSnapshot, Int, Data) -> DocumentRenderingResult<Data>
    package let processedLayerPixelData: @Sendable (Data, Int, Int, LayerProcessingRequest) -> DocumentRenderingResult<Data>
    package let alphaMask: @Sendable (Data, Int, Int) -> DocumentRenderingResult<[UInt8]>
    package let croppedSelectionMask: @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?
    package let scaledPixelData: @Sendable (Data, Int, Int, Int, Int) -> DocumentRenderingResult<Data>
    package let translatedPixelData: @Sendable (Data, Int, Int, Int, Int, Int, Int) -> DocumentRenderingResult<Data>

    public init(
        compositedPaperPreviewRGBA: @escaping @Sendable (Data, Int, Int, CanvasPaperStyle) -> DocumentRenderingResult<Data>,
        compositedPreviewPixelData: @escaping @Sendable (MetalDocumentSnapshot, Int, Data) -> DocumentRenderingResult<Data>,
        processedLayerPixelData: @escaping @Sendable (Data, Int, Int, LayerProcessingRequest) -> DocumentRenderingResult<Data>,
        alphaMask: @escaping @Sendable (Data, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        croppedSelectionMask: @escaping @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?,
        scaledPixelData: @escaping @Sendable (Data, Int, Int, Int, Int) -> DocumentRenderingResult<Data>,
        translatedPixelData: @escaping @Sendable (Data, Int, Int, Int, Int, Int, Int) -> DocumentRenderingResult<Data>
    ) {
        self.compositedPaperPreviewRGBA = compositedPaperPreviewRGBA
        self.compositedPreviewPixelData = compositedPreviewPixelData
        self.processedLayerPixelData = processedLayerPixelData
        self.alphaMask = alphaMask
        self.croppedSelectionMask = croppedSelectionMask
        self.scaledPixelData = scaledPixelData
        self.translatedPixelData = translatedPixelData
    }
}

public struct StrokePreviewLease: Equatable, Sendable {
    package let surfaceHandle: MetalBufferHandle?

    public static let none = StrokePreviewLease(surfaceHandle: nil)

    package init(surfaceHandle: MetalBufferHandle?) {
        self.surfaceHandle = surfaceHandle
    }

    public var isPresent: Bool {
        surfaceHandle != nil
    }
}

public protocol SurfaceHandleReleasing: Sendable {
    func releaseSurfaceLease(_ lease: StrokePreviewLease)
}

public struct DocumentSurfaceHandleReleaser: SurfaceHandleReleasing {
    private let releaseSurfaceHandleHandler: @Sendable (MetalBufferHandle?) -> Void

    public init(releaseSurfaceHandle: @escaping @Sendable (MetalBufferHandle?) -> Void) {
        self.releaseSurfaceHandleHandler = releaseSurfaceHandle
    }

    public func releaseSurfaceLease(_ lease: StrokePreviewLease) {
        releaseSurfaceHandleHandler(lease.surfaceHandle)
    }
}

public extension DocumentGpuOperationGateway {
    var canvasPreviewRenderingOperations: DocumentCanvasPreviewRenderingOperations {
        DocumentCanvasPreviewRenderingOperations(
            compositedPaperPreviewRGBA: compositedPaperPreviewRGBA,
            compositedPreviewPixelData: compositedPreviewPixelData,
            selectionOverlayRGBA: selectionOverlayRGBA,
            eyedropperLoupeRGBA: eyedropperLoupeRGBA,
            shapePreviewSurface: shapePreviewSurface,
            textLayerSurface: textLayerSurface,
            textLayoutRect: textLayoutRect
        )
    }

    var selectionMaskOperations: DocumentSelectionMaskOperations {
        DocumentSelectionMaskOperations(
            alphaMask: alphaMask,
            croppedSelectionMask: croppedSelectionMask,
            combinedSelectionMask: combinedSelectionMask,
            expandedSelectionMask: expandedSelectionMask,
            lassoSelection: lassoSelection,
            autoSelection: autoSelection,
            colorRangeSelection: colorRangeSelection,
            expandedMask: expandedMask,
            contractedMask: contractedMask,
            featheredMask: featheredMask,
            invertMask: invertMask,
            transformedSelectionMask: transformedSelectionMask
        )
    }

    var layerTransformOperations: DocumentLayerTransformOperations {
        DocumentLayerTransformOperations(transformedLayerPixelData: transformedLayerPixelData)
    }

    var renderingOperations: DocumentRenderingOperations {
        DocumentRenderingOperations(
            compositedPaperPreviewRGBA: compositedPaperPreviewRGBA,
            compositedPreviewPixelData: compositedPreviewPixelData,
            processedLayerPixelData: processedLayerPixelData,
            alphaMask: alphaMask,
            croppedSelectionMask: croppedSelectionMask,
            scaledPixelData: scaledPixelData,
            translatedPixelData: translatedPixelData
        )
    }

    var surfaceHandleReleaser: DocumentSurfaceHandleReleaser {
        DocumentSurfaceHandleReleaser(releaseSurfaceHandle: releaseSurfaceHandle)
    }
}
