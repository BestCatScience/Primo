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

    struct LayerContentWorkflowService {
        enum MutationFailure: Error, Equatable {
            case replacePixelsFailed(Int)
            case setTextLayerFailed(Int)
            case setActiveLayerFailed(Int)
        }

        let paintDocumentClient: PaintDocumentClient

        func applyPixels(
            _ pixelData: Data,
            to target: LayerContentMutationTarget
        ) -> Result<AppliedLayerContentMutation, MutationFailure> {
            apply(target: target) { targetLayerIndex in
                guard paintDocumentClient.replaceLayerPixels(targetLayerIndex, pixelData) else {
                    return .failure(.replacePixelsFailed(targetLayerIndex))
                }
                guard paintDocumentClient.setActiveLayer(targetLayerIndex) else {
                    return .failure(.setActiveLayerFailed(targetLayerIndex))
                }
                return .success(())
            }
        }

        func applyTextLayer(
            _ textLayer: TextLayerData,
            to target: LayerContentMutationTarget
        ) -> Result<AppliedLayerContentMutation, MutationFailure> {
            apply(target: target) { targetLayerIndex in
                guard paintDocumentClient.setTextLayer(targetLayerIndex, textLayer) else {
                    return .failure(.setTextLayerFailed(targetLayerIndex))
                }
                guard paintDocumentClient.setActiveLayer(targetLayerIndex) else {
                    return .failure(.setActiveLayerFailed(targetLayerIndex))
                }
                return .success(())
            }
        }

        private func apply(
            target: LayerContentMutationTarget,
            mutation: (Int) -> Result<Void, MutationFailure>
        ) -> Result<AppliedLayerContentMutation, MutationFailure> {
            let resolvedTarget = resolve(target)
            switch mutation(resolvedTarget.index) {
            case let .failure(failure):
                rollbackResolvedTargetIfNeeded(resolvedTarget)
                return .failure(failure)
            case .success:
                break
            }
            return .success(AppliedLayerContentMutation(targetLayerIndex: resolvedTarget.index))
        }

        private func resolve(_ target: LayerContentMutationTarget) -> (index: Int, createdNewLayer: Bool) {
            switch target {
            case let .existingLayer(index):
                return (index, false)
            case let .newLayer(name):
                return (paintDocumentClient.addLayer(name), true)
            }
        }

        private func rollbackResolvedTargetIfNeeded(_ resolvedTarget: (index: Int, createdNewLayer: Bool)) {
            guard resolvedTarget.createdNewLayer else { return }
            _ = paintDocumentClient.deleteLayer(resolvedTarget.index)
        }
    }

    var layerContentWorkflowService: LayerContentWorkflowService {
        LayerContentWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    func handlePhotoImport(
        state: inout State,
        name: String?,
        data: Data
    ) {
        guard let importedPixelData = Self.fittedLayerPixelData(fromImageData: data, canvasSize: state.canvas.canvasSize) else {
            state.application.presentFeedback(.couldNotImportPhoto(nil))
            return
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
        case .failure:
            state.application.presentFeedback(.couldNotImportPhoto(nil))
            return
        }
        state.canvas.activateLayerForNewContent(appliedMutation.targetLayerIndex)
        completeDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(successFeedback: .photoImportedToNewLayer)
        )
    }

    func handleApplyText(
        state: inout State,
        draft: TextLayerDraft
    ) {
        let namingPolicy = namingPolicy(for: state)
        let fontOption = state.brushPalette.text.availableFonts.first(where: { $0.postScriptName == draft.fontPostScriptName })
            ?? state.brushPalette.text.availableFonts.first
        guard let position = draft.position else { return }
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
        case .failure:
            state.application.presentFeedback(.textLayerApplyFailed)
            return
        }
        state.canvas.activateLayer(appliedMutation.targetLayerIndex)
        state.canvas.activateTool(.text)
        state.brushPalette.setTextTargetLayer(appliedMutation.targetLayerIndex)
        completeDocumentMutation(state: &state)
    }

    func handleClearActiveLayer(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        _ = handleDocumentMutation(
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

    func handleCreateLayerMask(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let maskData = Self.layerMaskData(from: state.canvas.selection, canvasSize: state.canvas.canvasSize) else {
            state.application.presentFeedback(.createLayerMaskNeedsSelection)
            return
        }
        guard handleDocumentMutation(
            state: &state,
            failureFeedback: .createLayerMaskFailed,
            mutation: {
                layerWorkflowService.replaceLayerMask(activeLayerIndex, maskData: maskData)
            }
        ) else { return }
    }

    func handleClearLayerMask(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        _ = handleDocumentMutation(
            state: &state,
            mutation: {
                layerWorkflowService.clearLayerMask(activeLayerIndex)
            }
        )
    }

    func handleApplyLayerMask(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard handleDocumentMutation(
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
        ) else { return }
    }
}
