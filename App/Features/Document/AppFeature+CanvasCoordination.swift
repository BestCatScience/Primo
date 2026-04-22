import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension AppFeature {
    struct DocumentPresentationQueryService {
        let documentQueryGateway: DocumentQueryGateway
        let documentExportGateway: DocumentExportGateway

        func lightweightPresentation() -> PaintDocumentPresentation {
            documentQueryGateway.lightweightPresentation()
        }

        func presentation() -> PaintDocumentPresentation {
            documentQueryGateway.presentation()
        }

        func pixelDataForLayer(_ index: Int) -> Data {
            documentQueryGateway.pixelDataForLayer(index)
        }

        func compositePNGData(paperStyle: CanvasPaperStyle) -> Data? {
            documentExportGateway.compositePNGData(paperStyle)
        }
    }

    struct DocumentPaperStyleSyncClient {
        let documentPersistenceGateway: DocumentPersistenceGateway

        func synchronizeEffect(_ paperStyle: CanvasPaperStyle) -> Effect<Action> {
            .run { [documentPersistenceGateway] _ in
                documentPersistenceGateway.setPaperStyle(paperStyle)
            }
        }
    }

    var documentPresentationQueryService: DocumentPresentationQueryService {
        DocumentPresentationQueryService(
            documentQueryGateway: documentQueryGateway,
            documentExportGateway: documentExportGateway
        )
    }

    var documentPaperStyleSyncClient: DocumentPaperStyleSyncClient {
        DocumentPaperStyleSyncClient(documentPersistenceGateway: documentPersistenceGateway)
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
