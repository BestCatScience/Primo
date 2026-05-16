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

    public var validatedSize: ValidCanvasSize? {
        ValidCanvasSize(width, height)
    }

    package var validatedPixelData: LayerPixelData? {
        LayerPixelData(width: width, height: height, rgba: pixelData)
    }
}

public struct DocumentCanvasCommandService: Sendable {
    package let rawCreateCanvas: @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult
    package let rawResizeCanvas: @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult
    package let rawResizeCanvasExtent: @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult
    public let initializeImportedCanvas: @Sendable (_ request: ImportedCanvasRequest, _ layerName: String) -> DocumentMutationResult
    public let compositeSurface: @Sendable () -> Result<DocumentCompositeSurface, DocumentMutationFailure>

    public init(
        createCanvas: @escaping @Sendable (ValidCanvasSize) -> DocumentMutationResult,
        resizeCanvas: @escaping @Sendable (ValidCanvasSize) -> DocumentMutationResult,
        resizeCanvasExtent: @escaping @Sendable (ValidCanvasSize) -> DocumentMutationResult,
        initializeImportedCanvas: @escaping @Sendable (_ request: ImportedCanvasRequest, _ layerName: String) -> DocumentMutationResult,
        compositeSurface: @escaping @Sendable () -> Result<DocumentCompositeSurface, DocumentMutationFailure>
    ) {
        self.rawCreateCanvas = { width, height in
            guard let size = ValidCanvasSize(width, height) else {
                return .failure(.invalidCanvasSize(width: width, height: height))
            }
            return createCanvas(size)
        }
        self.rawResizeCanvas = { width, height in
            guard let size = ValidCanvasSize(width, height) else {
                return .failure(.invalidCanvasSize(width: width, height: height))
            }
            return resizeCanvas(size)
        }
        self.rawResizeCanvasExtent = { width, height in
            guard let size = ValidCanvasSize(width, height) else {
                return .failure(.invalidCanvasSize(width: width, height: height))
            }
            return resizeCanvasExtent(size)
        }
        self.initializeImportedCanvas = initializeImportedCanvas
        self.compositeSurface = compositeSurface
    }

    package init(
        rawCreateCanvas: @escaping @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult,
        rawResizeCanvas: @escaping @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult,
        rawResizeCanvasExtent: @escaping @Sendable (_ width: Int, _ height: Int) -> DocumentMutationResult,
        initializeImportedCanvas: @escaping @Sendable (_ request: ImportedCanvasRequest, _ layerName: String) -> DocumentMutationResult,
        compositeSurface: @escaping @Sendable () -> Result<DocumentCompositeSurface, DocumentMutationFailure>
    ) {
        self.rawCreateCanvas = rawCreateCanvas
        self.rawResizeCanvas = rawResizeCanvas
        self.rawResizeCanvasExtent = rawResizeCanvasExtent
        self.initializeImportedCanvas = initializeImportedCanvas
        self.compositeSurface = compositeSurface
    }

    public func createCanvas(_ size: ValidCanvasSize) -> DocumentMutationResult {
        rawCreateCanvas(size.width, size.height)
    }

    public func resizeCanvas(_ size: ValidCanvasSize) -> DocumentMutationResult {
        rawResizeCanvas(size.width, size.height)
    }

    public func resizeCanvasExtent(_ size: ValidCanvasSize) -> DocumentMutationResult {
        rawResizeCanvasExtent(size.width, size.height)
    }

    package func createCanvas(_ width: Int, _ height: Int) -> DocumentMutationResult {
        rawCreateCanvas(width, height)
    }

    package func resizeCanvas(_ width: Int, _ height: Int) -> DocumentMutationResult {
        rawResizeCanvas(width, height)
    }

    package func resizeCanvasExtent(_ width: Int, _ height: Int) -> DocumentMutationResult {
        rawResizeCanvasExtent(width, height)
    }

    public init(
        queryGateway: DocumentQueryGateway,
        renderGateway: DocumentRenderGateway,
        mutationGateway: DocumentMutationGateway,
        persistenceGateway: DocumentPersistenceGateway
    ) {
        self.init(
            rawCreateCanvas: { width, height in
                guard let size = ValidCanvasSize(width, height) else {
                    return .failure(.invalidCanvasSize(width: width, height: height))
                }
                switch persistenceGateway.newCanvas(size.width, size.height) {
                case let .failure(failure): return .failure(failure)
                case .success: break
                }
                return persistenceGateway.prewarmDrawingResources()
            },
            rawResizeCanvas: { width, height in
                guard let size = ValidCanvasSize(width, height) else {
                    return .failure(.invalidCanvasSize(width: width, height: height))
                }
                return mutationGateway.resizeCanvas(size.width, size.height)
            },
            rawResizeCanvasExtent: { width, height in
                guard let size = ValidCanvasSize(width, height) else {
                    return .failure(.invalidCanvasSize(width: width, height: height))
                }
                return mutationGateway.resizeCanvasExtent(size.width, size.height)
            },
            initializeImportedCanvas: { request, layerName in
                guard let size = request.validatedSize else {
                    return .failure(.invalidCanvasSize(width: request.width, height: request.height))
                }
                guard let layerName = NonEmptyLayerName(layerName) else {
                    return .failure(.emptyInput)
                }
                guard let pixelData = request.validatedPixelData else {
                    let geometry = PixelGeometry(width: size.width, height: size.height)
                    return .failure(
                        .gpu(
                            .invalidPayloadSize(
                                operation: "initializeImportedCanvas",
                                expected: geometry?.rgbaByteCount ?? 0,
                                actual: request.pixelData.count
                            )
                        )
                    )
                }
                switch persistenceGateway.newCanvas(size.width, size.height) {
                case let .failure(failure): return .failure(failure)
                case .success: break
                }
                switch persistenceGateway.prewarmDrawingResources() {
                case let .failure(failure): return .failure(failure)
                case .success: break
                }
                switch mutationGateway.replaceLayerPixels(0, pixelData.rgba) {
                case let .failure(failure): return .failure(failure)
                case .success: break
                }
                switch mutationGateway.setLayerName(0, layerName.rawValue) {
                case let .failure(failure): return .failure(failure)
                case .success: break
                }
                return mutationGateway.setActiveLayer(0)
            },
            compositeSurface: renderGateway.compositeSurface
        )
    }
}

public struct DocumentLayerCommandService: Sendable {
    public let ensureLayerVisible: @Sendable (Int) -> DocumentMutationResult
    public let replaceLayerPixels: @Sendable (_ layerIndex: Int, _ pixelData: Data) -> DocumentMutationResult
    public let replaceLayerPixelsInRect: @Sendable (_ layerIndex: Int, _ rect: LayerPixelRect, _ pixelData: Data) -> DocumentMutationResult
    public let applyLayerSurfaceMutation: @Sendable (_ layerIndex: Int, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult
    public let applyLayerMutation: @Sendable (_ layerIndex: Int, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult
    public let applyTextLayerMutation: @Sendable (_ layerIndex: Int, _ textLayer: TextLayerData, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult
    public let revealLayerForEditing: @Sendable (Int) -> DocumentMutationResult

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
    public let beginStroke: @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult
    public let appendStroke: @Sendable (StylusSample) -> DocumentMutationResult
    public let endStroke: @Sendable () -> DocumentMutationResult
    public let cancelStroke: @Sendable () -> DocumentMutationResult
    public let applyGpuStrokeSurface: @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int) -> DocumentMutationResult
    public let blurStroke: @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int, _ clearSelectionAfterBlur: Bool) -> DocumentMutationResult
    public let endBlurStroke: @Sendable () -> DocumentMutationResult
    public let cancelBlurStroke: @Sendable () -> DocumentMutationResult
    public let fill: @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult

    public init(
        beginStroke: @escaping @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult,
        appendStroke: @escaping @Sendable (StylusSample) -> DocumentMutationResult,
        endStroke: @escaping @Sendable () -> DocumentMutationResult,
        cancelStroke: @escaping @Sendable () -> DocumentMutationResult,
        applyGpuStrokeSurface: @escaping @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int) -> DocumentMutationResult,
        blurStroke: @escaping @Sendable (_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int, _ clearSelectionAfterBlur: Bool) -> DocumentMutationResult,
        endBlurStroke: @escaping @Sendable () -> DocumentMutationResult,
        cancelBlurStroke: @escaping @Sendable () -> DocumentMutationResult,
        fill: @escaping @Sendable (_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult
    ) {
        self.beginStroke = beginStroke
        self.appendStroke = appendStroke
        self.endStroke = endStroke
        self.cancelStroke = cancelStroke
        self.applyGpuStrokeSurface = applyGpuStrokeSurface
        self.blurStroke = blurStroke
        self.endBlurStroke = endBlurStroke
        self.cancelBlurStroke = cancelBlurStroke
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
            cancelBlurStroke: strokeGateway.cancelBlurStroke,
            fill: strokeGateway.fill
        )
    }
}

public struct DocumentHistoryCommandService: Sendable {
    public let undo: @Sendable () -> DocumentMutationResult
    public let redo: @Sendable () -> DocumentMutationResult
    public let trimForMemoryPressure: @Sendable () -> Void

    public init(
        undo: @escaping @Sendable () -> DocumentMutationResult,
        redo: @escaping @Sendable () -> DocumentMutationResult,
        trimForMemoryPressure: @escaping @Sendable () -> Void = {}
    ) {
        self.undo = undo
        self.redo = redo
        self.trimForMemoryPressure = trimForMemoryPressure
    }

    public init(historyGateway: DocumentHistoryGateway) {
        self.init(
            undo: historyGateway.undo,
            redo: historyGateway.redo,
            trimForMemoryPressure: historyGateway.trimForMemoryPressure
        )
    }
}
