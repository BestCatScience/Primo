import Foundation
import ComposableArchitecture
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
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

extension LayerWorkflowReducer {
    var layerWorkflowService: LayerWorkflowService {
        documentMutationWorkflowService
    }

    var layerContentWorkflowService: LayerContentWorkflowService {
        documentContentService
    }

    private var commandValidator: DocumentWorkflowCommandValidator {
        DocumentWorkflowCommandValidator()
    }

    private func existingLayer(
        _ index: Int,
        in state: State
    ) -> Result<ExistingLayerIndex, DocumentMutationFailure> {
        commandValidator.existingLayerIndex(index, in: state)
    }

    private func editableLayer(
        _ index: Int,
        in state: State
    ) -> Result<EditableLayerIndex, DocumentMutationFailure> {
        commandValidator.editableLayerIndex(index, in: state)
    }

    private func existingFolder(
        _ folderID: Int,
        in state: State
    ) -> Result<ExistingFolderID, DocumentMutationFailure> {
        commandValidator.existingFolderID(folderID, in: state)
    }

    func handleActiveLayerVisibilityToggle(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let layer = state.layerSidebar.layer(withIndex: activeLayerIndex) else {
            return .none
        }
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            existingLayer(activeLayerIndex, in: validationState).flatMap {
                layerWorkflowService.setLayerVisibility($0, visible: !layer.visible)
            }
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
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                existingLayer(targetIndex, in: validationState).flatMap {
                    layerWorkflowService.setActiveLayer($0)
                }
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
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            existingLayer(index, in: validationState).flatMap { layerIndex in
                commandValidator.unitInterval(opacity).flatMap { typedOpacity in
                    layerWorkflowService.setLayerOpacity(layerIndex, opacity: typedOpacity)
                }
            }
        }
    }

    func handleLayerLockToggle(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        let validationState = state
        return performDocumentMutation(state: &state) {
            existingLayer(index, in: validationState).flatMap {
                layerWorkflowService.setLayerLocked($0, isLocked: !layer.isLocked)
            }
        }
    }

    func handleLayerAlphaLockToggle(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        let validationState = state
        return performDocumentMutation(state: &state) {
            existingLayer(index, in: validationState).flatMap {
                layerWorkflowService.setLayerAlphaLocked($0, isAlphaLocked: !layer.isAlphaLocked)
            }
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
        let validationState = state
        return performDocumentMutation(state: &state) {
            existingLayer(index, in: validationState).flatMap {
                layerWorkflowService.setLayerClipped($0, isClipped: !layer.isClipped)
            }
        }
    }

    func handleLayerSelection(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                existingLayer(index, in: validationState).flatMap {
                    layerWorkflowService.setActiveLayer($0)
                }
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
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            existingLayer(index, in: validationState).flatMap {
                layerWorkflowService.setLayerVisibility($0, visible: !layer.visible)
            }
        }
    }

    func handleFolderExpandedChange(
        state: inout State,
        folderID: Int,
        isExpanded: Bool
    ) -> Effect<Action> {
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation
        ) {
            existingFolder(folderID, in: validationState).flatMap {
                layerWorkflowService.setFolderExpanded($0, isExpanded: isExpanded)
            }
        }
    }

    func handleFolderVisibilityToggle(
        state: inout State,
        folderID: Int
    ) -> Effect<Action> {
        guard let folder = state.layerSidebar.folder(withID: folderID) else {
            return .none
        }
        let validationState = state
        return performDocumentMutation(state: &state) {
            existingFolder(folderID, in: validationState).flatMap {
                layerWorkflowService.setFolderVisibility($0, visible: !folder.visible)
            }
        }
    }

    func handleFolderRename(
        state: inout State,
        folderID: Int,
        name: String
    ) -> Effect<Action> {
        let validationState = state
        return performDocumentMutation(state: &state) {
            existingFolder(folderID, in: validationState).flatMap {
                layerWorkflowService.setFolderName($0, name: name)
            }
        }
    }

    func handleLayerBlendModeChange(
        state: inout State,
        index: Int,
        blendMode: LayerBlendMode
    ) -> Effect<Action> {
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            existingLayer(index, in: validationState).flatMap {
                layerWorkflowService.setLayerBlendMode($0, blendMode: blendMode)
            }
        }
    }

    func handleLayerRename(
        state: inout State,
        index: Int,
        name: String
    ) -> Effect<Action> {
        let validationState = state
        return performDocumentMutation(state: &state) {
            existingLayer(index, in: validationState).flatMap {
                layerWorkflowService.setLayerName($0, name: name)
            }
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
                state.canvas.activateLayerForEditing(newLayerIndex.rawValue)
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
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                commandValidator.layerAnchorIndex(activeLayerIndex, in: validationState).flatMap {
                    layerWorkflowService.createFolder(
                        named: folderName,
                        afterLayerAt: $0
                    )
                }
            }
        )
    }

    func handleFolderDeletion(
        state: inout State,
        folderID: Int
    ) -> Effect<Action> {
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                existingFolder(folderID, in: validationState).flatMap {
                    layerWorkflowService.deleteFolder($0)
                }
            }
        )
    }

    func handleLayerDeletion(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                existingLayer(index, in: validationState).flatMap {
                    layerWorkflowService.deleteLayer($0)
                }
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
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                existingLayer(index, in: validationState).flatMap {
                    layerWorkflowService.duplicateLayer($0, named: duplicateName)
                }
            }
        )
    }

    func handleLayerMove(
        state: inout State,
        index: Int,
        destinationIndex: Int
    ) -> Effect<Action> {
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                existingLayer(index, in: validationState).flatMap { layerIndex in
                    existingLayer(destinationIndex, in: validationState).flatMap { destinationLayerIndex in
                        layerWorkflowService.moveLayer(layerIndex, to: destinationLayerIndex)
                    }
                }
            }
        )
    }

    func handleLayerFolderAssignment(
        state: inout State,
        index: Int,
        folderID: Int?
    ) -> Effect<Action> {
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                existingLayer(index, in: validationState).flatMap { layerIndex in
                    commandValidator.existingFolderID(folderID, in: validationState).flatMap { typedFolderID in
                        layerWorkflowService.assignLayer(layerIndex, toFolder: typedFolderID)
                    }
                }
            }
        )
    }

    func handleLayerMergeDown(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        let validationState = state
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                existingLayer(index, in: validationState).flatMap {
                    layerWorkflowService.mergeLayerDown($0)
                }
            }
        )
    }

    func handlePhotoImport(
        state: inout State,
        name: String?,
        data: Data
    ) -> Effect<Action> {
        guard let importedPixelData = DocumentFeature.fittedLayerPixelData(
            fromImageData: data,
            canvasSize: state.canvas.canvasSize,
            gpuOperations: documentRenderingWorkflow
        ) else {
            return .send(.delegate(.documentMutationFeedback(.couldNotImportPhoto(nil))))
        }
        let namingPolicy = DocumentNamingPolicy(language: appLanguageClient.load())
        let layerName = namingPolicy.photoLayerName(
            proposedName: name,
            layerSidebar: state.layerSidebar
        )
        let appliedMutation: AppliedLayerContentMutation
        guard
            let geometry = PixelGeometry(
                width: Int(state.canvas.canvasSize.width.rounded()),
                height: Int(state.canvas.canvasSize.height.rounded())
            ),
            let importedLayerPixels = LayerPixelData(
                width: geometry.width,
                height: geometry.height,
                rgba: importedPixelData
            )
        else {
            return .send(.delegate(.documentMutationFeedback(.couldNotImportPhoto(nil))))
        }
        switch layerContentWorkflowService.applyPixels(
            importedLayerPixels,
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
        guard let textLayer = TextLayerData(
            validatingText: draft.text,
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
        ) else {
            return documentMutationFeedbackEffect(for: .textLayerApplyFailed)
        }

        let target: LayerContentMutationTarget
        if let existingIndex = draft.targetLayerIndex {
            switch editableLayer(existingIndex, in: state) {
            case let .success(index):
                target = .existingLayer(index: index)
            case .failure:
                return documentMutationFeedbackEffect(for: .textLayerApplyFailed)
            }
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
        state.canvas.strokeSession.resetCommittedPointCount()
        state.canvas.shapePreviewIsLive = false
        state.canvas.isStrokeActive = false
        state.canvas.isAwaitingCommittedRender = false
        state.canvas.resetStrokePreview()
        state.canvas.clearAdjustmentPreview()
        state.canvas.stagePendingCommittedSnapshot(nil)
        _ = canvasStrokeInteractionService.cancel()
        let validationState = state
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
                editableLayer(activeLayerIndex, in: validationState).flatMap {
                    layerWorkflowService.clearLayer($0)
                }
            }
        )
    }

    func handleCreateLayerMask(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        let canvasGeometry = state.canvas.renderSnapshot
            .flatMap { PixelGeometry(width: $0.width, height: $0.height) }
            ?? PixelGeometry(
                width: max(Int(state.canvas.canvasSize.width.rounded()), 1),
                height: max(Int(state.canvas.canvasSize.height.rounded()), 1)
            )
        guard let canvasGeometry else {
            return .send(.delegate(.documentMutationFeedback(.createLayerMaskNeedsSelection)))
        }
        guard let maskData = DocumentFeature.layerMaskData(
            from: state.canvas.selection,
            canvasGeometry: canvasGeometry,
            selectionWorkflow: selectionWorkflowService
        ) else {
            return .send(.delegate(.documentMutationFeedback(.createLayerMaskNeedsSelection)))
        }
        let validationState = state
        return performDocumentMutation(
            state: &state,
            failureFeedback: .createLayerMaskFailed,
            mutation: { () -> DocumentMutationResult in
                editableLayer(activeLayerIndex, in: validationState).flatMap { layerIndex in
                    let width = canvasGeometry.width
                    let height = canvasGeometry.height
                    guard let typedMaskData = LayerMaskData(width: width, height: height, bytes: maskData) else {
                        return .failure(.gpu(.invalidPayloadSize(operation: "replaceLayerMask", expected: width * height, actual: maskData.count)))
                    }
                    return layerWorkflowService.replaceLayerMask(layerIndex, mask: typedMaskData)
                }
            }
        )
    }

    func handleClearLayerMask(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        let validationState = state
        return performDocumentMutation(
            state: &state,
            mutation: {
                editableLayer(activeLayerIndex, in: validationState).flatMap {
                    layerWorkflowService.clearLayerMask($0)
                }
            }
        )
    }

    func handleApplyLayerMask(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        let validationState = state
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
                editableLayer(activeLayerIndex, in: validationState).flatMap {
                    layerWorkflowService.applyLayerMask($0)
                }
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
