import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentEngineInfrastructure

typealias DocumentMutationResult = PrimoDocumentContracts.DocumentMutationResult
typealias DocumentIndexedMutationResult = PrimoDocumentContracts.DocumentIndexedMutationResult
typealias DocumentMutationFailure = PrimoDocumentContracts.DocumentMutationFailure
typealias DocumentQueryGateway = PrimoDocumentContracts.DocumentQueryGateway
typealias DocumentMutationGateway = PrimoDocumentContracts.DocumentMutationGateway
typealias StrokeInputGateway = PrimoDocumentContracts.StrokeInputGateway
typealias DocumentHistoryGateway = PrimoDocumentContracts.DocumentHistoryGateway
typealias DocumentPersistenceGateway = PrimoDocumentContracts.DocumentPersistenceGateway
typealias DocumentExportGateway = PrimoDocumentContracts.DocumentExportGateway
typealias TextLayerGateway = PrimoDocumentContracts.TextLayerGateway
typealias DocumentLayerEffectsGateway = PrimoDocumentContracts.DocumentLayerEffectsGateway
typealias LayerPixelRect = PrimoDocumentContracts.LayerPixelRect
typealias DocumentEditingRequest = PrimoDocumentApplication.DocumentEditingRequest
typealias DocumentEditingResult = PrimoDocumentApplication.DocumentEditingResult
typealias DocumentEditingGateway = PrimoDocumentApplication.DocumentEditingGateway

struct PaintDocumentClient: Sendable {
    var lightweightPresentation: @Sendable () -> PaintDocumentPresentation
    var presentation: @Sendable () -> PaintDocumentPresentation
    var compositePixelData: @Sendable () -> Data
    var prewarmDrawingResources: @Sendable () -> Void
    var compositePNGData: @Sendable (CanvasPaperStyle) -> Data?
    var timelapseCapture: @Sendable () -> TimelapseCapture?
    var saveProject: @Sendable (URL, CanvasPaperStyle) throws -> Void
    var loadProject: @Sendable (URL) throws -> LoadedPaintProject
    var setPaperStyle: @Sendable (CanvasPaperStyle) -> Void
    var newCanvas: @Sendable (Int, Int) -> Void
    var resizeCanvas: @Sendable (Int, Int) -> DocumentMutationResult
    var resizeCanvasExtent: @Sendable (Int, Int) -> DocumentMutationResult
    var beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var appendStroke: @Sendable (StylusSample) -> Void
    var endStroke: @Sendable () -> Void
    var cancelStroke: @Sendable () -> Void
    var blurStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult
    var endBlurStroke: @Sendable () -> Void
    var fill: @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult
    var canUndo: @Sendable () -> Bool
    var canRedo: @Sendable () -> Bool
    var undo: @Sendable () -> DocumentMutationResult
    var redo: @Sendable () -> DocumentMutationResult
    var addLayer: @Sendable (String) -> DocumentIndexedMutationResult
    var duplicateLayer: @Sendable (Int, String) -> DocumentIndexedMutationResult
    var deleteLayer: @Sendable (Int) -> DocumentMutationResult
    var moveLayer: @Sendable (Int, Int) -> DocumentMutationResult
    var createFolder: @Sendable (String, Int) -> DocumentIndexedMutationResult
    var deleteFolder: @Sendable (Int) -> DocumentMutationResult
    var setFolderVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    var setFolderName: @Sendable (Int, String) -> DocumentMutationResult
    var setFolderExpanded: @Sendable (Int, Bool) -> DocumentMutationResult
    var assignLayerToFolder: @Sendable (Int, Int) -> DocumentMutationResult
    var setActiveLayer: @Sendable (Int) -> DocumentMutationResult
    var setLayerName: @Sendable (Int, String) -> DocumentMutationResult
    var setLayerVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    var setLayerLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    var setLayerAlphaLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    var setLayerClipped: @Sendable (Int, Bool) -> DocumentMutationResult
    var revealLayerForEditing: @Sendable (Int) -> DocumentMutationResult
    var setLayerOpacity: @Sendable (Int, Double) -> DocumentMutationResult
    var setLayerBlendMode: @Sendable (Int, LayerBlendMode) -> DocumentMutationResult
    var mergeLayerDown: @Sendable (Int) -> DocumentMutationResult
    var textLayerData: @Sendable (Int) -> TextLayerData?
    var setTextLayer: @Sendable (Int, TextLayerData) -> DocumentMutationResult
    var clearTextLayerData: @Sendable (Int) -> Void
    var applyLayerProcessing: @Sendable (Int, LayerProcessingRequest) -> DocumentMutationResult
    var applySoftwareStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult
    var pixelDataForLayer: @Sendable (Int) -> Data
    var replaceLayerPixels: @Sendable (Int, Data) -> DocumentMutationResult
    var replaceLayerPixelsInRect: @Sendable (Int, LayerPixelRect, Data) -> DocumentMutationResult
    var replaceLayerMask: @Sendable (Int, Data) -> DocumentMutationResult
    var clearLayerMask: @Sendable (Int) -> DocumentMutationResult
    var applyLayerMask: @Sendable (Int) -> DocumentMutationResult
    var clearLayer: @Sendable (Int) -> DocumentMutationResult
    var consumeDirtyUpdate: @Sendable () -> IncrementalLayerUpdate?

    static func live(
        fileClient: FileClient,
        dateClient: DateClient,
        uuidClient: UUIDClient
    ) -> PaintDocumentClient {
        let composition = DocumentRuntimeCompositionFactory.live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        return PaintDocumentClient(composition: composition)
    }
}

extension PaintDocumentClient {
    init(composition: DocumentRuntimeComposition) {
        self.init(
            lightweightPresentation: composition.queryGateway.lightweightPresentation,
            presentation: composition.queryGateway.presentation,
            compositePixelData: composition.queryGateway.compositePixelData,
            prewarmDrawingResources: composition.persistenceGateway.prewarmDrawingResources,
            compositePNGData: composition.exportGateway.compositePNGData,
            timelapseCapture: composition.exportGateway.timelapseCapture,
            saveProject: composition.persistenceGateway.saveProject,
            loadProject: composition.persistenceGateway.loadProject,
            setPaperStyle: composition.persistenceGateway.setPaperStyle,
            newCanvas: composition.persistenceGateway.newCanvas,
            resizeCanvas: composition.mutationGateway.resizeCanvas,
            resizeCanvasExtent: composition.mutationGateway.resizeCanvasExtent,
            beginStroke: composition.strokeGateway.beginStroke,
            appendStroke: composition.strokeGateway.appendStroke,
            endStroke: composition.strokeGateway.endStroke,
            cancelStroke: composition.strokeGateway.cancelStroke,
            blurStroke: composition.strokeGateway.blurStroke,
            endBlurStroke: composition.strokeGateway.endBlurStroke,
            fill: composition.strokeGateway.fill,
            canUndo: composition.historyGateway.canUndo,
            canRedo: composition.historyGateway.canRedo,
            undo: composition.historyGateway.undo,
            redo: composition.historyGateway.redo,
            addLayer: { name in
                composition.editingGateway.execute(.structure(.addLayer(name: name))).flatMap(Self.extractIndexResult)
            },
            duplicateLayer: { index, name in
                composition.editingGateway.execute(.structure(.duplicateLayer(index: index, name: name)))
                    .flatMap(Self.extractIndexResult)
            },
            deleteLayer: { index in
                composition.editingGateway.execute(.structure(.deleteLayer(index: index))).map { _ in () }
            },
            moveLayer: { index, destinationIndex in
                composition.editingGateway.execute(
                    .structure(.moveLayer(index: index, destinationIndex: destinationIndex))
                ).map { _ in () }
            },
            createFolder: { name, layerIndex in
                composition.editingGateway.execute(
                    .structure(.createFolder(name: name, anchorLayerIndex: layerIndex))
                ).flatMap(Self.extractIndexResult)
            },
            deleteFolder: { folderID in
                composition.editingGateway.execute(.structure(.deleteFolder(folderID: folderID))).map { _ in () }
            },
            setFolderVisibility: { folderID, isVisible in
                composition.editingGateway.execute(
                    .attribute(.setFolderVisibility(folderID: folderID, isVisible: isVisible))
                ).map { _ in () }
            },
            setFolderName: { folderID, name in
                composition.editingGateway.execute(.attribute(.setFolderName(folderID: folderID, name: name))).map { _ in () }
            },
            setFolderExpanded: { folderID, isExpanded in
                composition.editingGateway.execute(
                    .attribute(.setFolderExpanded(folderID: folderID, isExpanded: isExpanded))
                ).map { _ in () }
            },
            assignLayerToFolder: { index, folderID in
                composition.editingGateway.execute(
                    .structure(.assignLayerToFolder(index: index, folderID: folderID))
                ).map { _ in () }
            },
            setActiveLayer: { index in
                composition.editingGateway.execute(.attribute(.setActiveLayer(index: index))).map { _ in () }
            },
            setLayerName: { index, name in
                composition.editingGateway.execute(.attribute(.setLayerName(index: index, name: name))).map { _ in () }
            },
            setLayerVisibility: { index, isVisible in
                composition.editingGateway.execute(
                    .attribute(.setLayerVisibility(index: index, isVisible: isVisible))
                ).map { _ in () }
            },
            setLayerLocked: { index, isLocked in
                composition.editingGateway.execute(
                    .attribute(.setLayerLocked(index: index, isLocked: isLocked))
                ).map { _ in () }
            },
            setLayerAlphaLocked: { index, isAlphaLocked in
                composition.editingGateway.execute(
                    .attribute(.setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked))
                ).map { _ in () }
            },
            setLayerClipped: { index, isClipped in
                composition.editingGateway.execute(
                    .attribute(.setLayerClipped(index: index, isClipped: isClipped))
                ).map { _ in () }
            },
            revealLayerForEditing: { index in
                composition.editingGateway.execute(
                    .attribute(.revealLayerForEditing(index: index))
                ).map { _ in () }
            },
            setLayerOpacity: { index, opacity in
                composition.editingGateway.execute(
                    .attribute(.setLayerOpacity(index: index, opacity: opacity))
                ).map { _ in () }
            },
            setLayerBlendMode: { index, blendMode in
                composition.editingGateway.execute(
                    .attribute(.setLayerBlendMode(index: index, blendMode: blendMode))
                ).map { _ in () }
            },
            mergeLayerDown: composition.layerEffectsGateway.mergeLayerDown,
            textLayerData: composition.textLayerGateway.textLayerData,
            setTextLayer: composition.textLayerGateway.setTextLayer,
            clearTextLayerData: composition.textLayerGateway.clearTextLayerData,
            applyLayerProcessing: composition.mutationGateway.applyLayerProcessing,
            applySoftwareStroke: composition.strokeGateway.applySoftwareStroke,
            pixelDataForLayer: composition.queryGateway.pixelDataForLayer,
            replaceLayerPixels: composition.mutationGateway.replaceLayerPixels,
            replaceLayerPixelsInRect: composition.mutationGateway.replaceLayerPixelsInRect,
            replaceLayerMask: composition.mutationGateway.replaceLayerMask,
            clearLayerMask: composition.mutationGateway.clearLayerMask,
            applyLayerMask: composition.mutationGateway.applyLayerMask,
            clearLayer: composition.mutationGateway.clearLayer,
            consumeDirtyUpdate: composition.queryGateway.consumeDirtyUpdate
        )
    }

    private static func extractIndexResult(
        _ result: DocumentEditingResult
    ) -> Result<Int, DocumentMutationFailure> {
        guard case let .structure(plan) = result, let index = plan.resultingIndex else {
            return .failure(.bridgeMutationFailed("documentEditingGateway"))
        }
        return .success(index)
    }
}

private enum PaintDocumentClientKey: DependencyKey {
    static var liveValue: PaintDocumentClient {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient
        return .live(fileClient: fileClient, dateClient: dateClient, uuidClient: uuidClient)
    }
}

private enum DocumentRuntimeCompositionKey: DependencyKey {
    static var liveValue: DocumentRuntimeComposition {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient
        return DocumentRuntimeCompositionFactory.live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
    }
}

extension DependencyValues {
    var paintDocumentClient: PaintDocumentClient {
        get { self[PaintDocumentClientKey.self] }
        set {
            self[PaintDocumentClientKey.self] = newValue
            self[DocumentRuntimeCompositionKey.self] = .init(paintDocumentClient: newValue)
        }
    }

    var documentRuntimeComposition: DocumentRuntimeComposition {
        get { self[DocumentRuntimeCompositionKey.self] }
        set { self[DocumentRuntimeCompositionKey.self] = newValue }
    }

    var documentQueryGateway: DocumentQueryGateway {
        get { documentRuntimeComposition.queryGateway }
        set {
            var composition = documentRuntimeComposition
            composition.queryGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var documentMutationGateway: DocumentMutationGateway {
        get { documentRuntimeComposition.mutationGateway }
        set {
            var composition = documentRuntimeComposition
            composition.mutationGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var strokeInputGateway: StrokeInputGateway {
        get { documentRuntimeComposition.strokeGateway }
        set {
            var composition = documentRuntimeComposition
            composition.strokeGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var documentHistoryGateway: DocumentHistoryGateway {
        get { documentRuntimeComposition.historyGateway }
        set {
            var composition = documentRuntimeComposition
            composition.historyGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var documentPersistenceGateway: DocumentPersistenceGateway {
        get { documentRuntimeComposition.persistenceGateway }
        set {
            var composition = documentRuntimeComposition
            composition.persistenceGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var documentExportGateway: DocumentExportGateway {
        get { documentRuntimeComposition.exportGateway }
        set {
            var composition = documentRuntimeComposition
            composition.exportGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var textLayerGateway: TextLayerGateway {
        get { documentRuntimeComposition.textLayerGateway }
        set {
            var composition = documentRuntimeComposition
            composition.textLayerGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var documentLayerEffectsGateway: DocumentLayerEffectsGateway {
        get { documentRuntimeComposition.layerEffectsGateway }
        set {
            var composition = documentRuntimeComposition
            composition.layerEffectsGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var documentEditingGateway: DocumentEditingGateway {
        get { documentRuntimeComposition.editingGateway }
        set {
            var composition = documentRuntimeComposition
            composition.editingGateway = newValue
            documentRuntimeComposition = composition
        }
    }
}

extension DocumentRuntimeComposition {
    init(paintDocumentClient: PaintDocumentClient) {
        self.init(
            queryGateway: DocumentQueryGateway(
                lightweightPresentation: paintDocumentClient.lightweightPresentation,
                presentation: paintDocumentClient.presentation,
                compositePixelData: paintDocumentClient.compositePixelData,
                pixelDataForLayer: paintDocumentClient.pixelDataForLayer,
                consumeDirtyUpdate: paintDocumentClient.consumeDirtyUpdate
            ),
            mutationGateway: DocumentMutationGateway(
                resizeCanvas: paintDocumentClient.resizeCanvas,
                resizeCanvasExtent: paintDocumentClient.resizeCanvasExtent,
                addLayer: paintDocumentClient.addLayer,
                deleteLayer: paintDocumentClient.deleteLayer,
                setActiveLayer: paintDocumentClient.setActiveLayer,
                setLayerName: paintDocumentClient.setLayerName,
                setLayerVisibility: paintDocumentClient.setLayerVisibility,
                revealLayerForEditing: paintDocumentClient.revealLayerForEditing,
                replaceLayerPixels: paintDocumentClient.replaceLayerPixels,
                replaceLayerPixelsInRect: paintDocumentClient.replaceLayerPixelsInRect,
                replaceLayerMask: paintDocumentClient.replaceLayerMask,
                clearLayerMask: paintDocumentClient.clearLayerMask,
                applyLayerMask: paintDocumentClient.applyLayerMask,
                clearLayer: paintDocumentClient.clearLayer,
                applyLayerProcessing: paintDocumentClient.applyLayerProcessing
            ),
            strokeGateway: StrokeInputGateway(
                beginStroke: paintDocumentClient.beginStroke,
                appendStroke: paintDocumentClient.appendStroke,
                endStroke: paintDocumentClient.endStroke,
                cancelStroke: paintDocumentClient.cancelStroke,
                blurStroke: paintDocumentClient.blurStroke,
                endBlurStroke: paintDocumentClient.endBlurStroke,
                fill: paintDocumentClient.fill,
                applySoftwareStroke: paintDocumentClient.applySoftwareStroke
            ),
            historyGateway: DocumentHistoryGateway(
                canUndo: paintDocumentClient.canUndo,
                canRedo: paintDocumentClient.canRedo,
                undo: paintDocumentClient.undo,
                redo: paintDocumentClient.redo
            ),
            persistenceGateway: DocumentPersistenceGateway(
                saveProject: paintDocumentClient.saveProject,
                loadProject: paintDocumentClient.loadProject,
                setPaperStyle: paintDocumentClient.setPaperStyle,
                newCanvas: paintDocumentClient.newCanvas,
                prewarmDrawingResources: paintDocumentClient.prewarmDrawingResources
            ),
            exportGateway: DocumentExportGateway(
                compositePNGData: paintDocumentClient.compositePNGData,
                timelapseCapture: paintDocumentClient.timelapseCapture
            ),
            textLayerGateway: TextLayerGateway(
                textLayerData: paintDocumentClient.textLayerData,
                setTextLayer: paintDocumentClient.setTextLayer,
                clearTextLayerData: paintDocumentClient.clearTextLayerData
            ),
            layerEffectsGateway: DocumentLayerEffectsGateway(
                mergeLayerDown: paintDocumentClient.mergeLayerDown
            ),
            editingGateway: DocumentEditingGateway(paintDocumentClient: paintDocumentClient)
        )
    }
}

extension DocumentEditingGateway {
    init(paintDocumentClient: PaintDocumentClient) {
        let useCase = DocumentEditorUseCase()

        self.init { request in
            let presentation = paintDocumentClient.lightweightPresentation()
            let context = DocumentLayerMutationContext(
                layerCount: presentation.layerRows.count,
                folderIDs: Set(
                    presentation.layerSidebarRows.compactMap { row in
                        guard case let .folder(folder) = row else { return nil }
                        return folder.id
                    }
                ),
                isLayerLocked: { index in
                    presentation.layerRows.first(where: { $0.index == index })?.isLocked ?? false
                }
            )

            let gateway = PaintDocumentEditorAdapter(paintDocumentClient: paintDocumentClient)
            return useCase.execute(request, in: context, gateway: gateway)
                .mapError(mapEditingFailure)
        }
    }
}

private struct PaintDocumentEditorAdapter: DocumentEditorGateway {
    let paintDocumentClient: PaintDocumentClient

    func addLayer(name: String) -> Int {
        switch paintDocumentClient.addLayer(name) {
        case let .success(index):
            return index
        case .failure:
            return -1
        }
    }

    func setActiveLayerIndex(_ index: Int) {
        _ = paintDocumentClient.setActiveLayer(index)
    }

    func duplicateLayer(index: Int, name: String) -> Int {
        switch paintDocumentClient.duplicateLayer(index, name) {
        case let .success(duplicatedIndex):
            return duplicatedIndex
        case .failure:
            return -1
        }
    }

    func deleteLayer(index: Int) -> DocumentLayerMutationResult {
        switch paintDocumentClient.deleteLayer(index) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentLayerMutationResult {
        switch paintDocumentClient.moveLayer(index, destinationIndex) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func createFolder(name: String, anchorLayerIndex: Int) -> Int {
        switch paintDocumentClient.createFolder(name, anchorLayerIndex) {
        case let .success(folderID):
            return folderID
        case .failure:
            return -1
        }
    }

    func deleteFolder(id folderID: Int) -> DocumentLayerMutationResult {
        switch paintDocumentClient.deleteFolder(folderID) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentLayerMutationResult {
        switch paintDocumentClient.assignLayerToFolder(index, folderID) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func setLayerName(_ name: String, index: Int) {
        _ = paintDocumentClient.setLayerName(index, name)
    }

    func setLayerVisible(_ isVisible: Bool, index: Int) {
        _ = paintDocumentClient.setLayerVisibility(index, isVisible)
    }

    func setLayerLocked(_ isLocked: Bool, index: Int) {
        _ = paintDocumentClient.setLayerLocked(index, isLocked)
    }

    func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: Int) {
        _ = paintDocumentClient.setLayerAlphaLocked(index, isAlphaLocked)
    }

    func setLayerClipped(_ isClipped: Bool, index: Int) {
        _ = paintDocumentClient.setLayerClipped(index, isClipped)
    }

    func setLayerOpacity(_ opacity: Double, index: Int) {
        _ = paintDocumentClient.setLayerOpacity(index, opacity)
    }

    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: Int) {
        _ = paintDocumentClient.setLayerBlendMode(index, blendMode)
    }

    func setFolderExpanded(_ isExpanded: Bool, folderID: Int) {
        _ = paintDocumentClient.setFolderExpanded(folderID, isExpanded)
    }

    func setFolderVisible(_ isVisible: Bool, folderID: Int) {
        _ = paintDocumentClient.setFolderVisibility(folderID, isVisible)
    }

    func setFolderName(_ name: String, folderID: Int) {
        _ = paintDocumentClient.setFolderName(folderID, name)
    }
}

private func mapEditingFailure(_ failure: DocumentLayerMutationFailure) -> DocumentMutationFailure {
    switch failure {
    case let .invalidLayerIndex(index):
        return .invalidLayerIndex(index)
    case let .invalidFolderID(folderID):
        return .invalidFolderID(folderID)
    case let .layerLocked(index):
        return .layerLocked(index)
    case let .invalidOpacity(opacity):
        return .invalidOpacity(opacity)
    case let .bridgeMutationFailed(message):
        return .bridgeMutationFailed(message)
    }
}

private func mapRuntimeFailure(_ failure: DocumentMutationFailure) -> DocumentLayerMutationFailure {
    switch failure {
    case let .invalidLayerIndex(index):
        return .invalidLayerIndex(index)
    case let .invalidFolderID(folderID):
        return .invalidFolderID(folderID)
    case let .layerLocked(index):
        return .layerLocked(index)
    case let .invalidOpacity(opacity):
        return .invalidOpacity(opacity)
    case let .bridgeMutationFailed(message):
        return .bridgeMutationFailed(message)
    case .alphaLocked:
        return .bridgeMutationFailed("alphaLocked")
    case .invalidCanvasSize:
        return .bridgeMutationFailed("invalidCanvasSize")
    case .emptyInput:
        return .bridgeMutationFailed("emptyInput")
    case .noUndoState:
        return .bridgeMutationFailed("noUndoState")
    case .noRedoState:
        return .bridgeMutationFailed("noRedoState")
    case .incompatibleLayerType:
        return .bridgeMutationFailed("incompatibleLayerType")
    case let .transactionFailure(primary, rollback):
        return .bridgeMutationFailed("transactionFailure(\(primary),\(rollback))")
    }
}
