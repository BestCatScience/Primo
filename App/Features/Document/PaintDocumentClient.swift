import ComposableArchitecture
import Foundation
import Synchronization

typealias DocumentMutationResult = Result<Void, DocumentMutationFailure>
typealias DocumentIndexedMutationResult = Result<Int, DocumentMutationFailure>

enum DocumentMutationFailure: Error, Equatable, Sendable, OperationFailure {
    case invalidLayerIndex(Int)
    case invalidFolderID(Int)
    case layerLocked(Int)
    case alphaLocked(Int)
    case invalidCanvasSize(width: Int, height: Int)
    case invalidOpacity(Double)
    case emptyInput
    case noUndoState
    case noRedoState
    case bridgeMutationFailed(String)
    case incompatibleLayerType(Int)
    indirect case transactionFailure(primary: DocumentMutationFailure, rollback: DocumentMutationFailure)
}

struct PaintDocumentClient: Sendable {
    var lightweightPresentation: @Sendable () -> PaintDocumentPresentation
    var presentation: @Sendable () -> PaintDocumentPresentation
    var compositePixelData: @Sendable () -> Data
    var prewarmDrawingResources: @Sendable () -> Void
    var compositePNGData: @Sendable (CanvasPaperStyle) -> Data?
    var timelapseCapture: @Sendable () -> TimelapseCapture?
    var saveProject: @Sendable (URL, CanvasPaperStyle) throws -> Void
    var loadProject: @Sendable (URL) throws -> LoadedPaintProject
    var setPaperStyle: @Sendable (CanvasPaperStyle) -> Void
    var newCanvas: @Sendable (Int, Int) -> Void
    var resizeCanvas: @Sendable (Int, Int) -> DocumentMutationResult
    var resizeCanvasExtent: @Sendable (Int, Int) -> DocumentMutationResult
    var beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var appendStroke: @Sendable (StylusSample) -> Void
    var endStroke: @Sendable () -> Void
    var cancelStroke: @Sendable () -> Void
    var blurStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult
    var endBlurStroke: @Sendable () -> Void
    var fill: @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult
    var canUndo: @Sendable () -> Bool
    var canRedo: @Sendable () -> Bool
    var undo: @Sendable () -> DocumentMutationResult
    var redo: @Sendable () -> DocumentMutationResult
    var addLayer: @Sendable (String) -> DocumentIndexedMutationResult
    var duplicateLayer: @Sendable (Int, String) -> DocumentIndexedMutationResult
    var deleteLayer: @Sendable (Int) -> DocumentMutationResult
    var moveLayer: @Sendable (Int, Int) -> DocumentMutationResult
    var createFolder: @Sendable (String, Int) -> DocumentIndexedMutationResult
    var deleteFolder: @Sendable (Int) -> DocumentMutationResult
    var setFolderVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    var setFolderName: @Sendable (Int, String) -> DocumentMutationResult
    var setFolderExpanded: @Sendable (Int, Bool) -> DocumentMutationResult
    var assignLayerToFolder: @Sendable (Int, Int) -> DocumentMutationResult
    var setActiveLayer: @Sendable (Int) -> DocumentMutationResult
    var setLayerName: @Sendable (Int, String) -> DocumentMutationResult
    var setLayerVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    var setLayerLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    var setLayerAlphaLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    var setLayerClipped: @Sendable (Int, Bool) -> DocumentMutationResult
    var revealLayerForEditing: @Sendable (Int) -> DocumentMutationResult
    var setLayerOpacity: @Sendable (Int, Double) -> DocumentMutationResult
    var setLayerBlendMode: @Sendable (Int, LayerBlendMode) -> DocumentMutationResult
    var mergeLayerDown: @Sendable (Int) -> DocumentMutationResult
    var textLayerData: @Sendable (Int) -> TextLayerData?
    var setTextLayer: @Sendable (Int, TextLayerData) -> DocumentMutationResult
    var clearTextLayerData: @Sendable (Int) -> Void
    var applyLayerProcessing: @Sendable (Int, LayerProcessingRequest) -> DocumentMutationResult
    var applySoftwareStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult
    var pixelDataForLayer: @Sendable (Int) -> Data
    var replaceLayerPixels: @Sendable (Int, Data) -> DocumentMutationResult
    var replaceLayerMask: @Sendable (Int, Data) -> DocumentMutationResult
    var clearLayerMask: @Sendable (Int) -> DocumentMutationResult
    var applyLayerMask: @Sendable (Int) -> DocumentMutationResult
    var clearLayer: @Sendable (Int) -> DocumentMutationResult
    var consumeDirtyUpdate: @Sendable () -> IncrementalLayerUpdate?

    static func live(
        fileClient: FileClient,
        dateClient: DateClient,
        uuidClient: UUIDClient
    ) -> PaintDocumentClient {
        let sessionBox = PaintDocumentSessionBox(session: PaintDocumentSession(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        ))
        return PaintDocumentClient(
            lightweightPresentation: { sessionBox.withSession { $0.lightweightPresentation() } },
            presentation: { sessionBox.withSession { $0.presentation() } },
            compositePixelData: { sessionBox.withSession { $0.compositePixelData() } },
            prewarmDrawingResources: { sessionBox.withSession { $0.prewarmDrawingResources() } },
            compositePNGData: { style in sessionBox.withSession { $0.compositePNGData(paperStyle: style) } },
            timelapseCapture: { sessionBox.withSession { $0.timelapseCapture() } },
            saveProject: { url, paperStyle in
                try sessionBox.withSession { session in
                    try session.saveProject(to: url, paperStyle: paperStyle)
                }
            },
            loadProject: { url in
                let session = try PaintDocumentSession.loadProject(
                    from: url,
                    fileClient: fileClient,
                    dateClient: dateClient,
                    uuidClient: uuidClient
                )
                let loadedProject = LoadedPaintProject(
                    presentation: session.presentation(),
                    paperStyle: session.currentPaperStyle
                )
                sessionBox.replaceSession(with: session)
                return loadedProject
            },
            setPaperStyle: { style in sessionBox.withSession { $0.setPaperStyle(style) } },
            newCanvas: { width, height in
                sessionBox.replaceSession(with: PaintDocumentSession(
                    width: width,
                    height: height,
                    fileClient: fileClient,
                    dateClient: dateClient,
                    uuidClient: uuidClient
                ))
            },
            resizeCanvas: { width, height in
                sessionBox.withSession { $0.resizeCanvasMutation(width: width, height: height) }
            },
            resizeCanvasExtent: { width, height in
                sessionBox.withSession { $0.resizeCanvasExtentMutation(width: width, height: height) }
            },
            beginStroke: { sample, brush in sessionBox.withSession { $0.beginStroke(sample: sample, brush: brush) } },
            appendStroke: { sample in sessionBox.withSession { $0.appendStroke(sample: sample) } },
            endStroke: { sessionBox.withSession { $0.endStroke() } },
            cancelStroke: { sessionBox.withSession { $0.cancelStroke() } },
            blurStroke: { samples, brush, layerIndex, captureTimelapse in
                sessionBox.withSession {
                    $0.blurMutation(samples: samples, brush: brush, layerIndex: layerIndex, captureTimelapse: captureTimelapse)
                }
            },
            endBlurStroke: { sessionBox.withSession { $0.endBlurStroke() } },
            fill: { sample, brush in sessionBox.withSession { $0.fillMutation(sample: sample, brush: brush) } },
            canUndo: { sessionBox.withSession { $0.canUndo() } },
            canRedo: { sessionBox.withSession { $0.canRedo() } },
            undo: { sessionBox.withSession { $0.undoMutation() } },
            redo: { sessionBox.withSession { $0.redoMutation() } },
            addLayer: { name in sessionBox.withSession { $0.addLayerMutation(name: name) } },
            duplicateLayer: { index, name in sessionBox.withSession { $0.duplicateLayerMutation(index: index, name: name) } },
            deleteLayer: { index in sessionBox.withSession { $0.deleteLayerMutation(index: index) } },
            moveLayer: { index, destination in sessionBox.withSession { $0.moveLayerMutation(from: index, to: destination) } },
            createFolder: { name, layerIndex in sessionBox.withSession { $0.createFolderMutation(name: name, layerIndex: layerIndex) } },
            deleteFolder: { folderID in sessionBox.withSession { $0.deleteFolderMutation(folderID: folderID) } },
            setFolderVisibility: { folderID, isVisible in sessionBox.withSession { $0.setFolderVisibilityMutation(folderID: folderID, isVisible: isVisible) } },
            setFolderName: { folderID, name in sessionBox.withSession { $0.setFolderNameMutation(folderID: folderID, name: name) } },
            setFolderExpanded: { folderID, isExpanded in sessionBox.withSession { $0.setFolderExpandedMutation(folderID: folderID, isExpanded: isExpanded) } },
            assignLayerToFolder: { index, folderID in sessionBox.withSession { $0.assignLayerMutation(index: index, toFolder: folderID) } },
            setActiveLayer: { index in sessionBox.withSession { $0.setActiveLayerMutation(index: index) } },
            setLayerName: { index, name in sessionBox.withSession { $0.setLayerNameMutation(index: index, name: name) } },
            setLayerVisibility: { index, isVisible in sessionBox.withSession { $0.setLayerVisibilityMutation(index: index, isVisible: isVisible) } },
            setLayerLocked: { index, isLocked in sessionBox.withSession { $0.setLayerLockedMutation(index: index, isLocked: isLocked) } },
            setLayerAlphaLocked: { index, isAlphaLocked in sessionBox.withSession { $0.setLayerAlphaLockedMutation(index: index, isAlphaLocked: isAlphaLocked) } },
            setLayerClipped: { index, isClipped in sessionBox.withSession { $0.setLayerClippedMutation(index: index, isClipped: isClipped) } },
            revealLayerForEditing: { index in sessionBox.withSession { $0.revealLayerForEditingMutation(index: index) } },
            setLayerOpacity: { index, opacity in sessionBox.withSession { $0.setLayerOpacityMutation(index: index, opacity: opacity) } },
            setLayerBlendMode: { index, blendMode in sessionBox.withSession { $0.setLayerBlendModeMutation(index: index, blendMode: blendMode) } },
            mergeLayerDown: { index in sessionBox.withSession { $0.mergeLayerDownMutation(index: index) } },
            textLayerData: { index in sessionBox.withSession { $0.textLayerData(index: index) } },
            setTextLayer: { index, textLayer in sessionBox.withSession { $0.setTextLayerMutation(index: index, textLayer: textLayer) } },
            clearTextLayerData: { index in sessionBox.withSession { $0.clearTextLayerData(index: index) } },
            applyLayerProcessing: { index, request in sessionBox.withSession { $0.applyLayerProcessingMutation(index: index, request: request) } },
            applySoftwareStroke: { samples, brush, layerIndex in
                sessionBox.withSession {
                    $0.applySoftwareStrokeMutation(samples: samples, brush: brush, layerIndex: layerIndex)
                }
            },
            pixelDataForLayer: { index in sessionBox.withSession { $0.pixelDataForLayer(index: index) } },
            replaceLayerPixels: { index, data in
                sessionBox.withSession { $0.replaceLayerPixelsMutation(index: index, data: data) }
            },
            replaceLayerMask: { index, data in sessionBox.withSession { $0.replaceLayerMaskMutation(index: index, data: data) } },
            clearLayerMask: { index in sessionBox.withSession { $0.clearLayerMaskMutation(index: index) } },
            applyLayerMask: { index in sessionBox.withSession { $0.applyLayerMaskMutation(index: index) } },
            clearLayer: { index in sessionBox.withSession { $0.clearLayerMutation(index: index) } },
            consumeDirtyUpdate: { sessionBox.withSession { $0.consumeDirtyUpdate() } }
        )
    }
}

private final class PaintDocumentSessionBox: Sendable {
    private let storage: Mutex<PaintDocumentSession>

    init(session: PaintDocumentSession = PaintDocumentSession()) {
        self.storage = Mutex(session)
    }

    func withSession<T>(_ body: (PaintDocumentSession) throws -> T) rethrows -> T {
        try storage.withLock { session in
            try body(session)
        }
    }

    func replaceSession(with session: PaintDocumentSession) {
        storage.withLock { currentSession in
            currentSession = session
        }
    }
}

private enum PaintDocumentClientKey: DependencyKey {
    static var liveValue: PaintDocumentClient {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient
        return .live(fileClient: fileClient, dateClient: dateClient, uuidClient: uuidClient)
    }
}

extension DependencyValues {
    var paintDocumentClient: PaintDocumentClient {
        get { self[PaintDocumentClientKey.self] }
        set { self[PaintDocumentClientKey.self] = newValue }
    }
}

extension PaintDocumentSession {
    func resizeCanvasMutation(width: Int, height: Int) -> DocumentMutationResult {
        resizeCanvas(width: width, height: height)
    }

    func resizeCanvasExtentMutation(width: Int, height: Int) -> DocumentMutationResult {
        resizeCanvasExtent(width: width, height: height)
    }

    func blurMutation(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int,
        captureTimelapse: Bool
    ) -> DocumentMutationResult {
        blur(
            samples: samples,
            brush: brush,
            layerIndex: layerIndex,
            captureTimelapse: captureTimelapse
        )
    }

    func fillMutation(
        sample: StylusSample,
        brush: BrushRuntimeSettings
    ) -> DocumentMutationResult {
        fill(sample: sample, brush: brush)
    }

    func undoMutation() -> DocumentMutationResult {
        undo()
    }

    func redoMutation() -> DocumentMutationResult {
        redo()
    }

    func addLayerMutation(name: String) -> DocumentIndexedMutationResult {
        addLayer(name: name)
    }

    func duplicateLayerMutation(
        index: Int,
        name: String
    ) -> DocumentIndexedMutationResult {
        duplicateLayer(index: index, name: name)
    }

    func deleteLayerMutation(index: Int) -> DocumentMutationResult {
        deleteLayer(index: index)
    }

    func moveLayerMutation(
        from index: Int,
        to destinationIndex: Int
    ) -> DocumentMutationResult {
        moveLayer(from: index, to: destinationIndex)
    }

    func createFolderMutation(
        name: String,
        layerIndex: Int
    ) -> DocumentIndexedMutationResult {
        createFolder(name: name, layerIndex: layerIndex)
    }

    func deleteFolderMutation(folderID: Int) -> DocumentMutationResult {
        deleteFolder(folderID: folderID)
    }

    func setFolderVisibilityMutation(
        folderID: Int,
        isVisible: Bool
    ) -> DocumentMutationResult {
        setFolderVisibility(folderID: folderID, isVisible: isVisible)
    }

    func setFolderNameMutation(
        folderID: Int,
        name: String
    ) -> DocumentMutationResult {
        setFolderName(folderID: folderID, name: name)
    }

    func setFolderExpandedMutation(
        folderID: Int,
        isExpanded: Bool
    ) -> DocumentMutationResult {
        setFolderExpanded(folderID: folderID, isExpanded: isExpanded)
    }

    func assignLayerMutation(
        index: Int,
        toFolder folderID: Int
    ) -> DocumentMutationResult {
        assignLayer(index: index, toFolder: folderID)
    }

    func setActiveLayerMutation(index: Int) -> DocumentMutationResult {
        setActiveLayer(index: index)
    }

    func setLayerNameMutation(
        index: Int,
        name: String
    ) -> DocumentMutationResult {
        setLayerName(index: index, name: name)
    }

    func setLayerVisibilityMutation(
        index: Int,
        isVisible: Bool
    ) -> DocumentMutationResult {
        setLayerVisibility(index: index, isVisible: isVisible)
    }

    func setLayerLockedMutation(
        index: Int,
        isLocked: Bool
    ) -> DocumentMutationResult {
        setLayerLocked(index: index, isLocked: isLocked)
    }

    func setLayerAlphaLockedMutation(
        index: Int,
        isAlphaLocked: Bool
    ) -> DocumentMutationResult {
        setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked)
    }

    func setLayerClippedMutation(
        index: Int,
        isClipped: Bool
    ) -> DocumentMutationResult {
        setLayerClipped(index: index, isClipped: isClipped)
    }

    func revealLayerForEditingMutation(index: Int) -> DocumentMutationResult {
        revealLayerForEditing(index: index)
    }

    func setLayerOpacityMutation(
        index: Int,
        opacity: Double
    ) -> DocumentMutationResult {
        setLayerOpacity(index: index, opacity: opacity)
    }

    func setLayerBlendModeMutation(
        index: Int,
        blendMode: LayerBlendMode
    ) -> DocumentMutationResult {
        setLayerBlendMode(index: index, blendMode: blendMode)
    }

    func mergeLayerDownMutation(index: Int) -> DocumentMutationResult {
        mergeLayerDown(index: index)
    }

    func setTextLayerMutation(
        index: Int,
        textLayer: TextLayerData
    ) -> DocumentMutationResult {
        setTextLayer(index: index, textLayer: textLayer)
    }

    func applyLayerProcessingMutation(
        index: Int,
        request: LayerProcessingRequest
    ) -> DocumentMutationResult {
        applyLayerProcessing(index: index, request: request)
    }

    func applySoftwareStrokeMutation(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int
    ) -> DocumentMutationResult {
        applySoftwareStroke(samples: samples, brush: brush, layerIndex: layerIndex)
    }

    func replaceLayerPixelsMutation(
        index: Int,
        data: Data
    ) -> DocumentMutationResult {
        replaceLayerPixels(index: index, data: data)
    }

    func replaceLayerMaskMutation(
        index: Int,
        data: Data
    ) -> DocumentMutationResult {
        replaceLayerMask(index: index, maskData: data)
    }

    func clearLayerMaskMutation(index: Int) -> DocumentMutationResult {
        clearLayerMask(index: index)
    }

    func applyLayerMaskMutation(index: Int) -> DocumentMutationResult {
        applyLayerMask(index: index)
    }

    func clearLayerMutation(index: Int) -> DocumentMutationResult {
        clearLayer(index: index)
    }
}
