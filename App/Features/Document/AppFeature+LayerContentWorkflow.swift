import Foundation
import UIKit

extension AppFeature {
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
        let targetLayerIndex = layerWorkflowService.addLayer(named: layerName)
        layerWorkflowService.replaceLayerPixels(targetLayerIndex, pixelData: importedPixelData)
        layerWorkflowService.setActiveLayer(targetLayerIndex)
        state.canvas.activateLayerForNewContent(targetLayerIndex)
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

        let targetLayerIndex: Int
        if let existingIndex = draft.targetLayerIndex {
            targetLayerIndex = existingIndex
        } else {
            let resolvedName = namingPolicy.textLayerName(from: draft.text)
            targetLayerIndex = layerWorkflowService.addLayer(named: resolvedName)
        }

        guard layerWorkflowService.setTextLayer(targetLayerIndex, textLayer: textLayer) else {
            state.application.presentFeedback(.textLayerApplyFailed)
            return
        }
        layerWorkflowService.setActiveLayer(targetLayerIndex)
        state.canvas.activateLayer(targetLayerIndex)
        state.canvas.activateTool(.text)
        state.brushPalette.setTextTargetLayer(targetLayerIndex)
        completeDocumentMutation(state: &state)
    }

    func handleClearActiveLayer(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        _ = handleDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                finalizedLayerMutation: LayerMutationFinalization(
                    index: activeLayerIndex,
                    incrementsRevision: true
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
            mutation: {
                layerWorkflowService.replaceLayerMask(activeLayerIndex, maskData: maskData)
            }
        ) else {
            state.application.presentFeedback(.createLayerMaskFailed)
            return
        }
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
                finalizedLayerMutation: LayerMutationFinalization(
                    index: activeLayerIndex,
                    incrementsRevision: true
                )
            ),
            mutation: {
                layerWorkflowService.applyLayerMask(activeLayerIndex)
            }
        ) else {
            state.application.presentFeedback(.applyLayerMaskFailed)
            return
        }
    }
}
