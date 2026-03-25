import ComposableArchitecture
import Foundation

struct PaintDocumentClient: Sendable {
    var presentation: @Sendable () -> PaintDocumentPresentation
    var beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var appendStroke: @Sendable (StylusSample) -> Void
    var endStroke: @Sendable () -> Void
    var addLayer: @Sendable (String) -> Void
    var setActiveLayer: @Sendable (Int) -> Void
    var setLayerVisibility: @Sendable (Int, Bool) -> Void
    var clearLayer: @Sendable (Int) -> Void

    static let live: PaintDocumentClient = {
        let session = PaintDocumentSession()
        return PaintDocumentClient(
            presentation: { session.presentation() },
            beginStroke: { sample, brush in session.beginStroke(sample: sample, brush: brush) },
            appendStroke: { sample in session.appendStroke(sample: sample) },
            endStroke: { session.endStroke() },
            addLayer: { name in session.addLayer(name: name) },
            setActiveLayer: { index in session.setActiveLayer(index: index) },
            setLayerVisibility: { index, isVisible in session.setLayerVisibility(index: index, isVisible: isVisible) },
            clearLayer: { index in session.clearLayer(index: index) }
        )
    }()
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
