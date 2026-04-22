import Foundation
import PrimoDocumentContracts

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
    case compositePixelData
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
    case compositePixelData(Data)
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
            case .compositePixelData:
                return .success(.compositePixelData(queryGateway.compositePixelData()))

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

    public func compositePixelData() -> Data {
        switch execute(.compositePixelData) {
        case let .success(.compositePixelData(data)):
            return data
        case .success(.none), .failure:
            return Data()
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
