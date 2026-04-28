import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure

extension RootFeatureWorkflowReducer {
    typealias WorkspacePersistenceIssue = PrimoWorkspaceApplication.WorkspacePersistenceIssue
    typealias WorkspacePersistenceFailure = PrimoWorkspaceApplication.WorkspacePersistenceFailure
    typealias WorkspaceDocumentSavePurpose = PrimoWorkspaceApplication.WorkspaceDocumentSavePurpose
    typealias WorkspaceDocumentReplacementRequest = PrimoWorkspaceApplication.WorkspaceDocumentReplacementRequest
    typealias WorkspaceTabReservationRequest = PrimoWorkspaceApplication.WorkspaceTabReservationRequest
    typealias WorkspacePersistenceRequest = PrimoWorkspaceApplication.WorkspacePersistenceRequest
    typealias WorkspacePersistenceResult = PrimoWorkspaceApplication.WorkspacePersistenceResult
    typealias LoadedWorkspaceProjectPlan = PrimoWorkspaceApplication.LoadedWorkspaceProjectPlan
    typealias WorkspacePersistenceUseCase = PrimoWorkspaceApplication.WorkspacePersistenceUseCase
    typealias WorkspaceApplicationServices = PrimoWorkspaceInfrastructure.WorkspaceApplicationServices
    typealias PreparedWorkspaceTab = PrimoWorkspaceApplication.PreparedWorkspaceTab
    typealias WorkspaceDocumentContext = PrimoWorkspaceApplication.WorkspaceDocumentContext

    typealias PendingWorkspaceTabReservation = WorkspaceFeature.PendingWorkspaceTabReservation
    typealias PendingLoadedWorkspaceProject = WorkspaceFeature.PendingLoadedWorkspaceProject
    typealias PendingFreshDocumentMutation = WorkspaceFeature.PendingFreshDocumentMutation

    var workspaceApplicationServices: WorkspaceApplicationServices {
        WorkspaceApplicationServices(
            documentPersistenceGateway: documentPersistenceGateway,
            documentWorkspaceClient: documentWorkspaceClient,
            uuidClient: uuidClient
        )
    }

    var workspacePersistenceUseCase: WorkspacePersistenceUseCase {
        workspaceApplicationServices.persistenceUseCase
    }

    func applyPresentation(
        _ presentation: PaintDocumentPresentation,
        state: inout State
    ) -> Effect<Action> {
        guard DocumentFeature.canvasPresentationStateCoordinator.applyPresentation(presentation, to: &state.document) else {
            return .none
        }
        return .send(.application(.hydrationFinished()))
    }

    func applyLoadedProject(
        _ loaded: LoadedPaintProject,
        state: inout State
    ) -> Effect<Action> {
        guard DocumentFeature.canvasPresentationStateCoordinator.applyLoadedProject(loaded, to: &state.document) else {
            return .none
        }
        return .send(.application(.hydrationFinished()))
    }

    func syncTextEditorWithActiveLayer(state: inout State) {
        DocumentFeature.canvasPresentationStateCoordinator.syncTextEditorWithActiveLayer(state: &state.document)
    }

    func applyLiveCompositeSurface(
        _ compositeSurface: DocumentCompositeSurface,
        state: inout State
    ) -> Effect<Action> {
        if DocumentFeature.canvasPreviewStateCoordinator.applyLiveCompositeSurface(compositeSurface, to: &state.document) {
            return .send(.application(.hydrationFinished()))
        }
        return .none
    }

    func applyLiveStrokePreview(
        baseSnapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        state: inout State
    ) -> Effect<Action> {
        if DocumentFeature.canvasPreviewStateCoordinator.applyLiveStrokePreview(
            baseSnapshot: baseSnapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            gpuOperations: documentGpuOperationGateway,
            to: &state.document
        ) {
            return .send(.application(.hydrationFinished()))
        }
        return .none
    }

    func resolvedBrushSettings(for state: State) -> BrushRuntimeSettings {
        DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state.document)
    }

    func previewStrokeStyle(for state: State) -> PreviewStrokeStyle {
        DocumentFeature.canvasToolStateCoordinator.previewStrokeStyle(for: state.document)
    }

    func resolvedPaperStyle(for state: State) -> CanvasPaperStyle {
        DocumentFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: state.document)
    }

    private func currentWorkspacePreviewSurface(
        state: State,
        paperStyle: CanvasPaperStyle
    ) -> DocumentCompositeSurface? {
        state.document.canvas.renderSnapshot.map {
            DocumentFeature.renderedCompositeSurface(
                snapshot: $0,
                paperStyle: paperStyle,
                gpuOperations: documentGpuOperationGateway
            )
        } ?? documentExportGateway.compositeSurface(paperStyle)
    }

    func refreshActiveTabMetadataForPersistence(
        state: inout State
    ) -> OpenDocumentTab? {
        let paperStyle = resolvedPaperStyle(for: state)
        state.workspace.updateActiveTabMetadata(
            previewSurface: currentWorkspacePreviewSurface(
                state: state,
                paperStyle: paperStyle
            ),
            canvasSize: state.document.canvas.canvasSize
        )
        return state.workspace.activeTab
    }

    func documentReplacementRequest(
        state: inout State
    ) -> Result<WorkspaceDocumentReplacementRequest, WorkspacePersistenceFailure> {
        _ = refreshActiveTabMetadataForPersistence(state: &state)
        return workspaceApplicationWorkflowService.documentReplacementRequest(
            context: WorkspaceDocumentContext(
                activeTab: state.workspace.activeTab,
                paperStyle: resolvedPaperStyle(for: state)
            )
        )
    }

    func activatePreparedTab(
        _ preparedTab: PreparedWorkspaceTab,
        state: inout State
    ) -> Result<Void, WorkspacePersistenceFailure> {
        let tab = OpenDocumentTab(
            id: preparedTab.id,
            title: preparedTab.title,
            backingStoreURL: preparedTab.backingStoreURL,
            sourceProjectURL: preparedTab.sourceProjectURL,
            canvasSize: state.document.canvas.canvasSize,
            isDirty: false,
            pane: preparedTab.pane,
            previewSurface: currentWorkspacePreviewSurface(
                state: state,
                paperStyle: resolvedPaperStyle(for: state)
            ),
            previewImageData: nil
        )
        state.workspace.appendTab(tab)
        state.workspace.activateTab(preparedTab.id, pane: preparedTab.pane)
        return .success(())
    }

    typealias LoadedWorkspacePresentation = WorkspaceFeature.LoadedWorkspacePresentation

    func applyLoadedWorkspaceProject(
        _ loaded: LoadedPaintProject,
        using plan: LoadedWorkspaceProjectPlan,
        presentation: LoadedWorkspacePresentation = LoadedWorkspacePresentation(),
        state: inout State
    ) -> Effect<Action> {
        switch plan.destination {
        case let .newTab(title, sourceProjectURL):
            state.workspace.pendingWorkspaceTabReservation = .loadedProject(
                PendingLoadedWorkspaceProject(
                    loaded: loaded,
                    plan: plan,
                    presentation: presentation
                )
            )
            return .send(
                .workspace(.persistenceRequested(
                    .reserveNewTabBackingStore(
                        WorkspaceTabReservationRequest(
                            title: title,
                            sourceProjectURL: sourceProjectURL,
                            pane: state.workspace.focusedWorkspacePane
                        )
                    )
                ))
            )

        case .selectedTab, .activeTab:
            return completeLoadedWorkspaceProject(
                loaded,
                using: plan,
                presentation: presentation,
                preparedTab: nil,
                state: &state
            )
        }
    }

    func completeLoadedWorkspaceProject(
        _ loaded: LoadedPaintProject,
        using plan: LoadedWorkspaceProjectPlan,
        presentation: LoadedWorkspacePresentation,
        preparedTab: PreparedWorkspaceTab?,
        state: inout State
    ) -> Effect<Action> {
        let activationResult: Result<Void, WorkspacePersistenceFailure>
        let loadedProjectEffect: Effect<Action>
        switch plan.destination {
        case let .selectedTab(tabID, pane):
            state.workspace.activateTab(tabID, pane: pane)
            loadedProjectEffect = applyLoadedProject(loaded, state: &state)
            activationResult = .success(())

        case .newTab:
            guard let preparedTab else {
                return .send(
                    .application(.workspaceProjectLoadCompleted(
                        workspaceFeedbackMapper.message(
                            for: workspaceFeedbackMapper.feedback(
                                for: WorkspacePersistenceFailure(reason: .couldNotCreateTab)
                            ),
                            language: state.application.appLanguage
                        )
                    ))
                )
            }
            loadedProjectEffect = applyLoadedProject(loaded, state: &state)
            activationResult = activatePreparedTab(preparedTab, state: &state)

        case let .activeTab(title, sourceProjectURL):
            let existingPreviewSurface = state.workspace.activeTab?.previewSurface
            let existingPreviewImageData = state.workspace.activeTab?.previewImageData
            loadedProjectEffect = applyLoadedProject(loaded, state: &state)
            state.workspace.updateActiveTabMetadata(
                title: title,
                sourceProjectURL: sourceProjectURL,
                previewSurface: existingPreviewSurface,
                previewImageData: existingPreviewImageData,
                canvasSize: state.document.canvas.canvasSize
            )
            activationResult = .success(())
        }

        switch activationResult {
        case let .failure(failure):
            return .send(
                .application(.workspaceProjectLoadCompleted(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                ))
            )
        case .success:
            break
        }

        switch loadedWorkspaceFollowUpRequest(
            plan: plan,
            state: &state
        ) {
        case let .failure(failure):
            return .send(
                .application(.workspaceProjectLoadCompleted(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                ))
            )
        case let .success(.some(request)):
            return .merge(
                loadedProjectEffect,
                .send(.workspace(.persistenceRequested(request))),
                .send(.application(.deferredPresentationRefresh))
            )
        case .success(.none):
            let successEffectsEffect = applyLoadedWorkspaceSuccessEffects(
                plan.successEffects,
                state: &state
            )
            return .merge(
                loadedProjectEffect,
                successEffectsEffect,
                .send(.application(.workspaceProjectLoadCompleted(
                    workspaceFeedbackMapper.loadedWorkspaceCompletionMessage(
                        presentation: presentation,
                        language: state.application.appLanguage
                    )
                ))),
                .send(.application(.deferredPresentationRefresh))
            )
        }
    }

    func dirtyPresentationRequest(
        state: State
    ) -> WorkspacePersistenceRequest? {
        workspaceApplicationWorkflowService.dirtyPresentationRequest(
            context: WorkspaceDocumentContext(
                activeTab: state.workspace.activeTab,
                paperStyle: resolvedPaperStyle(for: state)
            )
        )
    }

    func lifecycleAutosaveRequest(
        state: inout State
    ) -> WorkspacePersistenceRequest? {
        _ = refreshActiveTabMetadataForPersistence(state: &state)
        return dirtyPresentationRequest(state: state)
    }

    func saveActiveDocumentRequest(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?,
        trigger: SaveHistoryTrigger,
        purpose: WorkspaceDocumentSavePurpose
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        _ = refreshActiveTabMetadataForPersistence(state: &state)
        return workspaceApplicationWorkflowService.saveActiveDocumentRequest(
            context: WorkspaceDocumentContext(
                activeTab: state.workspace.activeTab,
                paperStyle: resolvedPaperStyle(for: state)
            ),
            preferredDestinationURL: preferredDestinationURL,
            trigger: trigger,
            purpose: purpose
        )
    }

    var loadedWorkspaceFollowUpPlanner: WorkspaceLoadedProjectFollowUpPlanner {
        WorkspaceLoadedProjectFollowUpPlanner()
    }

    func loadedWorkspaceFollowUpRequest(
        plan: LoadedWorkspaceProjectPlan,
        state: inout State
    ) -> Result<WorkspacePersistenceRequest?, WorkspacePersistenceFailure> {
        _ = refreshActiveTabMetadataForPersistence(state: &state)
        let requiresBackingStorePersistence: Bool = {
            switch plan.destination {
            case .newTab:
                return true
            case .selectedTab, .activeTab:
                return false
            }
        }()

        switch workspaceApplicationWorkflowService.loadedWorkspaceFollowUp(
            plan: plan,
            context: WorkspaceDocumentContext(
                activeTab: state.workspace.activeTab,
                paperStyle: resolvedPaperStyle(for: state)
            ),
            requiresBackingStorePersistence: requiresBackingStorePersistence
        ) {
        case let .success(outcome):
            if outcome.marksActiveTabDirty {
                state.workspace.setActiveTabDirty(true)
            }
            return .success(outcome.followUpRequest)
        case let .failure(failure):
            return .failure(failure)
        }
    }

    func closeTabsPersistenceRequest(
        operation: PendingCloseOperation,
        tabIDs: [OpenDocumentTab.ID],
        state: inout State
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        var tabs = tabIDs.compactMap { state.workspace.tab(withID: $0) }
        let activeTabContext: WorkspaceDocumentContext?
        if let activeTabID = state.workspace.activeTabID, tabIDs.contains(activeTabID) {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                activeTabContext = WorkspaceDocumentContext(
                    activeTab: request.activeTab,
                    paperStyle: request.paperStyle
                )
                if let index = tabs.firstIndex(where: { $0.id == request.activeTab.id }) {
                    tabs[index] = request.activeTab
                }
            case let .failure(failure):
                return .failure(failure)
            }
        } else {
            activeTabContext = nil
        }
        return workspaceApplicationWorkflowService.closeTabsPersistenceRequest(
            operation: operation,
            tabs: tabs,
            activeTabContext: activeTabContext
        )
    }

    func discardArtifactsRequest(
        for tabs: [OpenDocumentTab]
    ) -> WorkspacePersistenceRequest {
        workspaceApplicationWorkflowService.discardArtifactsRequest(for: tabs)
    }

    func documentReplacementPreparationEffect(
        request: WorkspaceDocumentReplacementRequest?,
        onPrepared: @escaping @Sendable () -> Action,
        onFailure: @escaping @Sendable (WorkspacePersistenceFailure) -> Action
    ) -> Effect<Action> {
        guard let request else {
            return .send(onPrepared())
        }
        return .run { [workspacePersistenceUseCase] send in
            let persistenceRequest = WorkspacePersistenceRequest.prepareDocumentReplacement(request)
            switch workspacePersistenceUseCase.execute(persistenceRequest) {
            case .success:
                await send(onPrepared())
            case let .failure(failure):
                await send(onFailure(failure))
            }
        }
    }

    func handleWorkspacePersistenceSucceeded(
        state: inout State,
        result: WorkspacePersistenceResult
    ) -> Effect<Action> {
        switch result {
        case .dirtyPresentationPersisted:
            return .none

        case let .activeDocumentSaved(saved):
            state.workspace.updateTab(
                id: saved.activeTabID,
                title: saved.savedURL.displayName,
                sourceProjectURL: saved.savedURL,
                previewSurface: saved.previewSurface,
                previewImageData: saved.previewImageData,
                canvasSize: saved.canvasSize,
                isDirty: false
            )
            let warningMessage = workspaceFeedbackMapper.bannerMessage(
                for: saved.issues,
                language: state.application.appLanguage
            )
            let bannerMessage = warningMessage
                ?? workspaceFeedbackMapper.message(
                        for: .savedDocument(saved.savedURL.fileURL.lastPathComponent),
                        language: state.application.appLanguage
                )
            switch saved.purpose {
            case .saveDocument:
                return .merge(
                    .send(.application(.bannerPresented(bannerMessage))),
                    .send(.application(.homeProjectsLoadRequested))
                )
            case .homeReturn:
                return .merge(
                    .send(.application(.bannerPresented(bannerMessage))),
                    .send(.application(.showHomeRequested(.home))),
                    .send(.application(.homeProjectsLoadRequested))
                )
            }

        case .documentReplacementPrepared:
            return .none

        case let .newTabBackingStoreReserved(preparedTab):
            guard let pendingReservation = state.workspace.pendingWorkspaceTabReservation else {
                return .none
            }
            state.workspace.pendingWorkspaceTabReservation = nil
            switch pendingReservation {
            case let .loadedProject(pendingLoadedWorkspaceProject):
                return completeLoadedWorkspaceProject(
                    pendingLoadedWorkspaceProject.loaded,
                    using: pendingLoadedWorkspaceProject.plan,
                    presentation: pendingLoadedWorkspaceProject.presentation,
                    preparedTab: preparedTab,
                    state: &state
                )
            case let .freshDocument(pendingFreshDocumentMutation):
                return completeReservedFreshDocumentMutation(
                    pendingFreshDocumentMutation,
                    preparedTab: preparedTab,
                    state: &state
                )
            }

        case let .loadedWorkspaceFollowUpApplied(followUp):
            let successEffectsEffect = applyLoadedWorkspaceSuccessEffects(
                followUp.successEffects,
                state: &state
            )
            return .merge(
                successEffectsEffect,
                .send(
                .application(.workspaceProjectLoadCompleted(
                    workspaceFeedbackMapper.loadedWorkspaceCompletionMessage(
                        completion: followUp.successEffects.completion,
                        persistenceIssues: followUp.issues,
                        language: state.application.appLanguage
                    )
                ))
                )
            )

        case let .tabsSavedForClose(closeResult):
            if let warningMessage = workspaceFeedbackMapper.bannerMessage(
                for: closeResult.issues,
                language: state.application.appLanguage
            ) {
                return .merge(
                    .send(.application(.bannerPresented(warningMessage))),
                    performCloseOperation(closeResult.operation)
                )
            }
            return performCloseOperation(closeResult.operation)

        case let .autosaveArtifactsDiscarded(issues):
            if let warningMessage = workspaceFeedbackMapper.bannerMessage(
                for: issues,
                language: state.application.appLanguage
            ) {
                return .send(.application(.bannerPresented(warningMessage)))
            }
            return .none
        }
    }

    func handleWorkspacePersistenceFailed(
        state: inout State,
        failure: WorkspacePersistenceFailure
    ) -> Effect<Action> {
        switch failure.request {
        case .some(.loadedWorkspaceFollowUp):
            return .send(
                .application(.workspaceProjectLoadCompleted(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                ))
            )
        case .some(.reserveNewTabBackingStore):
            state.workspace.pendingWorkspaceTabReservation = nil
            return .send(
                .application(.workspaceProjectLoadCompleted(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                ))
            )
        default:
            return .send(
                .application(.bannerPresented(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                ))
            )
        }
    }

    func applyDirtyPresentation(
        state: inout State,
        updatesWorkspaceArtifacts: Bool = true
    ) -> Effect<Action> {
        let presentation = documentQueryGateway.lightweightPresentation()
        let lightweightPresentationEffect = applyPresentation(
            PaintDocumentPresentation(
                canvasSize: presentation.canvasSize,
                activeLayerIndex: presentation.activeLayerIndex,
                layerRows: presentation.layerRows,
                layerSidebarRows: presentation.layerSidebarRows,
                renderSnapshot: nil
            ),
            state: &state
        )
        if let dirtyUpdate = documentQueryGateway.consumeDirtyUpdate() {
            documentGpuOperationGateway.releaseSurfaceHandle(dirtyUpdate.gpuBufferHandle)
        }
        let presentationEffect = applyPresentation(documentQueryGateway.presentation(), state: &state)
        state.workspace.setActiveTabDirty(true)
        guard updatesWorkspaceArtifacts else {
            return .merge(lightweightPresentationEffect, presentationEffect)
        }
        let paperStyle = resolvedPaperStyle(for: state)
        state.workspace.updateActiveTabMetadata(
            previewSurface: currentWorkspacePreviewSurface(
                state: state,
                paperStyle: paperStyle
            ),
            canvasSize: state.document.canvas.canvasSize
        )
        guard let request = dirtyPresentationRequest(state: state) else {
            return .merge(lightweightPresentationEffect, presentationEffect)
        }
        return .merge(
            lightweightPresentationEffect,
            presentationEffect,
            .send(.workspace(.persistenceRequested(request)))
        )
    }

    func applyLoadedWorkspaceSuccessEffects(
        _ successEffects: LoadedWorkspaceProjectPlan.SuccessEffects,
        state: inout State
    ) -> Effect<Action> {
        var effects: [Effect<Action>] = []
        switch successEffects.recoveryResolution {
        case .none:
            break
        case let .removeItem(id):
            effects.append(.send(.application(.autosaveRecoveryDiscarded(id))))
        case let .completeRestore(id):
            effects.append(.send(.application(.autosaveRecoveryRestoreCompleted(id))))
        case .dismiss:
            effects.append(.send(.application(.autosaveRecoveryDismissed)))
        }

        switch successEffects.saveHistoryResolution {
        case .none:
            break
        case .completeRestore:
            state.importExport.saveHistory.completeRestore()
        }
        return .merge(effects)
    }

    static func nextUntitledTabTitle(existingTabs: [OpenDocumentTab]) -> String {
        let untitledTabs = existingTabs.filter { $0.sourceProjectURL == nil && $0.title.hasPrefix("Untitled") }
        return untitledTabs.isEmpty ? "Untitled" : "Untitled \(untitledTabs.count + 1)"
    }
}

extension RootFeatureWorkflowReducer {
    var workspaceFeedbackMapper: WorkspaceFeature.WorkspaceFeedbackMapper {
        WorkspaceFeature.WorkspaceFeedbackMapper()
    }
}
