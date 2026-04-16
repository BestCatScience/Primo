import Foundation

extension AppFeature.State {
    mutating func applyPresentation(_ presentation: PaintDocumentPresentation) {
        AppFeature.canvasUIStateCoordinator.applyPresentation(presentation, to: &self)
    }

    mutating func applyLoadedProject(_ loaded: LoadedPaintProject) {
        AppFeature.canvasUIStateCoordinator.applyLoadedProject(loaded, to: &self)
    }

    mutating func syncTextEditorWithActiveLayer() {
        AppFeature.canvasUIStateCoordinator.syncTextEditorWithActiveLayer(state: &self)
    }

    mutating func applyLiveCompositePixelData(_ compositePixelData: Data) {
        AppFeature.canvasUIStateCoordinator.applyLiveCompositePixelData(compositePixelData, to: &self)
    }

    mutating func applyLiveStrokePreview(
        baseSnapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) {
        AppFeature.canvasUIStateCoordinator.applyLiveStrokePreview(
            baseSnapshot: baseSnapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            to: &self
        )
    }

    func resolvedBrushSettings() -> BrushRuntimeSettings {
        AppFeature.canvasUIStateCoordinator.resolvedBrushSettings(for: self)
    }

    func previewStrokeStyle() -> PreviewStrokeStyle {
        AppFeature.canvasUIStateCoordinator.previewStrokeStyle(for: self)
    }

    func resolvedPaperStyle() -> CanvasPaperStyle {
        AppFeature.canvasUIStateCoordinator.resolvedPaperStyle(for: self)
    }
}
