import ComposableArchitecture
import Foundation
import UIKit

extension AppFeature {
    private struct DocumentWorkflowCoordinator {
        let paintDocumentClient: PaintDocumentClient
        let documentWorkspaceClient: DocumentWorkspaceClient
        let fileClient: FileClient
        let dateClient: DateClient

        func loadSaveHistoryEffect(for activeTab: OpenDocumentTab) -> Effect<Action> {
            .run { [documentWorkspaceClient] send in
                let entries = (try? documentWorkspaceClient.loadSaveHistoryEntries(activeTab)) ?? []
                await send(.saveHistoryLoaded(entries))
            }
        }

        func restoreSaveHistoryEffect(projectURL: DocumentProjectPath, openInNewTab: Bool) -> Effect<Action> {
            .run { [paintDocumentClient] send in
                do {
                    let loaded = try paintDocumentClient.loadProject(projectURL.fileURL)
                    await send(.saveHistoryOpened(loaded, projectURL, openInNewTab))
                } catch {
                    await send(.openDocumentFailed(error.localizedDescription))
                }
            }
        }

        func makeTimelapseExportEffect(
            capture: TimelapseCapture,
            failureMessage: String
        ) -> Effect<Action> {
            .run { [documentWorkspaceClient, fileClient, dateClient] send in
                do {
                    let url = try TimelapseExporter.exportVideo(
                        from: capture,
                        to: documentWorkspaceClient.timelapseTemporaryDirectory(),
                        fileClient: fileClient,
                        dateClient: dateClient
                    ) { progress, previewURL in
                        let previewData = try? fileClient.readData(previewURL)
                        Task {
                            await send(.timelapseExportProgressUpdated(progress, previewData))
                        }
                    }
                    await send(.timelapseExportSucceeded(url))
                } catch {
                    await send(.timelapseExportFailed(failureMessage))
                }
            }
            .cancellable(id: CancelID.timelapseExport, cancelInFlight: true)
        }
    }

    private var documentWorkflowCoordinator: DocumentWorkflowCoordinator {
        DocumentWorkflowCoordinator(
            paintDocumentClient: paintDocumentClient,
            documentWorkspaceClient: documentWorkspaceClient,
            fileClient: fileClient,
            dateClient: dateClient
        )
    }

    func handleSaveHistoryRequest(state: inout State) -> Effect<Action> {
        guard let activeTab = state.activeTab else { return .none }
        state.isShowingSaveHistory = true
        return documentWorkflowCoordinator.loadSaveHistoryEffect(for: activeTab)
    }

    func handleSaveHistoryRestoreRequest(
        state: inout State,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool
    ) -> Effect<Action> {
        if !state.showsHome {
            persistActiveTabToBackingStore(state: &state)
        }
        state.isHydrating = true
        return documentWorkflowCoordinator.restoreSaveHistoryEffect(
            projectURL: projectURL,
            openInNewTab: openInNewTab
        )
    }

    func handleSaveHistoryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool
    ) {
        let restoredTitle = projectURL.displayName
        if openInNewTab || state.activeTab == nil {
            state.applyLoadedProject(loaded)
            activateNewTab(
                state: &state,
                title: "\(restoredTitle) Snapshot",
                sourceProjectURL: nil
            )
        } else {
            let existingSourceURL = state.activeTab?.sourceProjectURL
            let existingTitle = state.activeTab?.title ?? restoredTitle
            state.applyLoadedProject(loaded)
            state.updateActiveTabMetadata(
                title: existingTitle,
                sourceProjectURL: existingSourceURL,
                previewImageData: paintDocumentClient.compositePNGData(state.resolvedPaperStyle())
            )
        }
        state.setActiveTabDirty(true)
        persistActiveTabToBackingStore(state: &state)
        persistActiveTabAutosave(state: &state)
        state.isHydrating = false
        state.showsHome = false
        state.isShowingSaveHistory = false
        state.bannerMessage = state.appLanguage.localized("保存履歴を復元しました")
    }

    func handleSaveDocumentRequest(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?
    ) -> Effect<Action> {
        guard let savedURL = persistActiveProjectToWorkspace(
            state: &state,
            preferredDestinationURL: preferredDestinationURL
        ) else {
            return .none
        }
        state.bannerMessage = StudioStrings.savedDocument(savedURL.fileURL.lastPathComponent, state.appLanguage)
        if let activeTab = state.activeTab {
            persistSaveHistorySnapshot(for: activeTab, trigger: .manualSave)
        }
        return .send(.homeProjectsLoadRequested)
    }

    func handleTimelapseExportRequest(state: inout State) -> Effect<Action> {
        guard let capture = paintDocumentClient.timelapseCapture() else {
            state.bannerMessage = state.appLanguage.localized("Not enough drawing history for timelapse yet")
            return .none
        }
        state.timelapseExportPreview = TimelapseExportPreview(
            progress: 0,
            previewImageData: capture.previewImageData
        )
        return documentWorkflowCoordinator.makeTimelapseExportEffect(
            capture: capture,
            failureMessage: state.appLanguage.localized("Timelapse export failed")
        )
    }

    private struct WorkspaceTabCoordinator {
        let paintDocumentClient: PaintDocumentClient
        let documentWorkspaceClient: DocumentWorkspaceClient

        func loadAutosaveRecoveryEffect() -> Effect<Action> {
            .run { [documentWorkspaceClient] send in
                let items = (try? documentWorkspaceClient.loadAutosaveRecoveryItems()) ?? []
                await send(.autosaveRecoveryLoaded(items))
            }
        }

        func restoreAutosaveEffect(item: AutosaveRecoveryItem) -> Effect<Action> {
            .run { [paintDocumentClient] send in
                do {
                    let loaded = try paintDocumentClient.loadProject(item.autosaveProjectURL.fileURL)
                    await send(.autosaveRecoveryOpened(loaded, item))
                } catch {
                    await send(.openDocumentFailed(error.localizedDescription))
                }
            }
        }

        func openProjectEffect(
            at url: DocumentProjectPath,
            removeWorkspaceItemAfterLoad: Bool
        ) -> Effect<Action> {
            .run { [paintDocumentClient, documentWorkspaceClient] send in
                do {
                    let loaded = try paintDocumentClient.loadProject(url.fileURL)
                    await send(.openDocumentLoaded(loaded, url))
                } catch {
                    await send(.openDocumentFailed(error.localizedDescription))
                }
                guard removeWorkspaceItemAfterLoad else { return }
                try? documentWorkspaceClient.removeWorkspaceItem(url)
            }
        }
    }

    private var workspaceTabCoordinator: WorkspaceTabCoordinator {
        WorkspaceTabCoordinator(
            paintDocumentClient: paintDocumentClient,
            documentWorkspaceClient: documentWorkspaceClient
        )
    }

    func handleAutosaveRecoveryLoadRequest() -> Effect<Action> {
        workspaceTabCoordinator.loadAutosaveRecoveryEffect()
    }

    func handleAutosaveRecoveryRestoreRequest(
        state: inout State,
        autosaveID: WorkspaceItemID
    ) -> Effect<Action> {
        guard let item = state.autosaveRecoveryItems.first(where: { $0.id == autosaveID }) else {
            return .none
        }
        if !state.showsHome {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        state.isHydrating = true
        state.isShowingAutosaveRecovery = false
        return workspaceTabCoordinator.restoreAutosaveEffect(item: item)
    }

    func handleAutosaveRecoveryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        item: AutosaveRecoveryItem
    ) {
        try? documentWorkspaceClient.discardAutosaveEntry(item.id)
        state.applyLoadedProject(loaded)
        activateNewTab(
            state: &state,
            title: item.title,
            sourceProjectURL: item.sourceProjectURL
        )
        state.setActiveTabDirty(true)
        _ = persistActiveTabToBackingStore(state: &state)
        persistActiveTabAutosave(state: &state)
        state.isHydrating = false
        state.showsHome = false
        state.autosaveRecoveryItems.removeAll { $0.id == item.id }
        state.isShowingAutosaveRecovery = false
        state.bannerMessage = state.appLanguage.localized("自動保存から復元しました")
    }

    func handleAutosaveRecoveryDiscardRequest(
        state: inout State,
        autosaveID: WorkspaceItemID
    ) {
        state.autosaveRecoveryItems.removeAll { $0.id == autosaveID }
        state.isShowingAutosaveRecovery = !state.autosaveRecoveryItems.isEmpty
        try? documentWorkspaceClient.discardAutosaveEntry(autosaveID)
    }

    func handleTabSelection(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let targetTab = state.openTabs.first(where: { $0.id == tabID }) else {
            return
        }
        if !state.showsHome, state.activeTabID != tabID {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        do {
            let loaded = try paintDocumentClient.loadProject(targetTab.backingStoreURL.fileURL)
            state.activeTabID = tabID
            state.setSelectedTabID(tabID, for: targetTab.pane)
            state.focusedWorkspacePane = targetTab.pane
            state.applyLoadedProject(loaded)
            state.showsHome = false
        } catch {
            state.bannerMessage = error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.appLanguage) : error.localizedDescription
        }
    }

    func handleTabClosed(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let closingIndex = state.openTabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }
        let closingTab = state.openTabs[closingIndex]
        let wasActive = state.activeTabID == tabID
        state.openTabs.remove(at: closingIndex)
        clearAutosave(for: closingTab)
        try? documentWorkspaceClient.removeWorkspaceItem(closingTab.backingStoreURL)
        state.ensureWorkspaceSelectionIntegrity()

        guard wasActive else { return }
        let replacement = state.selectedTab(in: closingTab.pane)
            ?? state.selectedTab(in: closingTab.pane == .primary ? .secondary : .primary)
        guard let replacement else {
            state.activeTabID = nil
            state.showsHome = true
            return
        }

        do {
            let loaded = try paintDocumentClient.loadProject(replacement.backingStoreURL.fileURL)
            state.activeTabID = replacement.id
            state.focusedWorkspacePane = replacement.pane
            state.applyLoadedProject(loaded)
            state.showsHome = false
        } catch {
            state.activeTabID = nil
            state.showsHome = true
            state.bannerMessage = error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.appLanguage) : error.localizedDescription
        }
    }

    func handleCloseOtherTabs(
        state: inout State,
        retaining tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let retainedTabs = state.openTabs.filter { $0.id == tabID }
        let removedTabs = state.openTabs.filter { $0.id != tabID }
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? documentWorkspaceClient.removeWorkspaceItem($0.backingStoreURL)
        }
        state.openTabs = retainedTabs
        state.primarySelectedTabID = retainedTabs.first(where: { $0.pane == .primary })?.id
        state.secondarySelectedTabID = retainedTabs.first(where: { $0.pane == .secondary })?.id
        if state.activeTabID != tabID {
            return .send(.tabSelected(tabID))
        }
        state.ensureWorkspaceSelectionIntegrity()
        return .none
    }

    func handleCloseTabsToRight(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let tabIndex = state.openTabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = state.openTabs[tabIndex]
        let paneTabs = state.openTabs.enumerated().filter { $0.element.pane == tab.pane }
        guard let paneIndex = paneTabs.firstIndex(where: { $0.element.id == tabID }) else { return }
        let idsToRemove = Set(paneTabs.dropFirst(paneIndex + 1).map(\.element.id))
        let removedTabs = state.openTabs.filter { idsToRemove.contains($0.id) }
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? documentWorkspaceClient.removeWorkspaceItem($0.backingStoreURL)
        }
        state.openTabs.removeAll { idsToRemove.contains($0.id) }
        state.ensureWorkspaceSelectionIntegrity()
    }

    func handleSavedProjectMove(
        state: inout State,
        url: DocumentProjectPath,
        relativeFolderPath: RelativeProjectFolderPath?
    ) -> Effect<Action> {
        do {
            let destinationURL = try documentWorkspaceClient.moveSavedProject(url, relativeFolderPath)
            if let openTabIndex = state.openTabs.firstIndex(where: { $0.sourceProjectURL == url }) {
                state.openTabs[openTabIndex].sourceProjectURL = destinationURL
            }
            return .send(.homeProjectsLoadRequested)
        } catch {
            state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Move failed") : error.localizedDescription
            return .none
        }
    }

    func handleOpenDocumentSelection(
        state: inout State,
        url: DocumentProjectPath,
        removesStagedWorkspaceItem: Bool
    ) -> Effect<Action> {
        if let existingTabID = state.tabID(forSourceProjectURL: url) {
            state.showsHome = false
            state.isHydrating = false
            return .send(.tabSelected(existingTabID))
        }
        if !state.showsHome {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        state.isHydrating = true
        return workspaceTabCoordinator.openProjectEffect(
            at: url,
            removeWorkspaceItemAfterLoad: removesStagedWorkspaceItem
        )
    }

    func handleOpenDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        sourceURL: DocumentProjectPath
    ) -> Effect<Action> {
        if let existingTabID = state.tabID(forSourceProjectURL: sourceURL) {
            state.activeTabID = existingTabID
            state.isHydrating = false
            state.showsHome = false
            return .send(.tabSelected(existingTabID))
        }
        state.applyLoadedProject(loaded)
        activateNewTab(
            state: &state,
            title: sourceURL.displayName,
            sourceProjectURL: sourceURL
        )
        state.isHydrating = false
        state.showsHome = false
        state.bannerMessage = StudioStrings.openedDocument(loaded.presentation.layerRows.count, state.appLanguage)
        return .none
    }

    struct AdjustmentWorkflowService {
        let paintDocumentClient: PaintDocumentClient

        func applyLayerProcessing(_ apply: () -> Bool) -> Bool {
            apply()
        }

        func replaceLayerPixels(_ layerIndex: Int, with pixelData: Data) {
            paintDocumentClient.replaceLayerPixels(layerIndex, pixelData)
        }
    }

    struct LayerWorkflowService {
        let paintDocumentClient: PaintDocumentClient
    }

    struct CanvasStrokeWorkflowService {
        let paintDocumentClient: PaintDocumentClient
    }

    var adjustmentWorkflowService: AdjustmentWorkflowService {
        AdjustmentWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    var layerWorkflowService: LayerWorkflowService {
        LayerWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    var canvasStrokeWorkflowService: CanvasStrokeWorkflowService {
        CanvasStrokeWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    func handleAdjustmentPreview(
        state: inout State,
        adjustedPixels: Data?
    ) {
        guard
            let adjustedPixels,
            let snapshot = state.canvas.renderSnapshot,
            let composite = Self.compositedPreviewPixelData(
                snapshot: snapshot,
                activeLayerIndex: state.canvas.activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels
            )
        else {
            state.canvas.adjustmentPreviewPixelData = nil
            return
        }
        state.canvas.adjustmentPreviewPixelData = composite
    }

    @discardableResult
    func handleAdjustmentApplyUsingProcessing(
        state: inout State,
        failureMessage: String,
        apply: () -> Bool
    ) -> Bool {
        state.canvas.adjustmentPreviewPixelData = nil
        guard adjustmentWorkflowService.applyLayerProcessing(apply) else {
            state.bannerMessage = failureMessage
            return false
        }
        if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
            state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
        }
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
        return true
    }

    @discardableResult
    func handleAdjustmentApplyUsingPixels(
        state: inout State,
        adjustedPixels: Data?,
        failureMessage: String
    ) -> Bool {
        state.canvas.adjustmentPreviewPixelData = nil
        guard let adjustedPixels else {
            state.bannerMessage = failureMessage
            return false
        }
        adjustmentWorkflowService.replaceLayerPixels(state.canvas.activeLayerIndex, with: adjustedPixels)
        if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
            state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
        }
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
        return true
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

    func resetStrokePreviewState(state: inout State) {
        state.canvas.activeStrokeBaseSnapshot = nil
        state.canvas.activeStrokePreviewLayerPixelData = nil
        state.canvas.pendingIncrementalUpdate = nil
    }

    func handleBeginStroke(
        state: inout State,
        sample: StylusSample
    ) -> Effect<Action> {
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
            return .none
        }
        canvasStrokeWorkflowService.paintDocumentClient.setLayerVisibility(state.canvas.activeLayerIndex, true)
        state.canvas.selection = nil
        canvasStrokeWorkflowService.paintDocumentClient.cancelStroke()
        if state.canvas.activeStrokeBaseSnapshot == nil {
            if state.canvas.renderSnapshot == nil {
                state.applyPresentation(paintDocumentClient.presentation())
            }
            state.canvas.activeStrokeBaseSnapshot = state.canvas.renderSnapshot
        }
        let brush = state.resolvedBrushSettings()
        var previewBrush = brush
        previewBrush.taperIn = 0
        previewBrush.taperOut = 0
        if
            let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
            let baseLayer = baseSnapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
            let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                basePixelData: baseLayer.pixelData,
                canvasWidth: baseSnapshot.width,
                canvasHeight: baseSnapshot.height,
                samples: [sample],
                brush: previewBrush,
                preserveAlphaLockedPixels: activeLayer.isAlphaLocked
            )
        {
            state.canvas.activeStrokePreviewLayerPixelData = adjustedPixels
            if
                Self.shouldUseIncrementalPreviewUpdate(for: previewBrush),
                let dirtyRect = Self.strokePreviewDirtyRect(
                    samples: [sample],
                    brush: previewBrush,
                    canvasWidth: baseSnapshot.width,
                    canvasHeight: baseSnapshot.height
                ),
                let incrementalUpdate = Self.compositedPreviewIncrementalUpdate(
                    snapshot: baseSnapshot,
                    activeLayerIndex: state.canvas.activeLayerIndex,
                    adjustedActiveLayerPixels: adjustedPixels,
                    dirtyRect: dirtyRect
                )
            {
                state.canvas.pendingIncrementalUpdate = incrementalUpdate
            } else {
                state.applyLiveStrokePreview(
                    baseSnapshot: baseSnapshot,
                    activeLayerIndex: state.canvas.activeLayerIndex,
                    adjustedActiveLayerPixels: adjustedPixels
                )
            }
        }
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleAppendStrokeSamples(
        state: inout State,
        samples: [StylusSample]
    ) {
        guard !samples.isEmpty else { return }
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
            return
        }
        let brush = state.resolvedBrushSettings()
        var previewBrush = brush
        previewBrush.taperIn = 0
        previewBrush.taperOut = 0
        if
            let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
            let baseLayer = baseSnapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex })
        {
            let fullSamples = state.canvas.activeStroke?.points.map(\.stylusSample) ?? samples
            let anchorIndex = max(fullSamples.count - samples.count - 1, 0)
            let anchor = fullSamples.indices.contains(anchorIndex) ? fullSamples[anchorIndex] : nil
            let previewSamples = anchor.map { [$0] + samples } ?? samples
            let basePixelData = state.canvas.activeStrokePreviewLayerPixelData ?? baseLayer.pixelData
            guard let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                basePixelData: basePixelData,
                canvasWidth: baseSnapshot.width,
                canvasHeight: baseSnapshot.height,
                samples: previewSamples,
                brush: previewBrush,
                preserveAlphaLockedPixels: activeLayer.isAlphaLocked
            ) else {
                return
            }
            state.canvas.activeStrokePreviewLayerPixelData = adjustedPixels
            if
                Self.shouldUseIncrementalPreviewUpdate(for: previewBrush),
                let dirtyRect = Self.strokePreviewDirtyRect(
                    samples: previewSamples,
                    brush: previewBrush,
                    canvasWidth: baseSnapshot.width,
                    canvasHeight: baseSnapshot.height
                ),
                let incrementalUpdate = Self.compositedPreviewIncrementalUpdate(
                    snapshot: baseSnapshot,
                    activeLayerIndex: state.canvas.activeLayerIndex,
                    adjustedActiveLayerPixels: adjustedPixels,
                    dirtyRect: dirtyRect
                )
            {
                state.canvas.pendingIncrementalUpdate = incrementalUpdate
            } else {
                state.applyLiveStrokePreview(
                    baseSnapshot: baseSnapshot,
                    activeLayerIndex: state.canvas.activeLayerIndex,
                    adjustedActiveLayerPixels: adjustedPixels
                )
            }
            return
        }

        guard
            let snapshot = state.canvas.renderSnapshot,
            let baseLayer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
            let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                basePixelData: baseLayer.pixelData,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                samples: samples,
                brush: previewBrush,
                preserveAlphaLockedPixels: activeLayer.isAlphaLocked
            )
        else { return }

        state.canvas.activeStrokeBaseSnapshot = snapshot
        state.canvas.activeStrokePreviewLayerPixelData = adjustedPixels
        if
            Self.shouldUseIncrementalPreviewUpdate(for: previewBrush),
            let dirtyRect = Self.strokePreviewDirtyRect(
                samples: samples,
                brush: previewBrush,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height
            ),
            let incrementalUpdate = Self.compositedPreviewIncrementalUpdate(
                snapshot: snapshot,
                activeLayerIndex: state.canvas.activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels,
                dirtyRect: dirtyRect
            )
        {
            state.canvas.pendingIncrementalUpdate = incrementalUpdate
        } else {
            state.applyLiveStrokePreview(
                baseSnapshot: snapshot,
                activeLayerIndex: state.canvas.activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels
            )
        }
    }

    func handlePreviewShapeStroke(
        state: inout State,
        samples: [StylusSample]
    ) -> Effect<Action> {
        guard let first = samples.first else { return .none }
        canvasStrokeWorkflowService.paintDocumentClient.setLayerVisibility(state.canvas.activeLayerIndex, true)
        state.canvas.selection = nil
        canvasStrokeWorkflowService.paintDocumentClient.cancelStroke()
        canvasStrokeWorkflowService.paintDocumentClient.beginStroke(first, state.resolvedBrushSettings())
        for sample in samples.dropFirst() {
            canvasStrokeWorkflowService.paintDocumentClient.appendStroke(sample)
        }
        state.applyLiveCompositePixelData(paintDocumentClient.compositePixelData())
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleCommitPreviewShapeStroke(state: inout State) -> Effect<Action> {
        canvasStrokeWorkflowService.paintDocumentClient.endStroke()
        applyDirtyPresentation(state: &state)
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleFinishStroke(
        state: inout State,
        samples: [StylusSample],
        keepsSelectionCleared: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> Effect<Action> {
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
            resetStrokePreviewState(state: &state)
            return .none
        }
        let brush = state.resolvedBrushSettings()
        let shouldApplyTaperOnCommit = brush.taperIn > 0.001 || brush.taperOut > 0.001
        if keepsSelectionCleared {
            canvasStrokeWorkflowService.paintDocumentClient.setLayerVisibility(state.canvas.activeLayerIndex, true)
            state.canvas.selection = nil
        }
        if let previewPixels = state.canvas.activeStrokePreviewLayerPixelData, !shouldApplyTaperOnCommit {
            canvasStrokeWorkflowService.paintDocumentClient.replaceLayerPixels(state.canvas.activeLayerIndex, previewPixels)
        } else {
            let didCommit = canvasStrokeWorkflowService.paintDocumentClient.applySoftwareStroke(
                samples,
                brush,
                state.canvas.activeLayerIndex
            )
            if !didCommit {
                if !refreshViaDirtyPresentation && state.canvas.renderSnapshot == nil {
                    state.applyPresentation(paintDocumentClient.presentation())
                }
                let fallbackSnapshot = refreshViaDirtyPresentation
                    ? state.canvas.activeStrokeBaseSnapshot
                    : (state.canvas.activeStrokeBaseSnapshot ?? state.canvas.renderSnapshot)
                if let snapshot = fallbackSnapshot,
                   let baseLayer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                   let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                        basePixelData: baseLayer.pixelData,
                        canvasWidth: snapshot.width,
                        canvasHeight: snapshot.height,
                        samples: samples,
                        brush: brush,
                        preserveAlphaLockedPixels: activeLayer.isAlphaLocked
                   ) {
                    canvasStrokeWorkflowService.paintDocumentClient.replaceLayerPixels(state.canvas.activeLayerIndex, adjustedPixels)
                }
            }
        }
        resetStrokePreviewState(state: &state)
        if refreshViaDirtyPresentation {
            applyDirtyPresentation(state: &state)
        } else {
            state.applyPresentation(paintDocumentClient.presentation())
        }
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleCancelStroke(state: inout State) -> Effect<Action> {
        if state.canvas.currentTool == .shape {
            canvasStrokeWorkflowService.paintDocumentClient.cancelStroke()
        }
        resetStrokePreviewState(state: &state)
        state.applyPresentation(paintDocumentClient.presentation())
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleBlurSamples(
        state: inout State,
        samples: [StylusSample]
    ) {
        guard !samples.isEmpty else { return }
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
            return
        }
        canvasStrokeWorkflowService.paintDocumentClient.revealLayerForEditing(state.canvas.activeLayerIndex)
        canvasStrokeWorkflowService.paintDocumentClient.blurStroke(samples, state.resolvedBrushSettings(), state.canvas.activeLayerIndex, false)
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleEndBlurStroke(state: inout State) {
        canvasStrokeWorkflowService.paintDocumentClient.endBlurStroke()
        applyDirtyPresentation(state: &state)
    }

    func handleFill(
        state: inout State,
        sample: StylusSample
    ) -> Effect<Action> {
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
            return .none
        }
        canvasStrokeWorkflowService.paintDocumentClient.setLayerVisibility(state.canvas.activeLayerIndex, true)
        canvasStrokeWorkflowService.paintDocumentClient.fill(sample, state.resolvedBrushSettings())
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }
}
