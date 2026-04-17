import ComposableArchitecture
import CoreGraphics
import Foundation

extension AppFeature {
    struct CanvasDimensions: Equatable {
        let width: Int
        let height: Int

        init?(width: Int, height: Int) {
            guard width > 0, height > 0 else { return nil }
            self.width = width
            self.height = height
        }

        func isWithin(_ supportedRange: ClosedRange<Int>) -> Bool {
            supportedRange.contains(width) && supportedRange.contains(height)
        }

        var size: CGSize {
            CGSize(width: width, height: height)
        }
    }

    struct ImportedCanvasRequest: Equatable {
        let dimensions: CanvasDimensions
        let pixelData: Data
    }

    enum ImportedCanvasRequestValidation {
        case invalidImageData
        case unsupportedSize
        case valid(ImportedCanvasRequest)
    }

    struct CanvasLifecycleService {
        let paintDocumentClient: PaintDocumentClient

        func createCanvas(_ dimensions: CanvasDimensions) {
            paintDocumentClient.newCanvas(dimensions.width, dimensions.height)
            paintDocumentClient.prewarmDrawingResources()
        }

        func resizeCanvas(_ dimensions: CanvasDimensions) {
            paintDocumentClient.resizeCanvas(dimensions.width, dimensions.height)
        }

        func resizeCanvasExtent(_ dimensions: CanvasDimensions) {
            paintDocumentClient.resizeCanvasExtent(dimensions.width, dimensions.height)
        }

        func initializeImportedCanvas(
            _ request: ImportedCanvasRequest,
            layerName: String
        ) {
            createCanvas(request.dimensions)
            paintDocumentClient.replaceLayerPixels(0, request.pixelData)
            paintDocumentClient.setLayerName(0, layerName)
            paintDocumentClient.setActiveLayer(0)
        }

        func undo() -> Bool {
            paintDocumentClient.undo()
        }

        func redo() -> Bool {
            paintDocumentClient.redo()
        }
    }

    var canvasLifecycleService: CanvasLifecycleService {
        CanvasLifecycleService(paintDocumentClient: paintDocumentClient)
    }

    func validatedCanvasDimensions(
        width: Int,
        height: Int
    ) -> CanvasDimensions? {
        CanvasDimensions(width: width, height: height)
    }

    func currentCanvasDimensions(state: State) -> CanvasDimensions? {
        CanvasDimensions(
            width: Int(state.canvas.canvasSize.width.rounded()),
            height: Int(state.canvas.canvasSize.height.rounded())
        )
    }

    func cancelStartupPresentationEffects() -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    static func importedCanvasRequest(from imageData: Data) -> ImportedCanvasRequestValidation {
        guard let importedImage = importedCanvasImage(from: imageData) else {
            return .invalidImageData
        }
        guard let dimensions = CanvasDimensions(
            width: importedImage.width,
            height: importedImage.height
        ) else {
            return .invalidImageData
        }
        guard dimensions.isWithin(64...8192) else {
            return .unsupportedSize
        }
        return .valid(
            ImportedCanvasRequest(
                dimensions: dimensions,
                pixelData: importedImage.pixelData
            )
        )
    }

    func handleNewCanvasRequest(
        state: inout State,
        width: Int,
        height: Int
    ) -> Effect<Action> {
        guard let dimensions = validatedCanvasDimensions(width: width, height: height) else {
            state.application.presentBanner(state.application.appLanguage.localized("Canvas size is not supported"))
            return .none
        }
        if !state.application.showsHome {
            persistActiveTabToBackingStore(state: &state)
        }
        canvasLifecycleService.createCanvas(dimensions)
        AppFeature.canvasPresentationStateCoordinator.prepareFreshDocument(
            canvasSize: dimensions.size,
            to: &state
        )
        syncPaperStyleToDocument(state: &state)
        applyCurrentDocumentPresentation(state: &state)
        activateNewTab(
            state: &state,
            title: Self.nextUntitledTabTitle(existingTabs: state.workspace.openTabs),
            sourceProjectURL: nil
        )
        return cancelStartupPresentationEffects()
    }

    func handleResizeCanvasRequest(
        state: inout State,
        width: Int,
        height: Int
    ) {
        guard let dimensions = validatedCanvasDimensions(width: width, height: height) else {
            state.application.presentBanner(state.application.appLanguage.localized("Canvas size is not supported"))
            return
        }
        guard let currentDimensions = currentCanvasDimensions(state: state) else {
            state.application.presentBanner(state.application.appLanguage.localized("Canvas size is not supported"))
            return
        }
        guard dimensions != currentDimensions else {
            return
        }
        canvasLifecycleService.resizeCanvas(dimensions)
        state.canvas.resetTransientEditingState()
        applyDirtyPresentation(state: &state)
        state.application.presentBanner(state.application.appLanguage.localized("Image resolution updated"))
    }

    func handleResizeCanvasExtentRequest(
        state: inout State,
        width: Int,
        height: Int
    ) {
        guard let dimensions = validatedCanvasDimensions(width: width, height: height) else {
            state.application.presentBanner(state.application.appLanguage.localized("Canvas size is not supported"))
            return
        }
        guard let currentDimensions = currentCanvasDimensions(state: state) else {
            state.application.presentBanner(state.application.appLanguage.localized("Canvas size is not supported"))
            return
        }
        guard dimensions != currentDimensions else {
            return
        }
        canvasLifecycleService.resizeCanvasExtent(dimensions)
        state.canvas.resetTransientEditingState()
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
        switch Self.importedCanvasRequest(from: data) {
        case .invalidImageData:
            state.application.presentBanner(state.application.appLanguage.localized("Could not create canvas from image"))
            return .none
        case .unsupportedSize:
            state.application.presentBanner(state.application.appLanguage.localized("Image size is not supported"))
            return .none
        case let .valid(request):
            AppFeature.canvasPresentationStateCoordinator.prepareFreshDocument(
                canvasSize: request.dimensions.size,
                to: &state
            )
            let nextName = {
                let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? (state.application.appLanguage == .japanese ? "画像 1" : "Image 1") : trimmed
            }()
            canvasLifecycleService.initializeImportedCanvas(
                request,
                layerName: nextName
            )
            syncPaperStyleToDocument(state: &state)
            applyCurrentDocumentPresentation(state: &state)
            activateNewTab(
                state: &state,
                title: nextName,
                sourceProjectURL: nil
            )
            state.application.presentBanner(state.application.appLanguage.localized("Canvas created from image"))
            return cancelStartupPresentationEffects()
        }
    }

    func handleUndoRequested(state: inout State) {
        guard !state.canvas.isStrokeActive else {
            state.application.presentBanner(state.application.appLanguage.localized("Undo is unavailable while drawing"))
            return
        }
        guard canvasLifecycleService.undo() else {
            return
        }
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }

    func handleRedoRequested(state: inout State) {
        guard !state.canvas.isStrokeActive else {
            state.application.presentBanner(state.application.appLanguage.localized("Redo is unavailable while drawing"))
            return
        }
        guard canvasLifecycleService.redo() else {
            return
        }
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }
}
