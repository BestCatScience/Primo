import ComposableArchitecture
import Foundation
import Synchronization

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
    var resizeCanvas: @Sendable (Int, Int) -> Void
    var resizeCanvasExtent: @Sendable (Int, Int) -> Void
    var beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var appendStroke: @Sendable (StylusSample) -> Void
    var endStroke: @Sendable () -> Void
    var cancelStroke: @Sendable () -> Void
    var blurStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> Void
    var endBlurStroke: @Sendable () -> Void
    var fill: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var canUndo: @Sendable () -> Bool
    var canRedo: @Sendable () -> Bool
    var undo: @Sendable () -> Bool
    var redo: @Sendable () -> Bool
    var addLayer: @Sendable (String) -> Void
    var duplicateLayer: @Sendable (Int, String) -> Int
    var deleteLayer: @Sendable (Int) -> Bool
    var moveLayer: @Sendable (Int, Int) -> Bool
    var createFolder: @Sendable (String, Int) -> Int
    var deleteFolder: @Sendable (Int) -> Bool
    var setFolderVisibility: @Sendable (Int, Bool) -> Void
    var setFolderName: @Sendable (Int, String) -> Void
    var setFolderExpanded: @Sendable (Int, Bool) -> Void
    var assignLayerToFolder: @Sendable (Int, Int) -> Bool
    var setActiveLayer: @Sendable (Int) -> Void
    var setLayerName: @Sendable (Int, String) -> Void
    var setLayerVisibility: @Sendable (Int, Bool) -> Void
    var setLayerLocked: @Sendable (Int, Bool) -> Void
    var setLayerAlphaLocked: @Sendable (Int, Bool) -> Void
    var setLayerClipped: @Sendable (Int, Bool) -> Void
    var revealLayerForEditing: @Sendable (Int) -> Void
    var setLayerOpacity: @Sendable (Int, Double) -> Void
    var setLayerBlendMode: @Sendable (Int, LayerBlendMode) -> Void
    var mergeLayerDown: @Sendable (Int) -> Bool
    var textLayerData: @Sendable (Int) -> TextLayerData?
    var setTextLayer: @Sendable (Int, TextLayerData) -> Bool
    var clearTextLayerData: @Sendable (Int) -> Void
    var applyLayerProcessing: @Sendable (Int, LayerProcessingRequest) -> Bool
    var applySoftwareStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> Bool
    var pixelDataForLayer: @Sendable (Int) -> Data
    var replaceLayerPixels: @Sendable (Int, Data) -> Void
    var replaceLayerMask: @Sendable (Int, Data) -> Bool
    var clearLayerMask: @Sendable (Int) -> Bool
    var applyLayerMask: @Sendable (Int) -> Bool
    var clearLayer: @Sendable (Int) -> Bool
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
                sessionBox.withSession { $0.resizeCanvas(width: width, height: height) }
            },
            resizeCanvasExtent: { width, height in
                sessionBox.withSession { $0.resizeCanvasExtent(width: width, height: height) }
            },
            beginStroke: { sample, brush in sessionBox.withSession { $0.beginStroke(sample: sample, brush: brush) } },
            appendStroke: { sample in sessionBox.withSession { $0.appendStroke(sample: sample) } },
            endStroke: { sessionBox.withSession { $0.endStroke() } },
            cancelStroke: { sessionBox.withSession { $0.cancelStroke() } },
            blurStroke: { samples, brush, layerIndex, captureTimelapse in
                sessionBox.withSession {
                    $0.blur(samples: samples, brush: brush, layerIndex: layerIndex, captureTimelapse: captureTimelapse)
                }
            },
            endBlurStroke: { sessionBox.withSession { $0.endBlurStroke() } },
            fill: { sample, brush in sessionBox.withSession { $0.fill(sample: sample, brush: brush) } },
            canUndo: { sessionBox.withSession { $0.canUndo() } },
            canRedo: { sessionBox.withSession { $0.canRedo() } },
            undo: { sessionBox.withSession { $0.undo() } },
            redo: { sessionBox.withSession { $0.redo() } },
            addLayer: { name in sessionBox.withSession { $0.addLayer(name: name) } },
            duplicateLayer: { index, name in sessionBox.withSession { $0.duplicateLayer(index: index, name: name) } },
            deleteLayer: { index in sessionBox.withSession { $0.deleteLayer(index: index) } },
            moveLayer: { index, destination in sessionBox.withSession { $0.moveLayer(from: index, to: destination) } },
            createFolder: { name, layerIndex in sessionBox.withSession { $0.createFolder(name: name, layerIndex: layerIndex) } },
            deleteFolder: { folderID in sessionBox.withSession { $0.deleteFolder(folderID: folderID) } },
            setFolderVisibility: { folderID, isVisible in sessionBox.withSession { $0.setFolderVisibility(folderID: folderID, isVisible: isVisible) } },
            setFolderName: { folderID, name in sessionBox.withSession { $0.setFolderName(folderID: folderID, name: name) } },
            setFolderExpanded: { folderID, isExpanded in sessionBox.withSession { $0.setFolderExpanded(folderID: folderID, isExpanded: isExpanded) } },
            assignLayerToFolder: { index, folderID in sessionBox.withSession { $0.assignLayer(index: index, toFolder: folderID) } },
            setActiveLayer: { index in sessionBox.withSession { $0.setActiveLayer(index: index) } },
            setLayerName: { index, name in sessionBox.withSession { $0.setLayerName(index: index, name: name) } },
            setLayerVisibility: { index, isVisible in sessionBox.withSession { $0.setLayerVisibility(index: index, isVisible: isVisible) } },
            setLayerLocked: { index, isLocked in sessionBox.withSession { $0.setLayerLocked(index: index, isLocked: isLocked) } },
            setLayerAlphaLocked: { index, isAlphaLocked in sessionBox.withSession { $0.setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked) } },
            setLayerClipped: { index, isClipped in sessionBox.withSession { $0.setLayerClipped(index: index, isClipped: isClipped) } },
            revealLayerForEditing: { index in sessionBox.withSession { $0.revealLayerForEditing(index: index) } },
            setLayerOpacity: { index, opacity in sessionBox.withSession { $0.setLayerOpacity(index: index, opacity: opacity) } },
            setLayerBlendMode: { index, blendMode in sessionBox.withSession { $0.setLayerBlendMode(index: index, blendMode: blendMode) } },
            mergeLayerDown: { index in sessionBox.withSession { $0.mergeLayerDown(index: index) } },
            textLayerData: { index in sessionBox.withSession { $0.textLayerData(index: index) } },
            setTextLayer: { index, textLayer in sessionBox.withSession { $0.setTextLayer(index: index, textLayer: textLayer) } },
            clearTextLayerData: { index in sessionBox.withSession { $0.clearTextLayerData(index: index) } },
            applyLayerProcessing: { index, request in sessionBox.withSession { $0.applyLayerProcessing(index: index, request: request) } },
            applySoftwareStroke: { samples, brush, layerIndex in
                sessionBox.withSession {
                    $0.applySoftwareStroke(samples: samples, brush: brush, layerIndex: layerIndex)
                }
            },
            pixelDataForLayer: { index in sessionBox.withSession { $0.pixelDataForLayer(index: index) } },
            replaceLayerPixels: { index, data in sessionBox.withSession { $0.replaceLayerPixels(index: index, data: data) } },
            replaceLayerMask: { index, data in sessionBox.withSession { $0.replaceLayerMask(index: index, maskData: data) } },
            clearLayerMask: { index in sessionBox.withSession { $0.clearLayerMask(index: index) } },
            applyLayerMask: { index in sessionBox.withSession { $0.applyLayerMask(index: index) } },
            clearLayer: { index in sessionBox.withSession { $0.clearLayer(index: index) } },
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
