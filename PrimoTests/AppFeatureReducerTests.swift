import ComposableArchitecture
import Foundation
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure
import XCTest
@testable import Primo

@MainActor
final class AppFeatureReducerTests: XCTestCase {
    private let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func testHomeReturnRequestedEmitsWorkspacePersistenceRequest() async {
        let previewData = Data([0x01, 0x02, 0x03])
        let activeTab = OpenDocumentTab.testValue()
        let refreshedTab = OpenDocumentTab.testValue(previewImageData: previewData)
        let store = TestStore(
            initialState: {
                var state = AppFeature.State()
                state.application.showsHome = false
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            AppFeature()
        } withDependencies: {
            $0.documentRuntimeComposition = .stub(
                exportGateway: .stub(
                    compositePNGData: { _ in previewData }
                )
            )
            $0.documentWorkspaceClient = .stub()
        }
        store.exhaustivity = .off

        await store.send(.homeReturnRequested)
        await store.receive(
            .workspacePersistenceRequested(
                .saveActiveDocument(
                    AppFeature.WorkspaceDocumentSaveRequest(
                        activeTab: refreshedTab,
                        paperStyle: .default,
                        preferredDestinationURL: activeTab.sourceProjectURL,
                        trigger: .autoSave,
                        purpose: .homeReturn
                    )
                )
            )
        )
    }

    func testPendingCloseSaveConfirmedEmitsClosePersistenceRequest() async {
        let previewData = Data([0x0A])
        let activeTab = OpenDocumentTab.testValue()
        let refreshedTab = OpenDocumentTab.testValue(previewImageData: previewData)
        let store = TestStore(
            initialState: {
                var state = AppFeature.State()
                state.application.showsHome = false
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                state.workspace.pendingCloseConfirmation = PendingCloseConfirmationState(
                    operation: .tab(activeTab.id),
                    tabIDs: [activeTab.id],
                    tabTitles: [activeTab.title]
                )
                return state
            }()
        ) {
            AppFeature()
        } withDependencies: {
            $0.documentRuntimeComposition = .stub(
                exportGateway: .stub(
                    compositePNGData: { _ in previewData }
                )
            )
            $0.documentWorkspaceClient = .stub()
        }
        store.exhaustivity = .off

        await store.send(.pendingCloseSaveConfirmed) {
            $0.workspace.pendingCloseConfirmation = nil
            $0.workspace.openTabs = [refreshedTab]
        }
        await store.receive(
            .workspacePersistenceRequested(
                .saveTabsForClose(
                    AppFeature.WorkspaceCloseTabsSaveRequest(
                        operation: .tab(activeTab.id),
                        tabs: [refreshedTab],
                        activeTab: AppFeature.WorkspaceDocumentReplacementRequest(
                            activeTab: refreshedTab,
                            paperStyle: .default
                        )
                    )
                )
            )
        )
    }

    func testLoadedWorkspaceFollowUpSuccessCompletesHydration() {
        let feature = AppFeature()
        var state = AppFeature.State()
        state.application.beginHydration()

        _ = feature.handleWorkspacePersistenceSucceeded(
            state: &state,
            result: .loadedWorkspaceFollowUpApplied(
                AppFeature.LoadedWorkspaceFollowUpPersistenceResult(
                    successEffects: .init(
                        completion: .restoredAutosave
                    ),
                    issues: []
                )
            )
        )

        XCTAssertFalse(state.application.isHydrating)
        XCTAssertFalse(state.application.showsHome)
        XCTAssertEqual(
            state.application.bannerMessage,
            AppFeature.ApplicationFeedback.restoredAutosave.message(for: .japanese)
        )
    }

    func testLoadedWorkspaceFollowUpFailureSurfacesFeedback() {
        let feature = AppFeature()
        var state = AppFeature.State()
        state.application.beginHydration()

        _ = feature.handleWorkspacePersistenceFailed(
            state: &state,
            failure: AppFeature.WorkspacePersistenceFailure(
                request: .loadedWorkspaceFollowUp(
                    AppFeature.LoadedWorkspaceFollowUpPersistenceRequest(
                        activeTab: .testValue(),
                        paperStyle: .default,
                        persistsToBackingStore: true,
                        persistsAutosave: false,
                        successEffects: .init()
                    )
                ),
                reason: .saveFailed("workspace follow-up failed")
            )
        )

        XCTAssertFalse(state.application.isHydrating)
        XCTAssertFalse(state.application.showsHome)
        XCTAssertEqual(state.application.bannerMessage, "workspace follow-up failed")
    }

    func testMoveSavedProjectUsesWorkspaceCatalogRequest() async {
        let sourceURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/source.atelier"))
        let destinationURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/moved.atelier"))
        let activeTab = OpenDocumentTab.testValue(sourceProjectURL: sourceURL)
        let store = TestStore(
            initialState: {
                var state = AppFeature.State()
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            AppFeature()
        } withDependencies: {
            $0.documentWorkspaceClient = .stub(
                moveSavedProject: { _, _ in destinationURL }
            )
        }
        store.exhaustivity = .off

        await store.send(.moveSavedProject(sourceURL, nil))
        await store.receive(
            .workspaceCatalogRequested(
                .moveSavedProject(
                    AppFeature.WorkspaceSavedProjectMoveRequest(
                        sourceURL: sourceURL,
                        relativeFolderPath: nil,
                        openTabID: activeTab.id
                    )
                )
            )
        )
        await store.receive(
            .workspaceCatalogSucceeded(
                .savedProjectMoved(
                    AppFeature.WorkspaceSavedProjectMoveResult(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        openTabID: activeTab.id
                    )
                )
            )
        ) {
            $0.workspace.openTabs[0].sourceProjectURL = destinationURL
        }
        await store.receive(.homeProjectsLoadRequested)
    }

    func testAutosaveRecoveryDiscardRemovesStateOnlyAfterCatalogSuccess() async {
        let autosaveID = WorkspaceItemID.testValue("autosave-1")
        let autosaveItem = AutosaveRecoveryItem(
            id: autosaveID,
            title: "Recovered",
            sourceProjectURL: nil,
            autosaveProjectURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/autosave.atelier")),
            updatedAt: Date(timeIntervalSince1970: 0),
            previewImageData: nil
        )
        let store = TestStore(
            initialState: {
                var state = AppFeature.State()
                state.recovery.items = [autosaveItem]
                state.recovery.isPresented = true
                return state
            }()
        ) {
            AppFeature()
        } withDependencies: {
            $0.documentWorkspaceClient = .stub(
                discardAutosaveEntry: { _ in }
            )
        }
        store.exhaustivity = .off

        await store.send(.autosaveRecoveryDiscardRequested(autosaveID))
        XCTAssertEqual(store.state.recovery.items, [autosaveItem])
        await store.receive(
            .workspaceCatalogRequested(
                .discardAutosaveEntry(
                    AppFeature.WorkspaceAutosaveEntryDiscardRequest(
                        autosaveID: autosaveID
                    )
                )
            )
        )
        await store.receive(
            .workspaceCatalogSucceeded(.autosaveEntryDiscarded(autosaveID))
        ) {
            $0.recovery.items = []
        }
    }

    func testHomeProjectsLoadUsesWorkspaceCatalogRequest() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        store.exhaustivity = .off

        await store.send(.homeProjectsLoadRequested) {
            $0.application.isLoadingHomeProjects = true
        }
        await store.receive(.workspaceCatalogRequested(.loadSavedProjects))
    }

    func testAutosaveRecoveryLoadUsesWorkspaceCatalogRequest() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        store.exhaustivity = .off

        await store.send(.autosaveRecoveryLoadRequested)
        await store.receive(.workspaceCatalogRequested(.loadAutosaveRecoveryItems))
    }

    func testSaveHistoryLoadUsesWorkspaceCatalogRequest() async {
        let activeTab = OpenDocumentTab.testValue()
        let store = TestStore(
            initialState: {
                var state = AppFeature.State()
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            AppFeature()
        }
        store.exhaustivity = .off

        await store.send(.saveHistoryRequested) {
            $0.saveHistory.isPresented = true
        }
        await store.receive(
            .workspaceCatalogRequested(
                .loadSaveHistoryEntries(
                    AppFeature.WorkspaceSaveHistoryLoadRequest(
                        activeTab: activeTab
                    )
                )
            )
        )
    }

    func testFreshDocumentPreparationRequestsReservation() async {
        let dimensions = AppFeature.CanvasDimensions(width: 640, height: 480)!
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        store.exhaustivity = .off

        await store.send(.newCanvasPreparationCompleted(dimensions)) {
            $0.workspace.pendingWorkspaceTabReservation = .freshDocument(
                AppFeature.PendingFreshDocumentMutation(
                    contract: AppFeature.FreshDocumentReplacementContract(
                        canvasSize: dimensions.size,
                        tabTitle: "Untitled"
                    ),
                    operation: .newCanvas(dimensions)
                )
            )
        }
        await store.receive(
            .workspacePersistenceRequested(
                .reserveNewTabBackingStore(
                    AppFeature.WorkspaceTabReservationRequest(
                        title: "Untitled",
                        sourceProjectURL: nil,
                        pane: .primary
                    )
                )
            )
        )
    }

    func testOpenDocumentLoadedRequestsReservationBeforeAppendingNewTab() async {
        let sourceURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/imported.atelier"))
        let reservedID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!
        let loaded = LoadedPaintProject.testValue()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.uuidClient = UUIDClient(generate: { reservedID })
            $0.documentWorkspaceClient = .stub(
                createTabBackingStoreURL: { id in
                    DocumentProjectPath(URL(fileURLWithPath: "/tmp/\(id.uuidString).atelier"))
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.openDocumentLoaded(loaded, sourceURL, [])) {
            $0.workspace.pendingWorkspaceTabReservation = .loadedProject(
                AppFeature.PendingLoadedWorkspaceProject(
                    loaded: loaded,
                    plan: AppFeature.LoadedWorkspaceProjectPlan(
                        destination: .newTab(
                            title: sourceURL.displayName,
                            sourceProjectURL: sourceURL
                        ),
                        successEffects: .init(
                            completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                        )
                    ),
                    presentation: AppFeature.LoadedWorkspacePresentation(
                        completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                    )
                )
            )
        }
        XCTAssertTrue(store.state.workspace.openTabs.isEmpty)
        await store.receive(
            .workspacePersistenceRequested(
                .reserveNewTabBackingStore(
                    AppFeature.WorkspaceTabReservationRequest(
                        title: sourceURL.displayName,
                        sourceProjectURL: sourceURL,
                        pane: .primary
                    )
                )
            )
        )
    }

    func testLoadedWorkspaceFollowUpIssuesOverrideSuccessBanner() {
        let feature = AppFeature()
        var state = AppFeature.State()
        state.application.beginHydration()

        _ = feature.handleWorkspacePersistenceSucceeded(
            state: &state,
            result: .loadedWorkspaceFollowUpApplied(
                AppFeature.LoadedWorkspaceFollowUpPersistenceResult(
                    successEffects: .init(
                        completion: .restoredAutosave
                    ),
                    issues: [.autosaveEntryDiscardFailed("discard failed")]
                )
            )
        )

        XCTAssertFalse(state.application.isHydrating)
        XCTAssertEqual(state.application.bannerMessage, "discard failed")
    }

    func testWorkspaceCatalogFailureUsesReasonBasedMapper() {
        let feature = AppFeature()
        var state = AppFeature.State()
        state.application.beginHydration()

        feature.handleWorkspaceCatalogFailed(
            state: &state,
            failure: AppFeature.WorkspaceCatalogFailure(
                request: .loadAutosaveRecoveryItems,
                reason: .loadAutosaveRecoveryItemsFailed("catalog load failed")
            )
        )

        XCTAssertFalse(state.application.isHydrating)
        XCTAssertEqual(state.application.bannerMessage, "catalog load failed")
    }

    func testArchitectureContractsExposeLayeredProtocolVocabulary() throws {
        let contents = try String(
            contentsOf: repoRoot.appendingPathComponent("App/Support/OperationContracts.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(contents.contains("protocol DomainCommand"))
        XCTAssertTrue(contents.contains("protocol DomainOutcome"))
        XCTAssertTrue(contents.contains("protocol FailureReason"))
        XCTAssertTrue(contents.contains("protocol DomainIssue"))
    }

    func testDocumentWorkspaceInfrastructureDoesNotReferencePresentationFeedback() throws {
        let contents = try String(
            contentsOf: repoRoot.appendingPathComponent("App/Features/Document/DocumentWorkspaceClient.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(contents.contains("ApplicationFeedback"))
        XCTAssertFalse(contents.contains("message(for:"))
    }

    func testCanvasLifecycleFailureNoLongerEmbedsPresentationFeedback() throws {
        let contents = try String(
            contentsOf: repoRoot.appendingPathComponent("App/Features/Document/AppFeature+CanvasLifecycleWorkflow.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(contents.contains("var feedback: ApplicationFeedback"))
        XCTAssertTrue(contents.contains("CanvasLifecycleFeedbackMapper"))
    }

    func testWorkspaceShellFeatureHomeProjectsLoadRoutesToCatalogRequest() async {
        let store = TestStore(initialState: AppFeature.State()) {
            WorkspaceShellFeature()
        }
        store.exhaustivity = .off

        await store.send(.homeProjectsLoadRequested) {
            $0.application.isLoadingHomeProjects = true
        }
        await store.receive(.workspaceCatalogRequested(.loadSavedProjects))
    }

    func testDocumentEditorFeatureUndoRoutesToHistoryMutation() async {
        let store = TestStore(
            initialState: {
                var state = AppFeature.State()
                state.application.showsHome = false
                return state
            }()
        ) {
            DocumentEditorFeature()
        } withDependencies: {
            $0.documentHistoryGateway = .stub(undo: { .success(()) })
        }
        store.exhaustivity = .off

        await store.send(.undoRequested)
        await store.receive(.refreshPresentationRequested)
    }

    func testAssetImportExportFeatureSaveHistoryRoutesToCatalogRequest() async {
        let activeTab = OpenDocumentTab.testValue()
        let store = TestStore(
            initialState: {
                var state = AppFeature.State()
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            AssetImportExportFeature()
        }
        store.exhaustivity = .off

        await store.send(.saveHistoryRequested)
        await store.receive(
            .workspaceCatalogRequested(
                .loadSaveHistoryEntries(
                    AppFeature.WorkspaceSaveHistoryLoadRequest(activeTab: activeTab)
                )
            )
        )
    }
}
