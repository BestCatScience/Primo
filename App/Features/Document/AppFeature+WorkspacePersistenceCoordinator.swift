import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoWorkspaceDomain

extension AppFeature {
    typealias WorkspacePersistenceIssue = PrimoWorkspaceDomain.WorkspacePersistenceIssue
    typealias WorkspacePersistenceFailureReason = PrimoWorkspaceDomain.WorkspacePersistenceFailureReason
    typealias WorkspacePersistenceFailure = PrimoWorkspaceDomain.WorkspacePersistenceFailure
    typealias WorkspaceDirtyPresentationRequest = PrimoWorkspaceDomain.WorkspaceDirtyPresentationRequest
    typealias WorkspaceDocumentSavePurpose = PrimoWorkspaceDomain.WorkspaceDocumentSavePurpose
    typealias WorkspaceDocumentSaveRequest = PrimoWorkspaceDomain.WorkspaceDocumentSaveRequest
    typealias WorkspaceDocumentSaveResult = PrimoWorkspaceDomain.WorkspaceDocumentSaveResult
    typealias WorkspaceDocumentReplacementRequest = PrimoWorkspaceDomain.WorkspaceDocumentReplacementRequest
    typealias LoadedWorkspaceFollowUpPersistenceRequest = PrimoWorkspaceDomain.LoadedWorkspaceFollowUpPersistenceRequest
    typealias LoadedWorkspaceFollowUpPersistenceResult = PrimoWorkspaceDomain.LoadedWorkspaceFollowUpPersistenceResult
    typealias WorkspaceCloseTabsSaveRequest = PrimoWorkspaceDomain.WorkspaceCloseTabsSaveRequest
    typealias WorkspaceCloseTabsSaveResult = PrimoWorkspaceDomain.WorkspaceCloseTabsSaveResult
    typealias WorkspaceArtifactDiscardRequest = PrimoWorkspaceDomain.WorkspaceArtifactDiscardRequest
    typealias WorkspaceTabReservationRequest = PrimoWorkspaceDomain.WorkspaceTabReservationRequest
    typealias WorkspaceSavedProjectMoveRequest = PrimoWorkspaceDomain.WorkspaceSavedProjectMoveRequest
    typealias WorkspaceSavedProjectMoveResult = PrimoWorkspaceDomain.WorkspaceSavedProjectMoveResult
    typealias WorkspaceAutosaveEntryDiscardRequest = PrimoWorkspaceDomain.WorkspaceAutosaveEntryDiscardRequest
    typealias WorkspaceSaveHistoryLoadRequest = PrimoWorkspaceDomain.WorkspaceSaveHistoryLoadRequest
    typealias WorkspaceCatalogFailureReason = PrimoWorkspaceDomain.WorkspaceCatalogFailureReason
    typealias WorkspaceCatalogFailure = PrimoWorkspaceDomain.WorkspaceCatalogFailure
    typealias WorkspacePersistenceRequest = PrimoWorkspaceDomain.WorkspacePersistenceRequest
    typealias WorkspacePersistenceResult = PrimoWorkspaceDomain.WorkspacePersistenceResult
    typealias WorkspaceCatalogRequest = PrimoWorkspaceDomain.WorkspaceCatalogRequest
    typealias WorkspaceCatalogResult = PrimoWorkspaceDomain.WorkspaceCatalogResult
    typealias LoadedWorkspaceProjectPlan = PrimoWorkspaceDomain.LoadedWorkspaceProjectPlan
    typealias WorkspacePersistenceUseCase = PrimoWorkspaceDomain.WorkspacePersistenceUseCase
    typealias WorkspaceCatalogUseCase = PrimoWorkspaceDomain.WorkspaceCatalogUseCase

    struct WorkspaceBackingStoreService: Sendable {
        let paintDocumentClient: PaintDocumentClient
        let documentWorkspaceClient: DocumentWorkspaceClient

        func saveProject(
            at fileURL: URL,
            paperStyle: CanvasPaperStyle
        ) throws {
            try paintDocumentClient.saveProject(fileURL, paperStyle)
        }

        func persistProjectSnapshot(
            _ sourceURL: DocumentProjectPath,
            preferredDestinationURL: DocumentProjectPath?
        ) throws -> DocumentProjectPath {
            try documentWorkspaceClient.persistProjectSnapshot(
                sourceURL,
                preferredDestinationURL
            )
        }

        func createTabBackingStoreURL(_ tabID: OpenDocumentTab.ID) throws -> DocumentProjectPath {
            try documentWorkspaceClient.createTabBackingStoreURL(tabID)
        }

        func persistAutosaveSnapshot(
            _ backingStoreURL: DocumentProjectPath,
            _ tab: OpenDocumentTab
        ) throws {
            try documentWorkspaceClient.persistAutosaveSnapshot(backingStoreURL, tab)
        }

        func discardAutosaveSnapshot(_ tab: OpenDocumentTab) throws {
            try documentWorkspaceClient.discardAutosaveSnapshot(tab)
        }

        func persistSaveHistorySnapshot(
            _ backingStoreURL: DocumentProjectPath,
            _ tab: OpenDocumentTab,
            _ trigger: SaveHistoryTrigger
        ) throws {
            try documentWorkspaceClient.persistSaveHistorySnapshot(backingStoreURL, tab, trigger)
        }

        func removeWorkspaceItem(_ url: DocumentProjectPath) throws {
            try documentWorkspaceClient.removeWorkspaceItem(url)
        }
    }

    struct WorkspaceCatalogService: Sendable {
        let documentWorkspaceClient: DocumentWorkspaceClient

        func loadSavedProjects() throws -> [SavedProjectSummary] {
            try documentWorkspaceClient.loadSavedProjects()
        }

        func moveSavedProject(
            _ url: DocumentProjectPath,
            to relativeFolderPath: RelativeProjectFolderPath?
        ) throws -> DocumentProjectPath {
            try documentWorkspaceClient.moveSavedProject(url, relativeFolderPath)
        }

        func loadAutosaveRecoveryItems() throws -> [AutosaveRecoveryItem] {
            try documentWorkspaceClient.loadAutosaveRecoveryItems()
        }

        func discardAutosaveEntry(_ id: WorkspaceItemID) throws {
            try documentWorkspaceClient.discardAutosaveEntry(id)
        }

        func loadSaveHistoryEntries(for tab: OpenDocumentTab) throws -> [SaveHistoryEntry] {
            try documentWorkspaceClient.loadSaveHistoryEntries(tab)
        }
    }

    struct WorkspaceArtifactService: Sendable {
        let documentWorkspaceClient: DocumentWorkspaceClient

        func timelapseTemporaryDirectory() -> URL {
            documentWorkspaceClient.timelapseTemporaryDirectory()
        }

        func writePNGToTemporaryDirectory(_ data: Data) throws -> URL {
            try documentWorkspaceClient.writePNGToTemporaryDirectory(data)
        }
    }

    struct WorkspaceIdentityService: Sendable {
        let uuidClient: UUIDClient

        func generateTabID() -> OpenDocumentTab.ID {
            uuidClient.generate()
        }
    }

    typealias PreparedWorkspaceTab = PrimoWorkspaceDomain.PreparedWorkspaceTab

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

    var workspaceBackingStoreService: WorkspaceBackingStoreService {
        WorkspaceBackingStoreService(
            paintDocumentClient: paintDocumentClient,
            documentWorkspaceClient: documentWorkspaceClient
        )
    }

    var workspaceCatalogService: WorkspaceCatalogService {
        WorkspaceCatalogService(
            documentWorkspaceClient: documentWorkspaceClient
        )
    }

    var workspaceArtifactService: WorkspaceArtifactService {
        WorkspaceArtifactService(
            documentWorkspaceClient: documentWorkspaceClient
        )
    }

    var workspacePersistenceUseCase: WorkspacePersistenceUseCase {
        WorkspacePersistenceUseCase(
            workspaceBackingStoreService: workspaceBackingStoreService,
            workspaceCatalogService: workspaceCatalogService,
            workspaceIdentityService: workspaceIdentityService
        )
    }

    var workspaceCatalogUseCase: WorkspaceCatalogUseCase {
        WorkspaceCatalogUseCase(
            workspaceCatalogService: workspaceCatalogService
        )
    }

    var workspaceIdentityService: WorkspaceIdentityService {
        WorkspaceIdentityService(
            uuidClient: uuidClient
        )
    }

    func saveFailureFeedback(_ error: Error) -> ApplicationFeedback {
        .saveFailed(Self.optionalErrorMessage(error))
    }

    func refreshActiveTabMetadataForPersistence(
        state: inout State
    ) -> OpenDocumentTab? {
        let paperStyle = resolvedPaperStyle(for: state)
        state.workspace.updateActiveTabMetadata(
            previewImageData: documentPresentationQueryService.compositePNGData(
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
            previewImageData: documentPresentationQueryService.compositePNGData(
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
            applyLoadedProject(loaded, state: &state)
            state.workspace.updateActiveTabMetadata(
                title: title,
                sourceProjectURL: sourceProjectURL,
                previewImageData: documentPresentationQueryService.compositePNGData(
                    paperStyle: resolvedPaperStyle(for: state)
                ),
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
            return .send(.workspacePersistenceRequested(request))
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
            return .none
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

    struct LoadedWorkspaceFollowUpPlanner: Sendable {
        func request(
            plan: LoadedWorkspaceProjectPlan,
            context: WorkspaceDocumentReplacementRequest,
            requiresBackingStorePersistence: Bool
        ) -> WorkspacePersistenceRequest? {
            let shouldPersistToBackingStore = requiresBackingStorePersistence || plan.followUp.persistsToBackingStore
            guard shouldPersistToBackingStore
                || plan.followUp.persistsAutosave
                || plan.successEffects.discardedAutosaveEntryID != nil
            else {
                return nil
            }

            return .loadedWorkspaceFollowUp(
                LoadedWorkspaceFollowUpPersistenceRequest(
                    activeTab: context.activeTab,
                    paperStyle: context.paperStyle,
                    persistsToBackingStore: shouldPersistToBackingStore,
                    persistsAutosave: plan.followUp.persistsAutosave,
                    successEffects: plan.successEffects
                )
            )
        }
    }

    var loadedWorkspaceFollowUpPlanner: LoadedWorkspaceFollowUpPlanner {
        LoadedWorkspaceFollowUpPlanner()
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

    func applyDirtyPresentation(state: inout State) -> Effect<Action> {
        applyPresentation(documentPresentationQueryService.presentation(), state: &state)
        state.workspace.setActiveTabDirty(true)
        state.workspace.updateActiveTabMetadata(
            previewImageData: documentPresentationQueryService.compositePNGData(
                paperStyle: resolvedPaperStyle(for: state)
            ),
            canvasSize: state.canvas.canvasSize
        )
        guard let request = dirtyPresentationRequest(state: state) else {
            return .none
        }
        return .send(.workspacePersistenceRequested(request))
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

extension PrimoWorkspaceDomain.WorkspacePersistenceUseCase {
    init(
        workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService,
        workspaceCatalogService: AppFeature.WorkspaceCatalogService,
        workspaceIdentityService: AppFeature.WorkspaceIdentityService
    ) {
        self.init(
            workspaceBackingStore: WorkspaceBackingStoreGateway(
                saveProject: { fileURL, paperStyle in
                    try workspaceBackingStoreService.saveProject(at: fileURL, paperStyle: paperStyle)
                },
                persistProjectSnapshot: { sourceURL, preferredDestinationURL in
                    try workspaceBackingStoreService.persistProjectSnapshot(
                        sourceURL,
                        preferredDestinationURL: preferredDestinationURL
                    )
                },
                createTabBackingStoreURL: { tabID in
                    try workspaceBackingStoreService.createTabBackingStoreURL(tabID)
                },
                persistAutosaveSnapshot: { backingStoreURL, tab in
                    try workspaceBackingStoreService.persistAutosaveSnapshot(backingStoreURL, tab)
                },
                discardAutosaveSnapshot: { tab in
                    try workspaceBackingStoreService.discardAutosaveSnapshot(tab)
                },
                persistSaveHistorySnapshot: { backingStoreURL, tab, trigger in
                    try workspaceBackingStoreService.persistSaveHistorySnapshot(
                        backingStoreURL,
                        tab,
                        trigger
                    )
                },
                removeWorkspaceItem: { url in
                    try workspaceBackingStoreService.removeWorkspaceItem(url)
                }
            ),
            workspaceCatalog: WorkspaceCatalogGateway(
                loadSavedProjects: {
                    try workspaceCatalogService.loadSavedProjects()
                },
                moveSavedProject: { sourceURL, relativeFolderPath in
                    try workspaceCatalogService.moveSavedProject(sourceURL, to: relativeFolderPath)
                },
                loadAutosaveRecoveryItems: {
                    try workspaceCatalogService.loadAutosaveRecoveryItems()
                },
                discardAutosaveEntry: { autosaveID in
                    try workspaceCatalogService.discardAutosaveEntry(autosaveID)
                },
                loadSaveHistoryEntries: { activeTab in
                    try workspaceCatalogService.loadSaveHistoryEntries(for: activeTab)
                }
            ),
            identityGenerator: WorkspaceIdentityGenerator(
                generateTabID: {
                    workspaceIdentityService.generateTabID()
                }
            )
        )
    }
}

extension PrimoWorkspaceDomain.WorkspaceCatalogUseCase {
    init(workspaceCatalogService: AppFeature.WorkspaceCatalogService) {
        self.init(
            workspaceCatalog: WorkspaceCatalogGateway(
                loadSavedProjects: {
                    try workspaceCatalogService.loadSavedProjects()
                },
                moveSavedProject: { sourceURL, relativeFolderPath in
                    try workspaceCatalogService.moveSavedProject(sourceURL, to: relativeFolderPath)
                },
                loadAutosaveRecoveryItems: {
                    try workspaceCatalogService.loadAutosaveRecoveryItems()
                },
                discardAutosaveEntry: { autosaveID in
                    try workspaceCatalogService.discardAutosaveEntry(autosaveID)
                },
                loadSaveHistoryEntries: { activeTab in
                    try workspaceCatalogService.loadSaveHistoryEntries(for: activeTab)
                }
            )
        )
    }
}
