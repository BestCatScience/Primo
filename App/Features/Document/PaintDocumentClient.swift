import ComposableArchitecture
import Foundation

struct PaintDocumentClient: Sendable {
    var lightweightPresentation: @Sendable () -> PaintDocumentPresentation
    var presentation: @Sendable () -> PaintDocumentPresentation
    var compositePNGData: @Sendable () -> Data?
    var timelapseCapture: @Sendable () -> TimelapseCapture?
    var beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var appendStroke: @Sendable (StylusSample) -> Void
    var endStroke: @Sendable () -> Void
    var fill: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var canUndo: @Sendable () -> Bool
    var canRedo: @Sendable () -> Bool
    var undo: @Sendable () -> Bool
    var redo: @Sendable () -> Bool
    var addLayer: @Sendable (String) -> Void
    var setActiveLayer: @Sendable (Int) -> Void
    var setLayerVisibility: @Sendable (Int, Bool) -> Void
    var replaceLayerPixels: @Sendable (Int, Data) -> Void
    var clearLayer: @Sendable (Int) -> Void
    var consumeDirtyUpdate: @Sendable () -> IncrementalLayerUpdate?

    static let live: PaintDocumentClient = {
        let sessionBox = PaintDocumentSessionBox()
        return PaintDocumentClient(
            lightweightPresentation: { sessionBox.session.lightweightPresentation() },
            presentation: { sessionBox.session.presentation() },
            compositePNGData: { sessionBox.session.compositePNGData() },
            timelapseCapture: { sessionBox.session.timelapseCapture() },
            beginStroke: { sample, brush in sessionBox.session.beginStroke(sample: sample, brush: brush) },
            appendStroke: { sample in sessionBox.session.appendStroke(sample: sample) },
            endStroke: { sessionBox.session.endStroke() },
            fill: { sample, brush in sessionBox.session.fill(sample: sample, brush: brush) },
            canUndo: { sessionBox.session.canUndo() },
            canRedo: { sessionBox.session.canRedo() },
            undo: { sessionBox.session.undo() },
            redo: { sessionBox.session.redo() },
            addLayer: { name in sessionBox.session.addLayer(name: name) },
            setActiveLayer: { index in sessionBox.session.setActiveLayer(index: index) },
            setLayerVisibility: { index, isVisible in sessionBox.session.setLayerVisibility(index: index, isVisible: isVisible) },
            replaceLayerPixels: { index, data in sessionBox.session.replaceLayerPixels(index: index, data: data) },
            clearLayer: { index in sessionBox.session.clearLayer(index: index) },
            consumeDirtyUpdate: { sessionBox.session.consumeDirtyUpdate() }
        )
    }()
}

private final class PaintDocumentSessionBox: @unchecked Sendable {
    lazy var session = PaintDocumentSession()
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
