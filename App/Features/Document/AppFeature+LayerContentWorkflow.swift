import ComposableArchitecture
import Foundation
import UIKit

extension AppFeature {
    enum LayerContentMutationTarget {
        case existingLayer(index: Int)
        case newLayer(name: String)
    }

    struct AppliedLayerContentMutation {
        let targetLayerIndex: Int
    }

    struct LayerContentTransactionService {
        let documentQueryGateway: DocumentQueryGateway
        let documentMutationGateway: DocumentMutationGateway

        func apply(
            target: LayerContentMutationTarget,
            mutation: (Int) -> DocumentMutationResult
        ) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> {
            let resolvedTarget: (index: Int, createdNewLayer: Bool, originalActiveLayerIndex: Int)
            switch resolve(target) {
            case let .failure(failure):
                return .failure(failure)
            case let .success(target):
                resolvedTarget = target
            }
            switch mutation(resolvedTarget.index) {
            case let .failure(failure):
                if let rollbackFailure = rollbackResolvedTargetIfNeeded(resolvedTarget) {
                    return .failure(
                        .transactionFailure(
                            primary: failure,
                            rollback: rollbackFailure
                        )
                    )
                }
                return .failure(failure)
            case .success:
                return .success(
                    AppliedLayerContentMutation(
                        targetLayerIndex: resolvedTarget.index
                    )
                )
            }
        }

        private func resolve(
            _ target: LayerContentMutationTarget
        ) -> Result<(index: Int, createdNewLayer: Bool, originalActiveLayerIndex: Int), DocumentMutationFailure> {
            let originalActiveLayerIndex = documentQueryGateway.lightweightPresentation().activeLayerIndex
            switch target {
            case let .existingLayer(index):
                return .success((index, false, originalActiveLayerIndex))
            case let .newLayer(name):
                switch documentMutationGateway.addLayer(name) {
                case let .success(index):
                    return .success((index, true, originalActiveLayerIndex))
                case let .failure(failure):
                    return .failure(failure)
                }
            }
        }

        private func rollbackResolvedTargetIfNeeded(
            _ resolvedTarget: (index: Int, createdNewLayer: Bool, originalActiveLayerIndex: Int)
        ) -> DocumentMutationFailure? {
            var rollbackFailure: DocumentMutationFailure?
            if resolvedTarget.createdNewLayer, resolvedTarget.index >= 0 {
                switch documentMutationGateway.deleteLayer(resolvedTarget.index) {
                case .success:
                    break
                case let .failure(failure):
                    rollbackFailure = failure
                }
            }
            switch documentMutationGateway.setActiveLayer(resolvedTarget.originalActiveLayerIndex) {
            case .success:
                break
            case let .failure(failure):
                if let rollbackFailure {
                    return .transactionFailure(
                        primary: rollbackFailure,
                        rollback: failure
                    )
                }
                return failure
            }
            return rollbackFailure
        }
    }

    struct LayerContentWorkflowService {
        let documentMutationGateway: DocumentMutationGateway
        let textLayerGateway: TextLayerGateway
        let layerContentTransactionService: LayerContentTransactionService

        func applyPixels(
            _ pixelData: Data,
            to target: LayerContentMutationTarget
        ) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> {
            layerContentTransactionService.apply(target: target) { targetLayerIndex in
                switch documentMutationGateway.replaceLayerPixels(targetLayerIndex, pixelData) {
                case let .failure(failure):
                    return .failure(failure)
                case .success:
                    return documentMutationGateway.setActiveLayer(targetLayerIndex)
                }
            }
        }

        func applyTextLayer(
            _ textLayer: TextLayerData,
            to target: LayerContentMutationTarget
        ) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> {
            layerContentTransactionService.apply(target: target) { targetLayerIndex in
                switch textLayerGateway.setTextLayer(targetLayerIndex, textLayer) {
                case let .failure(failure):
                    return .failure(failure)
                case .success:
                    return documentMutationGateway.setActiveLayer(targetLayerIndex)
                }
            }
        }
    }

    var layerContentTransactionService: LayerContentTransactionService {
        LayerContentTransactionService(
            documentQueryGateway: documentQueryGateway,
            documentMutationGateway: documentMutationGateway
        )
    }

    var layerContentWorkflowService: LayerContentWorkflowService {
        LayerContentWorkflowService(
            documentMutationGateway: documentMutationGateway,
            textLayerGateway: textLayerGateway,
            layerContentTransactionService: layerContentTransactionService
        )
    }

    func handlePhotoImport(
        state: inout State,
        name: String?,
        data: Data
    ) -> Effect<Action> {
        guard let importedPixelData = Self.fittedLayerPixelData(fromImageData: data, canvasSize: state.canvas.canvasSize) else {
            state.application.presentFeedback(.couldNotImportPhoto(nil))
            return .none
        }
        let namingPolicy = namingPolicy(for: state)
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
            state.application.presentFeedback(
                documentMutationFeedbackMapper.feedback(
                    for: failure,
                    default: .couldNotImportPhoto(nil)
                ) ?? .couldNotImportPhoto(nil)
            )
            return .none
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
        let namingPolicy = namingPolicy(for: state)
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
            state.application.presentFeedback(
                documentMutationFeedbackMapper.feedback(
                    for: failure,
                    default: .textLayerApplyFailed
                ) ?? .textLayerApplyFailed
            )
            return .none
        }
        state.canvas.activateLayer(appliedMutation.targetLayerIndex)
        state.canvas.activateTool(.text)
        state.brushPalette.setTextTargetLayer(appliedMutation.targetLayerIndex)
        return completeDocumentMutation(state: &state)
    }

    func handleClearActiveLayer(state: inout State) -> Effect<Action> {
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
            mutation: {
                layerWorkflowService.clearLayer(activeLayerIndex)
            }
        )
    }

    func handleCreateLayerMask(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let maskData = Self.layerMaskData(from: state.canvas.selection, canvasSize: state.canvas.canvasSize) else {
            state.application.presentFeedback(.createLayerMaskNeedsSelection)
            return .none
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
