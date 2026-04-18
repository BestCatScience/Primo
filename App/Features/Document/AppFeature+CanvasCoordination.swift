import ComposableArchitecture
import Foundation

extension AppFeature {
    struct DocumentPresentationQueryService {
        let paintDocumentClient: PaintDocumentClient

        func presentation() -> PaintDocumentPresentation {
            paintDocumentClient.presentation()
        }

        func compositePNGData(paperStyle: CanvasPaperStyle) -> Data? {
            paintDocumentClient.compositePNGData(paperStyle)
        }
    }

    struct DocumentPaperStyleSyncClient {
        let paintDocumentClient: PaintDocumentClient

        func synchronizeEffect(_ paperStyle: CanvasPaperStyle) -> Effect<Action> {
            .run { [paintDocumentClient] _ in
                paintDocumentClient.setPaperStyle(paperStyle)
            }
        }
    }

    var documentPresentationQueryService: DocumentPresentationQueryService {
        DocumentPresentationQueryService(paintDocumentClient: paintDocumentClient)
    }

    var documentPaperStyleSyncClient: DocumentPaperStyleSyncClient {
        DocumentPaperStyleSyncClient(paintDocumentClient: paintDocumentClient)
    }

    func applyPresentation(
        _ presentation: PaintDocumentPresentation,
        state: inout State
    ) {
        AppFeature.canvasPresentationStateCoordinator.applyPresentation(presentation, to: &state)
    }

    func applyLoadedProject(
        _ loaded: LoadedPaintProject,
        state: inout State
    ) {
        AppFeature.canvasPresentationStateCoordinator.applyLoadedProject(loaded, to: &state)
    }

    func syncTextEditorWithActiveLayer(state: inout State) {
        AppFeature.canvasPresentationStateCoordinator.syncTextEditorWithActiveLayer(state: &state)
    }

    func applyLiveCompositePixelData(
        _ compositePixelData: Data,
        state: inout State
    ) {
        if AppFeature.canvasPreviewStateCoordinator.applyLiveCompositePixelData(compositePixelData, to: &state) {
            state.application.finishHydration()
        }
    }

    func applyLiveStrokePreview(
        baseSnapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        state: inout State
    ) {
        if AppFeature.canvasPreviewStateCoordinator.applyLiveStrokePreview(
            baseSnapshot: baseSnapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            to: &state
        ) {
            state.application.finishHydration()
        }
    }

    func resolvedBrushSettings(for state: State) -> BrushRuntimeSettings {
        AppFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
    }

    func previewStrokeStyle(for state: State) -> PreviewStrokeStyle {
        AppFeature.canvasToolStateCoordinator.previewStrokeStyle(for: state)
    }

    func resolvedPaperStyle(for state: State) -> CanvasPaperStyle {
        AppFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: state)
    }
}
