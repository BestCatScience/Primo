import Foundation
import UIKit

extension AppFeature {
    struct LayerWorkflowService {
        let paintDocumentClient: PaintDocumentClient
    }

    var layerWorkflowService: LayerWorkflowService {
        LayerWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    func handlePhotoImport(
        state: inout State,
        name: String?,
        data: Data
    ) {
        guard let importedPixelData = Self.fittedLayerPixelData(fromImageData: data, canvasSize: state.canvas.canvasSize) else {
            state.bannerMessage = state.appLanguage.localized("Could not import photo")
            return
        }
        let nextNumber = state.layerSidebar.layers.count + 1
        let fallbackName = state.appLanguage == .japanese ? "写真 \(nextNumber)" : "Photo \(nextNumber)"
        let layerName = {
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? fallbackName : trimmed
        }()
        layerWorkflowService.paintDocumentClient.addLayer(layerName)
        let targetLayerIndex = state.layerSidebar.layers.count
        layerWorkflowService.paintDocumentClient.replaceLayerPixels(targetLayerIndex, importedPixelData)
        layerWorkflowService.paintDocumentClient.setActiveLayer(targetLayerIndex)
        state.canvas.activeLayerIndex = targetLayerIndex
        state.canvas.selection = nil
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
        applyDirtyPresentation(state: &state)
        state.bannerMessage = state.appLanguage.localized("Photo imported to a new layer")
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
            let resolvedName = (layerName?.isEmpty == false ? layerName! : (state.appLanguage == .japanese ? "テキスト" : "Text"))
            layerWorkflowService.paintDocumentClient.addLayer(resolvedName)
            targetLayerIndex = state.layerSidebar.layers.count
        }

        guard layerWorkflowService.paintDocumentClient.setTextLayer(targetLayerIndex, textLayer) else {
            state.bannerMessage = state.appLanguage.localized("テキストをレイヤーに適用できませんでした")
            return
        }
        layerWorkflowService.paintDocumentClient.setActiveLayer(targetLayerIndex)
        state.canvas.activeLayerIndex = targetLayerIndex
        state.canvas.currentTool = .text
        state.brushPalette.text.targetLayerIndex = targetLayerIndex
        applyDirtyPresentation(state: &state)
    }

    func handleClearActiveLayer(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        layerWorkflowService.paintDocumentClient.clearLayer(activeLayerIndex)
        if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == activeLayerIndex }) {
            state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
            state.canvas.localBufferRevision += 1
        }
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleCreateLayerMask(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let maskData = Self.layerMaskData(from: state.canvas.selection, canvasSize: state.canvas.canvasSize) else {
            state.bannerMessage = state.appLanguage.localized("選択範囲を作成してからマスクを追加してください")
            return
        }
        guard layerWorkflowService.paintDocumentClient.replaceLayerMask(activeLayerIndex, maskData) else {
            state.bannerMessage = state.appLanguage.localized("レイヤーマスクを作成できませんでした")
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
            state.bannerMessage = state.appLanguage.localized("レイヤーマスクを適用できませんでした")
            return
        }
        if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == activeLayerIndex }) {
            state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
            state.canvas.localBufferRevision += 1
        }
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleActiveLayerVisibilityToggle(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let layer = state.layerSidebar.layers.first(where: { $0.index == activeLayerIndex }) else {
            return
        }
        layerWorkflowService.paintDocumentClient.setLayerVisibility(activeLayerIndex, !layer.visible)
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleSelectAdjacentLayer(
        state: inout State,
        direction: Int
    ) {
        guard let currentPosition = state.layerSidebar.layers.firstIndex(where: { $0.index == state.layerSidebar.activeLayerIndex }) else {
            return
        }
        let targetPosition = currentPosition + direction
        guard state.layerSidebar.layers.indices.contains(targetPosition) else {
            return
        }
        let targetIndex = state.layerSidebar.layers[targetPosition].index
        layerWorkflowService.paintDocumentClient.setActiveLayer(targetIndex)
        state.canvas.activeLayerIndex = targetIndex
        state.canvas.selection = nil
        state.applyPresentation(paintDocumentClient.presentation())
    }

    func handleAddLayer(state: inout State) {
        layerWorkflowService.paintDocumentClient.addLayer("Layer \(state.layerSidebar.layers.count + 1)")
        state.canvas.activeLayerIndex = state.layerSidebar.layers.count
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleAddFolder(state: inout State) {
        let nextFolderNumber = state.layerSidebar.rows.reduce(into: 0) { partialResult, row in
            if case .folder = row {
                partialResult += 1
            }
        } + 1
        _ = layerWorkflowService.paintDocumentClient.createFolder(
            StudioStrings.folderName(nextFolderNumber, state.appLanguage),
            state.layerSidebar.activeLayerIndex
        )
        applyDirtyPresentation(state: &state)
    }

    func handleLayerMutation(
        state: inout State,
        clearsSelection: Bool = false,
        updatesPresentationDirectly: Bool = false,
        mutation: () -> Bool
    ) {
        guard mutation() else { return }
        if clearsSelection {
            state.canvas.selection = nil
        }
        if updatesPresentationDirectly {
            state.applyPresentation(paintDocumentClient.presentation())
        } else {
            applyDirtyPresentation(state: &state)
        }
    }

    func handleFolderDeletion(
        state: inout State,
        folderID: Int
    ) {
        handleLayerMutation(state: &state) {
            layerWorkflowService.paintDocumentClient.deleteFolder(folderID)
        }
    }

    func handleLayerDeletion(
        state: inout State,
        index: Int
    ) {
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.paintDocumentClient.deleteLayer(index)
        }
    }

    func handleLayerDuplication(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
            return
        }
        let duplicateName = state.appLanguage == .japanese ? "\(layer.name) のコピー" : "\(layer.name) Copy"
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.paintDocumentClient.duplicateLayer(index, duplicateName) >= 0
        }
    }

    func handleLayerMove(
        state: inout State,
        index: Int,
        destinationIndex: Int
    ) {
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.paintDocumentClient.moveLayer(index, destinationIndex)
        }
    }

    func handleLayerFolderAssignment(
        state: inout State,
        index: Int,
        folderID: Int
    ) {
        handleLayerMutation(state: &state) {
            layerWorkflowService.paintDocumentClient.assignLayerToFolder(index, folderID)
        }
    }

    func handleLayerMergeDown(
        state: inout State,
        index: Int
    ) {
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.paintDocumentClient.mergeLayerDown(index)
        }
    }

    func handleLayerOpacityChange(
        state: inout State,
        index: Int,
        opacity: Double
    ) {
        layerWorkflowService.paintDocumentClient.setLayerOpacity(index, opacity)
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleLayerLockToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
            return
        }
        layerWorkflowService.paintDocumentClient.setLayerLocked(index, !layer.isLocked)
        applyDirtyPresentation(state: &state)
    }

    func handleLayerAlphaLockToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
            return
        }
        layerWorkflowService.paintDocumentClient.setLayerAlphaLocked(index, !layer.isAlphaLocked)
        applyDirtyPresentation(state: &state)
    }

    func handleLayerClippingToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
            return
        }
        guard layer.isClipped || index > 0 else {
            return
        }
        layerWorkflowService.paintDocumentClient.setLayerClipped(index, !layer.isClipped)
        applyDirtyPresentation(state: &state)
    }

    func handleLayerSelection(
        state: inout State,
        index: Int
    ) {
        layerWorkflowService.paintDocumentClient.setActiveLayer(index)
        state.canvas.activeLayerIndex = index
        state.canvas.selection = nil
        state.applyPresentation(paintDocumentClient.presentation())
    }

    func handleLayerVisibilityToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
            return
        }
        layerWorkflowService.paintDocumentClient.setLayerVisibility(index, !layer.visible)
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleFolderExpandedChange(
        state: inout State,
        folderID: Int,
        isExpanded: Bool
    ) {
        layerWorkflowService.paintDocumentClient.setFolderExpanded(folderID, isExpanded)
        state.applyPresentation(paintDocumentClient.presentation())
    }

    func handleFolderVisibilityToggle(
        state: inout State,
        folderID: Int
    ) {
        guard let folder = state.layerSidebar.rows.compactMap({ row -> LayerFolderModel? in
            if case let .folder(folder) = row, folder.id == folderID {
                return folder
            }
            return nil
        }).first else {
            return
        }
        layerWorkflowService.paintDocumentClient.setFolderVisibility(folderID, !folder.visible)
        applyDirtyPresentation(state: &state)
    }

    func handleFolderRename(
        state: inout State,
        folderID: Int,
        name: String
    ) {
        layerWorkflowService.paintDocumentClient.setFolderName(folderID, name)
        applyDirtyPresentation(state: &state)
    }

    func handleLayerBlendModeChange(
        state: inout State,
        index: Int,
        blendMode: LayerBlendMode
    ) {
        layerWorkflowService.paintDocumentClient.setLayerBlendMode(index, blendMode)
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleLayerRename(
        state: inout State,
        index: Int,
        name: String
    ) {
        layerWorkflowService.paintDocumentClient.setLayerName(index, name)
        applyDirtyPresentation(state: &state)
    }
}
