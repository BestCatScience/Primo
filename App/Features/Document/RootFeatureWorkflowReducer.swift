import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication

struct RootFeatureWorkflowReducer: Reducer, RootFeatureIntegrationReducer {
    @Dependency(\.canvasStrokeInteractionService) var canvasStrokeInteractionService
    @Dependency(\.dateClient) var dateClient
    @Dependency(\.documentCanvasCommandService) var documentCanvasCommandService
    @Dependency(\.documentExportGateway) var documentExportGateway
    @Dependency(\.documentGpuOperationGateway) var documentGpuOperationGateway
    @Dependency(\.documentLayerCommandService) var documentLayerCommandService
    @Dependency(\.documentMutationGateway) var documentMutationGateway
    @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway
    @Dependency(\.documentQueryGateway) var documentQueryGateway
    @Dependency(\.documentStrokeCommandService) var documentStrokeCommandService
    @Dependency(\.documentStrokeSessionUseCase) var documentStrokeSessionUseCase
    @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient
    @Dependency(\.nanoBananaEditUseCase) var nanoBananaEditUseCase
    @Dependency(\.textLayerGateway) var textLayerGateway
    @Dependency(\.uuidClient) var uuidClient
    @Dependency(\.workspaceApplicationWorkflowService) var workspaceApplicationWorkflowService

    typealias DocumentCanvasMutation = DocumentFeature.DocumentCanvasMutation
    typealias DocumentPresentationRefresh = DocumentFeature.DocumentPresentationRefresh
    typealias LayerMutationFinalization = DocumentFeature.LayerMutationFinalization
    typealias DocumentMutationContract = DocumentFeature.DocumentMutationContract

    struct DocumentMutationFeedbackCoordinator {
        func effect(
            for feedback: ApplicationFeedback?
        ) -> Effect<Action> {
            guard let feedback else { return .none }
            return .send(.application(.feedbackPresented(feedback)))
        }
    }

    var documentCanvasMutationCoordinator: DocumentFeature.DocumentCanvasMutationCoordinator {
        DocumentFeature.DocumentCanvasMutationCoordinator()
    }

    var documentMutationFeedbackCoordinator: DocumentMutationFeedbackCoordinator {
        DocumentMutationFeedbackCoordinator()
    }

    var documentMutationFeedbackMapper: DocumentFeature.DocumentMutationFeedbackMapper {
        DocumentFeature.DocumentMutationFeedbackMapper()
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .application:
            return .none

        case let .workspace(workspaceAction):
            return routeWorkspaceAction(state: &state, action: workspaceAction)

        case .document:
            if let effect = routeDocumentEditorAction(state: &state, action: action) {
                return effect
            }
            if let effect = routeDocumentEditorEditingAction(state: &state, action: action) {
                return effect
            }
            return routeCanvasInteractionAction(state: &state, action: action) ?? .none

        case .importExport, .nanoBanana:
            return routeAssetImportExportAction(state: &state, action: action) ?? .none
        }
    }

    @discardableResult
    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        documentCanvasMutationCoordinator.apply(
            contract.canvasMutation,
            to: &state.document
        )
        let effect: Effect<Action>
        switch contract.refresh {
        case .none:
            effect = .none
        case .current:
            effect = applyPresentation(documentQueryGateway.presentation(), state: &state)
        case .dirty:
            effect = applyDirtyPresentation(
                state: &state,
                updatesWorkspaceArtifacts: contract.updatesWorkspaceArtifacts
            )
        }
        return .merge(
            effect,
            documentMutationFeedbackCoordinator.effect(for: contract.successFeedback)
        )
    }

    @discardableResult
    func performDocumentMutation<Success>(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        failureFeedback: ApplicationFeedback? = nil,
        mutation: () -> Result<Success, DocumentMutationFailure>,
        onSuccess: (Success, inout State) -> Void = { _, _ in }
    ) -> Effect<Action> {
        switch mutation() {
        case let .success(success):
            onSuccess(success, &state)
            return completeDocumentMutation(state: &state, contract: contract)
        case let .failure(failure):
            return documentMutationFeedbackCoordinator.effect(
                for: documentMutationFeedbackMapper.feedback(
                    for: failure,
                    default: failureFeedback
                )
            )
        }
    }

    func handleLifecycleAutosaveRequested(
        state: inout State
    ) -> Effect<Action> {
        guard state.workspace.activeTab?.isDirty == true else { return .none }
        guard let request = lifecycleAutosaveRequest(state: &state) else { return .none }
        return .send(.workspace(.persistenceRequested(request)))
    }

    func handleHomeReturnRequest(state: inout State) -> Effect<Action> {
        if state.workspace.activeTab != nil {
            switch saveActiveDocumentRequest(
                state: &state,
                preferredDestinationURL: state.workspace.activeTab?.sourceProjectURL,
                trigger: .autoSave,
                purpose: .homeReturn
            ) {
            case let .success(request):
                return .send(.workspace(.persistenceRequested(request)))
            case let .failure(failure):
                return .send(.application(.bannerPresented(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                )))
            }
        }
        return .merge(
            .send(.application(.showHomeRequested(.home))),
            .send(.application(.homeProjectsLoadRequested))
        )
    }

    func handleAutosaveRecoveryRestoreRequest(
        state: inout State,
        item: AutosaveRecoveryItem
    ) -> Effect<Action> {
        switch preparedDocumentReplacementRequestForProjectLoad(state: &state) {
        case let .success(replacementRequest):
            return .merge(
                .send(.application(.hydrationStarted)),
                .send(.workspace(.autosaveRecoveryProjectLoadRequested(item, replacementRequest: replacementRequest)))
            )
        case let .failure(failure):
            return presentWorkspaceLoadPreparationFailure(failure, state: state)
        }
    }

    func handleAutosaveRecoveryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        item: AutosaveRecoveryItem,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .newTab(
                    title: item.title,
                    sourceProjectURL: item.sourceProjectURL
                ),
                followUp: .init(
                    marksTabDirty: true,
                    persistsToBackingStore: true,
                    persistsAutosave: true
                ),
                successEffects: .init(
                    discardedAutosaveEntryID: item.id,
                    recoveryResolution: .completeRestore(item.id),
                    completion: .restoredAutosave
                )
            ),
            presentation: LoadedWorkspacePresentation(
                issues: issues,
                completion: .restoredAutosave
            ),
            state: &state
        )
    }

    func performCloseOperation(
        _ operation: PendingCloseOperation
    ) -> Effect<Action> {
        switch operation {
        case let .tab(tabID):
            return .send(.workspace(.tabClosed(tabID)))
        case let .closeOtherTabs(tabID):
            return .send(.workspace(.closeOtherTabs(tabID)))
        case let .closeTabsToRight(tabID):
            return .send(.workspace(.closeTabsToRight(tabID)))
        }
    }

    func handlePendingCloseSaveConfirmed(state: inout State) -> Effect<Action> {
        guard let confirmation = state.workspace.consumeCloseConfirmation() else { return .none }
        switch closeTabsPersistenceRequest(
            operation: confirmation.operation,
            tabIDs: confirmation.tabIDs,
            state: &state
        ) {
        case let .success(request):
            return .send(.workspace(.persistenceRequested(request)))
        case let .failure(failure):
            return .send(.application(.bannerPresented(
                workspaceFeedbackMapper.message(
                    for: workspaceFeedbackMapper.feedback(for: failure),
                    language: state.application.appLanguage
                )
            )))
        }
    }

    func routeWorkspaceAction(
        state: inout State,
        action: WorkspaceAction
    ) -> Effect<Action> {
        switch action {
        case .persistenceRequested:
            return .none

        case let .persistenceSucceeded(result):
            return handleWorkspacePersistenceSucceeded(state: &state, result: result)

        case let .persistenceFailed(failure):
            return handleWorkspacePersistenceFailed(state: &state, failure: failure)

        case let .autosaveRecoveryRestoreRequested(item):
            return handleAutosaveRecoveryRestoreRequest(state: &state, item: item)

        case .autosaveRecoveryProjectLoadRequested:
            return .none

        case let .autosaveRecoveryOpened(loaded, item, issues):
            return handleAutosaveRecoveryOpened(state: &state, loaded: loaded, item: item, issues: issues)

        case .catalogRequested:
            return .none

        case .saveHistoryEntriesRequested:
            return .none

        case .saveHistoryProjectLoadRequested:
            return .none

        case .catalogSucceeded:
            return .none

        case .catalogFailed:
            return .none

        case let .tabSelected(tabID):
            return handleTabSelection(state: &state, tabID: tabID)

        case .tabProjectLoadRequested:
            return .none

        case let .tabSelectionLoaded(tabID, loaded):
            return handleTabSelectionLoaded(state: &state, tabID: tabID, loaded: loaded)

        case .tabSelectionFailed:
            return .none

        case .tabCloseRequested:
            return .none

        case .closeOtherTabsRequested:
            return .none

        case .closeTabsToRightRequested:
            return .none

        case .pendingCloseSaveConfirmed:
            return handlePendingCloseSaveConfirmed(state: &state)

        case .pendingCloseDiscardConfirmed:
            return .none

        case .pendingCloseCancelled:
            return .none

        case .tabClosed:
            return .none

        case .closeOtherTabs:
            return .none

        case .closeTabsToRight:
            return .none

        case .moveTabToSecondaryPane:
            return .none

        case .tabReordered:
            return .none

        case .tabDropped:
            return .none

        case .splitActiveTabIntoSecondaryPane:
            return .none

        case .mergeWorkspacePanes:
            return .none

        case .workspacePaneActivated:
            return .none

        case .moveSavedProject:
            return .none

        case .homeReturnRequested:
            return handleHomeReturnRequest(state: &state)

        case .lifecycleAutosaveRequested:
            return handleLifecycleAutosaveRequested(state: &state)

        case let .openImportedDocumentRequested(sourceURL):
            return handleOpenImportedDocumentRequest(
                state: &state,
                sourceURL: sourceURL
            )

        case .importedProjectLoadRequested:
            return .none

        case let .openImportedDocumentLoaded(loaded, suggestedTitle, issues):
            return handleOpenImportedDocumentLoaded(
                state: &state,
                loaded: loaded,
                suggestedTitle: suggestedTitle,
                issues: issues
            )

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

        case .projectLoadRequested:
            return .none

        case let .openDocumentLoaded(loaded, sourceURL, issues):
            return handleOpenDocumentLoaded(
                state: &state,
                loaded: loaded,
                sourceURL: sourceURL,
                issues: issues
            )

        case .openDocumentFailed:
            return .none

        case .delegate:
            return .none
        }
    }

    func routeDocumentEditorAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .document(.newCanvasRequested(width, height)):
            return handleNewCanvasRequest(state: &state, width: width, height: height)

        case let .document(.newCanvasPreparationCompleted(dimensions)):
            return handleNewCanvasPreparationCompleted(state: &state, dimensions: dimensions)

        default:
            return nil
        }
    }

    func routeAssetImportExportAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case .importExport(.newCanvasFromImageReceived(_, _)):
            return nil

        case let .importExport(.newCanvasFromImagePreparationCompleted(plan)):
            return handleNewCanvasFromImagePreparationCompleted(state: &state, plan: plan)

        case .importExport(.newCanvasFromImageFailed(_)):
            return nil

        case .importExport(.saveHistoryRequested):
            return nil

        case .importExport(.saveHistoryLoaded(_)):
            return nil

        case .importExport(.saveHistoryLoadFailed(_)):
            return nil

        case .importExport(.saveHistoryLoadFailedFeedback(_)):
            return nil

        case .importExport(.saveHistoryDismissed):
            return nil

        case let .importExport(.saveHistoryRestoreRequested(projectURL, openInNewTab)):
            return handleSaveHistoryRestoreRequest(
                state: &state,
                projectURL: projectURL,
                openInNewTab: openInNewTab
            )

        case let .importExport(.saveHistoryOpened(loaded, projectURL, openInNewTab, issues)):
            return handleSaveHistoryOpened(
                state: &state,
                loaded: loaded,
                projectURL: projectURL,
                openInNewTab: openInNewTab,
                issues: issues
            )

        case .importExport(.saveHistoryRestoreFailed):
            return nil

        case .importExport(.exportDocumentRequested):
            return nil

        case .importExport(.saveDocumentRequested):
            return nil

        case .importExport(.saveDocumentCopyRequested):
            return nil

        case .importExport(.exportTimelapseRequested):
            return nil

        case .importExport(.timelapseExportProgressUpdated(_)):
            return nil

        case .importExport(.timelapseExportSucceeded(_)):
            return nil

        case .importExport(.timelapseExportFailed(_)):
            return nil

        case .importExport(.photoImportFailed(_)):
            return nil

        case let .importExport(.delegate(delegateAction)):
            switch delegateAction {
            case .saveHistoryEntriesRequested:
                return nil
            case let .saveActiveDocumentRequested(preferredDestinationURL):
                return handleSaveDocumentRequest(
                    state: &state,
                    preferredDestinationURL: preferredDestinationURL ?? state.workspace.activeTab?.sourceProjectURL
                )
            case .saveDocumentCopyRequested:
                return handleSaveDocumentRequest(
                    state: &state,
                    preferredDestinationURL: nil
                )
            case .exportPNGDataRequested:
                return nil
            case .exportFailed:
                return nil
            case .timelapseHistoryUnavailable:
                return nil
            case .presentBanner:
                return nil
            case .presentFeedback:
                return nil
            case let .newCanvasFromImagePrepared(plan):
                return handleNewCanvasFromImagePreparationCompleted(state: &state, plan: plan)
            }

        case let .nanoBanana(.delegate(delegateAction)):
            switch delegateAction {
            case let .requestEdit(request):
                return handleNanoBananaEditRequest(state: &state, request: request)
            case .cancelEdit:
                return handleNanoBananaCancelRequested(state: &state)
            }

        case let .nanoBanana(.generationSucceeded(preview)):
            return handleNanoBananaEditSucceeded(state: &state, preview: preview)

        case let .nanoBanana(.generationFailed(feedback)):
            return handleNanoBananaEditFailed(state: &state, feedback: feedback)

        default:
            return nil
        }
    }

    func routeDocumentAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        if let effect = routeDocumentEditorAction(state: &state, action: action) {
            return effect
        }
        return routeAssetImportExportAction(state: &state, action: action)
    }
}
