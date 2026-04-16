import Foundation
import UIKit

extension AppFeature {
    func handlePhotoImport(
        state: inout State,
        name: String?,
        data: Data
    ) {
        guard let importedPixelData = Self.fittedLayerPixelData(fromImageData: data, canvasSize: state.canvas.canvasSize) else {
            state.application.presentBanner(state.application.appLanguage.localized("Could not import photo"))
            return
        }
        let nextNumber = state.layerSidebar.layers.count + 1
        let fallbackName = state.application.appLanguage == .japanese ? "写真 \(nextNumber)" : "Photo \(nextNumber)"
        let layerName = {
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? fallbackName : trimmed
        }()
        layerWorkflowService.paintDocumentClient.addLayer(layerName)
        let targetLayerIndex = state.layerSidebar.layers.count
        layerWorkflowService.paintDocumentClient.replaceLayerPixels(targetLayerIndex, importedPixelData)
        layerWorkflowService.paintDocumentClient.setActiveLayer(targetLayerIndex)
        state.canvas.activateLayer(targetLayerIndex)
        state.canvas.clearSelectionState()
        applyDirtyPresentation(state: &state)
        state.application.presentBanner(state.application.appLanguage.localized("Photo imported to a new layer"))
    }

    func handleApplyText(
        state: inout State,
        draft: TextLayerDraft
    ) {
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
            let layerName = draft.text
                .components(separatedBy: CharacterSet.newlines)
                .first?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let resolvedName = (
                layerName?.isEmpty == false
                ? layerName!
                : (state.application.appLanguage == .japanese ? "テキスト" : "Text")
            )
            layerWorkflowService.paintDocumentClient.addLayer(resolvedName)
            targetLayerIndex = state.layerSidebar.layers.count
        }

        guard layerWorkflowService.paintDocumentClient.setTextLayer(targetLayerIndex, textLayer) else {
            state.application.presentBanner(state.application.appLanguage.localized("テキストをレイヤーに適用できませんでした"))
            return
        }
        layerWorkflowService.paintDocumentClient.setActiveLayer(targetLayerIndex)
        state.canvas.activateLayer(targetLayerIndex)
        state.canvas.activateTool(.text)
        state.brushPalette.text.targetLayerIndex = targetLayerIndex
        applyDirtyPresentation(state: &state)
    }

    func handleClearActiveLayer(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        layerWorkflowService.paintDocumentClient.clearLayer(activeLayerIndex)
        state.canvas.discardBufferedStrokes(for: activeLayerIndex, incrementsRevision: true)
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }

    func handleCreateLayerMask(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let maskData = Self.layerMaskData(from: state.canvas.selection, canvasSize: state.canvas.canvasSize) else {
            state.application.presentBanner(state.application.appLanguage.localized("選択範囲を作成してからマスクを追加してください"))
            return
        }
        guard layerWorkflowService.paintDocumentClient.replaceLayerMask(activeLayerIndex, maskData) else {
            state.application.presentBanner(state.application.appLanguage.localized("レイヤーマスクを作成できませんでした"))
            return
        }
        applyDirtyPresentation(state: &state)
    }

    func handleClearLayerMask(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard layerWorkflowService.paintDocumentClient.clearLayerMask(activeLayerIndex) else {
            return
        }
        applyDirtyPresentation(state: &state)
    }

    func handleApplyLayerMask(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard layerWorkflowService.paintDocumentClient.applyLayerMask(activeLayerIndex) else {
            state.application.presentBanner(state.application.appLanguage.localized("レイヤーマスクを適用できませんでした"))
            return
        }
        state.canvas.discardBufferedStrokes(for: activeLayerIndex, incrementsRevision: true)
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }
}
