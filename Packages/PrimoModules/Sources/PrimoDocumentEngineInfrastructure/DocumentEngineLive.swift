import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentInfrastructure

package struct DocumentEngineLive: Sendable {
    package let queryGateway: DocumentQueryGateway
    package let renderGateway: DocumentRenderGateway
    package let dirtyUpdateQueue: DocumentDirtyUpdateQueue
    package let mutationGateway: DocumentMutationGateway
    package let strokeGateway: StrokeInputGateway
    package let historyGateway: DocumentHistoryGateway
    package let persistenceGateway: DocumentPersistenceGateway
    package let exportGateway: DocumentExportGateway
    package let textLayerGateway: TextLayerGateway
    package let editingGateway: DocumentEditingGateway

    package let duplicateLayer: @Sendable (Int, String) -> DocumentCreatedLayerMutationResult
    package let moveLayer: @Sendable (Int, Int) -> DocumentMutationResult
    package let createFolder: @Sendable (String, LayerAnchorIndex) -> DocumentCreatedFolderMutationResult
    package let deleteFolder: @Sendable (Int) -> DocumentMutationResult
    package let setFolderVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    package let setFolderName: @Sendable (Int, String) -> DocumentMutationResult
    package let setFolderExpanded: @Sendable (Int, Bool) -> DocumentMutationResult
    package let assignLayerToFolder: @Sendable (ExistingLayerIndex, ExistingFolderID?) -> DocumentMutationResult
    package let setLayerLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    package let setLayerAlphaLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    package let setLayerClipped: @Sendable (Int, Bool) -> DocumentMutationResult
    package let setLayerOpacity: @Sendable (Int, Double) -> DocumentMutationResult
    package let setLayerBlendMode: @Sendable (Int, LayerBlendMode) -> DocumentMutationResult
    package let mergeLayerDown: @Sendable (Int) -> DocumentMutationResult
}

package enum DocumentEngineFactory {
    package static func live(
        fileClient: PrimoCoreTypes.FileClient = .live,
        dateClient: PrimoCoreTypes.DateClient = .live,
        uuidClient: PrimoCoreTypes.UUIDClient = .live
    ) -> DocumentEngineLive {
        live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient,
            gpuServices: DocumentRuntimeGpuServicesFactory.live()
        )
    }

    static func live(
        fileClient: PrimoCoreTypes.FileClient = .live,
        dateClient: PrimoCoreTypes.DateClient = .live,
        uuidClient: PrimoCoreTypes.UUIDClient = .live,
        gpuServices: DocumentRuntimeGpuServices
    ) -> DocumentEngineLive {
        let runtimeExecutor = LockedDocumentRuntimeExecutor(
            runtime: SwiftDocumentRuntime(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient,
                gpuServices: gpuServices
            )
        )

        let queryGateway = DocumentEngineQueryGatewayFactory.live(runtimeExecutor: runtimeExecutor)
        let renderGateway = DocumentEngineRenderGatewayFactory.live(
            runtimeExecutor: runtimeExecutor,
            gpuServices: gpuServices
        )
        let dirtyUpdateQueue = DocumentEngineDirtyUpdateQueueFactory.live(runtimeExecutor: runtimeExecutor)
        let mutationGateway = DocumentEngineMutationGatewayFactory.live(runtimeExecutor: runtimeExecutor)
        let strokeGateway = DocumentEngineStrokeGatewayFactory.live(runtimeExecutor: runtimeExecutor)
        let historyGateway = DocumentEngineHistoryGatewayFactory.live(runtimeExecutor: runtimeExecutor)
        let persistenceGateway = DocumentEnginePersistenceGatewayFactory.live(
            runtimeExecutor: runtimeExecutor,
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient,
            gpuServices: gpuServices
        )
        let exportGateway = DocumentEngineExportGatewayFactory.live(
            runtimeExecutor: runtimeExecutor,
            gpuServices: gpuServices
        )
        let textLayerGateway = DocumentEngineTextLayerGatewayFactory.live(runtimeExecutor: runtimeExecutor)
        let editingGateway = DocumentEngineEditingGatewayFactory.live(runtimeExecutor: runtimeExecutor)
        let layerEffects = DocumentEngineLayerEffectsFactory.live(runtimeExecutor: runtimeExecutor)

        return DocumentEngineLive(
            queryGateway: queryGateway,
            renderGateway: renderGateway,
            dirtyUpdateQueue: dirtyUpdateQueue,
            mutationGateway: mutationGateway,
            strokeGateway: strokeGateway,
            historyGateway: historyGateway,
            persistenceGateway: persistenceGateway,
            exportGateway: exportGateway,
            textLayerGateway: textLayerGateway,
            editingGateway: editingGateway,
            duplicateLayer: layerEffects.duplicateLayer,
            moveLayer: layerEffects.moveLayer,
            createFolder: layerEffects.createFolder,
            deleteFolder: layerEffects.deleteFolder,
            setFolderVisibility: layerEffects.setFolderVisibility,
            setFolderName: layerEffects.setFolderName,
            setFolderExpanded: layerEffects.setFolderExpanded,
            assignLayerToFolder: layerEffects.assignLayerToFolder,
            setLayerLocked: layerEffects.setLayerLocked,
            setLayerAlphaLocked: layerEffects.setLayerAlphaLocked,
            setLayerClipped: layerEffects.setLayerClipped,
            setLayerOpacity: layerEffects.setLayerOpacity,
            setLayerBlendMode: layerEffects.setLayerBlendMode,
            mergeLayerDown: layerEffects.mergeLayerDown
        )
    }
}

struct RuntimeDocumentEditorGateway: DocumentEditorGateway {
    let runtime: SwiftDocumentRuntime
    let currentPresentation: PaintDocumentPresentation

    // Authoritative stale validation happens at the runtime boundary with the
    // current presentation revision, even when the app already preflighted.
    func addLayerAndSelect(name: String) -> DocumentLayerAddSelectionResult {
        runtime.addLayer(name: name)
            .map { AddedAndSelectedLayer.addedAndSelected($0) }
            .mapError(mapDocumentRuntimeFailure)
    }

    func setActiveLayerIndex(_ index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setActiveLayer(index: index.rawValue)
            .mapError(mapDocumentRuntimeFailure)
    }

    func duplicateLayer(index: ExistingLayerIndex, name: String) -> DocumentLayerCreatedMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.duplicateLayer(index: index.rawValue, name: name)
            .mapError(mapDocumentRuntimeFailure)
    }

    func deleteLayer(index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.deleteLayer(index: index.rawValue)
            .mapError(mapDocumentRuntimeFailure)
    }

    func moveLayer(from index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        if let failure = validateFreshLayerIndex(destinationIndex) { return .failure(failure) }
        return runtime.moveLayer(from: index.rawValue, to: destinationIndex.rawValue)
            .mapError(mapDocumentRuntimeFailure)
    }

    func createFolder(name: String, anchorLayerIndex: LayerAnchorIndex) -> DocumentFolderCreatedMutationResult {
        if let failure = validateFreshLayerAnchorIndex(anchorLayerIndex) { return .failure(failure) }
        return runtime.createFolder(name: name, anchorLayerIndex: anchorLayerIndex)
            .mapError(mapDocumentRuntimeFailure)
    }

    func deleteFolder(id folderID: ExistingFolderID) -> DocumentLayerMutationResult {
        if let failure = validateFreshFolderID(folderID) { return .failure(failure) }
        return runtime.deleteFolder(folderID: folderID.rawValue)
            .mapError(mapDocumentRuntimeFailure)
    }

    func assignLayer(index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        if let folderID, let failure = validateFreshFolderID(folderID) { return .failure(failure) }
        return runtime.assignLayerToFolder(index: index, folderID: folderID)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setLayerName(_ name: String, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerName(index: index.rawValue, name: name)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setLayerVisible(_ isVisible: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerVisibility(index: index.rawValue, isVisible: isVisible)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setLayerLocked(_ isLocked: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerLocked(index: index.rawValue, isLocked: isLocked)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerAlphaLocked(index: index.rawValue, isAlphaLocked: isAlphaLocked)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setLayerClipped(_ isClipped: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerClipped(index: index.rawValue, isClipped: isClipped)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setLayerOpacity(_ opacity: ValidatedLayerOpacity, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerOpacity(index: index.rawValue, opacity: opacity.rawValue)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setLayerBlendMode(index: index.rawValue, blendMode: blendMode)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setFolderExpanded(_ isExpanded: Bool, folderID: ExistingFolderID) -> DocumentLayerMutationResult {
        if let failure = validateFreshFolderID(folderID) { return .failure(failure) }
        return runtime.setFolderExpanded(folderID: folderID.rawValue, isExpanded: isExpanded)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setFolderVisible(_ isVisible: Bool, folderID: ExistingFolderID) -> DocumentLayerMutationResult {
        if let failure = validateFreshFolderID(folderID) { return .failure(failure) }
        return runtime.setFolderVisibility(folderID: folderID.rawValue, isVisible: isVisible)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setFolderName(_ name: String, folderID: ExistingFolderID) -> DocumentLayerMutationResult {
        if let failure = validateFreshFolderID(folderID) { return .failure(failure) }
        return runtime.setFolderName(folderID: folderID.rawValue, name: name)
            .mapError(mapDocumentRuntimeFailure)
    }

    func replaceLayerPixels(index: EditableLayerIndex, pixelData: LayerPixelData) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.replaceLayerPixels(index: index.rawValue, data: pixelData.rgba)
            .mapError(mapDocumentRuntimeFailure)
    }

    func setTextLayer(index: EditableLayerIndex, textLayer: TextLayerData) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.setTextLayer(index: index.rawValue, textLayer: textLayer)
            .mapError(mapDocumentRuntimeFailure)
    }

    func clearLayer(index: EditableLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.clearLayer(index: index.rawValue)
            .mapError(mapDocumentRuntimeFailure)
    }

    func applyLayerProcessing(
        index: EditableLayerIndex,
        request: ValidatedLayerProcessingRequest
    ) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.applyLayerProcessing(index: index.rawValue, request: request.rawValue)
            .mapError(mapDocumentRuntimeFailure)
    }

    func replaceLayerMask(index: EditableLayerIndex, mask: LayerMaskData) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.replaceLayerMask(index: index.rawValue, data: mask.bytes)
            .mapError(mapDocumentRuntimeFailure)
    }

    func clearLayerMask(index: EditableLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.clearLayerMask(index: index.rawValue)
            .mapError(mapDocumentRuntimeFailure)
    }

    func applyLayerMask(index: EditableLayerIndex) -> DocumentLayerMutationResult {
        if let failure = validateFreshLayerIndex(index) { return .failure(failure) }
        return runtime.applyLayerMask(index: index.rawValue)
            .mapError(mapDocumentRuntimeFailure)
    }

    private func validateFreshLayerIndex(_ index: ExistingLayerIndex) -> DocumentLayerMutationFailure? {
        guard index.revision == currentPresentation.revision else {
            return .staleLayerIndex(
                index: index.rawValue,
                validationRevision: index.revision,
                currentRevision: currentPresentation.revision
            )
        }
        guard currentPresentation.layerRows.contains(where: { $0.index == index.rawValue }) else {
            return .invalidLayerIndex(index.rawValue)
        }
        return nil
    }

    private func validateFreshLayerIndex(_ index: EditableLayerIndex) -> DocumentLayerMutationFailure? {
        guard index.revision == currentPresentation.revision else {
            return .staleLayerIndex(
                index: index.rawValue,
                validationRevision: index.revision,
                currentRevision: currentPresentation.revision
            )
        }
        guard let layer = currentPresentation.layerRows.first(where: { $0.index == index.rawValue }) else {
            return .invalidLayerIndex(index.rawValue)
        }
        guard !layer.isLocked else {
            return .layerLocked(index.rawValue)
        }
        return nil
    }

    private func validateFreshFolderID(_ folderID: ExistingFolderID) -> DocumentLayerMutationFailure? {
        let currentFolderIDs: Set<Int> = Set(currentPresentation.layerSidebarRows.compactMap { row in
            guard case let .folder(folder) = row else { return nil }
            return folder.id
        })
        guard folderID.revision == currentPresentation.revision else {
            return .staleFolderID(
                folderID: folderID.rawValue,
                validationRevision: folderID.revision,
                currentRevision: currentPresentation.revision
            )
        }
        guard currentFolderIDs.contains(folderID.rawValue) else {
            return .invalidFolderID(folderID.rawValue)
        }
        return nil
    }

    private func validateFreshLayerAnchorIndex(_ index: LayerAnchorIndex) -> DocumentLayerMutationFailure? {
        guard index.revision == currentPresentation.revision else {
            return .staleLayerAnchor(
                anchorLayerIndex: index.rawValue,
                validationRevision: index.revision,
                currentRevision: currentPresentation.revision
            )
        }
        guard let rawValue = index.rawValue else {
            return nil
        }
        guard currentPresentation.layerRows.contains(where: { $0.index == rawValue }) else {
            return .invalidLayerIndex(rawValue)
        }
        return nil
    }
}

func mapDocumentEditorFailure(_ failure: DocumentLayerMutationFailure) -> DocumentMutationFailure {
    DocumentMutationFailure(coreFailure: failure.coreFailure)
}

func mapDocumentRuntimeFailure(_ failure: DocumentMutationFailure) -> DocumentLayerMutationFailure {
    DocumentLayerMutationFailure(coreFailure: failure.coreFailure)
}

/// @unchecked Sendable: replay state is held behind a `LockedDocumentRuntimeExecutor` and uses injected GPU services.
/// Concurrency test: timelapseReplayServiceUsesLockedRuntimeExecutorForReplayState
package final class DocumentTimelapseReplayService: @unchecked Sendable {
    private let stateExecutor: LockedDocumentRuntimeExecutor<DocumentTimelapseReplayState>

    init(
        canvasSize: CGSize,
        fileClient: PrimoCoreTypes.FileClient = .live,
        dateClient: PrimoCoreTypes.DateClient = .live,
        uuidClient: PrimoCoreTypes.UUIDClient = .live,
        gpuServices: DocumentRuntimeGpuServices
    ) {
        self.stateExecutor = LockedDocumentRuntimeExecutor(
            runtime: DocumentTimelapseReplayState(
                runtime: SwiftDocumentRuntime(
                    width: max(Int(canvasSize.width.rounded()), 1),
                    height: max(Int(canvasSize.height.rounded()), 1),
                    fileClient: fileClient,
                    dateClient: dateClient,
                    uuidClient: uuidClient,
                    gpuServices: gpuServices
                )
            )
        )
    }

    package func replaySurface(_ operation: TimelapseOperation) -> DocumentCompositeSurface? {
        try? stateExecutor.performThrowing(operation: "replayTimelapseOperation") { state in
            state.runtime.replayTimelapseOperation(operation, folderIDMap: &state.folderIDMap)
            return state.runtime.timelapseCompositeSurface()
        }
    }

    // Legacy convenience retained for callers that still expect CGImage.
    // Replay/export code should prefer `replaySurface(_:)`.
    @available(*, deprecated, message: "Prefer replaySurface(_:) for live replay paths.")
    package func replay(_ operation: TimelapseOperation) -> CGImage? {
        guard let surface = replaySurface(operation) else { return nil }
        let result = stateExecutor.performValue(operation: "timelapseReplayCGImage") {
            $0.runtime.cgImage(from: surface.pixelData, width: surface.width, height: surface.height)
        }
        switch result {
        case let .success(image):
            return image
        case .failure:
            return nil
        }
    }
}

private final class DocumentTimelapseReplayState {
    let runtime: SwiftDocumentRuntime
    var folderIDMap: [DocumentFolderID: Int] = [:]

    init(runtime: SwiftDocumentRuntime) {
        self.runtime = runtime
    }
}
