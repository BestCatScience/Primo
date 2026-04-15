import ComposableArchitecture
import Foundation

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
    var clearLayer: @Sendable (Int) -> Void
    var consumeDirtyUpdate: @Sendable () -> IncrementalLayerUpdate?

    static let live: PaintDocumentClient = {
        let sessionBox = PaintDocumentSessionBox()
        return PaintDocumentClient(
            lightweightPresentation: { sessionBox.session.lightweightPresentation() },
            presentation: { sessionBox.session.presentation() },
            compositePixelData: { sessionBox.session.compositePixelData() },
            prewarmDrawingResources: { sessionBox.session.prewarmDrawingResources() },
            compositePNGData: { style in sessionBox.session.compositePNGData(paperStyle: style) },
            timelapseCapture: { sessionBox.session.timelapseCapture() },
            saveProject: { url, paperStyle in
                sessionBox.session.setPaperStyle(paperStyle)
                try sessionBox.session.saveProject(to: url)
            },
            loadProject: { url in
                let session = try PaintDocumentSession.loadProject(from: url)
                sessionBox.session = session
                return LoadedPaintProject(
                    presentation: session.presentation(),
                    paperStyle: session.currentPaperStyle
                )
            },
            setPaperStyle: { style in sessionBox.session.setPaperStyle(style) },
            newCanvas: { width, height in
                sessionBox.session = PaintDocumentSession(width: width, height: height)
            },
            beginStroke: { sample, brush in sessionBox.session.beginStroke(sample: sample, brush: brush) },
            appendStroke: { sample in sessionBox.session.appendStroke(sample: sample) },
            endStroke: { sessionBox.session.endStroke() },
            cancelStroke: { sessionBox.session.cancelStroke() },
            blurStroke: { samples, brush, layerIndex, captureTimelapse in
                sessionBox.session.blur(samples: samples, brush: brush, layerIndex: layerIndex, captureTimelapse: captureTimelapse)
            },
            endBlurStroke: { sessionBox.session.endBlurStroke() },
            fill: { sample, brush in sessionBox.session.fill(sample: sample, brush: brush) },
            canUndo: { sessionBox.session.canUndo() },
            canRedo: { sessionBox.session.canRedo() },
            undo: { sessionBox.session.undo() },
            redo: { sessionBox.session.redo() },
            addLayer: { name in sessionBox.session.addLayer(name: name) },
            duplicateLayer: { index, name in sessionBox.session.duplicateLayer(index: index, name: name) },
            deleteLayer: { index in sessionBox.session.deleteLayer(index: index) },
            moveLayer: { index, destination in sessionBox.session.moveLayer(from: index, to: destination) },
            createFolder: { name, layerIndex in sessionBox.session.createFolder(name: name, layerIndex: layerIndex) },
            deleteFolder: { folderID in sessionBox.session.deleteFolder(folderID: folderID) },
            setFolderVisibility: { folderID, isVisible in sessionBox.session.setFolderVisibility(folderID: folderID, isVisible: isVisible) },
            setFolderName: { folderID, name in sessionBox.session.setFolderName(folderID: folderID, name: name) },
            setFolderExpanded: { folderID, isExpanded in sessionBox.session.setFolderExpanded(folderID: folderID, isExpanded: isExpanded) },
            assignLayerToFolder: { index, folderID in sessionBox.session.assignLayer(index: index, toFolder: folderID) },
            setActiveLayer: { index in sessionBox.session.setActiveLayer(index: index) },
            setLayerName: { index, name in sessionBox.session.setLayerName(index: index, name: name) },
            setLayerVisibility: { index, isVisible in sessionBox.session.setLayerVisibility(index: index, isVisible: isVisible) },
            setLayerLocked: { index, isLocked in sessionBox.session.setLayerLocked(index: index, isLocked: isLocked) },
            setLayerAlphaLocked: { index, isAlphaLocked in sessionBox.session.setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked) },
            setLayerClipped: { index, isClipped in sessionBox.session.setLayerClipped(index: index, isClipped: isClipped) },
            revealLayerForEditing: { index in sessionBox.session.revealLayerForEditing(index: index) },
            setLayerOpacity: { index, opacity in sessionBox.session.setLayerOpacity(index: index, opacity: opacity) },
            setLayerBlendMode: { index, blendMode in sessionBox.session.setLayerBlendMode(index: index, blendMode: blendMode) },
            mergeLayerDown: { index in sessionBox.session.mergeLayerDown(index: index) },
            textLayerData: { index in sessionBox.session.textLayerData(index: index) },
            setTextLayer: { index, textLayer in sessionBox.session.setTextLayer(index: index, textLayer: textLayer) },
            clearTextLayerData: { index in sessionBox.session.clearTextLayerData(index: index) },
            applyLayerProcessing: { index, request in sessionBox.session.applyLayerProcessing(index: index, request: request) },
            applySoftwareStroke: { samples, brush, layerIndex in
                sessionBox.session.applySoftwareStroke(samples: samples, brush: brush, layerIndex: layerIndex)
            },
            pixelDataForLayer: { index in sessionBox.session.pixelDataForLayer(index: index) },
            replaceLayerPixels: { index, data in sessionBox.session.replaceLayerPixels(index: index, data: data) },
            replaceLayerMask: { index, data in sessionBox.session.replaceLayerMask(index: index, maskData: data) },
            clearLayerMask: { index in sessionBox.session.clearLayerMask(index: index) },
            applyLayerMask: { index in sessionBox.session.applyLayerMask(index: index) },
            clearLayer: { index in sessionBox.session.clearLayer(index: index) },
            consumeDirtyUpdate: { sessionBox.session.consumeDirtyUpdate() }
        )
    }()
}

private final class PaintDocumentSessionBox: @unchecked Sendable {
    var session = PaintDocumentSession()
}

private enum PaintDocumentClientKey: DependencyKey {
    static let liveValue = PaintDocumentClient.live
}

extension DependencyValues {
    var paintDocumentClient: PaintDocumentClient {
        get { self[PaintDocumentClientKey.self] }
        set { self[PaintDocumentClientKey.self] = newValue }
    }
}
