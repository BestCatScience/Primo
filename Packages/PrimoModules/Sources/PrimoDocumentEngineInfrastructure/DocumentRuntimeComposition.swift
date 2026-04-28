import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentStrokeApplication

public struct DocumentRuntimeComposition: Sendable {
    public var queryGateway: DocumentQueryGateway
    public var mutationGateway: DocumentMutationGateway
    public var strokeGateway: StrokeInputGateway
    public var historyGateway: DocumentHistoryGateway
    public var persistenceGateway: DocumentPersistenceGateway
    public var exportGateway: DocumentExportGateway
    public var textLayerGateway: TextLayerGateway
    public var layerEffectsGateway: DocumentLayerEffectsGateway
    public var editingGateway: DocumentEditingGateway
    public var strokeSessionUseCase: DocumentStrokeSessionUseCase
    public var gpuOperationGateway: DocumentGpuOperationGateway

    public init(
        queryGateway: DocumentQueryGateway,
        mutationGateway: DocumentMutationGateway,
        strokeGateway: StrokeInputGateway,
        historyGateway: DocumentHistoryGateway,
        persistenceGateway: DocumentPersistenceGateway,
        exportGateway: DocumentExportGateway,
        textLayerGateway: TextLayerGateway,
        layerEffectsGateway: DocumentLayerEffectsGateway,
        editingGateway: DocumentEditingGateway,
        strokeSessionUseCase: DocumentStrokeSessionUseCase,
        gpuOperationGateway: DocumentGpuOperationGateway
    ) {
        self.queryGateway = queryGateway
        self.mutationGateway = mutationGateway
        self.strokeGateway = strokeGateway
        self.historyGateway = historyGateway
        self.persistenceGateway = persistenceGateway
        self.exportGateway = exportGateway
        self.textLayerGateway = textLayerGateway
        self.layerEffectsGateway = layerEffectsGateway
        self.editingGateway = editingGateway
        self.strokeSessionUseCase = strokeSessionUseCase
        self.gpuOperationGateway = gpuOperationGateway
    }
}

public enum DocumentRuntimeCompositionFactory {
    public static func live(
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

        return DocumentRuntimeComposition(
            queryGateway: runtime.queryGateway,
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
            gpuOperationGateway: DocumentGpuOperationGatewayFactory.live()
        )
    }
}

extension DocumentEngineLive {
    public func makeEditingGateway() -> DocumentEditingGateway {
        let useCase = DocumentEditorUseCase()

        return DocumentEditingGateway { request in
            let presentation = self.queryGateway.lightweightPresentation()
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

            let gateway = LiveDocumentEditorGateway(runtime: self)
            return useCase.execute(request, in: context, gateway: gateway)
                .mapError(mapEditingFailure)
        }
    }
}

private struct LiveDocumentEditorGateway: DocumentEditorGateway {
    let runtime: DocumentEngineLive

    func addLayer(name: String) -> DocumentLayerIndexedMutationResult {
        runtime.mutationGateway.addLayer(name)
            .mapError(mapRuntimeFailure)
    }

    func setActiveLayerIndex(_ index: Int) -> DocumentLayerMutationResult {
        runtime.mutationGateway.setActiveLayer(index)
            .mapError(mapRuntimeFailure)
    }

    func duplicateLayer(index: Int, name: String) -> DocumentLayerIndexedMutationResult {
        runtime.duplicateLayer(index, name)
            .mapError(mapRuntimeFailure)
    }

    func deleteLayer(index: Int) -> DocumentLayerMutationResult {
        switch runtime.mutationGateway.deleteLayer(index) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentLayerMutationResult {
        switch runtime.moveLayer(index, destinationIndex) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func createFolder(name: String, anchorLayerIndex: Int) -> DocumentLayerIndexedMutationResult {
        runtime.createFolder(name, anchorLayerIndex)
            .mapError(mapRuntimeFailure)
    }

    func deleteFolder(id folderID: Int) -> DocumentLayerMutationResult {
        switch runtime.deleteFolder(folderID) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentLayerMutationResult {
        switch runtime.assignLayerToFolder(index, folderID) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(mapRuntimeFailure(failure))
        }
    }

    func setLayerName(_ name: String, index: Int) -> DocumentLayerMutationResult {
        runtime.mutationGateway.setLayerName(index, name)
            .mapError(mapRuntimeFailure)
    }

    func setLayerVisible(_ isVisible: Bool, index: Int) -> DocumentLayerMutationResult {
        runtime.mutationGateway.setLayerVisibility(index, isVisible)
            .mapError(mapRuntimeFailure)
    }

    func setLayerLocked(_ isLocked: Bool, index: Int) -> DocumentLayerMutationResult {
        runtime.setLayerLocked(index, isLocked)
            .mapError(mapRuntimeFailure)
    }

    func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: Int) -> DocumentLayerMutationResult {
        runtime.setLayerAlphaLocked(index, isAlphaLocked)
            .mapError(mapRuntimeFailure)
    }

    func setLayerClipped(_ isClipped: Bool, index: Int) -> DocumentLayerMutationResult {
        runtime.setLayerClipped(index, isClipped)
            .mapError(mapRuntimeFailure)
    }

    func setLayerOpacity(_ opacity: Double, index: Int) -> DocumentLayerMutationResult {
        runtime.setLayerOpacity(index, opacity)
            .mapError(mapRuntimeFailure)
    }

    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: Int) -> DocumentLayerMutationResult {
        runtime.setLayerBlendMode(index, blendMode)
            .mapError(mapRuntimeFailure)
    }

    func setFolderExpanded(_ isExpanded: Bool, folderID: Int) -> DocumentLayerMutationResult {
        runtime.setFolderExpanded(folderID, isExpanded)
            .mapError(mapRuntimeFailure)
    }

    func setFolderVisible(_ isVisible: Bool, folderID: Int) -> DocumentLayerMutationResult {
        runtime.setFolderVisibility(folderID, isVisible)
            .mapError(mapRuntimeFailure)
    }

    func setFolderName(_ name: String, folderID: Int) -> DocumentLayerMutationResult {
        runtime.setFolderName(folderID, name)
            .mapError(mapRuntimeFailure)
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
