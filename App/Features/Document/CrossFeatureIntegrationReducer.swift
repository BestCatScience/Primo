import ComposableArchitecture
import PrimoWorkspaceApplication

struct CrossFeatureIntegrationReducer: Reducer {
    typealias State = PrimoRootFeature.State
    typealias Action = PrimoRootFeature.Action

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .application(.delegate(.requestHomeProjectsLoad)):
            return .send(.workspace(.catalogRequested(.loadSavedProjects)))

        case .application(.delegate(.requestAutosaveRecoveryLoad)):
            return .send(.workspace(.catalogRequested(.loadAutosaveRecoveryItems)))

        case let .application(.delegate(.requestAutosaveRecoveryRestore(item))):
            return .send(.workspace(.autosaveRecoveryRestoreRequested(item)))

        case let .application(.delegate(.requestAutosaveRecoveryDiscard(id))):
            return .send(
                .workspace(
                    .catalogRequested(
                        .discardAutosaveEntry(
                            PrimoWorkspaceApplication.WorkspaceAutosaveEntryDiscardRequest(autosaveID: id)
                        )
                    )
                )
            )

        case .application(.delegate(.requestPresentationRefresh)):
            return .send(.document(.presentation(.presentationRefreshRequested)))

        case .application(.delegate(.requestLifecycleAutosave)):
            return .send(.workspace(.lifecycleAutosaveRequested))

        case .application(.delegate(.requestStartupPresentationBootstrap)):
            return .send(.document(.presentation(.startupPresentationBootstrapRequested)))

        case .importExport(.delegate(.saveHistoryEntriesRequested)):
            return .send(.workspace(.saveHistoryEntriesRequested))

        case let .importExport(.delegate(.saveActiveDocumentRequested(preferredDestinationURL))):
            return .send(.workspace(.saveActiveDocumentRequested(preferredDestinationURL: preferredDestinationURL)))

        case .importExport(.delegate(.saveDocumentCopyRequested)):
            return .send(.workspace(.saveDocumentCopyRequested))

        case .importExport(.delegate(.exportFailed)):
            return .send(.application(.feedbackPresented(.exportFailed)))

        case .importExport(.delegate(.timelapseHistoryUnavailable)):
            return .send(.application(.feedbackPresented(.timelapseHistoryUnavailable)))

        case let .importExport(.photoImportReceived(name, data)):
            return .send(.document(.layerWorkflow(.photoImportReceived(name: name, data: data))))

        case .importExport(.photoImportFailed):
            return .none

        case let .importExport(.delegate(.presentBanner(message))):
            return .send(.application(.bannerPresented(message)))

        case let .importExport(.delegate(.presentFeedback(feedback))):
            return .send(.application(.feedbackPresented(feedback)))

        case let .importExport(.delegate(.newCanvasFromImagePrepared(plan))):
            return .send(.document(.lifecycle(.newCanvasFromImagePreparationCompleted(plan))))

        case let .importExport(.saveHistoryRestoreFailed(message)):
            return .send(.application(.hydrationFailed(message)))

        case let .importExport(.saveHistoryRestoreRequested(projectURL, openInNewTab)):
            return .send(
                .workspace(
                    .saveHistoryProjectLoadRequested(
                        projectURL,
                        openInNewTab: openInNewTab,
                        replacementRequest: nil
                    )
                )
            )

        case let .importExport(.saveHistoryOpened(loaded, projectURL, openInNewTab, issues)):
            return .send(.workspace(.saveHistoryProjectOpened(loaded, projectURL, openInNewTab, issues)))

        case let .workspace(.delegate(.homeProjectsLoaded(projects))):
            return .send(.application(.homeProjectsLoaded(projects)))

        case let .workspace(.delegate(.presentFeedback(feedback))):
            return .send(.application(.feedbackPresented(feedback)))

        case let .workspace(.delegate(.presentBanner(message))):
            return .send(.application(.bannerPresented(message)))

        case .workspace(.delegate(.showHome)):
            return .send(.application(.showHomeRequested(.home)))

        case let .workspace(.delegate(.workspaceProjectLoadFailed(message, showingHome))):
            return .send(.application(.hydrationFailed(message, showingHome: showingHome)))

        case let .workspace(.delegate(.workspaceProjectLoadFailedFeedback(feedback, showingHome))):
            return .send(.application(.hydrationFeedbackPresented(feedback, showingHome: showingHome)))

        case let .workspace(.delegate(.workspaceProjectLoadCompleted(message))):
            return .send(.application(.workspaceProjectLoadCompleted(message)))

        case let .workspace(.delegate(.autosaveRecoveryLoaded(items))):
            return .send(.application(.autosaveRecoveryLoaded(items)))

        case let .workspace(.delegate(.autosaveRecoveryLoadFailed(feedback))):
            return .send(.application(.hydrationFeedbackPresented(feedback)))

        case let .workspace(.delegate(.autosaveRecoveryDiscarded(id))):
            return .send(.application(.autosaveRecoveryDiscarded(id)))

        case let .workspace(.delegate(.autosaveRecoveryRestoreCompleted(id))):
            return .send(.application(.autosaveRecoveryRestoreCompleted(id)))

        case .workspace(.delegate(.autosaveRecoveryDismissed)):
            return .send(.application(.autosaveRecoveryDismissed))

        case let .workspace(.delegate(.saveHistoryLoaded(entries))):
            return .send(.importExport(.saveHistoryLoaded(entries)))

        case let .workspace(.delegate(.saveHistoryLoadFailed(feedback))):
            return .send(.importExport(.saveHistoryLoadFailedFeedback(feedback)))

        case let .workspace(.delegate(.saveHistoryProjectOpened(loaded, projectURL, openInNewTab, issues))):
            return .send(.importExport(.saveHistoryOpened(loaded, projectURL, openInNewTab, issues)))

        case let .workspace(.delegate(.saveHistoryRestoreFailedFeedback(feedback))):
            return .send(.application(.hydrationFeedbackPresented(feedback)))

        case .workspace(.delegate(.saveHistoryRestoreCompleted)):
            return .send(.importExport(.saveHistoryRestoreCompleted))

        case .workspace(.delegate(.requestHomeProjectsLoad)):
            return .send(.application(.homeProjectsLoadRequested))

        case .workspace(.delegate(.requestDocumentSnapshot)):
            return .send(.document(.presentation(.workspaceSnapshotRequested(.pendingWorkspaceOperation))))

        case let .workspace(.delegate(.applyLoadedProject(loaded))):
            return .send(.document(.presentation(.applyLoadedProjectRequested(loaded))))

        case let .workspace(.delegate(.requestFreshDocumentMutation(request))):
            return .send(.document(.lifecycle(.freshDocumentMutationRequested(request))))

        case let .document(.delegate(.workspaceSnapshotPrepared(_, snapshot))):
            return .send(.workspace(.documentSnapshotPrepared(snapshot)))

        case .document(.delegate(.loadedProjectApplied)):
            return .send(.workspace(.loadedProjectApplied))

        case .document(.delegate(.loadedProjectApplySkipped)):
            return .send(.workspace(.loadedProjectApplySkipped))

        case let .document(.delegate(.freshDocumentRequested(contract, operation))):
            return .send(.workspace(.freshDocumentRequested(contract, operation)))

        case let .document(.delegate(.freshDocumentMutationSucceeded(preparedTab, contract, snapshot))):
            return .send(.workspace(.freshDocumentMutationSucceeded(preparedTab, contract, snapshot)))

        case let .document(.delegate(.freshDocumentMutationFailed(feedback))):
            return .send(.workspace(.freshDocumentMutationFailed(feedback)))

        case let .document(.delegate(.aiImageGenerationStarted(start))):
            return .send(.aiImage(.generationStarted(start)))

        case let .document(.delegate(.aiImageGenerationFailed(feedback, language))):
            return .merge(
                .send(.aiImage(.generationFailedFeedback(feedback, language))),
                .send(.application(.feedbackPresented(feedback)))
            )

        case let .document(.delegate(.aiImageEditApplied(applied))):
            return .send(.aiImage(.generationApplied(applied)))

        case let .aiImage(.delegate(.requestEdit(request))):
            return .send(.document(.aiImageWorkflow(.aiImageEditRequested(request))))

        case .aiImage(.delegate(.cancelEdit)):
            return .send(.document(.aiImageWorkflow(.aiImageCancelRequested)))

        case let .document(.delegate(.paperStyleSyncRequested(paperStyle))):
            return .send(.document(.presentation(.paperStyleSyncRequested(paperStyle))))

        case .document(.brushPalette(.delegate(.cancelTransform))),
             .document(.brushPalette(.delegate(.applyTransform))),
             .document(.canvas(.delegate(.applyTransform))):
            return .none

        case .document(.layerWorkflow(.editing(.activeLayerVisibilityToggled))),
             .document(.layerWorkflow(.editing(.selectPreviousLayer))),
             .document(.layerWorkflow(.editing(.selectNextLayer))),
             .document(.layerSidebar(.delegate(.setOpacity))),
             .document(.layerSidebar(.delegate(.toggleLayerLock))),
             .document(.layerSidebar(.delegate(.toggleAlphaLock))),
             .document(.layerSidebar(.delegate(.toggleClippingMask))),
             .document(.layerSidebar(.delegate(.selectLayer))),
             .document(.layerSidebar(.delegate(.toggleVisibility))),
             .document(.layerSidebar(.delegate(.setFolderExpanded))),
             .document(.layerSidebar(.delegate(.toggleFolderVisibility))),
             .document(.layerSidebar(.delegate(.renameFolder))),
             .document(.layerSidebar(.delegate(.setBlendMode))),
             .document(.layerSidebar(.delegate(.renameLayer))),
             .document(.layerSidebar(.delegate(.addLayer))),
             .document(.layerSidebar(.delegate(.addFolder))),
             .document(.layerSidebar(.delegate(.deleteFolder))),
             .document(.layerSidebar(.delegate(.deleteLayer))),
             .document(.layerSidebar(.delegate(.duplicateLayer))),
             .document(.layerSidebar(.delegate(.moveLayer))),
             .document(.layerSidebar(.delegate(.moveLayerToFolder))),
             .document(.layerSidebar(.delegate(.removeLayerFromFolder))),
             .document(.layerSidebar(.delegate(.mergeDown))),
             .document(.brushPalette(.delegate(.applyText))),
             .document(.layerWorkflow(.editing(.clearActiveLayerButtonTapped))),
             .document(.brushPalette(.delegate(.clearActiveLayer))),
             .document(.layerWorkflow(.editing(.createLayerMaskFromSelectionRequested))),
             .document(.layerWorkflow(.editing(.clearLayerMaskRequested))),
             .document(.layerWorkflow(.editing(.applyLayerMaskRequested))),
             .document(.layerWorkflow(.photoImportReceived)):
            return .none

        case .document(.delegate(.presentationRefreshRequested)):
            return .send(.document(.presentation(.presentationRefreshRequested)))

        case let .document(.delegate(.documentMutationFeedback(feedback))):
            return .send(.application(.feedbackPresented(feedback)))

        case .document(.adjustment),
             .document(.lifecycle(.resizeCanvasRequested)),
             .document(.lifecycle(.resizeCanvasExtentRequested)),
             .document(.lifecycle(.undoRequested)),
             .document(.lifecycle(.redoRequested)):
            return .none

        case .application(.deferredPresentationRefresh):
            return .send(.document(.presentation(.deferredPresentationRefreshRequested)))

        case .application(.refreshPresentationRequested):
            return .send(.document(.presentation(.presentationRefreshRequested)))

        case .application(.loadPresentationAfterLaunch):
            return .send(.document(.presentation(.deferredPresentationLoadRequested)))

        case let .application(.documentPaperStyleSyncRequested(paperStyle)):
            return .send(.document(.presentation(.paperStyleSyncRequested(paperStyle))))

        case let .application(.bootstrapPresentationLoaded(presentation)):
            return .send(.document(.presentation(.bootstrapPresentationLoaded(presentation))))

        case let .application(.presentationLoaded(presentation)):
            return .send(.document(.presentation(.presentationLoaded(presentation))))

        case .document(.delegate(.presentationApplied)):
            return .send(.application(.hydrationFinished()))

        case .application(.task),
             .application(.startupStarted),
             .application(.startupLanguageLoaded),
             .application(.scenePhaseChanged),
             .application(.homeProjectsLoadRequested),
             .application(.homeProjectsLoaded),
             .application(.homeProjectsLoadFailed),
             .application(.autosaveRecoveryLoadRequested),
             .application(.autosaveRecoveryLoaded),
             .application(.autosaveRecoveryLoadFailed),
             .application(.autosaveRecoveryRestoreRequested),
             .application(.autosaveRecoveryRestoreFailed),
             .application(.autosaveRecoveryRestoreCompleted),
             .application(.autosaveRecoveryDiscardRequested),
             .application(.autosaveRecoveryDiscarded),
             .application(.autosaveRecoveryDismissed),
             .application(.hydrationStarted),
             .application(.hydrationFailed),
             .application(.hydrationFinished),
             .application(.workspaceProjectLoadCompleted),
             .application(.hydrationFeedbackPresented),
             .application(.feedbackPresented),
             .application(.bannerPresented),
             .application(.showHomeRequested),
             .application(.showWorkspaceRequested),
             .application(.homeSectionSelected),
             .application(.languageChanged),
             .application(.bannerDismissed):
            return .none

        case .workspace(.saveHistoryEntriesRequested),
             .workspace(.saveHistoryProjectLoadRequested),
             .workspace(.tabProjectLoadRequested),
             .workspace(.catalogRequested),
             .workspace(.catalogSucceeded),
             .workspace(.catalogFailed),
             .workspace(.persistenceRequested),
             .workspace(.persistenceSucceeded),
             .workspace(.persistenceFailed),
             .workspace(.pendingCloseSaveConfirmed),
             .workspace(.tabCloseRequested),
             .workspace(.closeOtherTabsRequested),
             .workspace(.closeTabsToRightRequested),
             .workspace(.pendingCloseDiscardConfirmed),
             .workspace(.pendingCloseCancelled),
             .workspace(.tabClosed),
             .workspace(.closeOtherTabs),
             .workspace(.closeTabsToRight),
             .workspace(.moveTabToSecondaryPane),
             .workspace(.tabReordered),
             .workspace(.tabDropped),
             .workspace(.splitActiveTabIntoSecondaryPane),
             .workspace(.mergeWorkspacePanes),
             .workspace(.workspacePaneActivated),
             .workspace(.moveSavedProject),
             .workspace(.homeReturnRequested),
             .workspace(.lifecycleAutosaveRequested),
             .workspace(.openImportedDocumentRequested),
             .workspace(.openImportedDocumentLoaded),
             .workspace(.openDocumentSelected),
             .workspace(.homeProjectSelected),
             .workspace(.openDocumentLoaded),
             .workspace(.autosaveRecoveryRestoreRequested),
             .workspace(.autosaveRecoveryOpened),
             .workspace(.autosaveRecoveryProjectLoadRequested),
             .workspace(.projectLoadRequested),
             .workspace(.importedProjectLoadRequested),
             .workspace(.saveActiveDocumentRequested),
             .workspace(.saveDocumentCopyRequested),
             .workspace(.documentSnapshotPrepared),
             .workspace(.loadedProjectApplied),
             .workspace(.loadedProjectApplySkipped),
             .workspace(.freshDocumentRequested),
             .workspace(.freshDocumentMutationSucceeded),
             .workspace(.freshDocumentMutationFailed),
             .workspace(.openDocumentFailed),
             .workspace(.tabSelectionFailed):
            return .none

        default:
            return .none
        }
    }
}
