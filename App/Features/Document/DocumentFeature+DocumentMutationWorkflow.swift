import Foundation
import ComposableArchitecture
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import UIKit

extension DocumentMutationWorkflowOutcome where Selection == CanvasSelection, Feedback == ApplicationFeature.Feedback {
    init(
        canvasMutation: DocumentCanvasMutationIntent<CanvasSelection> = .none,
        refresh: DocumentPresentationRefreshIntent = .dirty,
        successFeedback: ApplicationFeature.Feedback?,
        updatesWorkspaceArtifacts: Bool = true
    ) {
        self.init(
            canvasMutation: canvasMutation,
            refresh: refresh,
            feedback: successFeedback.map { .success($0) } ?? .none,
            updatesWorkspaceArtifacts: updatesWorkspaceArtifacts
        )
    }
}

extension DocumentFeature {
    typealias LayerContentMutationTarget = PrimoDocumentApplication.LayerContentMutationTarget
    typealias AppliedLayerContentMutation = PrimoDocumentApplication.AppliedLayerContentMutation
    typealias LayerContentWorkflowService = PrimoDocumentApplication.DocumentContentService

    var layerWorkflowService: LayerWorkflowService {
        documentMutationWorkflowService
    }

    var layerContentWorkflowService: LayerContentWorkflowService {
        LayerContentWorkflowService(
            documentQueryGateway: documentQueryGateway,
            documentMutationGateway: documentMutationGateway,
            textLayerGateway: textLayerGateway
        )
    }

    struct DocumentCanvasMutationCoordinator {
        func apply(
            _ mutation: DocumentCanvasMutation,
            to state: inout State
        ) {
            switch mutation {
            case .none:
                break
            case .clearSelection:
                state.canvas.clearSelection()
            case let .finalizeLayer(finalization):
                state.canvas.finalizeLayerMutation(
                    at: finalization.index,
                    incrementsRevision: finalization.incrementsRevision,
                    clearsSelection: finalization.clearsSelection
                )
            case let .completeTransform(layerIndex, selection):
                state.canvas.completeTransformMutation(
                    at: layerIndex,
                    selection: selection
                )
            case .resetTransientEditingState:
                state.canvas.resetTransientEditingState()
            case .resetTransformPreview:
                state.canvas.resetTransformPreview()
            }
        }
    }

    @discardableResult
    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        DocumentCanvasMutationCoordinator().apply(
            contract.canvasMutation,
            to: &state
        )
        let refreshEffect: Effect<Action>
        switch contract.refresh {
        case .none:
            refreshEffect = .none
        case .current:
            refreshEffect = applyPresentation(documentQueryGateway.presentation(), to: &state)
        case .dirty:
            refreshEffect = .send(.delegate(.presentationRefreshRequested))
        }
        return .merge(
            refreshEffect,
            documentMutationFeedbackEffect(for: contract.successFeedback)
        )
    }

    @discardableResult
    func performDocumentMutation<Success>(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        failureFeedback: ApplicationFeature.Feedback? = nil,
        mutation: () -> Result<Success, DocumentMutationFailure>,
        onSuccess: (Success, inout State) -> Void = { _, _ in }
    ) -> Effect<Action> {
        switch mutation() {
        case let .success(success):
            onSuccess(success, &state)
            return completeDocumentMutation(state: &state, contract: contract)

        case let .failure(failure):
            return documentMutationFeedbackEffect(
                for: DocumentMutationFeedbackMapper().feedback(
                    for: failure,
                    default: failureFeedback
                )
            )
        }
    }

    private func documentMutationFeedbackEffect(
        for feedback: ApplicationFeature.Feedback?
    ) -> Effect<Action> {
        guard let feedback else { return .none }
        return .send(.delegate(.documentMutationFeedback(feedback)))
    }

    func handleActiveLayerVisibilityToggle(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let layer = state.layerSidebar.layer(withIndex: activeLayerIndex) else {
            return .none
        }
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            layerWorkflowService.setLayerVisibility(activeLayerIndex, visible: !layer.visible)
        }
    }

    func handleSelectAdjacentLayer(
        state: inout State,
        direction: Int
    ) -> Effect<Action> {
        guard let currentPosition = state.layerSidebar.layers.firstIndex(where: { $0.index == state.layerSidebar.activeLayerIndex }) else {
            return .none
        }
        let targetPosition = currentPosition + direction
        guard state.layerSidebar.layers.indices.contains(targetPosition) else {
            return .none
        }
        let targetIndex = state.layerSidebar.layers[targetPosition].index
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.setActiveLayer(targetIndex)
            },
            onSuccess: { _, state in
                state.canvas.activateLayerForEditing(targetIndex)
            }
        )
    }

    func handleLayerOpacityChange(
        state: inout State,
        index: Int,
        opacity: Double
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            layerWorkflowService.setLayerOpacity(index, opacity: opacity)
        }
    }

    func handleLayerLockToggle(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        return performDocumentMutation(state: &state) {
            layerWorkflowService.setLayerLocked(index, isLocked: !layer.isLocked)
        }
    }

    func handleLayerAlphaLockToggle(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        return performDocumentMutation(state: &state) {
            layerWorkflowService.setLayerAlphaLocked(index, isAlphaLocked: !layer.isAlphaLocked)
        }
    }

    func handleLayerClippingToggle(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        guard layer.isClipped || index > 0 else {
            return .none
        }
        return performDocumentMutation(state: &state) {
            layerWorkflowService.setLayerClipped(index, isClipped: !layer.isClipped)
        }
    }

    func handleLayerSelection(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.setActiveLayer(index)
            },
            onSuccess: { _, state in
                state.canvas.activateLayerForEditing(index)
            }
        )
    }

    func handleLayerVisibilityToggle(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            layerWorkflowService.setLayerVisibility(index, visible: !layer.visible)
        }
    }

    func handleFolderExpandedChange(
        state: inout State,
        folderID: Int,
        isExpanded: Bool
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: .currentPresentation
        ) {
            layerWorkflowService.setFolderExpanded(folderID, isExpanded: isExpanded)
        }
    }

    func handleFolderVisibilityToggle(
        state: inout State,
        folderID: Int
    ) -> Effect<Action> {
        guard let folder = state.layerSidebar.folder(withID: folderID) else {
            return .none
        }
        return performDocumentMutation(state: &state) {
            layerWorkflowService.setFolderVisibility(folderID, visible: !folder.visible)
        }
    }

    func handleFolderRename(
        state: inout State,
        folderID: Int,
        name: String
    ) -> Effect<Action> {
        performDocumentMutation(state: &state) {
            layerWorkflowService.setFolderName(folderID, name: name)
        }
    }

    func handleLayerBlendModeChange(
        state: inout State,
        index: Int,
        blendMode: LayerBlendMode
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            layerWorkflowService.setLayerBlendMode(index, blendMode: blendMode)
        }
    }

    func handleLayerRename(
        state: inout State,
        index: Int,
        name: String
    ) -> Effect<Action> {
        performDocumentMutation(state: &state) {
            layerWorkflowService.setLayerName(index, name: name)
        }
    }

    func handleAddLayer(state: inout State) -> Effect<Action> {
        let namingPolicy = DocumentNamingPolicy(language: appLanguageClient.load())
        let layerName = namingPolicy.defaultLayerName(for: state.layerSidebar)
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.addLayer(named: layerName)
            },
            onSuccess: { newLayerIndex, state in
                state.canvas.activateLayerForEditing(newLayerIndex)
            }
        )
    }

    func handleAddFolder(state: inout State) -> Effect<Action> {
        let namingPolicy = DocumentNamingPolicy(language: appLanguageClient.load())
        let nextFolderNumber = state.layerSidebar.rows.reduce(into: 0) { partialResult, row in
            if case .folder = row {
                partialResult += 1
            }
        } + 1
        let folderName = namingPolicy.folderName(forOrdinal: nextFolderNumber)
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.createFolder(
                    named: folderName,
                    afterLayerAt: activeLayerIndex
                )
            }
        )
    }

    func handleFolderDeletion(
        state: inout State,
        folderID: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.deleteFolder(folderID)
            }
        )
    }

    func handleLayerDeletion(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                layerWorkflowService.deleteLayer(index)
            }
        )
    }

    func handleLayerDuplication(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        let namingPolicy = DocumentNamingPolicy(language: appLanguageClient.load())
        let duplicateName = namingPolicy.duplicatedLayerName(for: layer.name)
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                layerWorkflowService.duplicateLayer(index, named: duplicateName)
            }
        )
    }

    func handleLayerMove(
        state: inout State,
        index: Int,
        destinationIndex: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                layerWorkflowService.moveLayer(index, to: destinationIndex)
            }
        )
    }

    func handleLayerFolderAssignment(
        state: inout State,
        index: Int,
        folderID: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.assignLayer(index, toFolder: folderID)
            }
        )
    }

    func handleLayerMergeDown(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                layerWorkflowService.mergeLayerDown(index)
            }
        )
    }

    func handlePhotoImport(
        state: inout State,
        name: String?,
        data: Data
    ) -> Effect<Action> {
        guard let importedPixelData = Self.fittedLayerPixelData(
            fromImageData: data,
            canvasSize: state.canvas.canvasSize,
            gpuOperations: documentGpuOperationGateway
        ) else {
            return .send(.delegate(.documentMutationFeedback(.couldNotImportPhoto(nil))))
        }
        let namingPolicy = DocumentNamingPolicy(language: appLanguageClient.load())
        let layerName = namingPolicy.photoLayerName(
            proposedName: name,
            layerSidebar: state.layerSidebar
        )
        let appliedMutation: AppliedLayerContentMutation
        switch layerContentWorkflowService.applyPixels(
            importedPixelData,
            to: .newLayer(name: layerName)
        ) {
        case let .success(mutation):
            appliedMutation = mutation
        case let .failure(failure):
            return documentMutationFeedbackEffect(
                for: DocumentMutationFeedbackMapper().feedback(
                    for: failure,
                    default: .couldNotImportPhoto(nil)
                ) ?? .couldNotImportPhoto(nil)
            )
        }
        state.canvas.activateLayerForNewContent(appliedMutation.targetLayerIndex)
        return completeDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(successFeedback: .photoImportedToNewLayer)
        )
    }

    func handleApplyText(
        state: inout State,
        draft: TextLayerDraft
    ) -> Effect<Action> {
        let namingPolicy = DocumentNamingPolicy(language: appLanguageClient.load())
        let fontOption = state.brushPalette.text.availableFonts.first(where: { $0.postScriptName == draft.fontPostScriptName })
            ?? state.brushPalette.text.availableFonts.first
        guard let position = draft.position else { return .none }
        let uiColor = UIColor(state.brushPalette.brush.activeOpaqueColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let textLayer = TextLayerData(
            text: draft.text,
            positionX: position.x,
            positionY: position.y,
            fontPostScriptName: fontOption?.postScriptName ?? draft.fontPostScriptName ?? UIFont.systemFont(ofSize: draft.fontSize).fontName,
            fontDisplayName: fontOption?.displayName ?? draft.fontDisplayName ?? UIFont.systemFont(ofSize: draft.fontSize).fontName,
            fontSize: draft.fontSize,
            scale: draft.scale,
            rotationDegrees: draft.rotationDegrees,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )

        let target: LayerContentMutationTarget
        if let existingIndex = draft.targetLayerIndex {
            target = .existingLayer(index: existingIndex)
        } else {
            target = .newLayer(name: namingPolicy.textLayerName(from: draft.text))
        }
        let appliedMutation: AppliedLayerContentMutation
        switch layerContentWorkflowService.applyTextLayer(
            textLayer,
            to: target
        ) {
        case let .success(mutation):
            appliedMutation = mutation
        case let .failure(failure):
            return documentMutationFeedbackEffect(
                for: DocumentMutationFeedbackMapper().feedback(
                    for: failure,
                    default: .textLayerApplyFailed
                ) ?? .textLayerApplyFailed
            )
        }
        state.canvas.activateLayer(appliedMutation.targetLayerIndex)
        state.canvas.activateTool(.text)
        state.brushPalette.setTextTargetLayer(appliedMutation.targetLayerIndex)
        return completeDocumentMutation(state: &state)
    }

    func handleClearActiveLayer(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        state.canvas.activeStroke = nil
        state.canvas.strokeSession.committedPointCount = 0
        state.canvas.shapePreviewIsLive = false
        state.canvas.isStrokeActive = false
        state.canvas.isAwaitingCommittedRender = false
        state.canvas.resetStrokePreview()
        state.canvas.clearAdjustmentPreview()
        state.canvas.stagePendingCommittedSnapshot(nil)
        _ = documentStrokeSessionUseCase.execute(.cancel)
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .finalizeLayer(
                    LayerMutationFinalization(
                        index: activeLayerIndex,
                        incrementsRevision: true
                    )
                )
            ),
            mutation: {
                layerWorkflowService.clearLayer(activeLayerIndex)
            }
        )
    }

    func handleCreateLayerMask(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let maskData = Self.layerMaskData(
            from: state.canvas.selection,
            canvasSize: state.canvas.canvasSize,
            gpuOperations: documentGpuOperationGateway
        ) else {
            return .send(.delegate(.documentMutationFeedback(.createLayerMaskNeedsSelection)))
        }
        return performDocumentMutation(
            state: &state,
            failureFeedback: .createLayerMaskFailed,
            mutation: {
                layerWorkflowService.replaceLayerMask(activeLayerIndex, maskData: maskData)
            }
        )
    }

    func handleClearLayerMask(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        return performDocumentMutation(
            state: &state,
            mutation: {
                layerWorkflowService.clearLayerMask(activeLayerIndex)
            }
        )
    }

    func handleApplyLayerMask(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .finalizeLayer(
                    LayerMutationFinalization(
                        index: activeLayerIndex,
                        incrementsRevision: true
                    )
                )
            ),
            failureFeedback: .applyLayerMaskFailed,
            mutation: {
                layerWorkflowService.applyLayerMask(activeLayerIndex)
            }
        )
    }
}

extension DocumentMutationWorkflowOutcome where Selection == CanvasSelection, Feedback == ApplicationFeature.Feedback {
    var successFeedback: ApplicationFeature.Feedback? {
        guard case let .success(feedback) = feedback else { return nil }
        return feedback
    }
}
