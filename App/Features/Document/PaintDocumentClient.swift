import ComposableArchitecture
import Foundation

struct PaintDocumentClient: Sendable {
    var lightweightPresentation: @Sendable () -> PaintDocumentPresentation
    var presentation: @Sendable () -> PaintDocumentPresentation
    var beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var appendStroke: @Sendable (StylusSample) -> Void
    var endStroke: @Sendable () -> Void
    var addLayer: @Sendable (String) -> Void
    var setActiveLayer: @Sendable (Int) -> Void
    var setLayerVisibility: @Sendable (Int, Bool) -> Void
    var clearLayer: @Sendable (Int) -> Void

    static let live: PaintDocumentClient = {
        let sessionBox = PaintDocumentSessionBox()
        return PaintDocumentClient(
            lightweightPresentation: { sessionBox.session.lightweightPresentation() },
            presentation: { sessionBox.session.presentation() },
            beginStroke: { sample, brush in sessionBox.session.beginStroke(sample: sample, brush: brush) },
            appendStroke: { sample in sessionBox.session.appendStroke(sample: sample) },
            endStroke: { sessionBox.session.endStroke() },
            addLayer: { name in sessionBox.session.addLayer(name: name) },
            setActiveLayer: { index in sessionBox.session.setActiveLayer(index: index) },
            setLayerVisibility: { index, isVisible in sessionBox.session.setLayerVisibility(index: index, isVisible: isVisible) },
            clearLayer: { index in sessionBox.session.clearLayer(index: index) }
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
