import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentStrokeApplication

package struct DocumentRuntimeComposition: Sendable {
    package let queryGateway: DocumentQueryGateway
    package let renderGateway: DocumentRenderGateway
    package let dirtyUpdateQueue: DocumentDirtyUpdateQueue
    package let mutationGateway: DocumentMutationGateway
    package let strokeGateway: StrokeInputGateway
    package let historyGateway: DocumentHistoryGateway
    package let persistenceGateway: DocumentPersistenceGateway
    package let exportGateway: DocumentExportGateway
    package let textLayerGateway: TextLayerGateway
    package let layerEffectsGateway: DocumentLayerEffectsGateway
    package let editingGateway: DocumentEditingGateway
    package let strokeSessionUseCase: DocumentStrokeSessionUseCase
    package let canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations
    package let selectionMaskOperations: DocumentSelectionMaskOperations
    package let layerTransformOperations: DocumentLayerTransformOperations
    package let renderingOperations: DocumentRenderingOperations
    package let surfaceHandleReleaser: DocumentSurfaceHandleReleaser

    package init(
        queryGateway: DocumentQueryGateway,
        renderGateway: DocumentRenderGateway,
        dirtyUpdateQueue: DocumentDirtyUpdateQueue,
        mutationGateway: DocumentMutationGateway,
        strokeGateway: StrokeInputGateway,
        historyGateway: DocumentHistoryGateway,
        persistenceGateway: DocumentPersistenceGateway,
        exportGateway: DocumentExportGateway,
        textLayerGateway: TextLayerGateway,
        layerEffectsGateway: DocumentLayerEffectsGateway,
        editingGateway: DocumentEditingGateway,
        strokeSessionUseCase: DocumentStrokeSessionUseCase,
        canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations,
        selectionMaskOperations: DocumentSelectionMaskOperations,
        layerTransformOperations: DocumentLayerTransformOperations,
        renderingOperations: DocumentRenderingOperations,
        surfaceHandleReleaser: DocumentSurfaceHandleReleaser
    ) {
        self.queryGateway = queryGateway
        self.renderGateway = renderGateway
        self.dirtyUpdateQueue = dirtyUpdateQueue
        self.mutationGateway = mutationGateway
        self.strokeGateway = strokeGateway
        self.historyGateway = historyGateway
        self.persistenceGateway = persistenceGateway
        self.exportGateway = exportGateway
        self.textLayerGateway = textLayerGateway
        self.layerEffectsGateway = layerEffectsGateway
        self.editingGateway = editingGateway
        self.strokeSessionUseCase = strokeSessionUseCase
        self.canvasPreviewOperations = canvasPreviewOperations
        self.selectionMaskOperations = selectionMaskOperations
        self.layerTransformOperations = layerTransformOperations
        self.renderingOperations = renderingOperations
        self.surfaceHandleReleaser = surfaceHandleReleaser
    }

    package func withOverrides(
        queryGateway: DocumentQueryGateway? = nil,
        renderGateway: DocumentRenderGateway? = nil,
        dirtyUpdateQueue: DocumentDirtyUpdateQueue? = nil,
        mutationGateway: DocumentMutationGateway? = nil,
        strokeGateway: StrokeInputGateway? = nil,
        historyGateway: DocumentHistoryGateway? = nil,
        persistenceGateway: DocumentPersistenceGateway? = nil,
        exportGateway: DocumentExportGateway? = nil,
        textLayerGateway: TextLayerGateway? = nil,
        layerEffectsGateway: DocumentLayerEffectsGateway? = nil,
        editingGateway: DocumentEditingGateway? = nil,
        strokeSessionUseCase: DocumentStrokeSessionUseCase? = nil,
        canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations? = nil,
        selectionMaskOperations: DocumentSelectionMaskOperations? = nil,
        layerTransformOperations: DocumentLayerTransformOperations? = nil,
        renderingOperations: DocumentRenderingOperations? = nil,
        surfaceHandleReleaser: DocumentSurfaceHandleReleaser? = nil
    ) -> DocumentRuntimeComposition {
        DocumentRuntimeComposition(
            queryGateway: queryGateway ?? self.queryGateway,
            renderGateway: renderGateway ?? self.renderGateway,
            dirtyUpdateQueue: dirtyUpdateQueue ?? self.dirtyUpdateQueue,
            mutationGateway: mutationGateway ?? self.mutationGateway,
            strokeGateway: strokeGateway ?? self.strokeGateway,
            historyGateway: historyGateway ?? self.historyGateway,
            persistenceGateway: persistenceGateway ?? self.persistenceGateway,
            exportGateway: exportGateway ?? self.exportGateway,
            textLayerGateway: textLayerGateway ?? self.textLayerGateway,
            layerEffectsGateway: layerEffectsGateway ?? self.layerEffectsGateway,
            editingGateway: editingGateway ?? self.editingGateway,
            strokeSessionUseCase: strokeSessionUseCase ?? self.strokeSessionUseCase,
            canvasPreviewOperations: canvasPreviewOperations ?? self.canvasPreviewOperations,
            selectionMaskOperations: selectionMaskOperations ?? self.selectionMaskOperations,
            layerTransformOperations: layerTransformOperations ?? self.layerTransformOperations,
            renderingOperations: renderingOperations ?? self.renderingOperations,
            surfaceHandleReleaser: surfaceHandleReleaser ?? self.surfaceHandleReleaser
        )
    }
}

package enum DocumentRuntimeCompositionFactory {
    package static func live(
        fileClient: PrimoCoreTypes.FileClient = .live,
        dateClient: PrimoCoreTypes.DateClient = .live,
        uuidClient: PrimoCoreTypes.UUIDClient = .live
    ) -> DocumentRuntimeComposition {
        let runtime = DocumentEngineFactory.live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        let strokeUseCases = DocumentStrokeUseCasesLive.live()

        let gpuOperations = DocumentGpuOperationGatewayFactory.live()

        return DocumentRuntimeComposition(
            queryGateway: runtime.queryGateway,
            renderGateway: runtime.renderGateway,
            dirtyUpdateQueue: runtime.dirtyUpdateQueue,
            mutationGateway: runtime.mutationGateway,
            strokeGateway: runtime.strokeGateway,
            historyGateway: runtime.historyGateway,
            persistenceGateway: runtime.persistenceGateway,
            exportGateway: runtime.exportGateway,
            textLayerGateway: runtime.textLayerGateway,
            layerEffectsGateway: DocumentLayerEffectsGateway(
                mergeLayerDown: runtime.mergeLayerDown
            ),
            editingGateway: runtime.makeEditingGateway(),
            strokeSessionUseCase: strokeUseCases.session,
            canvasPreviewOperations: gpuOperations.canvasPreviewRenderingOperations,
            selectionMaskOperations: gpuOperations.selectionMaskOperations,
            layerTransformOperations: gpuOperations.layerTransformOperations,
            renderingOperations: gpuOperations.renderingOperations,
            surfaceHandleReleaser: gpuOperations.surfaceHandleReleaser
        )
    }
}

extension DocumentEngineLive {
    package func makeEditingGateway() -> DocumentEditingGateway {
        let useCase = DocumentEditorUseCase()

        return DocumentEditingGateway { request in
            let presentation = self.queryGateway.lightweightPresentation()
            let context = DocumentLayerMutationContext(
                revision: presentation.revision,
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

            let gateway = LiveDocumentEditorGateway(runtime: self)
            return useCase.execute(request, in: context, gateway: gateway)
                .mapError(mapEditingFailure)
        }
    }
}

private struct LiveDocumentEditorGateway: DocumentEditorGateway {
    let runtime: DocumentEngineLive

    func addLayerAndSelect(name: String) -> DocumentLayerAddSelectionResult {
        runtime.mutationGateway.addLayer(name)
            .map { AddedAndSelectedLayer.addedAndSelected(index: $0) }
            .mapError(mapRuntimeFailure)
    }

    func setActiveLayerIndex(_ index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.mutationGateway.setActiveLayer(index.rawValue)
            .mapError(mapRuntimeFailure)
    }

    func duplicateLayer(index: ExistingLayerIndex, name: String) -> DocumentLayerIndexedMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.duplicateLayer(index.rawValue, name)
            .mapError(mapRuntimeFailure)
    }

    func deleteLayer(index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        switch runtime.mutationGateway.deleteLayer(index.rawValue) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func moveLayer(from index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        if let failure = validateFreshLayerIndex(destinationIndex) { return .failure(failure) }
        switch runtime.moveLayer(index.rawValue, destinationIndex.rawValue) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func createFolder(name: String, anchorLayerIndex: LayerAnchorIndex) -> DocumentLayerIndexedMutationResult {
        runtime.createFolder(name, anchorLayerIndex)
            .mapError(mapRuntimeFailure)
    }

    func deleteFolder(id folderID: ExistingFolderID) -> DocumentLayerMutationResult {
        switch runtime.deleteFolder(folderID.rawValue) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func assignLayer(index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        switch runtime.assignLayerToFolder(index, folderID) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func setLayerName(_ name: String, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.mutationGateway.setLayerName(index.rawValue, name)
            .mapError(mapRuntimeFailure)
    }

    func setLayerVisible(_ isVisible: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.mutationGateway.setLayerVisibility(index.rawValue, isVisible)
            .mapError(mapRuntimeFailure)
    }

    func setLayerLocked(_ isLocked: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerLocked(index.rawValue, isLocked)
            .mapError(mapRuntimeFailure)
    }

    func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerAlphaLocked(index.rawValue, isAlphaLocked)
            .mapError(mapRuntimeFailure)
    }

    func setLayerClipped(_ isClipped: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerClipped(index.rawValue, isClipped)
            .mapError(mapRuntimeFailure)
    }

    func setLayerOpacity(_ opacity: ValidatedLayerOpacity, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerOpacity(index.rawValue, opacity.rawValue)
            .mapError(mapRuntimeFailure)
    }

    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerBlendMode(index.rawValue, blendMode)
            .mapError(mapRuntimeFailure)
    }

    func setFolderExpanded(_ isExpanded: Bool, folderID: ExistingFolderID) -> DocumentLayerMutationResult {
        runtime.setFolderExpanded(folderID.rawValue, isExpanded)
            .mapError(mapRuntimeFailure)
    }

    func setFolderVisible(_ isVisible: Bool, folderID: ExistingFolderID) -> DocumentLayerMutationResult {
        runtime.setFolderVisibility(folderID.rawValue, isVisible)
            .mapError(mapRuntimeFailure)
    }

    func setFolderName(_ name: String, folderID: ExistingFolderID) -> DocumentLayerMutationResult {
        runtime.setFolderName(folderID.rawValue, name)
            .mapError(mapRuntimeFailure)
    }

    func replaceLayerPixels(index: EditableLayerIndex, pixelData: LayerPixelData) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.mutationGateway.replaceLayerPixels(index.rawValue, pixelData.rgba)
            .mapError(mapRuntimeFailure)
    }

    func setTextLayer(index: EditableLayerIndex, textLayer: TextLayerData) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.textLayerGateway.setTextLayer(index.rawValue, textLayer)
            .mapError(mapRuntimeFailure)
    }

    func clearLayer(index: EditableLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.mutationGateway.clearLayer(index.rawValue)
            .mapError(mapRuntimeFailure)
    }

    func applyLayerProcessing(
        index: EditableLayerIndex,
        request: ValidatedLayerProcessingRequest
    ) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.mutationGateway.applyLayerProcessing(index.rawValue, request)
            .mapError(mapRuntimeFailure)
    }

    func replaceLayerMask(index: EditableLayerIndex, mask: LayerMaskData) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.mutationGateway.replaceLayerMask(index.rawValue, mask.bytes)
            .mapError(mapRuntimeFailure)
    }

    func clearLayerMask(index: EditableLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.mutationGateway.clearLayerMask(index.rawValue)
            .mapError(mapRuntimeFailure)
    }

    func applyLayerMask(index: EditableLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.mutationGateway.applyLayerMask(index.rawValue)
            .mapError(mapRuntimeFailure)
    }

    // Authoritative stale validation happens immediately before raw runtime
    // mutation so UI preflight results cannot grant stale access.
    private func validateFreshLayerIndex(_ index: ExistingLayerIndex) -> DocumentLayerMutationFailure? {
        let currentRevision = runtime.queryGateway.lightweightPresentation().revision
        guard index.revision == currentRevision else {
            return .staleLayerIndex(
                index: index.rawValue,
                validationRevision: index.revision,
                currentRevision: currentRevision
            )
        }
        return nil
    }

    private func validateFreshLayerIndex(_ index: EditableLayerIndex) -> DocumentLayerMutationFailure? {
        let currentRevision = runtime.queryGateway.lightweightPresentation().revision
        guard index.revision == currentRevision else {
            return .staleLayerIndex(
                index: index.rawValue,
                validationRevision: index.revision,
                currentRevision: currentRevision
            )
        }
        return nil
    }
}

private func mapEditingFailure(_ failure: DocumentLayerMutationFailure) -> DocumentMutationFailure {
    switch failure {
    case let .invalidLayerIndex(index):
        return .invalidLayerIndex(index)
    case let .staleLayerIndex(index, validationRevision, currentRevision):
        return .staleLayerIndex(
            index: index,
            validationRevision: validationRevision,
            currentRevision: currentRevision
        )
    case let .invalidFolderID(folderID):
        return .invalidFolderID(folderID)
    case let .layerLocked(index):
        return .layerLocked(index)
    case let .alphaLocked(index):
        return .alphaLocked(index)
    case let .invalidCanvasSize(width, height):
        return .invalidCanvasSize(width: width, height: height)
    case let .invalidOpacity(opacity):
        return .invalidOpacity(opacity)
    case .emptyInput:
        return .emptyInput
    case .noUndoState:
        return .noUndoState
    case .noRedoState:
        return .noRedoState
    case let .gpu(failure):
        return .gpu(failure)
    case let .bridgeMutationFailed(message):
        return .bridgeMutationFailed(message)
    case let .incompatibleLayerType(index):
        return .incompatibleLayerType(index)
    case let .transactionFailure(primary, rollback):
        return .transactionFailure(
            primary: mapEditingFailure(primary),
            rollback: mapEditingFailure(rollback)
        )
    }
}

private func mapRuntimeFailure(_ failure: DocumentMutationFailure) -> DocumentLayerMutationFailure {
    switch failure {
    case let .invalidLayerIndex(index):
        return .invalidLayerIndex(index)
    case let .staleLayerIndex(index, validationRevision, currentRevision):
        return .staleLayerIndex(
            index: index,
            validationRevision: validationRevision,
            currentRevision: currentRevision
        )
    case let .invalidFolderID(folderID):
        return .invalidFolderID(folderID)
    case let .layerLocked(index):
        return .layerLocked(index)
    case let .alphaLocked(index):
        return .alphaLocked(index)
    case let .invalidCanvasSize(width, height):
        return .invalidCanvasSize(width: width, height: height)
    case let .invalidOpacity(opacity):
        return .invalidOpacity(opacity)
    case .emptyInput:
        return .emptyInput
    case .noUndoState:
        return .noUndoState
    case .noRedoState:
        return .noRedoState
    case let .gpu(failure):
        return .gpu(failure)
    case let .bridgeMutationFailed(message):
        return .bridgeMutationFailed(message)
    case let .incompatibleLayerType(index):
        return .incompatibleLayerType(index)
    case let .transactionFailure(primary, rollback):
        return .transactionFailure(
            primary: mapRuntimeFailure(primary),
            rollback: mapRuntimeFailure(rollback)
        )
    }
}
