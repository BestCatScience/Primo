import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure
import XCTest
@testable import Primo

@MainActor
final class PrimoRootFeatureIntegrationTests: XCTestCase {
    private let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func previewSurface() -> DocumentCompositeSurface {
        DocumentCompositeSurface(
            width: 1,
            height: 1,
            pixelData: Data([0x01, 0x02, 0x03, 0xFF])
        )
    }

    func testHomeReturnRequestedEmitsWorkspacePersistenceRequest() async {
        let previewData = DocumentRasterImageService.pngData(from: previewSurface())
        let activeTab = OpenDocumentTab.testValue()
        let refreshedTab = OpenDocumentTab.testValue(previewImageData: previewData)
        let store = TestStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.showsHome = false
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            PrimoRootFeature()
        } withDependencies: {
            $0.documentRuntimeComposition = .stub(
                exportGateway: .stub(
                    compositeSurface: { _ in self.previewSurface() }
                )
            )
            $0.documentWorkspaceClient = .stub()
        }
        store.exhaustivity = .off

        await store.send(.workspace(.homeReturnRequested))
        await store.receive(
            .workspacePersistenceRequested(
                .saveActiveDocument(
                    DocumentFeatureRuntimeReducer.WorkspaceDocumentSaveRequest(
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

    func testBackgroundScenePersistsDirtyActiveTabAutosave() async {
        let previewSurface = previewSurface()
        let activeTab = OpenDocumentTab.testValue(isDirty: true)
        var refreshedTab = activeTab
        refreshedTab.previewSurface = previewSurface
        let store = TestStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.showsHome = false
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            PrimoRootFeature()
        } withDependencies: {
            $0.documentRuntimeComposition = .stub(
                exportGateway: .stub(
                    compositeSurface: { _ in previewSurface }
                )
            )
            $0.documentWorkspaceClient = .stub()
            $0.workspaceApplicationWorkflowService = WorkspaceApplicationWorkflowService()
            $0.uuidClient = UUIDClient(generate: {
                UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
            })
        }
        store.exhaustivity = .off

        await store.send(.application(.scenePhaseChanged(.background))) {
            $0.workspace.openTabs = [refreshedTab]
        }
        await store.receive(
            .workspacePersistenceRequested(
                .dirtyPresentationRefreshed(
                    DocumentFeatureRuntimeReducer.WorkspaceDirtyPresentationRequest(
                        activeTab: refreshedTab,
                        paperStyle: .default
                    )
                )
            )
        )
    }

    func testPendingCloseSaveConfirmedEmitsClosePersistenceRequest() async {
        let previewData = DocumentRasterImageService.pngData(from: previewSurface())
        let activeTab = OpenDocumentTab.testValue()
        let refreshedTab = OpenDocumentTab.testValue(previewImageData: previewData)
        let store = TestStore(
            initialState: {
                var state = PrimoRootFeature.State()
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
            PrimoRootFeature()
        } withDependencies: {
            $0.documentRuntimeComposition = .stub(
                exportGateway: .stub(
                    compositeSurface: { _ in self.previewSurface() }
                )
            )
            $0.documentWorkspaceClient = .stub()
        }
        store.exhaustivity = .off

        await store.send(.workspace(.pendingCloseSaveConfirmed)) {
            $0.workspace.pendingCloseConfirmation = nil
            $0.workspace.openTabs = [refreshedTab]
        }
        await store.receive(
            .workspacePersistenceRequested(
                .saveTabsForClose(
                    DocumentFeatureRuntimeReducer.WorkspaceCloseTabsSaveRequest(
                        operation: .tab(activeTab.id),
                        tabs: [refreshedTab],
                        activeTab: DocumentFeatureRuntimeReducer.WorkspaceDocumentReplacementRequest(
                            activeTab: refreshedTab,
                            paperStyle: .default
                        )
                    )
                )
            )
        )
    }

    func testLoadedWorkspaceFollowUpSuccessCompletesHydration() {
        let feature = DocumentFeatureRuntimeReducer()
        var state = PrimoRootFeature.State()
        state.application.beginHydration()

        _ = feature.handleWorkspacePersistenceSucceeded(
            state: &state,
            result: .loadedWorkspaceFollowUpApplied(
                DocumentFeatureRuntimeReducer.LoadedWorkspaceFollowUpPersistenceResult(
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
            ApplicationFeature.Feedback.restoredAutosave.message(for: .japanese)
        )
    }

    func testLoadedWorkspaceFollowUpFailureSurfacesFeedback() {
        let feature = DocumentFeatureRuntimeReducer()
        var state = PrimoRootFeature.State()
        state.application.beginHydration()

        _ = feature.handleWorkspacePersistenceFailed(
            state: &state,
            failure: DocumentFeatureRuntimeReducer.WorkspacePersistenceFailure(
                request: .loadedWorkspaceFollowUp(
                    DocumentFeatureRuntimeReducer.LoadedWorkspaceFollowUpPersistenceRequest(
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
                var state = PrimoRootFeature.State()
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            PrimoRootFeature()
        } withDependencies: {
            $0.documentWorkspaceClient = .stub(
                moveSavedProject: { _, _ in destinationURL }
            )
        }
        store.exhaustivity = .off

        await store.send(.workspace(.moveSavedProject(sourceURL, nil)))
        await store.receive(
            .workspaceCatalogRequested(
                .moveSavedProject(
                    DocumentFeatureRuntimeReducer.WorkspaceSavedProjectMoveRequest(
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
                    DocumentFeatureRuntimeReducer.WorkspaceSavedProjectMoveResult(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        openTabID: activeTab.id
                    )
                )
            )
        ) {
            $0.workspace.openTabs[0].sourceProjectURL = destinationURL
        }
        await store.receive(.application(.homeProjectsLoadRequested))
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
                var state = PrimoRootFeature.State()
                state.recovery.items = [autosaveItem]
                state.recovery.isPresented = true
                return state
            }()
        ) {
            PrimoRootFeature()
        } withDependencies: {
            $0.documentWorkspaceClient = .stub(
                discardAutosaveEntry: { _ in }
            )
        }
        store.exhaustivity = .off

        await store.send(.application(.autosaveRecoveryDiscardRequested(autosaveID)))
        XCTAssertEqual(store.state.recovery.items, [autosaveItem])
        await store.receive(
            .workspaceCatalogRequested(
                .discardAutosaveEntry(
                    DocumentFeatureRuntimeReducer.WorkspaceAutosaveEntryDiscardRequest(
                        autosaveID: autosaveID
                    )
                )
            )
        )
        await store.receive(
            .workspace(.catalogSucceeded(.autosaveEntryDiscarded(autosaveID)))
        ) {
            $0.recovery.items = []
        }
    }

    func testHomeProjectsLoadUsesWorkspaceCatalogRequest() async {
        let store = TestStore(initialState: PrimoRootFeature.State()) {
            PrimoRootFeature()
        }
        store.exhaustivity = .off

        await store.send(.application(.homeProjectsLoadRequested)) {
            $0.application.isLoadingHomeProjects = true
        }
        await store.receive(.workspace(.catalogRequested(.loadSavedProjects)))
    }

    func testAutosaveRecoveryLoadUsesWorkspaceCatalogRequest() async {
        let store = TestStore(initialState: PrimoRootFeature.State()) {
            PrimoRootFeature()
        }
        store.exhaustivity = .off

        await store.send(.application(.autosaveRecoveryLoadRequested))
        await store.receive(.workspace(.catalogRequested(.loadAutosaveRecoveryItems)))
    }

    func testAutosaveRecoveryRestoreLoadsSelectedAutosaveProject() async {
        let autosaveID = WorkspaceItemID.testValue("autosave-restore")
        let autosaveURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/autosave-restore.atelier"))
        let item = AutosaveRecoveryItem(
            id: autosaveID,
            title: "Recovered",
            sourceProjectURL: nil,
            autosaveProjectURL: autosaveURL,
            updatedAt: Date(timeIntervalSince1970: 0),
            previewImageData: nil
        )
        let loaded = LoadedPaintProject.testValue()
        let loadProjectCalls = TestRecorder<URL>()
        let reservedID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
        let store = TestStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.recovery.items = [item]
                state.recovery.isPresented = true
                return state
            }()
        ) {
            PrimoRootFeature()
        } withDependencies: {
            $0.uuidClient = UUIDClient(generate: { reservedID })
            $0.documentRuntimeComposition = .stub(
                persistenceGateway: .stub(
                    loadProject: { url in
                        loadProjectCalls.record(url)
                        return loaded
                    }
                )
            )
            $0.documentWorkspaceClient = .stub(
                createTabBackingStoreURL: { id in
                    DocumentProjectPath(URL(fileURLWithPath: "/tmp/\(id.uuidString).atelier"))
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.application(.autosaveRecoveryRestoreRequested(autosaveID))) {
            $0.application.isHydrating = true
        }
        await store.receive(.application(.autosaveRecoveryOpened(loaded, item, [])))
        await store.receive(
            .workspacePersistenceRequested(
                .reserveNewTabBackingStore(
                    DocumentFeatureRuntimeReducer.WorkspaceTabReservationRequest(
                        title: item.title,
                        sourceProjectURL: nil,
                        pane: .primary
                    )
                )
            )
        )
        XCTAssertEqual(loadProjectCalls.values, [autosaveURL.fileURL])
    }

    func testSaveHistoryLoadUsesWorkspaceCatalogRequest() async {
        let activeTab = OpenDocumentTab.testValue()
        let store = TestStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            PrimoRootFeature()
        }
        store.exhaustivity = .off

        await store.send(.importExport(.saveHistoryRequested)) {
            $0.saveHistory.isPresented = true
        }
        await store.receive(
            .workspaceCatalogRequested(
                .loadSaveHistoryEntries(
                    DocumentFeatureRuntimeReducer.WorkspaceSaveHistoryLoadRequest(
                        activeTab: activeTab
                    )
                )
            )
        )
    }

    func testFreshDocumentPreparationRequestsReservation() async {
        let dimensions = DocumentFeature.CanvasDimensions(width: 640, height: 480)!
        let store = TestStore(initialState: PrimoRootFeature.State()) {
            PrimoRootFeature()
        }
        store.exhaustivity = .off

        await store.send(.document(.newCanvasPreparationCompleted(dimensions))) {
            $0.workspace.pendingWorkspaceTabReservation = .freshDocument(
                DocumentFeatureRuntimeReducer.PendingFreshDocumentMutation(
                    contract: DocumentFeatureRuntimeReducer.FreshDocumentReplacementContract(
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
                    DocumentFeatureRuntimeReducer.WorkspaceTabReservationRequest(
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
        let store = TestStore(initialState: PrimoRootFeature.State()) {
            PrimoRootFeature()
        } withDependencies: {
            $0.uuidClient = UUIDClient(generate: { reservedID })
            $0.documentWorkspaceClient = .stub(
                createTabBackingStoreURL: { id in
                    DocumentProjectPath(URL(fileURLWithPath: "/tmp/\(id.uuidString).atelier"))
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.workspace(.openDocumentLoaded(loaded, sourceURL, []))) {
            $0.workspace.pendingWorkspaceTabReservation = .loadedProject(
                DocumentFeatureRuntimeReducer.PendingLoadedWorkspaceProject(
                    loaded: loaded,
                    plan: DocumentFeatureRuntimeReducer.LoadedWorkspaceProjectPlan(
                        destination: .newTab(
                            title: sourceURL.displayName,
                            sourceProjectURL: sourceURL
                        ),
                        successEffects: .init(
                            completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                        )
                    ),
                    presentation: DocumentFeatureRuntimeReducer.LoadedWorkspacePresentation(
                        completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                    )
                )
            )
        }
        XCTAssertTrue(store.state.workspace.openTabs.isEmpty)
        await store.receive(
            .workspacePersistenceRequested(
                .reserveNewTabBackingStore(
                    DocumentFeatureRuntimeReducer.WorkspaceTabReservationRequest(
                        title: sourceURL.displayName,
                        sourceProjectURL: sourceURL,
                        pane: .primary
                    )
                )
            )
        )
    }

    func testLoadedWorkspaceFollowUpIssuesOverrideSuccessBanner() {
        let feature = DocumentFeatureRuntimeReducer()
        var state = PrimoRootFeature.State()
        state.application.beginHydration()

        _ = feature.handleWorkspacePersistenceSucceeded(
            state: &state,
            result: .loadedWorkspaceFollowUpApplied(
                DocumentFeatureRuntimeReducer.LoadedWorkspaceFollowUpPersistenceResult(
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
        let feature = DocumentFeatureRuntimeReducer()
        var state = PrimoRootFeature.State()
        state.application.beginHydration()

        feature.handleWorkspaceCatalogFailed(
            state: &state,
            failure: DocumentFeatureRuntimeReducer.WorkspaceCatalogFailure(
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
            contentsOf: repoRoot.appendingPathComponent("App/Features/Document/PrimoRootFeature+CanvasLifecycleWorkflow.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(contents.contains("var feedback: ApplicationFeedback"))
        XCTAssertTrue(contents.contains("CanvasLifecycleFeedbackMapper"))
    }

    func testDocumentFeatureRuntimeReducerHomeProjectsLoadRoutesToCatalogRequest() async {
        let store = TestStore(initialState: PrimoRootFeature.State()) {
            DocumentFeatureRuntimeReducer()
        }
        store.exhaustivity = .off

        await store.send(.application(.homeProjectsLoadRequested)) {
            $0.application.isLoadingHomeProjects = true
        }
        await store.receive(.workspace(.catalogRequested(.loadSavedProjects)))
    }

    func testDocumentFeatureRuntimeReducerUndoRoutesToHistoryMutation() async {
        let store = TestStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.showsHome = false
                return state
            }()
        ) {
            DocumentFeatureRuntimeReducer()
        } withDependencies: {
            $0.documentHistoryGateway = .stub(undo: { .success(()) })
        }
        store.exhaustivity = .off

        await store.send(.document(.undoRequested))
        await store.receive(.application(.refreshPresentationRequested))
    }

    func testDocumentFeatureRuntimeReducerSaveHistoryRoutesToCatalogRequest() async {
        let activeTab = OpenDocumentTab.testValue()
        let store = TestStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            DocumentFeatureRuntimeReducer()
        }
        store.exhaustivity = .off

        await store.send(.importExport(.saveHistoryRequested))
        await store.receive(
            .workspaceCatalogRequested(
                .loadSaveHistoryEntries(
                    DocumentFeatureRuntimeReducer.WorkspaceSaveHistoryLoadRequest(activeTab: activeTab)
                )
            )
        )
    }

    func testPrimoRootFeatureStateStoresEditorAndImportExportInFeatureSlices() {
        var state = PrimoRootFeature.State()

        state.canvas.zoomScale = 2.0
        state.saveHistory.isPresented = true

        XCTAssertEqual(state.document.canvas.zoomScale, 2.0)
        XCTAssertTrue(state.importExport.saveHistory.isPresented)
    }

    func testDocumentFeatureOwnsCanvasReducerScope() async {
        let store = TestStore(initialState: DocumentFeature.State()) {
            DocumentFeature()
        }

        await store.send(.canvas(.zoomScaleChanged(1.75))) {
            $0.canvas.zoomScale = 1.75
        }
    }

    func testImportExportDismissalRoutesThroughFeatureSlice() async {
        let store = TestStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.importExport.saveHistory.isPresented = true
                return state
            }()
        ) {
            PrimoRootFeature()
        }
        store.exhaustivity = .off

        await store.send(.importExport(.saveHistoryDismissed)) {
            $0.importExport.saveHistory.isPresented = false
        }
    }
}
