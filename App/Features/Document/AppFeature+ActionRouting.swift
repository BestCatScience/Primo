import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleAction(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .task:
            return handleTask(state: &state)

        case let .bootstrapPresentationLoaded(presentation):
            handleBootstrapPresentationLoaded(state: &state, presentation: presentation)
            return .none

        case .loadPresentationAfterLaunch:
            return handleLoadPresentationAfterLaunch()

        case .homeProjectsLoadRequested:
            return handleHomeProjectsLoadRequest(state: &state)

        case let .homeProjectsLoaded(projects):
            handleHomeProjectsLoaded(state: &state, projects: projects)
            return .none

        case .autosaveRecoveryLoadRequested:
            return handleAutosaveRecoveryLoadRequest()

        case let .autosaveRecoveryLoaded(items):
            handleAutosaveRecoveryLoaded(state: &state, items: items)
            return .none

        case let .autosaveRecoveryRestoreRequested(autosaveID):
            return handleAutosaveRecoveryRestoreRequest(state: &state, autosaveID: autosaveID)

        case let .autosaveRecoveryOpened(loaded, item):
            handleAutosaveRecoveryOpened(state: &state, loaded: loaded, item: item)
            return .none

        case let .autosaveRecoveryDiscardRequested(autosaveID):
            handleAutosaveRecoveryDiscardRequest(state: &state, autosaveID: autosaveID)
            return .none

        case .autosaveRecoveryDismissed:
            handleAutosaveRecoveryDismissed(state: &state)
            return .none

        case let .homeSectionSelected(section):
            handleHomeSectionSelected(state: &state, section: section)
            return .none

        case let .tabSelected(tabID):
            handleTabSelection(state: &state, tabID: tabID)
            return .none

        case let .tabCloseRequested(tabID):
            return requestCloseOperation(state: &state, operation: .tab(tabID))

        case let .closeOtherTabsRequested(tabID):
            return requestCloseOperation(state: &state, operation: .closeOtherTabs(tabID))

        case let .closeTabsToRightRequested(tabID):
            return requestCloseOperation(state: &state, operation: .closeTabsToRight(tabID))

        case .pendingCloseSaveConfirmed:
            return handlePendingCloseSaveConfirmed(state: &state)

        case .pendingCloseDiscardConfirmed:
            return handlePendingCloseDiscardConfirmed(state: &state)

        case .pendingCloseCancelled:
            handlePendingCloseCancelled(state: &state)
            return .none

        case let .tabClosed(tabID):
            handleTabClosed(state: &state, tabID: tabID)
            return .none

        case let .closeOtherTabs(tabID):
            return handleCloseOtherTabs(state: &state, retaining: tabID)

        case let .closeTabsToRight(tabID):
            handleCloseTabsToRight(state: &state, tabID: tabID)
            return .none

        case let .moveTabToSecondaryPane(tabID):
            handleMoveTabToSecondaryPane(state: &state, tabID: tabID)
            return .none

        case let .tabReordered(movingID, targetID):
            handleTabReordered(state: &state, movingID: movingID, targetID: targetID)
            return .none

        case let .tabDropped(movingID, pane, targetID):
            handleTabDropped(state: &state, movingID: movingID, pane: pane, targetID: targetID)
            return .none

        case .splitActiveTabIntoSecondaryPane:
            handleSplitActiveTabIntoSecondaryPane(state: &state)
            return .none

        case .mergeWorkspacePanes:
            handleMergeWorkspacePanes(state: &state)
            return .none

        case let .workspacePaneActivated(pane):
            return handleWorkspacePaneActivated(state: &state, pane: pane)

        case let .moveSavedProject(url, relativeFolderPath):
            return handleSavedProjectMove(
                state: &state,
                url: url,
                relativeFolderPath: relativeFolderPath
            )

        case .homeReturnRequested:
            return handleHomeReturnRequest(state: &state)

        case let .presentationLoaded(presentation):
            handlePresentationLoaded(state: &state, presentation: presentation)
            return .none

        case .deferredPresentationRefresh:
            return handleDeferredPresentationRefresh()

        case .refreshPresentationRequested:
            handleRefreshPresentationRequest(state: &state)
            return .none

        case let .languageChanged(language):
            handleLanguageChanged(state: &state, language: language)
            return .none

        case let .newCanvasRequested(width, height):
            return handleNewCanvasRequest(state: &state, width: width, height: height)

        case let .resizeCanvasRequested(width, height):
            handleResizeCanvasRequest(state: &state, width: width, height: height)
            return .none

        case let .resizeCanvasExtentRequested(width, height):
            handleResizeCanvasExtentRequest(state: &state, width: width, height: height)
            return .none

        case let .newCanvasFromImageReceived(name, data):
            return handleNewCanvasFromImageReceived(state: &state, name: name, data: data)

        case let .newCanvasFromImageFailed(message):
            handleNewCanvasFromImageFailed(state: &state, message: message)
            return .none

        case .undoRequested:
            handleUndoRequested(state: &state)
            return .none

        case .redoRequested:
            handleRedoRequested(state: &state)
            return .none

        case .saveHistoryRequested:
            return handleSaveHistoryRequest(state: &state)

        case let .saveHistoryLoaded(entries):
            state.saveHistoryEntries = entries
            state.isShowingSaveHistory = true
            return .none

        case .saveHistoryDismissed:
            state.isShowingSaveHistory = false
            return .none

        case let .saveHistoryRestoreRequested(projectURL, openInNewTab):
            return handleSaveHistoryRestoreRequest(
                state: &state,
                projectURL: projectURL,
                openInNewTab: openInNewTab
            )

        case let .saveHistoryOpened(loaded, projectURL, openInNewTab):
            handleSaveHistoryOpened(
                state: &state,
                loaded: loaded,
                projectURL: projectURL,
                openInNewTab: openInNewTab
            )
            return .none

        case let .gradientMapSelected(preset):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .gradientMap(preset),
                failureMessage: state.appLanguage.localized("Could not apply gradient map")
            )
            return .none

        case let .gradientMapPreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.gradientMappedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .gradientMapApplied(settings):
            let adjusted = adjustedActiveLayerPixels(in: state) {
                Self.gradientMappedLayerPixels(source: $0, settings: settings)
            }
            _ = handleAdjustmentApplyUsingPixels(
                state: &state,
                adjustedPixels: adjusted,
                failureMessage: state.appLanguage.localized("Could not apply gradient map")
            )
            return .none

        case let .hueSaturationBrightnessPreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.hueSaturationBrightnessAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .hueSaturationBrightnessApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .hueSaturationBrightness(settings),
                failureMessage: state.appLanguage.localized("Could not apply color adjustment")
            )
            return .none

        case let .brightnessContrastPreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.brightnessContrastAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .brightnessContrastApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .brightnessContrast(settings),
                failureMessage: state.appLanguage.localized("Could not apply color adjustment")
            )
            return .none

        case let .levelsPreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.levelsAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .levelsApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .levels(settings),
                failureMessage: state.appLanguage.localized("Could not apply color adjustment")
            )
            return .none

        case let .toneCurvePreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.toneCurveAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .toneCurveApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .toneCurve(settings),
                failureMessage: state.appLanguage.localized("Could not apply color adjustment")
            )
            return .none

        case let .colorBalancePreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.colorBalanceAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .colorBalanceApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .colorBalance(settings),
                failureMessage: state.appLanguage.localized("Could not apply color adjustment")
            )
            return .none

        case let .thresholdPreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.thresholdAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .thresholdApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .threshold(settings),
                failureMessage: state.appLanguage.localized("Could not apply color adjustment")
            )
            return .none

        case let .posterizePreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.posterizedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .posterizeApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .posterize(settings),
                failureMessage: state.appLanguage.localized("Could not apply color adjustment")
            )
            return .none

        case .luminanceToAlphaRequested:
            let adjusted = adjustedActiveLayerPixels(in: state) {
                Self.luminanceToAlphaLayerPixels(source: $0)
            }
            _ = handleAdjustmentApplyUsingPixels(
                state: &state,
                adjustedPixels: adjusted,
                failureMessage: state.appLanguage.localized("Could not apply color adjustment")
            )
            return .none

        case .exportDocumentRequested:
            handleExportDocumentRequest(state: &state)
            return .none

        case .saveDocumentRequested:
            return handleSaveDocumentRequest(
                state: &state,
                preferredDestinationURL: state.activeTab?.sourceProjectURL
            )

        case .saveDocumentCopyRequested:
            return handleSaveDocumentRequest(
                state: &state,
                preferredDestinationURL: nil
            )

        case .exportTimelapseRequested:
            return handleTimelapseExportRequest(state: &state)

        case let .nanoBananaEditRequested(request):
            return handleNanoBananaEditRequest(state: &state, request: request)

        case let .nanoBananaEditSucceeded(preview):
            handleNanoBananaEditSucceeded(state: &state, preview: preview)
            return .none

        case let .nanoBananaEditFailed(message):
            handleNanoBananaEditFailed(state: &state, message: message)
            return .none

        case .nanoBananaCancelRequested:
            return handleNanoBananaCancelRequested(state: &state)

        case .nanoBananaPreviewAccepted:
            handleNanoBananaPreviewAccepted(state: &state)
            return .none

        case .nanoBananaPreviewDiscarded:
            handleNanoBananaPreviewDiscarded(state: &state)
            return .none

        case .nanoBananaRegenerateRequested:
            return handleNanoBananaRegenerateRequested(state: &state)

        case let .nanoBananaRetryJob(jobID):
            return handleNanoBananaRetryJob(state: &state, jobID: jobID)

        case let .timelapseExportProgressUpdated(progress, previewData):
            handleTimelapseExportProgressUpdated(state: &state, progress: progress, previewData: previewData)
            return .none

        case let .timelapseExportSucceeded(url):
            handleTimelapseExportSucceeded(state: &state, url: url)
            return .none

        case let .timelapseExportFailed(message):
            handleTimelapseExportFailed(state: &state, message: message)
            return .none

        case .exportSheetDismissed:
            handleExportSheetDismissed(state: &state)
            return .none

        case .bannerDismissed:
            handleBannerDismissed(state: &state)
            return .none

        case let .openDocumentSelected(url):
            return handleOpenDocumentSelection(
                state: &state,
                url: url,
                removesStagedWorkspaceItem: true
            )

        case let .homeProjectSelected(url):
            return handleOpenDocumentSelection(
                state: &state,
                url: url,
                removesStagedWorkspaceItem: false
            )

        case let .openDocumentLoaded(loaded, sourceURL):
            return handleOpenDocumentLoaded(
                state: &state,
                loaded: loaded,
                sourceURL: sourceURL
            )

        case let .openDocumentFailed(message):
            handleOpenDocumentFailed(state: &state, message: message)
            return .none

        case let .photoImportReceived(name, data):
            handlePhotoImport(state: &state, name: name, data: data)
            return .none

        case let .photoImportFailed(message):
            handlePhotoImportFailed(state: &state, message: message)
            return .none

        case let .toolSelected(tool):
            handleToolSelection(
                state: &state,
                tool: tool,
                showsBrushSettingsPopover: false
            )
            return .none

        case let .toolLongPressed(tool):
            handleToolSelection(
                state: &state,
                tool: tool,
                showsBrushSettingsPopover: tool == .brush || tool == .erase
            )
            return .none

        case let .panelCollapseToggled(panel):
            state.toggleCollapse(for: panel)
            return .none

        case .brushPalette(.delegate(.clearSelection)):
            handleClearSelection(state: &state)
            return .none

        case .brushPalette(.delegate(.invertSelection)):
            handleInvertSelection(state: &state)
            return .none

        case let .brushPalette(.delegate(.expandSelection(expansion))):
            handleAdjustSelection(state: &state, expansion: max(expansion, 1))
            return .none

        case let .brushPalette(.delegate(.contractSelection(contraction))):
            handleAdjustSelection(state: &state, expansion: -max(contraction, 1))
            return .none

        case let .featherSelectionRequested(radius):
            handleFeatherSelection(state: &state, radius: max(radius, 1))
            return .none

        case let .colorRangeSelectionRequested(request):
            return handleColorRangeSelectionRequest(state: &state, request: request)

        case .brushPalette(.delegate(.cancelTransform)):
            state.canvas.resetTransformPreview()
            return .none

        case .brushPalette(.delegate(.applyTransform)):
            return applyTransform(state: &state)

        case let .brushPalette(.delegate(.applyText(draft))):
            handleApplyText(state: &state, draft: draft)
            return .none

        case .canvas(.delegate(.applyTransform)):
            return .none

        case let .canvas(.delegate(.placeText(point))):
            handlePlaceText(state: &state, point: point)
            return .none

        case .clearActiveLayerButtonTapped, .brushPalette(.delegate(.clearActiveLayer)):
            handleClearActiveLayer(state: &state)
            return .none

        case .createLayerMaskFromSelectionRequested:
            handleCreateLayerMask(state: &state)
            return .none

        case .clearLayerMaskRequested:
            handleClearLayerMask(state: &state)
            return .none

        case .applyLayerMaskRequested:
            handleApplyLayerMask(state: &state)
            return .none

        case .activeLayerVisibilityToggled:
            handleActiveLayerVisibilityToggle(state: &state)
            return .none

        case .selectPreviousLayer:
            handleSelectAdjacentLayer(state: &state, direction: -1)
            return .none

        case .selectNextLayer:
            handleSelectAdjacentLayer(state: &state, direction: 1)
            return .none

        case .brushPalette:
            handleBrushPaletteStateRefresh(state: &state)
            return .none

        case .layerSidebar(.binding(\.paperColor)):
            handlePaperColorBindingChanged(state: &state)
            return .none

        case .layerSidebar(.binding(\.transparentPaper)):
            handleTransparentPaperBindingChanged(state: &state)
            return .none

        case .layerSidebar(.delegate(.addLayer)):
            handleAddLayer(state: &state)
            return .none

        case .layerSidebar(.delegate(.addFolder)):
            handleAddFolder(state: &state)
            return .none

        case let .layerSidebar(.delegate(.deleteFolder(folderID))):
            handleFolderDeletion(state: &state, folderID: folderID)
            return .none

        case let .layerSidebar(.delegate(.deleteLayer(index))):
            handleLayerDeletion(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.duplicateLayer(index))):
            handleLayerDuplication(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.moveLayer(index, destinationIndex))):
            handleLayerMove(state: &state, index: index, destinationIndex: destinationIndex)
            return .none

        case let .layerSidebar(.delegate(.moveLayerToFolder(index, folderID))):
            handleLayerFolderAssignment(state: &state, index: index, folderID: folderID)
            return .none

        case let .layerSidebar(.delegate(.removeLayerFromFolder(index))):
            handleLayerFolderAssignment(state: &state, index: index, folderID: -1)
            return .none

        case let .layerSidebar(.delegate(.setOpacity(index, opacity))):
            handleLayerOpacityChange(state: &state, index: index, opacity: opacity)
            return .none

        case let .layerSidebar(.delegate(.toggleLayerLock(index))):
            handleLayerLockToggle(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.toggleAlphaLock(index))):
            handleLayerAlphaLockToggle(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.toggleClippingMask(index))):
            handleLayerClippingToggle(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.mergeDown(index))):
            handleLayerMergeDown(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.selectLayer(index))):
            handleLayerSelection(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.toggleVisibility(index))):
            handleLayerVisibilityToggle(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.setFolderExpanded(folderID, isExpanded))):
            handleFolderExpandedChange(state: &state, folderID: folderID, isExpanded: isExpanded)
            return .none

        case let .layerSidebar(.delegate(.toggleFolderVisibility(folderID))):
            handleFolderVisibilityToggle(state: &state, folderID: folderID)
            return .none

        case let .layerSidebar(.delegate(.renameFolder(folderID, name))):
            handleFolderRename(state: &state, folderID: folderID, name: name)
            return .none

        case let .layerSidebar(.delegate(.setBlendMode(index, blendMode))):
            handleLayerBlendModeChange(state: &state, index: index, blendMode: blendMode)
            return .none

        case let .layerSidebar(.delegate(.renameLayer(index, name))):
            handleLayerRename(state: &state, index: index, name: name)
            return .none

        case let .canvas(.delegate(.beginStroke(sample))):
            return handleBeginStroke(state: &state, sample: sample)

        case let .canvas(.delegate(.appendSamples(samples))):
            handleAppendStrokeSamples(state: &state, samples: samples)
            return .none

        case let .canvas(.delegate(.previewShapeStroke(samples))):
            return handlePreviewShapeStroke(state: &state, samples: samples)

        case .canvas(.delegate(.commitPreviewShapeStroke)):
            return handleCommitPreviewShapeStroke(state: &state)

        case let .canvas(.delegate(.endStroke(samples))):
            return handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: true
            )

        case .canvas(.delegate(.cancelStroke)):
            return handleCancelStroke(state: &state)

        case let .canvas(.delegate(.commitStroke(samples))):
            return handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: true,
                refreshViaDirtyPresentation: false
            )

        case let .canvas(.delegate(.blurSamples(samples))):
            handleBlurSamples(state: &state, samples: samples)
            return .none

        case .canvas(.delegate(.endBlurStroke)):
            handleEndBlurStroke(state: &state)
            return .none

        case let .canvas(.delegate(.fill(sample))):
            return handleFill(state: &state, sample: sample)

        case let .canvas(.delegate(.lassoSelect(points))):
            return handleLassoSelection(state: &state, points: points)

        case let .canvas(.delegate(.autoSelect(sample))):
            return handleAutoSelection(state: &state, sample: sample)

        case .canvas(.delegate(.requestUndo)):
            return .send(.undoRequested)

        case .canvas(.delegate(.requestRedo)):
            return .send(.redoRequested)

        case .canvas(.delegate(.toggleBrushAndEraser)):
            handleToggleBrushAndEraser(state: &state)
            return .none

        case let .canvas(.colorSampled(sampledColor)):
            handleColorSampled(state: &state, sampledColor: sampledColor)
            return .none

        case .layerSidebar, .canvas:
            return .none
        }
    }
}
