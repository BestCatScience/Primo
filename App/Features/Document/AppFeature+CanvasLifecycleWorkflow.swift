import ComposableArchitecture
import CoreGraphics
import Foundation

extension AppFeature {
    func handleNewCanvasRequest(
        state: inout State,
        width: Int,
        height: Int
    ) -> Effect<Action> {
        if !state.application.showsHome {
            persistActiveTabToBackingStore(state: &state)
        }
        let width = max(width, 1)
        let height = max(height, 1)
        paintDocumentClient.newCanvas(width, height)
        paintDocumentClient.prewarmDrawingResources()
        state.application.showWorkspace()
        state.canvas = CanvasFeature.State()
        state.canvas.canvasSize = CGSize(width: width, height: height)
        state.layerSidebar = LayerSidebarFeature.State()
        state.brushPalette = BrushPaletteFeature.State()
        state.brushPanel = StudioPanelLayoutState()
        state.layerPanel = StudioPanelLayoutState()
        state.canvas.adjustmentPreviewPixelData = nil
        state.export.clearOutputs()
        state.application.clearBanner()
        state.application.finishHydration()
        paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
        state.applyPresentation(paintDocumentClient.presentation())
        activateNewTab(
            state: &state,
            title: Self.nextUntitledTabTitle(existingTabs: state.workspace.openTabs),
            sourceProjectURL: nil
        )
        return .merge(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleResizeCanvasRequest(
        state: inout State,
        width: Int,
        height: Int
    ) {
        let width = max(width, 1)
        let height = max(height, 1)
        let currentWidth = max(Int(state.canvas.canvasSize.width.rounded()), 1)
        let currentHeight = max(Int(state.canvas.canvasSize.height.rounded()), 1)
        guard width != currentWidth || height != currentHeight else {
            return
        }
        paintDocumentClient.resizeCanvas(width, height)
        state.canvas.selection = nil
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
        state.canvas.adjustmentPreviewPixelData = nil
        applyDirtyPresentation(state: &state)
        state.application.presentBanner(state.application.appLanguage.localized("Image resolution updated"))
    }

    func handleResizeCanvasExtentRequest(
        state: inout State,
        width: Int,
        height: Int
    ) {
        let width = max(width, 1)
        let height = max(height, 1)
        let currentWidth = max(Int(state.canvas.canvasSize.width.rounded()), 1)
        let currentHeight = max(Int(state.canvas.canvasSize.height.rounded()), 1)
        guard width != currentWidth || height != currentHeight else {
            return
        }
        paintDocumentClient.resizeCanvasExtent(width, height)
        state.canvas.selection = nil
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
        state.canvas.adjustmentPreviewPixelData = nil
        applyDirtyPresentation(state: &state)
        state.application.presentBanner(state.application.appLanguage.localized("Canvas size updated"))
    }

    func handleNewCanvasFromImageReceived(
        state: inout State,
        name: String?,
        data: Data
    ) -> Effect<Action> {
        if !state.application.showsHome {
            persistActiveTabToBackingStore(state: &state)
        }
        guard let importedImage = Self.importedCanvasImage(from: data) else {
            state.application.presentBanner(state.application.appLanguage.localized("Could not create canvas from image"))
            return .none
        }
        let width = importedImage.width
        let height = importedImage.height
        guard (64...8192).contains(width), (64...8192).contains(height) else {
            state.application.presentBanner(state.application.appLanguage.localized("Image size is not supported"))
            return .none
        }

        paintDocumentClient.newCanvas(width, height)
        paintDocumentClient.prewarmDrawingResources()
        state.application.showWorkspace()
        state.canvas = CanvasFeature.State()
        state.canvas.canvasSize = CGSize(width: width, height: height)
        state.layerSidebar = LayerSidebarFeature.State()
        state.brushPalette = BrushPaletteFeature.State()
        state.brushPanel = StudioPanelLayoutState()
        state.layerPanel = StudioPanelLayoutState()
        state.canvas.adjustmentPreviewPixelData = nil
        state.export.clearOutputs()
        state.application.clearBanner()
        state.application.finishHydration()
        paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
        paintDocumentClient.replaceLayerPixels(0, importedImage.pixelData)
        let nextName = {
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? (state.application.appLanguage == .japanese ? "画像 1" : "Image 1") : trimmed
        }()
        paintDocumentClient.setLayerName(0, nextName)
        paintDocumentClient.setActiveLayer(0)
        state.applyPresentation(paintDocumentClient.presentation())
        activateNewTab(
            state: &state,
            title: nextName,
            sourceProjectURL: nil
        )
        state.application.presentBanner(state.application.appLanguage.localized("Canvas created from image"))
        return .merge(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleUndoRequested(state: inout State) {
        guard !state.canvas.isStrokeActive else {
            state.application.presentBanner(state.application.appLanguage.localized("Undo is unavailable while drawing"))
            return
        }
        guard paintDocumentClient.undo() else {
            return
        }
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleRedoRequested(state: inout State) {
        guard !state.canvas.isStrokeActive else {
            state.application.presentBanner(state.application.appLanguage.localized("Redo is unavailable while drawing"))
            return
        }
        guard paintDocumentClient.redo() else {
            return
        }
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }
}
