import Foundation

extension AppFeature.State {
    mutating func applyPresentation(_ presentation: PaintDocumentPresentation) {
        AppFeature.canvasPresentationStateCoordinator.applyPresentation(presentation, to: &self)
    }

    mutating func applyLoadedProject(_ loaded: LoadedPaintProject) {
        AppFeature.canvasPresentationStateCoordinator.applyLoadedProject(loaded, to: &self)
    }

    mutating func syncTextEditorWithActiveLayer() {
        AppFeature.canvasPresentationStateCoordinator.syncTextEditorWithActiveLayer(state: &self)
    }

    mutating func applyLiveCompositePixelData(_ compositePixelData: Data) {
        AppFeature.canvasPreviewStateCoordinator.applyLiveCompositePixelData(compositePixelData, to: &self)
    }

    mutating func applyLiveStrokePreview(
        baseSnapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) {
        AppFeature.canvasPreviewStateCoordinator.applyLiveStrokePreview(
            baseSnapshot: baseSnapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            to: &self
        )
    }

    func resolvedBrushSettings() -> BrushRuntimeSettings {
        AppFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: self)
    }

    func previewStrokeStyle() -> PreviewStrokeStyle {
        AppFeature.canvasToolStateCoordinator.previewStrokeStyle(for: self)
    }

    func resolvedPaperStyle() -> CanvasPaperStyle {
        AppFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: self)
    }
}
