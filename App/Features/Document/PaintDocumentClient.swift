import ComposableArchitecture
import Foundation

struct PaintDocumentClient: Sendable {
    var lightweightPresentation: @Sendable () -> PaintDocumentPresentation
    var presentation: @Sendable () -> PaintDocumentPresentation
    var prewarmDrawingResources: @Sendable () -> Void
    var compositePNGData: @Sendable (CanvasPaperStyle) -> Data?
    var timelapseCapture: @Sendable () -> TimelapseCapture?
    var setPaperStyle: @Sendable (CanvasPaperStyle) -> Void
    var newCanvas: @Sendable (Int, Int) -> Void
    var beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var appendStroke: @Sendable (StylusSample) -> Void
    var endStroke: @Sendable () -> Void
    var fill: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var canUndo: @Sendable () -> Bool
    var canRedo: @Sendable () -> Bool
    var undo: @Sendable () -> Bool
    var redo: @Sendable () -> Bool
    var addLayer: @Sendable (String) -> Void
    var deleteLayer: @Sendable (Int) -> Bool
    var moveLayer: @Sendable (Int, Int) -> Bool
    var setActiveLayer: @Sendable (Int) -> Void
    var setLayerName: @Sendable (Int, String) -> Void
    var setLayerVisibility: @Sendable (Int, Bool) -> Void
    var setLayerOpacity: @Sendable (Int, Double) -> Void
    var setLayerBlendMode: @Sendable (Int, LayerBlendMode) -> Void
    var replaceLayerPixels: @Sendable (Int, Data) -> Void
    var clearLayer: @Sendable (Int) -> Void
    var consumeDirtyUpdate: @Sendable () -> IncrementalLayerUpdate?

    static let live: PaintDocumentClient = {
        let sessionBox = PaintDocumentSessionBox()
        return PaintDocumentClient(
            lightweightPresentation: { sessionBox.session.lightweightPresentation() },
            presentation: { sessionBox.session.presentation() },
            prewarmDrawingResources: { sessionBox.session.prewarmDrawingResources() },
            compositePNGData: { style in sessionBox.session.compositePNGData(paperStyle: style) },
            timelapseCapture: { sessionBox.session.timelapseCapture() },
            setPaperStyle: { style in sessionBox.session.setPaperStyle(style) },
            newCanvas: { width, height in
                sessionBox.session = PaintDocumentSession(width: width, height: height)
            },
            beginStroke: { sample, brush in sessionBox.session.beginStroke(sample: sample, brush: brush) },
            appendStroke: { sample in sessionBox.session.appendStroke(sample: sample) },
            endStroke: { sessionBox.session.endStroke() },
            fill: { sample, brush in sessionBox.session.fill(sample: sample, brush: brush) },
            canUndo: { sessionBox.session.canUndo() },
            canRedo: { sessionBox.session.canRedo() },
            undo: { sessionBox.session.undo() },
            redo: { sessionBox.session.redo() },
            addLayer: { name in sessionBox.session.addLayer(name: name) },
            deleteLayer: { index in sessionBox.session.deleteLayer(index: index) },
            moveLayer: { index, destination in sessionBox.session.moveLayer(from: index, to: destination) },
            setActiveLayer: { index in sessionBox.session.setActiveLayer(index: index) },
            setLayerName: { index, name in sessionBox.session.setLayerName(index: index, name: name) },
            setLayerVisibility: { index, isVisible in sessionBox.session.setLayerVisibility(index: index, isVisible: isVisible) },
            setLayerOpacity: { index, opacity in sessionBox.session.setLayerOpacity(index: index, opacity: opacity) },
            setLayerBlendMode: { index, blendMode in sessionBox.session.setLayerBlendMode(index: index, blendMode: blendMode) },
            replaceLayerPixels: { index, data in sessionBox.session.replaceLayerPixels(index: index, data: data) },
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
