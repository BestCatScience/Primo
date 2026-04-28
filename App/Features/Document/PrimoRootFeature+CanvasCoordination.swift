import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension DocumentFeatureRuntimeReducer {
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

        func compositeSurface(paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface? {
            documentExportGateway.compositeSurface(paperStyle)
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
        PrimoRootFeature.canvasPresentationStateCoordinator.applyPresentation(presentation, to: &state)
    }

    func applyLoadedProject(
        _ loaded: LoadedPaintProject,
        state: inout State
    ) {
        PrimoRootFeature.canvasPresentationStateCoordinator.applyLoadedProject(loaded, to: &state)
    }

    func syncTextEditorWithActiveLayer(state: inout State) {
        PrimoRootFeature.canvasPresentationStateCoordinator.syncTextEditorWithActiveLayer(state: &state)
    }

    func applyLiveCompositeSurface(
        _ compositeSurface: DocumentCompositeSurface,
        state: inout State
    ) {
        if PrimoRootFeature.canvasPreviewStateCoordinator.applyLiveCompositeSurface(compositeSurface, to: &state) {
            state.application.finishHydration()
        }
    }

    func applyLiveStrokePreview(
        baseSnapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        state: inout State
    ) {
        if PrimoRootFeature.canvasPreviewStateCoordinator.applyLiveStrokePreview(
            baseSnapshot: baseSnapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            gpuOperations: documentGpuOperationGateway,
            to: &state
        ) {
            state.application.finishHydration()
        }
    }

    func resolvedBrushSettings(for state: State) -> BrushRuntimeSettings {
        PrimoRootFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
    }

    func previewStrokeStyle(for state: State) -> PreviewStrokeStyle {
        PrimoRootFeature.canvasToolStateCoordinator.previewStrokeStyle(for: state)
    }

    func resolvedPaperStyle(for state: State) -> CanvasPaperStyle {
        PrimoRootFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: state)
    }
}
