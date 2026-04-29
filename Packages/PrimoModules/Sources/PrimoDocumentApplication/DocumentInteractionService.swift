import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain

public struct ImportedCanvasRequest: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixelData: Data

    public init(width: Int, height: Int, pixelData: Data) {
        self.width = width
        self.height = height
        self.pixelData = pixelData
    }
}

public struct DocumentCanvasCommandService: Sendable {
    public var createCanvas: @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult
    public var resizeCanvas: @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult
    public var resizeCanvasExtent: @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult
    public var initializeImportedCanvas: @Sendable (_ request: ImportedCanvasRequest, _ layerName: String) -> DocumentMutationResult
    public var compositeSurface: @Sendable () -> DocumentCompositeSurface

    public init(
        createCanvas: @escaping @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult,
        resizeCanvas: @escaping @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult,
        resizeCanvasExtent: @escaping @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult,
        initializeImportedCanvas: @escaping @Sendable (_ request: ImportedCanvasRequest, _ layerName: String) -> DocumentMutationResult,
        compositeSurface: @escaping @Sendable () -> DocumentCompositeSurface
    ) {
        self.createCanvas = createCanvas
        self.resizeCanvas = resizeCanvas
        self.resizeCanvasExtent = resizeCanvasExtent
        self.initializeImportedCanvas = initializeImportedCanvas
        self.compositeSurface = compositeSurface
    }

    public init(
        queryGateway: DocumentQueryGateway,
        mutationGateway: DocumentMutationGateway,
        persistenceGateway: DocumentPersistenceGateway
    ) {
        self.init(
            createCanvas: { width, height in
                persistenceGateway.newCanvas(width, height)
                persistenceGateway.prewarmDrawingResources()
                return .success(())
            },
            resizeCanvas: mutationGateway.resizeCanvas,
            resizeCanvasExtent: mutationGateway.resizeCanvasExtent,
            initializeImportedCanvas: { request, layerName in
                persistenceGateway.newCanvas(request.width, request.height)
                persistenceGateway.prewarmDrawingResources()
                switch mutationGateway.replaceLayerPixels(0, request.pixelData) {
                case let .failure(failure): return .failure(failure)
                case .success: break
                }
                switch mutationGateway.setLayerName(0, layerName) {
                case let .failure(failure): return .failure(failure)
                case .success: break
                }
                return mutationGateway.setActiveLayer(0)
            },
            compositeSurface: queryGateway.compositeSurface
        )
    }
}

public struct DocumentLayerCommandService: Sendable {
    public var ensureLayerVisible: @Sendable (Int) -> DocumentMutationResult
    public var replaceLayerPixels: @Sendable (_ layerIndex: Int, _ pixelData: Data) -> DocumentMutationResult
    public var replaceLayerPixelsInRect: @Sendable (_ layerIndex: Int, _ rect: LayerPixelRect, _ pixelData: Data) -> DocumentMutationResult
    public var applyLayerSurfaceMutation: @Sendable (_ layerIndex: Int, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult
    public var applyLayerMutation: @Sendable (_ layerIndex: Int, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult
    public var applyTextLayerMutation: @Sendable (_ layerIndex: Int, _ textLayer: TextLayerData, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult
    public var revealLayerForEditing: @Sendable (Int) -> DocumentMutationResult

    public init(
        ensureLayerVisible: @escaping @Sendable (Int) -> DocumentMutationResult,
        replaceLayerPixels: @escaping @Sendable (_ layerIndex: Int, _ pixelData: Data) -> DocumentMutationResult,
        replaceLayerPixelsInRect: @escaping @Sendable (_ layerIndex: Int, _ rect: LayerPixelRect, _ pixelData: Data) -> DocumentMutationResult,
        applyLayerSurfaceMutation: @escaping @Sendable (_ layerIndex: Int, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult,
        applyLayerMutation: @escaping @Sendable (_ layerIndex: Int, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult,
        applyTextLayerMutation: @escaping @Sendable (_ layerIndex: Int, _ textLayer: TextLayerData, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult,
        revealLayerForEditing: @escaping @Sendable (Int) -> DocumentMutationResult
    ) {
        self.ensureLayerVisible = ensureLayerVisible
        self.replaceLayerPixels = replaceLayerPixels
        self.replaceLayerPixelsInRect = replaceLayerPixelsInRect
        self.applyLayerSurfaceMutation = applyLayerSurfaceMutation
        self.applyLayerMutation = applyLayerMutation
        self.applyTextLayerMutation = applyTextLayerMutation
        self.revealLayerForEditing = revealLayerForEditing
    }

    public init(mutationGateway: DocumentMutationGateway) {
        self.init(
            ensureLayerVisible: { mutationGateway.setLayerVisibility($0, true) },
            replaceLayerPixels: mutationGateway.replaceLayerPixels,
            replaceLayerPixelsInRect: mutationGateway.replaceLayerPixelsInRect,
            applyLayerSurfaceMutation: mutationGateway.applyLayerSurfaceMutation,
            applyLayerMutation: mutationGateway.applyLayerMutation,
            applyTextLayerMutation: mutationGateway.applyTextLayerMutation,
            revealLayerForEditing: mutationGateway.revealLayerForEditing
        )
    }
}

public struct DocumentStrokeCommandService: Sendable {
    public var beginStroke: @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> Void
    public var appendStroke: @Sendable (StylusSample) -> Void
    public var endStroke: @Sendable () -> DocumentMutationResult
    public var cancelStroke: @Sendable () -> Void
    public var applyGpuStrokeSurface: @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int) -> DocumentMutationResult
    public var blurStroke: @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int, _ clearSelectionAfterBlur: Bool) -> DocumentMutationResult
    public var endBlurStroke: @Sendable () -> DocumentMutationResult
    public var fill: @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult

    public init(
        beginStroke: @escaping @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> Void,
        appendStroke: @escaping @Sendable (StylusSample) -> Void,
        endStroke: @escaping @Sendable () -> DocumentMutationResult,
        cancelStroke: @escaping @Sendable () -> Void,
        applyGpuStrokeSurface: @escaping @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int) -> DocumentMutationResult,
        blurStroke: @escaping @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int, _ clearSelectionAfterBlur: Bool) -> DocumentMutationResult,
        endBlurStroke: @escaping @Sendable () -> DocumentMutationResult,
        fill: @escaping @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult
    ) {
        self.beginStroke = beginStroke
        self.appendStroke = appendStroke
        self.endStroke = endStroke
        self.cancelStroke = cancelStroke
        self.applyGpuStrokeSurface = applyGpuStrokeSurface
        self.blurStroke = blurStroke
        self.endBlurStroke = endBlurStroke
        self.fill = fill
    }

    public init(strokeGateway: StrokeInputGateway) {
        self.init(
            beginStroke: strokeGateway.beginStroke,
            appendStroke: strokeGateway.appendStroke,
            endStroke: strokeGateway.endStroke,
            cancelStroke: strokeGateway.cancelStroke,
            applyGpuStrokeSurface: strokeGateway.applyGpuStrokeSurface,
            blurStroke: strokeGateway.blurStroke,
            endBlurStroke: strokeGateway.endBlurStroke,
            fill: strokeGateway.fill
        )
    }
}

public struct DocumentHistoryCommandService: Sendable {
    public var undo: @Sendable () -> DocumentMutationResult
    public var redo: @Sendable () -> DocumentMutationResult

    public init(
        undo: @escaping @Sendable () -> DocumentMutationResult,
        redo: @escaping @Sendable () -> DocumentMutationResult
    ) {
        self.undo = undo
        self.redo = redo
    }

    public init(historyGateway: DocumentHistoryGateway) {
        self.init(
            undo: historyGateway.undo,
            redo: historyGateway.redo
        )
    }
}
