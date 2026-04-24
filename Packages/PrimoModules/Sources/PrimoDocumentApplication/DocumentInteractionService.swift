import Foundation
import PrimoDocumentContracts
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

public enum DocumentInteractionRequest: Equatable, Sendable {
    case compositeSurface
    case newCanvas(width: Int, height: Int)
    case resizeCanvas(width: Int, height: Int)
    case resizeCanvasExtent(width: Int, height: Int)
    case initializeImportedCanvas(ImportedCanvasRequest, layerName: String)
    case beginStroke(StylusSample, BrushRuntimeSettings)
    case appendStroke(StylusSample)
    case endStroke
    case cancelStroke
    case ensureLayerVisible(Int)
    case replaceLayerPixels(layerIndex: Int, pixelData: Data)
    case replaceLayerPixelsInRect(layerIndex: Int, rect: LayerPixelRect, pixelData: Data)
    case applyLayerMutation(layerIndex: Int, payload: DocumentLayerMutationPayload)
    case applyTextLayerMutation(layerIndex: Int, textLayer: TextLayerData, payload: DocumentLayerMutationPayload)
    case applySoftwareStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int)
    case revealLayerForEditing(Int)
    case blurStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, clearSelectionAfterBlur: Bool)
    case endBlurStroke
    case fill(StylusSample, BrushRuntimeSettings)
    case undo
    case redo
}

public enum DocumentInteractionResult: Equatable, Sendable {
    case none
    case compositeSurface(DocumentCompositeSurface)
}

public struct DocumentInteractionService: Sendable {
    public var execute: @Sendable (DocumentInteractionRequest) -> Result<DocumentInteractionResult, DocumentMutationFailure>

    public init(
        execute: @escaping @Sendable (DocumentInteractionRequest) -> Result<DocumentInteractionResult, DocumentMutationFailure>
    ) {
        self.execute = execute
    }

    public init(
        queryGateway: DocumentQueryGateway,
        mutationGateway: DocumentMutationGateway,
        strokeGateway: StrokeInputGateway,
        historyGateway: DocumentHistoryGateway,
        persistenceGateway: DocumentPersistenceGateway
    ) {
        self.execute = { request in
            switch request {
            case .compositeSurface:
                return .success(.compositeSurface(queryGateway.compositeSurface()))

            case let .newCanvas(width, height):
                persistenceGateway.newCanvas(width, height)
                persistenceGateway.prewarmDrawingResources()
                return .success(.none)

            case let .resizeCanvas(width, height):
                return mutationGateway.resizeCanvas(width, height).map { .none }

            case let .resizeCanvasExtent(width, height):
                return mutationGateway.resizeCanvasExtent(width, height).map { .none }

            case let .initializeImportedCanvas(request, layerName):
                persistenceGateway.newCanvas(request.width, request.height)
                persistenceGateway.prewarmDrawingResources()
                switch mutationGateway.replaceLayerPixels(0, request.pixelData) {
                case let .failure(failure):
                    return .failure(failure)
                case .success:
                    break
                }
                switch mutationGateway.setLayerName(0, layerName) {
                case let .failure(failure):
                    return .failure(failure)
                case .success:
                    break
                }
                return mutationGateway.setActiveLayer(0).map { .none }

            case let .beginStroke(sample, brush):
                strokeGateway.beginStroke(sample, brush)
                return .success(.none)

            case let .appendStroke(sample):
                strokeGateway.appendStroke(sample)
                return .success(.none)

            case .endStroke:
                strokeGateway.endStroke()
                return .success(.none)

            case .cancelStroke:
                strokeGateway.cancelStroke()
                return .success(.none)

            case let .ensureLayerVisible(layerIndex):
                return mutationGateway.setLayerVisibility(layerIndex, true).map { .none }

            case let .replaceLayerPixels(layerIndex, pixelData):
                return mutationGateway.replaceLayerPixels(layerIndex, pixelData).map { .none }

            case let .replaceLayerPixelsInRect(layerIndex, rect, pixelData):
                return mutationGateway.replaceLayerPixelsInRect(layerIndex, rect, pixelData).map { .none }

            case let .applyLayerMutation(layerIndex, payload):
                return mutationGateway.applyLayerMutation(layerIndex, payload).map { .none }

            case let .applyTextLayerMutation(layerIndex, textLayer, payload):
                return mutationGateway.applyTextLayerMutation(layerIndex, textLayer, payload).map { .none }

            case let .applySoftwareStroke(samples, brush, layerIndex):
                return strokeGateway.applySoftwareStroke(samples, brush, layerIndex).map { .none }

            case let .revealLayerForEditing(layerIndex):
                return mutationGateway.revealLayerForEditing(layerIndex).map { .none }

            case let .blurStroke(samples, brush, layerIndex, clearSelectionAfterBlur):
                return strokeGateway.blurStroke(samples, brush, layerIndex, clearSelectionAfterBlur).map { .none }

            case .endBlurStroke:
                strokeGateway.endBlurStroke()
                return .success(.none)

            case let .fill(sample, brush):
                return strokeGateway.fill(sample, brush).map { .none }

            case .undo:
                return historyGateway.undo().map { .none }

            case .redo:
                return historyGateway.redo().map { .none }
            }
        }
    }

    @available(*, deprecated, message: "Prefer compositeSurface() for live rendering queries.")
    public func compositePixelData() -> Data {
        // Legacy convenience retained for callers that still expect readback bytes.
        compositeSurface().pixelData
    }

    public func compositeSurface() -> DocumentCompositeSurface {
        switch execute(.compositeSurface) {
        case let .success(.compositeSurface(surface)):
            return surface
        case .success(.none), .failure:
            return DocumentCompositeSurface(width: 0, height: 0, pixelData: Data())
        }
    }

    public func createCanvas(width: Int, height: Int) -> DocumentMutationResult {
        execute(.newCanvas(width: width, height: height)).map { _ in () }
    }

    public func resizeCanvas(width: Int, height: Int) -> DocumentMutationResult {
        execute(.resizeCanvas(width: width, height: height)).map { _ in () }
    }

    public func resizeCanvasExtent(width: Int, height: Int) -> DocumentMutationResult {
        execute(.resizeCanvasExtent(width: width, height: height)).map { _ in () }
    }

    public func initializeImportedCanvas(
        _ request: ImportedCanvasRequest,
        layerName: String
    ) -> DocumentMutationResult {
        execute(.initializeImportedCanvas(request, layerName: layerName)).map { _ in () }
    }

    public func ensureLayerVisible(_ layerIndex: Int) -> DocumentMutationResult {
        execute(.ensureLayerVisible(layerIndex)).map { _ in () }
    }

    public func beginStroke(_ sample: StylusSample, brush: BrushRuntimeSettings) {
        _ = execute(.beginStroke(sample, brush))
    }

    public func appendStroke(_ sample: StylusSample) {
        _ = execute(.appendStroke(sample))
    }

    public func endStroke() {
        _ = execute(.endStroke)
    }

    public func cancelStroke() {
        _ = execute(.cancelStroke)
    }

    public func replaceLayerPixels(
        _ layerIndex: Int,
        pixelData: Data
    ) -> DocumentMutationResult {
        execute(.replaceLayerPixels(layerIndex: layerIndex, pixelData: pixelData)).map { _ in () }
    }

    public func replaceLayerPixels(
        _ layerIndex: Int,
        in dirtyRect: LayerPixelRect,
        pixelData: Data
    ) -> DocumentMutationResult {
        execute(.replaceLayerPixelsInRect(layerIndex: layerIndex, rect: dirtyRect, pixelData: pixelData)).map { _ in () }
    }

    public func applyLayerMutation(
        _ layerIndex: Int,
        payload: DocumentLayerMutationPayload
    ) -> DocumentMutationResult {
        execute(.applyLayerMutation(layerIndex: layerIndex, payload: payload)).map { _ in () }
    }

    public func applyTextLayerMutation(
        _ layerIndex: Int,
        textLayer: TextLayerData,
        payload: DocumentLayerMutationPayload
    ) -> DocumentMutationResult {
        execute(.applyTextLayerMutation(layerIndex: layerIndex, textLayer: textLayer, payload: payload)).map { _ in () }
    }

    public func applySoftwareStroke(
        _ samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int
    ) -> DocumentMutationResult {
        execute(.applySoftwareStroke(samples: samples, brush: brush, layerIndex: layerIndex)).map { _ in () }
    }

    public func revealLayerForEditing(_ layerIndex: Int) -> DocumentMutationResult {
        execute(.revealLayerForEditing(layerIndex)).map { _ in () }
    }

    public func blurStroke(
        _ samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int,
        clearSelectionAfterBlur: Bool
    ) -> DocumentMutationResult {
        execute(.blurStroke(samples: samples, brush: brush, layerIndex: layerIndex, clearSelectionAfterBlur: clearSelectionAfterBlur)).map { _ in () }
    }

    public func endBlurStroke() {
        _ = execute(.endBlurStroke)
    }

    public func fill(
        _ sample: StylusSample,
        brush: BrushRuntimeSettings
    ) -> DocumentMutationResult {
        execute(.fill(sample, brush)).map { _ in () }
    }

    public func undo() -> DocumentMutationResult {
        execute(.undo).map { _ in () }
    }

    public func redo() -> DocumentMutationResult {
        execute(.redo).map { _ in () }
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

    public init(interactionService: DocumentInteractionService) {
        self.init(
            createCanvas: interactionService.createCanvas(width:height:),
            resizeCanvas: interactionService.resizeCanvas(width:height:),
            resizeCanvasExtent: interactionService.resizeCanvasExtent(width:height:),
            initializeImportedCanvas: interactionService.initializeImportedCanvas(_:layerName:),
            compositeSurface: interactionService.compositeSurface
        )
    }
}

public struct DocumentLayerCommandService: Sendable {
    public var ensureLayerVisible: @Sendable (Int) -> DocumentMutationResult
    public var replaceLayerPixels: @Sendable (_ layerIndex: Int, _ pixelData: Data) -> DocumentMutationResult
    public var replaceLayerPixelsInRect: @Sendable (_ layerIndex: Int, _ rect: LayerPixelRect, _ pixelData: Data) -> DocumentMutationResult
    public var applyLayerMutation: @Sendable (_ layerIndex: Int, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult
    public var applyTextLayerMutation: @Sendable (_ layerIndex: Int, _ textLayer: TextLayerData, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult
    public var revealLayerForEditing: @Sendable (Int) -> DocumentMutationResult

    public init(
        ensureLayerVisible: @escaping @Sendable (Int) -> DocumentMutationResult,
        replaceLayerPixels: @escaping @Sendable (_ layerIndex: Int, _ pixelData: Data) -> DocumentMutationResult,
        replaceLayerPixelsInRect: @escaping @Sendable (_ layerIndex: Int, _ rect: LayerPixelRect, _ pixelData: Data) -> DocumentMutationResult,
        applyLayerMutation: @escaping @Sendable (_ layerIndex: Int, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult,
        applyTextLayerMutation: @escaping @Sendable (_ layerIndex: Int, _ textLayer: TextLayerData, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult,
        revealLayerForEditing: @escaping @Sendable (Int) -> DocumentMutationResult
    ) {
        self.ensureLayerVisible = ensureLayerVisible
        self.replaceLayerPixels = replaceLayerPixels
        self.replaceLayerPixelsInRect = replaceLayerPixelsInRect
        self.applyLayerMutation = applyLayerMutation
        self.applyTextLayerMutation = applyTextLayerMutation
        self.revealLayerForEditing = revealLayerForEditing
    }

    public init(interactionService: DocumentInteractionService) {
        self.init(
            ensureLayerVisible: interactionService.ensureLayerVisible,
            replaceLayerPixels: interactionService.replaceLayerPixels(_:pixelData:),
            replaceLayerPixelsInRect: interactionService.replaceLayerPixels(_:in:pixelData:),
            applyLayerMutation: interactionService.applyLayerMutation(_:payload:),
            applyTextLayerMutation: interactionService.applyTextLayerMutation(_:textLayer:payload:),
            revealLayerForEditing: interactionService.revealLayerForEditing
        )
    }
}

public struct DocumentStrokeCommandService: Sendable {
    public var beginStroke: @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> Void
    public var appendStroke: @Sendable (StylusSample) -> Void
    public var endStroke: @Sendable () -> Void
    public var cancelStroke: @Sendable () -> Void
    public var applySoftwareStroke: @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int) -> DocumentMutationResult
    public var blurStroke: @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int, _ clearSelectionAfterBlur: Bool) -> DocumentMutationResult
    public var endBlurStroke: @Sendable () -> Void
    public var fill: @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult

    public init(
        beginStroke: @escaping @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> Void,
        appendStroke: @escaping @Sendable (StylusSample) -> Void,
        endStroke: @escaping @Sendable () -> Void,
        cancelStroke: @escaping @Sendable () -> Void,
        applySoftwareStroke: @escaping @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int) -> DocumentMutationResult,
        blurStroke: @escaping @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int, _ clearSelectionAfterBlur: Bool) -> DocumentMutationResult,
        endBlurStroke: @escaping @Sendable () -> Void,
        fill: @escaping @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult
    ) {
        self.beginStroke = beginStroke
        self.appendStroke = appendStroke
        self.endStroke = endStroke
        self.cancelStroke = cancelStroke
        self.applySoftwareStroke = applySoftwareStroke
        self.blurStroke = blurStroke
        self.endBlurStroke = endBlurStroke
        self.fill = fill
    }

    public init(interactionService: DocumentInteractionService) {
        self.init(
            beginStroke: interactionService.beginStroke(_:brush:),
            appendStroke: interactionService.appendStroke,
            endStroke: interactionService.endStroke,
            cancelStroke: interactionService.cancelStroke,
            applySoftwareStroke: interactionService.applySoftwareStroke(_:brush:layerIndex:),
            blurStroke: interactionService.blurStroke(_:brush:layerIndex:clearSelectionAfterBlur:),
            endBlurStroke: interactionService.endBlurStroke,
            fill: interactionService.fill(_:brush:)
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

    public init(interactionService: DocumentInteractionService) {
        self.init(
            undo: interactionService.undo,
            redo: interactionService.redo
        )
    }
}
