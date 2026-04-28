import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure
import os

protocol RootFeatureIntegrationReducer {
    static var startupLogger: Logger { get }
}

extension RootFeatureIntegrationReducer {
    static var startupLogger: Logger { PrimoRootFeature.startupLogger }

    typealias State = PrimoRootFeature.State
    typealias Action = PrimoRootFeature.Action
    typealias ApplicationAction = ApplicationFeature.Action
    typealias WorkspaceAction = WorkspaceFeature.Action
    typealias DocumentAction = DocumentFeature.Action
    typealias EditingAction = DocumentFeature.EditingAction
    typealias AppScenePhase = ApplicationFeature.ScenePhase
    typealias ApplicationFeedback = ApplicationFeature.Feedback
    typealias DocumentNamingPolicy = DocumentFeature.DocumentNamingPolicy
    typealias CancelID = ApplicationFeature.CancelID
    typealias WorkspaceTabClosureDisposition = WorkspaceFeature.WorkspaceTabClosureDisposition
    typealias WorkspacePaneActivationDisposition = WorkspaceFeature.WorkspacePaneActivationDisposition
    typealias WorkspaceTabClosureResult = WorkspaceFeature.WorkspaceTabClosureResult

    typealias CanvasDimensions = DocumentFeature.CanvasDimensions
    typealias ImportedCanvasPlan = ImportExportFeature.ImportedCanvasPlan
    typealias FreshDocumentReplacementContract = DocumentFeature.FreshDocumentReplacementContract
    typealias PendingWorkspaceTabReservation = WorkspaceFeature.PendingWorkspaceTabReservation
    typealias PendingLoadedWorkspaceProject = WorkspaceFeature.PendingLoadedWorkspaceProject
    typealias PendingFreshDocumentMutation = WorkspaceFeature.PendingFreshDocumentMutation
    typealias LoadedWorkspacePresentation = WorkspaceFeature.LoadedWorkspacePresentation
    typealias WorkspaceFeedbackMapper = WorkspaceFeature.WorkspaceFeedbackMapper
    typealias WorkspaceLoadFailureContext = WorkspaceFeature.WorkspaceLoadFailureContext

    typealias WorkspacePersistenceIssue = PrimoWorkspaceApplication.WorkspacePersistenceIssue
    typealias WorkspacePersistenceFailureReason = PrimoWorkspaceApplication.WorkspacePersistenceFailureReason
    typealias WorkspacePersistenceFailure = PrimoWorkspaceApplication.WorkspacePersistenceFailure
    typealias WorkspaceDirtyPresentationRequest = PrimoWorkspaceApplication.WorkspaceDirtyPresentationRequest
    typealias WorkspaceDocumentSavePurpose = PrimoWorkspaceApplication.WorkspaceDocumentSavePurpose
    typealias WorkspaceDocumentSaveRequest = PrimoWorkspaceApplication.WorkspaceDocumentSaveRequest
    typealias WorkspaceDocumentSaveResult = PrimoWorkspaceApplication.WorkspaceDocumentSaveResult
    typealias WorkspaceDocumentReplacementRequest = PrimoWorkspaceApplication.WorkspaceDocumentReplacementRequest
    typealias LoadedWorkspaceFollowUpPersistenceRequest = PrimoWorkspaceApplication.LoadedWorkspaceFollowUpPersistenceRequest
    typealias LoadedWorkspaceFollowUpPersistenceResult = PrimoWorkspaceApplication.LoadedWorkspaceFollowUpPersistenceResult
    typealias WorkspaceCloseTabsSaveRequest = PrimoWorkspaceApplication.WorkspaceCloseTabsSaveRequest
    typealias WorkspaceCloseTabsSaveResult = PrimoWorkspaceApplication.WorkspaceCloseTabsSaveResult
    typealias WorkspaceArtifactDiscardRequest = PrimoWorkspaceApplication.WorkspaceArtifactDiscardRequest
    typealias WorkspaceTabReservationRequest = PrimoWorkspaceApplication.WorkspaceTabReservationRequest
    typealias WorkspaceSavedProjectMoveRequest = PrimoWorkspaceApplication.WorkspaceSavedProjectMoveRequest
    typealias WorkspaceSavedProjectMoveResult = PrimoWorkspaceApplication.WorkspaceSavedProjectMoveResult
    typealias WorkspaceAutosaveEntryDiscardRequest = PrimoWorkspaceApplication.WorkspaceAutosaveEntryDiscardRequest
    typealias WorkspaceSaveHistoryLoadRequest = PrimoWorkspaceApplication.WorkspaceSaveHistoryLoadRequest
    typealias WorkspaceCatalogFailureReason = PrimoWorkspaceApplication.WorkspaceCatalogFailureReason
    typealias WorkspaceCatalogFailure = PrimoWorkspaceApplication.WorkspaceCatalogFailure
    typealias WorkspacePersistenceRequest = PrimoWorkspaceApplication.WorkspacePersistenceRequest
    typealias WorkspacePersistenceResult = PrimoWorkspaceApplication.WorkspacePersistenceResult
    typealias WorkspaceCatalogRequest = PrimoWorkspaceApplication.WorkspaceCatalogRequest
    typealias WorkspaceCatalogResult = PrimoWorkspaceApplication.WorkspaceCatalogResult
    typealias LoadedWorkspaceProjectPlan = PrimoWorkspaceApplication.LoadedWorkspaceProjectPlan
    typealias PreparedWorkspaceTab = PrimoWorkspaceApplication.PreparedWorkspaceTab
    typealias WorkspaceProjectLoadIssue = PrimoWorkspaceApplication.WorkspaceProjectLoadIssue
    typealias WorkspaceProjectLoadFailureReason = PrimoWorkspaceApplication.WorkspaceProjectLoadFailureReason
    typealias WorkspaceProjectLoadOperation = PrimoWorkspaceApplication.WorkspaceProjectLoadOperation
    typealias WorkspaceImportedProjectLoadOperation = PrimoWorkspaceApplication.WorkspaceImportedProjectLoadOperation
    typealias WorkspaceProjectLoadRequest = PrimoWorkspaceApplication.WorkspaceProjectLoadRequest
    typealias WorkspaceProjectLoadResult = PrimoWorkspaceApplication.WorkspaceProjectLoadResult<LoadedPaintProject>
    typealias WorkspaceProjectLoadFailure = PrimoWorkspaceApplication.WorkspaceProjectLoadFailure
    typealias WorkspaceProjectPreparationUseCase = PrimoWorkspaceApplication.WorkspaceProjectPreparationUseCase
    typealias WorkspaceProjectLoadUseCase = PrimoWorkspaceApplication.WorkspaceProjectLoadUseCase<LoadedPaintProject>
    typealias WorkspaceProjectLoadCommand = PrimoWorkspaceApplication.WorkspaceProjectLoadCommand
    typealias WorkspaceProjectLoadingService = PrimoWorkspaceApplication.WorkspaceProjectLoadingService<LoadedPaintProject>
}

struct CrossFeatureIntegrationReducer: Reducer, RootFeatureIntegrationReducer {
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
                            WorkspaceAutosaveEntryDiscardRequest(autosaveID: id)
                        )
                    )
                )
            )

        case .application(.delegate(.requestPresentationRefresh)):
            return .send(.document(.presentationRefreshRequested))

        case .application(.delegate(.requestLifecycleAutosave)):
            return .send(.workspace(.lifecycleAutosaveRequested))

        case .application(.delegate(.requestStartupPresentationBootstrap)):
            return .send(.document(.startupPresentationBootstrapRequested))

        case .importExport(.delegate(.saveHistoryEntriesRequested)):
            return .send(.workspace(.saveHistoryEntriesRequested))

        case .importExport(.delegate(.exportFailed)):
            return .send(.application(.feedbackPresented(.exportFailed)))

        case .importExport(.delegate(.timelapseHistoryUnavailable)):
            return .send(.application(.feedbackPresented(.timelapseHistoryUnavailable)))

        case let .importExport(.photoImportReceived(name, data)):
            return .send(.document(.photoImportReceived(name: name, data: data)))

        case .importExport(.photoImportFailed):
            return .none

        case let .importExport(.delegate(.presentBanner(message))):
            return .send(.application(.bannerPresented(message)))

        case let .importExport(.delegate(.presentFeedback(feedback))):
            return .send(.application(.feedbackPresented(feedback)))

        case let .importExport(.saveHistoryRestoreFailed(message)):
            return .send(.application(.hydrationFailed(message)))

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

        case let .workspace(.delegate(.autosaveRecoveryLoaded(items))):
            return .send(.application(.autosaveRecoveryLoaded(items)))

        case let .workspace(.delegate(.autosaveRecoveryLoadFailed(feedback))):
            return .send(.application(.hydrationFeedbackPresented(feedback)))

        case let .workspace(.delegate(.autosaveRecoveryDiscarded(id))):
            return .send(.application(.autosaveRecoveryDiscarded(id)))

        case let .workspace(.delegate(.saveHistoryLoaded(entries))):
            return .send(.importExport(.saveHistoryLoaded(entries)))

        case let .workspace(.delegate(.saveHistoryLoadFailed(feedback))):
            return .send(.importExport(.saveHistoryLoadFailedFeedback(feedback)))

        case let .workspace(.delegate(.saveHistoryProjectOpened(loaded, projectURL, openInNewTab, issues))):
            return .send(.importExport(.saveHistoryOpened(loaded, projectURL, openInNewTab, issues)))

        case let .workspace(.delegate(.saveHistoryRestoreFailedFeedback(feedback))):
            return .send(.application(.hydrationFeedbackPresented(feedback)))

        case .workspace(.delegate(.requestHomeProjectsLoad)):
            return .send(.application(.homeProjectsLoadRequested))

        case let .document(.delegate(.paperStyleSyncRequested(paperStyle))):
            return .send(.document(.paperStyleSyncRequested(paperStyle)))

        case .document(.brushPalette(.delegate(.cancelTransform))),
             .document(.brushPalette(.delegate(.applyTransform))),
             .document(.canvas(.delegate(.applyTransform))):
            return .none

        case .document(.editing(.activeLayerVisibilityToggled)),
             .document(.editing(.selectPreviousLayer)),
             .document(.editing(.selectNextLayer)),
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
             .document(.editing(.clearActiveLayerButtonTapped)),
             .document(.brushPalette(.delegate(.clearActiveLayer))),
             .document(.editing(.createLayerMaskFromSelectionRequested)),
             .document(.editing(.clearLayerMaskRequested)),
             .document(.editing(.applyLayerMaskRequested)),
             .document(.photoImportReceived):
            return .none

        case .document(.delegate(.presentationRefreshRequested)):
            return .send(.document(.presentationRefreshRequested))

        case let .document(.delegate(.documentMutationFeedback(feedback))):
            return .send(.application(.feedbackPresented(feedback)))

        case .document(.editing(.gradientMapPreviewChanged)),
             .document(.editing(.hueSaturationBrightnessPreviewChanged)),
             .document(.editing(.brightnessContrastPreviewChanged)),
             .document(.editing(.levelsPreviewChanged)),
             .document(.editing(.toneCurvePreviewChanged)),
             .document(.editing(.colorBalancePreviewChanged)),
             .document(.editing(.thresholdPreviewChanged)),
             .document(.editing(.posterizePreviewChanged)),
             .document(.editing(.gradientMapSelected)),
             .document(.editing(.gradientMapApplied)),
             .document(.editing(.hueSaturationBrightnessApplied)),
             .document(.editing(.brightnessContrastApplied)),
             .document(.editing(.levelsApplied)),
             .document(.editing(.toneCurveApplied)),
             .document(.editing(.colorBalanceApplied)),
             .document(.editing(.thresholdApplied)),
             .document(.editing(.posterizeApplied)),
             .document(.editing(.luminanceToAlphaRequested)),
             .document(.resizeCanvasRequested),
             .document(.resizeCanvasExtentRequested),
             .document(.undoRequested),
             .document(.redoRequested):
            return .none

        case .application(.deferredPresentationRefresh):
            return .send(.document(.deferredPresentationRefreshRequested))

        case .application(.refreshPresentationRequested):
            return .send(.document(.presentationRefreshRequested))

        case .application(.loadPresentationAfterLaunch):
            return .send(.document(.deferredPresentationLoadRequested))

        case let .application(.documentPaperStyleSyncRequested(paperStyle)):
            return .send(.document(.paperStyleSyncRequested(paperStyle)))

        case let .application(.bootstrapPresentationLoaded(presentation)):
            return .send(.document(.bootstrapPresentationLoaded(presentation)))

        case let .application(.presentationLoaded(presentation)):
            return .send(.document(.presentationLoaded(presentation)))

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
             .workspace(.autosaveRecoveryProjectLoadRequested),
             .workspace(.projectLoadRequested),
             .workspace(.importedProjectLoadRequested),
             .workspace(.openDocumentFailed),
             .workspace(.tabSelectionFailed):
            return .none

        default:
            break
        }
        return RootFeatureWorkflowReducer().reduce(into: &state, action: action)
    }
}
