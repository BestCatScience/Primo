import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentInfrastructure

typealias DocumentMutationResult = PrimoDocumentContracts.DocumentMutationResult
typealias DocumentIndexedMutationResult = PrimoDocumentContracts.DocumentIndexedMutationResult
typealias DocumentMutationFailure = PrimoDocumentContracts.DocumentMutationFailure
typealias DocumentQueryGateway = PrimoDocumentContracts.DocumentQueryGateway
typealias DocumentMutationGateway = PrimoDocumentContracts.DocumentMutationGateway
typealias StrokeInputGateway = PrimoDocumentContracts.StrokeInputGateway
typealias DocumentHistoryGateway = PrimoDocumentContracts.DocumentHistoryGateway
typealias DocumentPersistenceGateway = PrimoDocumentContracts.DocumentPersistenceGateway
typealias DocumentExportGateway = PrimoDocumentContracts.DocumentExportGateway
typealias TextLayerGateway = PrimoDocumentContracts.TextLayerGateway

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
        let sessionBox = LockedDocumentRuntimeBox(runtime: PaintDocumentSession(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        ))
        return PaintDocumentClient(
            lightweightPresentation: { sessionBox.withRuntime { $0.lightweightPresentation() } },
            presentation: { sessionBox.withRuntime { $0.presentation() } },
            compositePixelData: { sessionBox.withRuntime { $0.compositePixelData() } },
            prewarmDrawingResources: { sessionBox.withRuntime { $0.prewarmDrawingResources() } },
            compositePNGData: { style in sessionBox.withRuntime { $0.compositePNGData(paperStyle: style) } },
            timelapseCapture: { sessionBox.withRuntime { $0.timelapseCapture() } },
            saveProject: { url, paperStyle in
                try sessionBox.withRuntime { session in
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
                sessionBox.replaceRuntime(with: session)
                return loadedProject
            },
            setPaperStyle: { style in sessionBox.withRuntime { $0.setPaperStyle(style) } },
            newCanvas: { width, height in
                sessionBox.replaceRuntime(with: PaintDocumentSession(
                    width: width,
                    height: height,
                    fileClient: fileClient,
                    dateClient: dateClient,
                    uuidClient: uuidClient
                ))
            },
            resizeCanvas: { width, height in
                sessionBox.withRuntime { $0.resizeCanvasMutation(width: width, height: height) }
            },
            resizeCanvasExtent: { width, height in
                sessionBox.withRuntime { $0.resizeCanvasExtentMutation(width: width, height: height) }
            },
            beginStroke: { sample, brush in sessionBox.withRuntime { $0.beginStroke(sample: sample, brush: brush) } },
            appendStroke: { sample in sessionBox.withRuntime { $0.appendStroke(sample: sample) } },
            endStroke: { sessionBox.withRuntime { $0.endStroke() } },
            cancelStroke: { sessionBox.withRuntime { $0.cancelStroke() } },
            blurStroke: { samples, brush, layerIndex, captureTimelapse in
                sessionBox.withRuntime {
                    $0.blurMutation(samples: samples, brush: brush, layerIndex: layerIndex, captureTimelapse: captureTimelapse)
                }
            },
            endBlurStroke: { sessionBox.withRuntime { $0.endBlurStroke() } },
            fill: { sample, brush in sessionBox.withRuntime { $0.fillMutation(sample: sample, brush: brush) } },
            canUndo: { sessionBox.withRuntime { $0.canUndo() } },
            canRedo: { sessionBox.withRuntime { $0.canRedo() } },
            undo: { sessionBox.withRuntime { $0.undoMutation() } },
            redo: { sessionBox.withRuntime { $0.redoMutation() } },
            addLayer: { name in sessionBox.withRuntime { $0.addLayerMutation(name: name) } },
            duplicateLayer: { index, name in sessionBox.withRuntime { $0.duplicateLayerMutation(index: index, name: name) } },
            deleteLayer: { index in sessionBox.withRuntime { $0.deleteLayerMutation(index: index) } },
            moveLayer: { index, destination in sessionBox.withRuntime { $0.moveLayerMutation(from: index, to: destination) } },
            createFolder: { name, layerIndex in sessionBox.withRuntime { $0.createFolderMutation(name: name, layerIndex: layerIndex) } },
            deleteFolder: { folderID in sessionBox.withRuntime { $0.deleteFolderMutation(folderID: folderID) } },
            setFolderVisibility: { folderID, isVisible in sessionBox.withRuntime { $0.setFolderVisibilityMutation(folderID: folderID, isVisible: isVisible) } },
            setFolderName: { folderID, name in sessionBox.withRuntime { $0.setFolderNameMutation(folderID: folderID, name: name) } },
            setFolderExpanded: { folderID, isExpanded in sessionBox.withRuntime { $0.setFolderExpandedMutation(folderID: folderID, isExpanded: isExpanded) } },
            assignLayerToFolder: { index, folderID in sessionBox.withRuntime { $0.assignLayerMutation(index: index, toFolder: folderID) } },
            setActiveLayer: { index in sessionBox.withRuntime { $0.setActiveLayerMutation(index: index) } },
            setLayerName: { index, name in sessionBox.withRuntime { $0.setLayerNameMutation(index: index, name: name) } },
            setLayerVisibility: { index, isVisible in sessionBox.withRuntime { $0.setLayerVisibilityMutation(index: index, isVisible: isVisible) } },
            setLayerLocked: { index, isLocked in sessionBox.withRuntime { $0.setLayerLockedMutation(index: index, isLocked: isLocked) } },
            setLayerAlphaLocked: { index, isAlphaLocked in sessionBox.withRuntime { $0.setLayerAlphaLockedMutation(index: index, isAlphaLocked: isAlphaLocked) } },
            setLayerClipped: { index, isClipped in sessionBox.withRuntime { $0.setLayerClippedMutation(index: index, isClipped: isClipped) } },
            revealLayerForEditing: { index in sessionBox.withRuntime { $0.revealLayerForEditingMutation(index: index) } },
            setLayerOpacity: { index, opacity in sessionBox.withRuntime { $0.setLayerOpacityMutation(index: index, opacity: opacity) } },
            setLayerBlendMode: { index, blendMode in sessionBox.withRuntime { $0.setLayerBlendModeMutation(index: index, blendMode: blendMode) } },
            mergeLayerDown: { index in sessionBox.withRuntime { $0.mergeLayerDownMutation(index: index) } },
            textLayerData: { index in sessionBox.withRuntime { $0.textLayerData(index: index) } },
            setTextLayer: { index, textLayer in sessionBox.withRuntime { $0.setTextLayerMutation(index: index, textLayer: textLayer) } },
            clearTextLayerData: { index in sessionBox.withRuntime { $0.clearTextLayerData(index: index) } },
            applyLayerProcessing: { index, request in sessionBox.withRuntime { $0.applyLayerProcessingMutation(index: index, request: request) } },
            applySoftwareStroke: { samples, brush, layerIndex in
                sessionBox.withRuntime {
                    $0.applySoftwareStrokeMutation(samples: samples, brush: brush, layerIndex: layerIndex)
                }
            },
            pixelDataForLayer: { index in sessionBox.withRuntime { $0.pixelDataForLayer(index: index) } },
            replaceLayerPixels: { index, data in
                sessionBox.withRuntime { $0.replaceLayerPixelsMutation(index: index, data: data) }
            },
            replaceLayerMask: { index, data in sessionBox.withRuntime { $0.replaceLayerMaskMutation(index: index, data: data) } },
            clearLayerMask: { index in sessionBox.withRuntime { $0.clearLayerMaskMutation(index: index) } },
            applyLayerMask: { index in sessionBox.withRuntime { $0.applyLayerMaskMutation(index: index) } },
            clearLayer: { index in sessionBox.withRuntime { $0.clearLayerMutation(index: index) } },
            consumeDirtyUpdate: { sessionBox.withRuntime { $0.consumeDirtyUpdate() } }
        )
    }
}

struct DocumentLayerClient: Sendable {
    let addLayer: @Sendable (String) -> DocumentIndexedMutationResult
    let duplicateLayer: @Sendable (Int, String) -> DocumentIndexedMutationResult
    let deleteLayer: @Sendable (Int) -> DocumentMutationResult
    let moveLayer: @Sendable (Int, Int) -> DocumentMutationResult
    let createFolder: @Sendable (String, Int) -> DocumentIndexedMutationResult
    let deleteFolder: @Sendable (Int) -> DocumentMutationResult
    let setFolderVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    let setFolderName: @Sendable (Int, String) -> DocumentMutationResult
    let setFolderExpanded: @Sendable (Int, Bool) -> DocumentMutationResult
    let assignLayerToFolder: @Sendable (Int, Int) -> DocumentMutationResult
    let setActiveLayer: @Sendable (Int) -> DocumentMutationResult
    let setLayerName: @Sendable (Int, String) -> DocumentMutationResult
    let setLayerVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    let setLayerLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    let setLayerAlphaLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    let setLayerClipped: @Sendable (Int, Bool) -> DocumentMutationResult
    let revealLayerForEditing: @Sendable (Int) -> DocumentMutationResult
    let setLayerOpacity: @Sendable (Int, Double) -> DocumentMutationResult
    let setLayerBlendMode: @Sendable (Int, LayerBlendMode) -> DocumentMutationResult
    let mergeLayerDown: @Sendable (Int) -> DocumentMutationResult
    let textLayerData: @Sendable (Int) -> TextLayerData?
    let setTextLayer: @Sendable (Int, TextLayerData) -> DocumentMutationResult
    let clearTextLayerData: @Sendable (Int) -> Void
    let replaceLayerPixels: @Sendable (Int, Data) -> DocumentMutationResult
    let replaceLayerMask: @Sendable (Int, Data) -> DocumentMutationResult
    let clearLayerMask: @Sendable (Int) -> DocumentMutationResult
    let applyLayerMask: @Sendable (Int) -> DocumentMutationResult
    let clearLayer: @Sendable (Int) -> DocumentMutationResult

    init(paintDocumentClient: PaintDocumentClient) {
        self.addLayer = paintDocumentClient.addLayer
        self.duplicateLayer = paintDocumentClient.duplicateLayer
        self.deleteLayer = paintDocumentClient.deleteLayer
        self.moveLayer = paintDocumentClient.moveLayer
        self.createFolder = paintDocumentClient.createFolder
        self.deleteFolder = paintDocumentClient.deleteFolder
        self.setFolderVisibility = paintDocumentClient.setFolderVisibility
        self.setFolderName = paintDocumentClient.setFolderName
        self.setFolderExpanded = paintDocumentClient.setFolderExpanded
        self.assignLayerToFolder = paintDocumentClient.assignLayerToFolder
        self.setActiveLayer = paintDocumentClient.setActiveLayer
        self.setLayerName = paintDocumentClient.setLayerName
        self.setLayerVisibility = paintDocumentClient.setLayerVisibility
        self.setLayerLocked = paintDocumentClient.setLayerLocked
        self.setLayerAlphaLocked = paintDocumentClient.setLayerAlphaLocked
        self.setLayerClipped = paintDocumentClient.setLayerClipped
        self.revealLayerForEditing = paintDocumentClient.revealLayerForEditing
        self.setLayerOpacity = paintDocumentClient.setLayerOpacity
        self.setLayerBlendMode = paintDocumentClient.setLayerBlendMode
        self.mergeLayerDown = paintDocumentClient.mergeLayerDown
        self.textLayerData = paintDocumentClient.textLayerData
        self.setTextLayer = paintDocumentClient.setTextLayer
        self.clearTextLayerData = paintDocumentClient.clearTextLayerData
        self.replaceLayerPixels = paintDocumentClient.replaceLayerPixels
        self.replaceLayerMask = paintDocumentClient.replaceLayerMask
        self.clearLayerMask = paintDocumentClient.clearLayerMask
        self.applyLayerMask = paintDocumentClient.applyLayerMask
        self.clearLayer = paintDocumentClient.clearLayer
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

    var documentQueryGateway: DocumentQueryGateway {
        get { self[DocumentQueryGatewayKey.self] }
        set { self[DocumentQueryGatewayKey.self] = newValue }
    }

    var documentMutationGateway: DocumentMutationGateway {
        get { self[DocumentMutationGatewayKey.self] }
        set { self[DocumentMutationGatewayKey.self] = newValue }
    }

    var strokeInputGateway: StrokeInputGateway {
        get { self[StrokeInputGatewayKey.self] }
        set { self[StrokeInputGatewayKey.self] = newValue }
    }

    var documentHistoryGateway: DocumentHistoryGateway {
        get { self[DocumentHistoryGatewayKey.self] }
        set { self[DocumentHistoryGatewayKey.self] = newValue }
    }

    var documentPersistenceGateway: DocumentPersistenceGateway {
        get { self[DocumentPersistenceGatewayKey.self] }
        set { self[DocumentPersistenceGatewayKey.self] = newValue }
    }

    var documentExportGateway: DocumentExportGateway {
        get { self[DocumentExportGatewayKey.self] }
        set { self[DocumentExportGatewayKey.self] = newValue }
    }

    var textLayerGateway: TextLayerGateway {
        get { self[TextLayerGatewayKey.self] }
        set { self[TextLayerGatewayKey.self] = newValue }
    }
}

private enum DocumentQueryGatewayKey: DependencyKey {
    static var liveValue: DocumentQueryGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return DocumentQueryGateway(
            lightweightPresentation: paintDocumentClient.lightweightPresentation,
            presentation: paintDocumentClient.presentation,
            compositePixelData: paintDocumentClient.compositePixelData,
            pixelDataForLayer: paintDocumentClient.pixelDataForLayer,
            consumeDirtyUpdate: paintDocumentClient.consumeDirtyUpdate
        )
    }
}

private enum DocumentMutationGatewayKey: DependencyKey {
    static var liveValue: DocumentMutationGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return DocumentMutationGateway(
            resizeCanvas: paintDocumentClient.resizeCanvas,
            resizeCanvasExtent: paintDocumentClient.resizeCanvasExtent,
            addLayer: paintDocumentClient.addLayer,
            deleteLayer: paintDocumentClient.deleteLayer,
            setActiveLayer: paintDocumentClient.setActiveLayer,
            setLayerName: paintDocumentClient.setLayerName,
            setLayerVisibility: paintDocumentClient.setLayerVisibility,
            revealLayerForEditing: paintDocumentClient.revealLayerForEditing,
            replaceLayerPixels: paintDocumentClient.replaceLayerPixels,
            replaceLayerMask: paintDocumentClient.replaceLayerMask,
            clearLayerMask: paintDocumentClient.clearLayerMask,
            applyLayerMask: paintDocumentClient.applyLayerMask,
            clearLayer: paintDocumentClient.clearLayer,
            applyLayerProcessing: paintDocumentClient.applyLayerProcessing
        )
    }
}

private enum StrokeInputGatewayKey: DependencyKey {
    static var liveValue: StrokeInputGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return StrokeInputGateway(
            beginStroke: paintDocumentClient.beginStroke,
            appendStroke: paintDocumentClient.appendStroke,
            endStroke: paintDocumentClient.endStroke,
            cancelStroke: paintDocumentClient.cancelStroke,
            blurStroke: paintDocumentClient.blurStroke,
            endBlurStroke: paintDocumentClient.endBlurStroke,
            fill: paintDocumentClient.fill,
            applySoftwareStroke: paintDocumentClient.applySoftwareStroke
        )
    }
}

private enum DocumentHistoryGatewayKey: DependencyKey {
    static var liveValue: DocumentHistoryGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return DocumentHistoryGateway(
            canUndo: paintDocumentClient.canUndo,
            canRedo: paintDocumentClient.canRedo,
            undo: paintDocumentClient.undo,
            redo: paintDocumentClient.redo
        )
    }
}

private enum DocumentPersistenceGatewayKey: DependencyKey {
    static var liveValue: DocumentPersistenceGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return DocumentPersistenceGateway(
            saveProject: paintDocumentClient.saveProject,
            loadProject: paintDocumentClient.loadProject,
            setPaperStyle: paintDocumentClient.setPaperStyle,
            newCanvas: paintDocumentClient.newCanvas,
            prewarmDrawingResources: paintDocumentClient.prewarmDrawingResources
        )
    }
}

private enum DocumentExportGatewayKey: DependencyKey {
    static var liveValue: DocumentExportGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return DocumentExportGateway(
            compositePNGData: paintDocumentClient.compositePNGData,
            timelapseCapture: paintDocumentClient.timelapseCapture
        )
    }
}

private enum TextLayerGatewayKey: DependencyKey {
    static var liveValue: TextLayerGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return TextLayerGateway(
            textLayerData: paintDocumentClient.textLayerData,
            setTextLayer: paintDocumentClient.setTextLayer,
            clearTextLayerData: paintDocumentClient.clearTextLayerData
        )
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
