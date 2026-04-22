import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure

extension AppFeature {
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
    typealias WorkspacePersistenceUseCase = PrimoWorkspaceApplication.WorkspacePersistenceUseCase
    typealias WorkspaceCatalogUseCase = PrimoWorkspaceApplication.WorkspaceCatalogUseCase
    typealias WorkspaceBackingStoreService = PrimoWorkspaceInfrastructure.WorkspaceBackingStoreService
    typealias WorkspaceCatalogService = PrimoWorkspaceInfrastructure.WorkspaceCatalogService
    typealias WorkspaceArtifactService = PrimoWorkspaceInfrastructure.WorkspaceArtifactService
    typealias WorkspaceIdentityService = PrimoWorkspaceInfrastructure.WorkspaceIdentityService
    typealias WorkspaceApplicationServices = PrimoWorkspaceInfrastructure.WorkspaceApplicationServices
    typealias PreparedWorkspaceTab = PrimoWorkspaceApplication.PreparedWorkspaceTab
    typealias WorkspaceLoadedProjectFollowUpPlanner = PrimoWorkspaceApplication.WorkspaceLoadedProjectFollowUpPlanner

    enum PendingWorkspaceTabReservation: Equatable, Sendable {
        case loadedProject(PendingLoadedWorkspaceProject)
        case freshDocument(PendingFreshDocumentMutation)
    }

    struct PendingLoadedWorkspaceProject: Equatable, Sendable {
        let loaded: LoadedPaintProject
        let plan: LoadedWorkspaceProjectPlan
        let presentation: LoadedWorkspacePresentation
    }

    struct PendingFreshDocumentMutation: Equatable, Sendable {
        enum Operation: Equatable, Sendable {
            case newCanvas(CanvasDimensions)
            case importedCanvas(ImportedCanvasPlan)
        }

        let contract: FreshDocumentReplacementContract
        let operation: Operation
    }

    var workspaceApplicationServices: WorkspaceApplicationServices {
        WorkspaceApplicationServices(
            documentPersistenceGateway: documentPersistenceGateway,
            documentWorkspaceClient: documentWorkspaceClient,
            uuidClient: uuidClient
        )
    }

    var workspaceBackingStoreService: WorkspaceBackingStoreService {
        workspaceApplicationServices.backingStoreService
    }

    var workspaceCatalogService: WorkspaceCatalogService {
        workspaceApplicationServices.catalogService
    }

    var workspaceArtifactService: WorkspaceArtifactService {
        workspaceApplicationServices.artifactService
    }

    var workspacePersistenceUseCase: WorkspacePersistenceUseCase {
        workspaceApplicationServices.persistenceUseCase
    }

    var workspaceCatalogUseCase: WorkspaceCatalogUseCase {
        workspaceApplicationServices.catalogUseCase
    }

    var workspaceIdentityService: WorkspaceIdentityService {
        workspaceApplicationServices.identityService
    }

    var workspaceBackingStoreGateway: WorkspaceBackingStoreGateway {
        workspaceApplicationServices.backingStoreGateway
    }

    var workspaceCatalogGateway: WorkspaceCatalogGateway {
        workspaceApplicationServices.catalogGateway
    }

    var workspaceIdentityGenerator: WorkspaceIdentityGenerator {
        workspaceApplicationServices.identityGenerator
    }

    func saveFailureFeedback(_ error: Error) -> ApplicationFeedback {
        .saveFailed(Self.optionalErrorMessage(error))
    }

    func refreshActiveTabMetadataForPersistence(
        state: inout State
    ) -> OpenDocumentTab? {
        let paperStyle = resolvedPaperStyle(for: state)
        state.workspace.updateActiveTabMetadata(
            previewImageData: state.canvas.renderSnapshot.flatMap {
                AppFeature.renderedCompositePNGData(snapshot: $0, paperStyle: paperStyle)
            } ?? documentPresentationQueryService.compositePNGData(
                paperStyle: paperStyle
            ),
            canvasSize: state.canvas.canvasSize
        )
        return state.workspace.activeTab
    }

    func requireActiveTab(
        in state: State,
    ) -> Result<OpenDocumentTab, WorkspacePersistenceFailure> {
        guard let activeTab = state.workspace.activeTab else {
            return .failure(
                WorkspacePersistenceFailure(
                    reason: .activeTabUnavailable
                )
            )
        }
        return .success(activeTab)
    }

    func documentReplacementRequest(
        state: inout State
    ) -> Result<WorkspaceDocumentReplacementRequest, WorkspacePersistenceFailure> {
        let activeTab: OpenDocumentTab
        switch requireActiveTab(in: state) {
        case let .success(tab):
            activeTab = tab
        case let .failure(failure):
            return .failure(failure)
        }
        let refreshedActiveTab = refreshActiveTabMetadataForPersistence(state: &state) ?? activeTab
        return .success(
            WorkspaceDocumentReplacementRequest(
                activeTab: refreshedActiveTab,
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
            canvasSize: state.canvas.canvasSize,
            isDirty: false,
            pane: preparedTab.pane,
            previewImageData: state.canvas.renderSnapshot.flatMap {
                AppFeature.renderedCompositePNGData(
                    snapshot: $0,
                    paperStyle: resolvedPaperStyle(for: state)
                )
            } ?? documentPresentationQueryService.compositePNGData(
                paperStyle: resolvedPaperStyle(for: state)
            )
        )
        state.workspace.appendTab(tab)
        state.workspace.activateTab(preparedTab.id, pane: preparedTab.pane)
        return .success(())
    }

    struct LoadedWorkspacePresentation: Equatable, Sendable {
        var issues: [WorkspaceProjectLoadIssue] = []
        var completion: LoadedWorkspaceProjectPlan.Completion = .none
    }

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
                .workspacePersistenceRequested(
                    .reserveNewTabBackingStore(
                        WorkspaceTabReservationRequest(
                            title: title,
                            sourceProjectURL: sourceProjectURL,
                            pane: state.workspace.focusedWorkspacePane
                        )
                    )
                )
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
        switch plan.destination {
        case let .selectedTab(tabID, pane):
            state.workspace.activateTab(tabID, pane: pane)
            applyLoadedProject(loaded, state: &state)
            activationResult = .success(())

        case .newTab:
            guard let preparedTab else {
                state.application.completeWorkspaceProjectLoad(
                    message: workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(
                            for: WorkspacePersistenceFailure(reason: .couldNotCreateTab)
                        ),
                        language: state.application.appLanguage
                    )
                )
                return .none
            }
            applyLoadedProject(loaded, state: &state)
            activationResult = activatePreparedTab(preparedTab, state: &state)

        case let .activeTab(title, sourceProjectURL):
            let existingPreviewImageData = state.workspace.activeTab?.previewImageData
            applyLoadedProject(loaded, state: &state)
            state.workspace.updateActiveTabMetadata(
                title: title,
                sourceProjectURL: sourceProjectURL,
                previewImageData: existingPreviewImageData,
                canvasSize: state.canvas.canvasSize
            )
            activationResult = .success(())
        }

        switch activationResult {
        case let .failure(failure):
            state.application.completeWorkspaceProjectLoad(
                message: workspaceFeedbackMapper.message(
                    for: workspaceFeedbackMapper.feedback(for: failure),
                    language: state.application.appLanguage
                )
            )
            return .none
        case .success:
            break
        }

        switch loadedWorkspaceFollowUpRequest(
            plan: plan,
            state: &state
        ) {
        case let .failure(failure):
            state.application.completeWorkspaceProjectLoad(
                message: workspaceFeedbackMapper.message(
                    for: workspaceFeedbackMapper.feedback(for: failure),
                    language: state.application.appLanguage
                )
            )
            return .none
        case let .success(.some(request)):
            return .merge(
                .send(.workspacePersistenceRequested(request)),
                .send(.deferredPresentationRefresh)
            )
        case .success(.none):
            applyLoadedWorkspaceSuccessEffects(
                plan.successEffects,
                state: &state
            )
            state.application.completeWorkspaceProjectLoad(
                message: workspaceFeedbackMapper.loadedWorkspaceCompletionMessage(
                    presentation: presentation,
                    language: state.application.appLanguage
                )
            )
            return .send(.deferredPresentationRefresh)
        }
    }

    func dirtyPresentationRequest(
        state: State
    ) -> WorkspacePersistenceRequest? {
        guard let activeTab = state.workspace.activeTab else {
            return nil
        }
        return .dirtyPresentationRefreshed(
            WorkspaceDirtyPresentationRequest(
                activeTab: activeTab,
                paperStyle: resolvedPaperStyle(for: state)
            )
        )
    }

    func saveActiveDocumentRequest(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?,
        trigger: SaveHistoryTrigger,
        purpose: WorkspaceDocumentSavePurpose
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        let context: WorkspaceDocumentReplacementRequest
        switch documentReplacementRequest(state: &state) {
        case let .success(request):
            context = request
        case let .failure(failure):
            return .failure(failure)
        }
        return .success(
            .saveActiveDocument(
                WorkspaceDocumentSaveRequest(
                    activeTab: context.activeTab,
                    paperStyle: context.paperStyle,
                    preferredDestinationURL: preferredDestinationURL,
                    trigger: trigger,
                    purpose: purpose
                )
            )
        )
    }

    var loadedWorkspaceFollowUpPlanner: WorkspaceLoadedProjectFollowUpPlanner {
        WorkspaceLoadedProjectFollowUpPlanner()
    }

    func loadedWorkspaceFollowUpRequest(
        plan: LoadedWorkspaceProjectPlan,
        state: inout State
    ) -> Result<WorkspacePersistenceRequest?, WorkspacePersistenceFailure> {
        if plan.followUp.marksTabDirty {
            state.workspace.setActiveTabDirty(true)
        }

        let requiresBackingStorePersistence: Bool = {
            switch plan.destination {
            case .newTab:
                return true
            case .selectedTab, .activeTab:
                return false
            }
        }()

        let shouldPersistToBackingStore = requiresBackingStorePersistence || plan.followUp.persistsToBackingStore
        guard shouldPersistToBackingStore
            || plan.followUp.persistsAutosave
            || plan.successEffects.discardedAutosaveEntryID != nil
        else {
            return .success(nil)
        }

        let context: WorkspaceDocumentReplacementRequest
        switch documentReplacementRequest(state: &state) {
        case let .success(request):
            context = request
        case let .failure(failure):
            return .failure(failure)
        }

        return .success(
            loadedWorkspaceFollowUpPlanner.request(
                plan: plan,
                context: context,
                requiresBackingStorePersistence: requiresBackingStorePersistence
            )
        )
    }

    func closeTabsPersistenceRequest(
        operation: PendingCloseOperation,
        tabIDs: [OpenDocumentTab.ID],
        state: inout State
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        var tabs = tabIDs.compactMap { state.workspace.tab(withID: $0) }
        let activeTabRequest: WorkspaceDocumentReplacementRequest?
        if let activeTabID = state.workspace.activeTabID, tabIDs.contains(activeTabID) {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                activeTabRequest = request
                if let index = tabs.firstIndex(where: { $0.id == request.activeTab.id }) {
                    tabs[index] = request.activeTab
                }
            case let .failure(failure):
                return .failure(failure)
            }
        } else {
            activeTabRequest = nil
        }
        return .success(
            .saveTabsForClose(
                WorkspaceCloseTabsSaveRequest(
                    operation: operation,
                    tabs: tabs,
                    activeTab: activeTabRequest
                )
            )
        )
    }

    func discardArtifactsRequest(
        for tabs: [OpenDocumentTab]
    ) -> WorkspacePersistenceRequest {
        .discardAutosaveArtifacts(
            WorkspaceArtifactDiscardRequest(
                tabs: tabs
            )
        )
    }

    func workspacePersistenceEffect(
        for request: WorkspacePersistenceRequest
    ) -> Effect<Action> {
        .run { [workspacePersistenceUseCase] send in
            switch workspacePersistenceUseCase.execute(request) {
            case let .success(result):
                await send(.workspacePersistenceSucceeded(result))
            case let .failure(failure):
                await send(.workspacePersistenceFailed(failure))
            }
        }
    }

    func workspaceCatalogEffect(
        for request: WorkspaceCatalogRequest
    ) -> Effect<Action> {
        .run { [workspaceCatalogUseCase] send in
            switch workspaceCatalogUseCase.execute(request) {
            case let .success(result):
                await send(.workspaceCatalogSucceeded(result))
            case let .failure(failure):
                await send(.workspaceCatalogFailed(failure))
            }
        }
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

    func handleWorkspacePersistenceRequested(
        request: WorkspacePersistenceRequest
    ) -> Effect<Action> {
        workspacePersistenceEffect(for: request)
    }

    func handleWorkspaceCatalogRequested(
        request: WorkspaceCatalogRequest
    ) -> Effect<Action> {
        workspaceCatalogEffect(for: request)
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
                previewImageData: saved.previewImageData,
                canvasSize: saved.canvasSize,
                isDirty: false
            )
            let warningMessage = workspaceFeedbackMapper.bannerMessage(
                for: saved.issues,
                language: state.application.appLanguage
            )
            if let warningMessage {
                state.application.presentBanner(warningMessage)
            } else {
                state.application.presentBanner(
                    workspaceFeedbackMapper.message(
                        for: .savedDocument(saved.savedURL.fileURL.lastPathComponent),
                        language: state.application.appLanguage
                    )
                )
            }
            switch saved.purpose {
            case .saveDocument:
                return .send(.homeProjectsLoadRequested)
            case .homeReturn:
                state.application.showHome()
                return .send(.homeProjectsLoadRequested)
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
            applyLoadedWorkspaceSuccessEffects(
                followUp.successEffects,
                state: &state
            )
            state.application.completeWorkspaceProjectLoad(
                message: workspaceFeedbackMapper.loadedWorkspaceCompletionMessage(
                    completion: followUp.successEffects.completion,
                    persistenceIssues: followUp.issues,
                    language: state.application.appLanguage
                )
            )
            return .none

        case let .tabsSavedForClose(closeResult):
            if let warningMessage = workspaceFeedbackMapper.bannerMessage(
                for: closeResult.issues,
                language: state.application.appLanguage
            ) {
                state.application.presentBanner(warningMessage)
            }
            return performCloseOperation(closeResult.operation)

        case let .autosaveArtifactsDiscarded(issues):
            if let warningMessage = workspaceFeedbackMapper.bannerMessage(
                for: issues,
                language: state.application.appLanguage
            ) {
                state.application.presentBanner(warningMessage)
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
            state.application.completeWorkspaceProjectLoad(
                message: workspaceFeedbackMapper.message(
                    for: workspaceFeedbackMapper.feedback(for: failure),
                    language: state.application.appLanguage
                )
            )
        case .some(.reserveNewTabBackingStore):
            state.workspace.pendingWorkspaceTabReservation = nil
            state.application.completeWorkspaceProjectLoad(
                message: workspaceFeedbackMapper.message(
                    for: workspaceFeedbackMapper.feedback(for: failure),
                    language: state.application.appLanguage
                )
            )
        default:
            state.application.presentBanner(
                workspaceFeedbackMapper.message(
                    for: workspaceFeedbackMapper.feedback(for: failure),
                    language: state.application.appLanguage
                )
            )
        }
        return .none
    }

    func handleWorkspaceCatalogSucceeded(
        state: inout State,
        result: WorkspaceCatalogResult
    ) -> Effect<Action> {
        switch result {
        case let .savedProjectsLoaded(projects):
            state.application.finishLoadingHomeProjects(projects)
            return .none

        case let .autosaveRecoveryItemsLoaded(items):
            state.recovery.present(items: items)
            return .none

        case let .saveHistoryEntriesLoaded(entries):
            state.saveHistory.present(entries: entries)
            return .none

        case let .savedProjectMoved(moveResult):
            if let openTabID = moveResult.openTabID {
                state.workspace.updateTab(id: openTabID, sourceProjectURL: moveResult.destinationURL)
            }
            return .send(.homeProjectsLoadRequested)

        case let .autosaveEntryDiscarded(autosaveID):
            state.recovery.removeItem(id: autosaveID)
            return .none
        }
    }

    func handleWorkspaceCatalogFailed(
        state: inout State,
        failure: WorkspaceCatalogFailure
    ) {
        let feedback = workspaceFeedbackMapper.feedback(for: failure)
        switch failure.request {
        case .loadSavedProjects:
            state.application.finishLoadingHomeProjects([])
            state.application.presentFeedback(feedback)
        case .loadAutosaveRecoveryItems:
            state.application.failHydration(
                message: workspaceFeedbackMapper.message(
                    for: feedback,
                    language: state.application.appLanguage
                )
            )
        case .loadSaveHistoryEntries:
            state.saveHistory.dismiss()
            state.application.presentFeedback(feedback)
        case .moveSavedProject, .discardAutosaveEntry:
            state.application.presentFeedback(feedback)
        }
    }

    func applyDirtyPresentation(
        state: inout State,
        updatesWorkspaceArtifacts: Bool = true
    ) -> Effect<Action> {
        let presentation = documentPresentationQueryService.lightweightPresentation()
        applyPresentation(
            PaintDocumentPresentation(
                canvasSize: presentation.canvasSize,
                activeLayerIndex: presentation.activeLayerIndex,
                layerRows: presentation.layerRows,
                layerSidebarRows: presentation.layerSidebarRows,
                renderSnapshot: nil
            ),
            state: &state
        )
        let canApplyIncrementalUpdate =
            canApplyDirtyUpdateIncrementally(
                presentation: presentation,
                state: state
            )
        if canApplyIncrementalUpdate,
           let dirtyUpdate = documentQueryGateway.consumeDirtyUpdate() {
            let activeLayerPixels = documentPresentationQueryService.pixelDataForLayer(
                presentation.activeLayerIndex
            )
            state.canvas.applyIncrementalRenderUpdate(
                dirtyUpdate,
                activeLayerIndex: presentation.activeLayerIndex,
                activeLayerPixelData: activeLayerPixels
            )
        } else {
            applyPresentation(documentPresentationQueryService.presentation(), state: &state)
        }
        guard updatesWorkspaceArtifacts else {
            return .none
        }
        state.workspace.setActiveTabDirty(true)
        state.workspace.updateActiveTabMetadata(
            previewImageData: state.canvas.renderSnapshot.flatMap {
                AppFeature.renderedCompositePNGData(
                    snapshot: $0,
                    paperStyle: resolvedPaperStyle(for: state)
                )
            } ?? documentPresentationQueryService.compositePNGData(
                paperStyle: resolvedPaperStyle(for: state)
            ),
            canvasSize: state.canvas.canvasSize
        )
        guard let request = dirtyPresentationRequest(state: state) else {
            return .none
        }
        return .send(.workspacePersistenceRequested(request))
    }

    private func canApplyDirtyUpdateIncrementally(
        presentation: PaintDocumentPresentation,
        state: State
    ) -> Bool {
        guard let currentSnapshot = state.canvas.renderSnapshot else {
            return false
        }
        let nextWidth = max(Int(presentation.canvasSize.width.rounded()), 1)
        let nextHeight = max(Int(presentation.canvasSize.height.rounded()), 1)
        guard currentSnapshot.width == nextWidth,
              currentSnapshot.height == nextHeight,
              currentSnapshot.layers.count == presentation.layerRows.count else {
            return false
        }

        let currentLayerIndices = currentSnapshot.layers.map(\.index)
        let nextLayerIndices = presentation.layerRows.map(\.index).sorted()
        guard currentLayerIndices == nextLayerIndices else {
            return false
        }

        return presentation.layerRows.contains(where: { $0.index == presentation.activeLayerIndex })
    }

    func applyLoadedWorkspaceSuccessEffects(
        _ successEffects: LoadedWorkspaceProjectPlan.SuccessEffects,
        state: inout State
    ) {
        switch successEffects.recoveryResolution {
        case .none:
            break
        case let .removeItem(id):
            state.recovery.removeItem(id: id)
        case let .completeRestore(id):
            state.recovery.completeRestore(of: id)
        case .dismiss:
            state.recovery.dismiss()
        }

        switch successEffects.saveHistoryResolution {
        case .none:
            break
        case .completeRestore:
            state.saveHistory.completeRestore()
        }
    }

    static func nextUntitledTabTitle(existingTabs: [OpenDocumentTab]) -> String {
        let untitledTabs = existingTabs.filter { $0.sourceProjectURL == nil && $0.title.hasPrefix("Untitled") }
        return untitledTabs.isEmpty ? "Untitled" : "Untitled \(untitledTabs.count + 1)"
    }
}

extension AppFeature {
    struct WorkspaceFeedbackMapper: Sendable {
        func feedback(for failure: WorkspacePersistenceFailure) -> ApplicationFeedback {
            switch failure.reason {
            case let .saveFailed(message):
                return .saveFailed(message)
            case .couldNotCreateTab:
                return .couldNotCreateTab
            case .activeTabUnavailable:
                return .saveFailed(nil)
            }
        }

        func feedback(
            for failure: WorkspaceCatalogFailure
        ) -> ApplicationFeedback {
            switch failure.reason {
            case let .loadSavedProjectsFailed(message):
                return .openFailed(message)
            case let .loadAutosaveRecoveryItemsFailed(message):
                return .autosaveRestoreFailed(message)
            case let .loadSaveHistoryEntriesFailed(message):
                return .saveHistoryRestoreFailed(message)
            case let .moveSavedProjectFailed(message):
                return .moveFailed(message)
            case let .discardAutosaveEntryFailed(message):
                return .autosaveRestoreFailed(message)
            }
        }

        func feedback(
            for failure: WorkspaceProjectLoadFailure,
            context: WorkspaceLoadFailureContext = .openDocument
        ) -> ApplicationFeedback {
            switch failure.reason {
            case let .prepareDocumentReplacementFailed(reason):
                return feedback(
                    for: WorkspacePersistenceFailure(
                        request: nil,
                        reason: reason
                    )
                )
            case let .openFailed(message):
                switch context {
                case .openDocument, .importDocument:
                    return .openFailed(message)
                case .autosaveRestore:
                    return .autosaveRestoreFailed(message)
                case .saveHistoryRestore:
                    return .saveHistoryRestoreFailed(message)
                }
            case let .importFailed(message):
                switch context {
                case .openDocument, .importDocument:
                    return .openFailed(message)
                case .autosaveRestore:
                    return .autosaveRestoreFailed(message)
                case .saveHistoryRestore:
                    return .saveHistoryRestoreFailed(message)
                }
            }
        }

        func bannerMessage(
            for issues: [WorkspacePersistenceIssue],
            language: AppLanguage
        ) -> String? {
            guard !issues.isEmpty else { return nil }
            return issues.map { message(for: $0, language: language) }.joined(separator: "\n")
        }

        func bannerMessage(
            for issues: [WorkspaceProjectLoadIssue],
            language: AppLanguage
        ) -> String? {
            guard !issues.isEmpty else { return nil }
            return issues.map { message(for: $0, language: language) }.joined(separator: "\n")
        }

        func loadedWorkspaceCompletionMessage(
            presentation: LoadedWorkspacePresentation,
            language: AppLanguage
        ) -> String? {
            if let issueBanner = bannerMessage(for: presentation.issues, language: language) {
                return issueBanner
            }
            return completionMessage(for: presentation.completion, language: language)
        }

        func loadedWorkspaceCompletionMessage(
            completion: LoadedWorkspaceProjectPlan.Completion,
            persistenceIssues: [WorkspacePersistenceIssue],
            language: AppLanguage
        ) -> String? {
            if let issueBanner = bannerMessage(for: persistenceIssues, language: language) {
                return issueBanner
            }
            return completionMessage(for: completion, language: language)
        }

        func message(
            for feedback: ApplicationFeedback?,
            language: AppLanguage
        ) -> String? {
            feedback?.message(for: language)
        }

        private func completionMessage(
            for completion: LoadedWorkspaceProjectPlan.Completion,
            language: AppLanguage
        ) -> String? {
            switch completion {
            case .none:
                return nil
            case let .openedDocument(layerCount):
                return ApplicationFeedback.openedDocument(layerCount).message(for: language)
            case .restoredSaveHistory:
                return ApplicationFeedback.restoredSaveHistory.message(for: language)
            case .restoredAutosave:
                return ApplicationFeedback.restoredAutosave.message(for: language)
            }
        }

        private func message(
            for issue: WorkspacePersistenceIssue,
            language: AppLanguage
        ) -> String {
            switch issue {
            case let .autosaveCleanupFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "保存後の自動保存クリーンアップに失敗しました"
                        : "Autosave cleanup failed after saving")
            case let .saveHistoryPersistFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "保存履歴の記録に失敗しました"
                        : "Saving to history failed")
            case let .workspaceItemRemovalFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "一時ワークスペース項目の削除に失敗しました"
                        : "Temporary workspace cleanup failed")
            case let .autosaveEntryDiscardFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "自動保存エントリの破棄に失敗しました"
                        : "Autosave entry cleanup failed")
            }
        }

        private func message(
            for issue: WorkspaceProjectLoadIssue,
            language: AppLanguage
        ) -> String {
            switch issue {
            case let .workspaceItemRemovalFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "読み込み後の一時ワークスペース項目の削除に失敗しました"
                        : "Temporary workspace cleanup failed after loading")
            case let .importedStagingCleanupFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "読み込み後の一時インポートデータの削除に失敗しました"
                        : "Imported staging cleanup failed after loading")
            }
        }
    }

    enum WorkspaceLoadFailureContext: Sendable {
        case openDocument
        case importDocument
        case autosaveRestore
        case saveHistoryRestore
    }

    var workspaceFeedbackMapper: WorkspaceFeedbackMapper {
        WorkspaceFeedbackMapper()
    }
}
