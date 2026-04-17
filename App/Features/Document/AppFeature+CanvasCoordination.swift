import Foundation

extension AppFeature {
    struct DocumentPresentationService {
        let paintDocumentClient: PaintDocumentClient

        func presentation() -> PaintDocumentPresentation {
            paintDocumentClient.presentation()
        }

        func setPaperStyle(_ paperStyle: CanvasPaperStyle) {
            paintDocumentClient.setPaperStyle(paperStyle)
        }

        func compositePNGData(paperStyle: CanvasPaperStyle) -> Data? {
            paintDocumentClient.compositePNGData(paperStyle)
        }
    }

    var documentPresentationService: DocumentPresentationService {
        DocumentPresentationService(paintDocumentClient: paintDocumentClient)
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
        AppFeature.canvasPreviewStateCoordinator.applyLiveCompositePixelData(compositePixelData, to: &state)
    }

    func applyLiveStrokePreview(
        baseSnapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        state: inout State
    ) {
        AppFeature.canvasPreviewStateCoordinator.applyLiveStrokePreview(
            baseSnapshot: baseSnapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            to: &state
        )
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

    func currentDocumentPresentation() -> PaintDocumentPresentation {
        documentPresentationService.presentation()
    }

    func applyCurrentDocumentPresentation(state: inout State) {
        applyPresentation(currentDocumentPresentation(), state: &state)
    }

    func syncPaperStyleToDocument(
        state: inout State,
        updateCanvasPaper: Bool = false
    ) {
        let paperStyle = resolvedPaperStyle(for: state)
        if updateCanvasPaper {
            state.canvas.updatePaperStyle(paperStyle)
        }
        documentPresentationService.setPaperStyle(paperStyle)
    }

    func compositePNGData(state: State) -> Data? {
        documentPresentationService.compositePNGData(
            paperStyle: resolvedPaperStyle(for: state)
        )
    }
}
