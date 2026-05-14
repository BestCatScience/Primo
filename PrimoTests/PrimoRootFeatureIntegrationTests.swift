import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import PrimoWorkspaceApplication
import PrimoWorkspaceApplication
import XCTest
@testable import Primo

@MainActor
final class PrimoRootFeatureIntegrationTests: XCTestCase {
    private let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func previewSurface() -> DocumentCompositeSurface {
        DocumentCompositeSurface(
            unsafeUncheckedWidth: 1,
            height: 1,
            pixelData: Data([0x01, 0x02, 0x03, 0xFF])
        )
    }

    private func workspaceSnapshot(
        activeTab: OpenDocumentTab? = nil,
        previewSurface: DocumentCompositeSurface? = nil
    ) -> DocumentFeature.WorkspaceDocumentSnapshot {
        DocumentFeature.WorkspaceDocumentSnapshot(
            activeTab: activeTab,
            paperStyle: .default,
            previewSurface: previewSurface,
            canvasSize: activeTab?.canvasSize ?? CanvasFeature.defaultCanvasSize
        )
    }

    private func makeRootStore(
        initialState: PrimoRootFeature.State = PrimoRootFeature.State(),
        configureDependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<PrimoRootFeature> {
        TestStore(initialState: initialState) {
            PrimoRootFeature()
        } withDependencies: {
            $0.documentRuntime = .stub()
            $0.documentWorkspaceClient = .stub()
            $0.workspaceApplicationWorkflowService = WorkspaceApplicationWorkflowService()
            $0.dateClient = DateClient(now: { Date(timeIntervalSince1970: 1_234) })
            $0.uuidClient = UUIDClient(generate: {
                UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!
            })
            $0.fileClient = .stub()
            configureDependencies(&$0)
            $0.workspaceApplicationCapability = .stub(
                documentWorkspaceClient: $0.documentWorkspaceClient,
                uuidClient: $0.uuidClient
            )
        }
    }

    func testSelectingActiveTabFromHomeShowsWorkspace() async {
        let activeTab = OpenDocumentTab.testValue()
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.showsHome = true
                state.application.isHydrating = false
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        )

        await store.send(.workspace(.tabSelected(activeTab.id)))
        await store.receive(.workspace(.delegate(.workspaceProjectLoadCompleted(nil))))
        await store.receive(.application(.workspaceProjectLoadCompleted(nil))) {
            $0.application.showsHome = false
        }
    }

    func testLoadedTabSelectionAppliesSelectedTab() async {
        let activeTab = OpenDocumentTab.testValue(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            title: "Active",
            backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/active.atelier")),
            sourceProjectURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/active-source.atelier"))
        )
        let targetTab = OpenDocumentTab.testValue(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            title: "Target",
            backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/target.atelier")),
            sourceProjectURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/target-source.atelier"))
        )
        let loaded = LoadedPaintProject.testValue()
        let store = TestStore(
            initialState: {
                var state = WorkspaceFeature.State()
                state.openTabs = [activeTab, targetTab]
                state.activeTabID = activeTab.id
                state.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            WorkspaceFeature()
        } withDependencies: {
            $0.documentRuntime = .stub()
            $0.documentWorkspaceClient = .stub()
            $0.workspaceApplicationWorkflowService = WorkspaceApplicationWorkflowService()
            $0.uuidClient = UUIDClient(generate: {
                UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!
            })
            $0.fileClient = .stub()
            $0.workspaceApplicationCapability = .stub(
                documentWorkspaceClient: $0.documentWorkspaceClient,
                uuidClient: $0.uuidClient
            )
        }

        await store.send(.tabSelectionLoaded(targetTab.id, loaded)) {
            $0.pendingLoadedWorkspaceApplication = WorkspaceFeature.PendingLoadedWorkspaceApplication(
                loaded: loaded,
                plan: WorkspaceFeature.LoadedWorkspaceProjectPlan(
                    destination: .selectedTab(tabID: targetTab.id, pane: targetTab.pane),
                    successEffects: .init(
                        completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                    )
                ),
                presentation: WorkspaceFeature.LoadedWorkspacePresentation(
                    completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                ),
                preparedTab: nil
            )
        }
        await store.receive(.delegate(.applyLoadedProject(loaded)))
        await store.send(.loadedProjectApplied) {
            $0.pendingLoadedWorkspaceApplication = nil
            $0.activeTabID = targetTab.id
            $0.primarySelectedTabID = targetTab.id
        }
        await store.receive(.delegate(.workspaceProjectLoadCompleted(nil)))
    }

    func testHomeReturnRequestedEmitsWorkspacePersistenceRequest() async {
        let previewSurface = previewSurface()
        let activeTab = OpenDocumentTab.testValue()
        var refreshedTab = activeTab
        refreshedTab.previewSurface = previewSurface
        var savedTab = refreshedTab
        savedTab.title = "source"
        savedTab.isDirty = false
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.showsHome = false
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            $0.documentRuntime = .stub(
                exportGateway: .stub(
                    compositeSurface: { _ in previewSurface }
                )
            )
        }
        store.exhaustivity = .off

        await store.send(.workspace(.homeReturnRequested))
        await store.receive(.workspace(.delegate(.requestDocumentSnapshot)))
        await store.receive(.document(.presentation(.workspaceSnapshotRequested(.pendingWorkspaceOperation))))
        await store.send(.workspace(.documentSnapshotPrepared(workspaceSnapshot(activeTab: activeTab, previewSurface: previewSurface)))) {
            $0.workspace.openTabs = [savedTab]
        }
    }

    func testBackgroundScenePersistsDirtyActiveTabAutosave() async {
        let previewSurface = previewSurface()
        let activeTab = OpenDocumentTab.testValue(isDirty: true)
        var refreshedTab = activeTab
        refreshedTab.previewSurface = previewSurface
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.showsHome = false
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            $0.documentRuntime = .stub(
                exportGateway: .stub(
                    compositeSurface: { _ in previewSurface }
                )
            )
            $0.uuidClient = UUIDClient(generate: {
                UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
            })
        }
        store.exhaustivity = .off

        await store.send(.application(.scenePhaseChanged(.background)))
        await store.receive(.workspace(.lifecycleAutosaveRequested)) {
            $0.workspace.pendingDocumentSnapshotOperation = .lifecycleAutosave
        }
        await store.receive(.workspace(.delegate(.requestDocumentSnapshot)))
        await store.receive(.document(.presentation(.workspaceSnapshotRequested(.pendingWorkspaceOperation))))
        await store.send(.workspace(.documentSnapshotPrepared(workspaceSnapshot(activeTab: activeTab, previewSurface: previewSurface)))) {
            $0.workspace.openTabs = [refreshedTab]
            $0.workspace.pendingDocumentSnapshotOperation = nil
        }
    }

    func testPendingCloseSaveConfirmedEmitsClosePersistenceRequest() async {
        let previewSurface = previewSurface()
        let activeTab = OpenDocumentTab.testValue()
        var refreshedTab = activeTab
        refreshedTab.previewSurface = previewSurface
        let store = makeRootStore(
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
            $0.documentRuntime = .stub(
                exportGateway: .stub(
                    compositeSurface: { _ in previewSurface }
                )
            )
        }
        store.exhaustivity = .off

        await store.send(.workspace(.pendingCloseSaveConfirmed)) {
            $0.workspace.pendingCloseConfirmation = nil
            $0.workspace.pendingDocumentSnapshotOperation = .closeTabsSave(.tab(activeTab.id), [activeTab.id])
        }
        await store.receive(.workspace(.delegate(.requestDocumentSnapshot)))
        await store.receive(.document(.presentation(.workspaceSnapshotRequested(.pendingWorkspaceOperation))))
        await store.send(.workspace(.documentSnapshotPrepared(workspaceSnapshot(activeTab: activeTab, previewSurface: previewSurface)))) {
            $0.workspace.openTabs = []
            $0.workspace.activeTabID = nil
            $0.workspace.primarySelectedTabID = nil
            $0.workspace.pendingDocumentSnapshotOperation = nil
        }
    }

    func testLoadedWorkspaceFollowUpSuccessCompletesHydration() async {
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.beginHydration()
                return state
            }()
        )
        store.exhaustivity = .off

        await store.send(
            .workspace(.persistenceSucceeded(
                .loadedWorkspaceFollowUpApplied(
                    WorkspaceFeature.LoadedWorkspaceFollowUpPersistenceResult(
                        successEffects: .init(
                            completion: .restoredAutosave
                        ),
                        issues: []
                    )
                )
            ))
        )
        await store.receive(.workspace(.delegate(.workspaceProjectLoadCompleted(nil))))
        await store.receive(.application(.workspaceProjectLoadCompleted(nil))) {
            $0.application.isHydrating = false
            $0.application.showsHome = false
        }
    }

    func testLoadedWorkspaceFollowUpFailureSurfacesFeedback() async {
        let failure = WorkspaceFeature.WorkspacePersistenceFailure(
            request: .loadedWorkspaceFollowUp(
                WorkspaceFeature.LoadedWorkspaceFollowUpPersistenceRequest(
                    activeTab: .testValue(),
                    paperStyle: .default,
                    persistsToBackingStore: true,
                    persistsAutosave: false,
                    successEffects: .init()
                )
            ),
            reason: .saveFailed("workspace follow-up failed")
        )
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.beginHydration()
                return state
            }()
        )
        store.exhaustivity = .off

        await store.send(.workspace(.persistenceFailed(failure)))
        await store.receive(.workspace(.delegate(.presentFeedback(.saveFailed("workspace follow-up failed")))))
        await store.receive(.application(.feedbackPresented(.saveFailed("workspace follow-up failed")))) {
            $0.application.bannerMessage = "workspace follow-up failed"
        }
    }

    func testMoveSavedProjectUsesWorkspaceCatalogRequest() async {
        let sourceURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/source.atelier"))
        let destinationURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/moved.atelier"))
        let activeTab = OpenDocumentTab.testValue(sourceProjectURL: sourceURL)
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        ) {
            $0.documentWorkspaceClient = .stub(
                moveSavedProject: { _, _ in destinationURL }
            )
        }
        store.exhaustivity = .off

        await store.send(.workspace(.moveSavedProject(sourceURL, nil)))
        await store.receive(
            .workspaceCatalogRequested(
                .moveSavedProject(
                    WorkspaceFeature.WorkspaceSavedProjectMoveRequest(
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
                    WorkspaceFeature.WorkspaceSavedProjectMoveResult(
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
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.recovery.items = [autosaveItem]
                state.application.recovery.isPresented = true
                return state
            }()
        ) {
            $0.documentWorkspaceClient = .stub(
                discardAutosaveEntry: { _ in }
            )
        }
        store.exhaustivity = .off

        await store.send(.application(.autosaveRecoveryDiscardRequested(autosaveID)))
        XCTAssertEqual(store.state.application.recovery.items, [autosaveItem])
        await store.receive(
            .workspaceCatalogRequested(
                .discardAutosaveEntry(
                    WorkspaceFeature.WorkspaceAutosaveEntryDiscardRequest(
                        autosaveID: autosaveID
                    )
                )
            )
        )
        await store.receive(
            .workspace(.catalogSucceeded(.autosaveEntryDiscarded(autosaveID)))
        )
        await store.receive(.workspace(.delegate(.autosaveRecoveryDiscarded(autosaveID))))
        await store.receive(.application(.autosaveRecoveryDiscarded(autosaveID))) {
            $0.application.recovery.items = []
        }
    }

    func testHomeProjectsLoadUsesWorkspaceCatalogRequest() async {
        let store = makeRootStore()
        store.exhaustivity = .off

        await store.send(.application(.homeProjectsLoadRequested)) {
            $0.application.isLoadingHomeProjects = true
        }
        await store.receive(.workspace(.catalogRequested(.loadSavedProjects)))
    }

    func testAutosaveRecoveryLoadUsesWorkspaceCatalogRequest() async {
        let store = makeRootStore()
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
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.recovery.items = [item]
                state.application.recovery.isPresented = true
                return state
            }()
        ) {
            $0.uuidClient = UUIDClient(generate: { reservedID })
            $0.documentRuntime = .stub(
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
        await store.receive(.workspace(.autosaveRecoveryRestoreRequested(item)))
        await store.receive(.workspace(.autosaveRecoveryOpened(loaded, item, [])))
        await store.receive(
            .workspacePersistenceRequested(
                .reserveNewTabBackingStore(
                    WorkspaceFeature.WorkspaceTabReservationRequest(
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
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        )
        store.exhaustivity = .off

        await store.send(.importExport(.saveHistoryRequested)) {
            $0.importExport.saveHistory.isPresented = true
        }
        await store.receive(
            .workspaceCatalogRequested(
                .loadSaveHistoryEntries(
                    WorkspaceFeature.WorkspaceSaveHistoryLoadRequest(
                        activeTab: activeTab
                    )
                )
            )
        )
    }

    func testFreshDocumentPreparationRequestsReservation() async {
        let dimensions = DocumentFeature.CanvasDimensions(width: 640, height: 480)!
        let store = makeRootStore()
        store.exhaustivity = .off

        await store.send(.document(.lifecycle(.newCanvasPreparationCompleted(dimensions))))
        await store.receive(
            .workspace(
                .freshDocumentRequested(
                    DocumentFeature.FreshDocumentReplacementContract(
                        canvasSize: dimensions.size,
                        tabTitle: "Untitled"
                    ),
                    .newCanvas(dimensions)
                )
            )
        ) {
            $0.workspace.pendingWorkspaceTabReservation = .freshDocument(
                WorkspaceFeature.PendingFreshDocumentMutation(
                    contract: DocumentFeature.FreshDocumentReplacementContract(
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
                    WorkspaceFeature.WorkspaceTabReservationRequest(
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
        let store = makeRootStore {
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
                WorkspaceFeature.PendingLoadedWorkspaceProject(
                    loaded: loaded,
                    plan: WorkspaceFeature.LoadedWorkspaceProjectPlan(
                        destination: .newTab(
                            title: sourceURL.displayName,
                            sourceProjectURL: sourceURL
                        ),
                        successEffects: .init(
                            completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                        )
                    ),
                    presentation: WorkspaceFeature.LoadedWorkspacePresentation(
                        completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                    )
                )
            )
        }
        XCTAssertTrue(store.state.workspace.openTabs.isEmpty)
        await store.receive(
            .workspacePersistenceRequested(
                .reserveNewTabBackingStore(
                    WorkspaceFeature.WorkspaceTabReservationRequest(
                        title: sourceURL.displayName,
                        sourceProjectURL: sourceURL,
                        pane: .primary
                    )
                )
            )
        )
    }

    func testLoadedWorkspaceFollowUpIssuesOverrideSuccessBanner() async {
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.beginHydration()
                return state
            }()
        )
        store.exhaustivity = .off

        await store.send(
            .workspace(.persistenceSucceeded(
                .loadedWorkspaceFollowUpApplied(
                    WorkspaceFeature.LoadedWorkspaceFollowUpPersistenceResult(
                        successEffects: .init(
                            completion: .restoredAutosave
                        ),
                        issues: [.autosaveEntryDiscardFailed("discard failed")]
                    )
                )
            ))
        )
        await store.receive(.workspace(.delegate(.workspaceProjectLoadCompleted(nil))))
        await store.receive(.application(.workspaceProjectLoadCompleted(nil))) {
            $0.application.isHydrating = false
            $0.application.showsHome = false
        }
    }

    func testWorkspaceCatalogFailureUsesReasonBasedMapper() async {
        let failure = WorkspaceFeature.WorkspaceCatalogFailure(
            request: .loadAutosaveRecoveryItems,
            reason: .loadAutosaveRecoveryItemsFailed("catalog load failed")
        )
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.beginHydration()
                return state
            }()
        )
        store.exhaustivity = .off

        await store.send(.workspace(.catalogFailed(failure)))
        await store.receive(.workspace(.delegate(.autosaveRecoveryLoadFailed(.autosaveRestoreFailed("catalog load failed")))))
        await store.receive(.application(.hydrationFeedbackPresented(.autosaveRestoreFailed("catalog load failed")))) {
            $0.application.isHydrating = false
            $0.application.bannerMessage = "catalog load failed"
        }
    }

    func testArchitectureContractsExposeLayeredProtocolVocabulary() throws {
        let contents = try String(
            contentsOf: repoRoot.appendingPathComponent("Packages/PrimoModules/Sources/PrimoCoreTypes/OperationContracts.swift"),
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

    func testCrossFeatureIntegrationReducerOnlyComposesBridgeReducers() throws {
        let contents = try String(
            contentsOf: repoRoot.appendingPathComponent("App/Features/Document/CrossFeatureIntegrationReducer.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(contents.contains("CombineReducers"))
        XCTAssertTrue(contents.contains("ApplicationWorkspaceBridge()"))
        XCTAssertTrue(contents.contains("WorkspaceDocumentBridge()"))
        XCTAssertTrue(contents.contains("ImportExportWorkspaceBridge()"))
        XCTAssertTrue(contents.contains("AIImageDocumentBridge()"))
        XCTAssertTrue(contents.contains("DocumentApplicationFeedbackBridge()"))
        XCTAssertFalse(contents.contains("switch action"))
    }

    func testDocumentApplicationEnvironmentDoesNotStoreWholeRuntime() throws {
        let contents = try String(
            contentsOf: repoRoot.appendingPathComponent("App/Features/Document/PaintDocumentClient.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(contents.contains("let runtime: DocumentRuntime"))
        XCTAssertFalse(contents.contains("@Dependency(\\.canvasPreviewRenderer)"))
        XCTAssertFalse(contents.contains("@Dependency(\\.canvasPresentationEnvironment)"))
    }

    func testCanvasLifecycleFailureNoLongerEmbedsPresentationFeedback() throws {
        let contents = try String(
            contentsOf: repoRoot.appendingPathComponent("App/Features/Document/DocumentLifecycleReducer+Workflow.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(contents.contains("var feedback: ApplicationFeedback"))
        XCTAssertTrue(contents.contains("CanvasLifecycleFeedbackMapper"))
    }

    func testPrimoAppInjectsOneSharedDocumentRuntime() throws {
        let contents = try String(
            contentsOf: repoRoot.appendingPathComponent("App/Application/PrimoApp.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(contents.contains("let documentRuntime = DocumentRuntimeFactory.live()"))
        XCTAssertTrue(contents.contains("$0.documentRuntime = documentRuntime"))
    }

    func testCrossFeatureIntegrationReducerHomeProjectsLoadRoutesToCatalogRequest() async {
        let store = makeRootStore()
        store.exhaustivity = .off

        await store.send(.application(.homeProjectsLoadRequested)) {
            $0.application.isLoadingHomeProjects = true
        }
        await store.receive(.workspace(.catalogRequested(.loadSavedProjects)))
    }

    func testCrossFeatureIntegrationReducerUndoRoutesToHistoryMutation() async {
        let undoPresentation = PaintDocumentPresentation.renderedTestValue(width: 3, height: 3)
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.showsHome = false
                return state
            }()
        ) {
            $0.documentRuntime = .stub(
                queryGateway: .stub(presentation: undoPresentation),
                historyGateway: .stub(undo: { .success(()) })
            )
        }
        store.exhaustivity = .off

        await store.send(.document(.lifecycle(.undoRequested))) {
            $0.document.editing.canvas.canvasSize = CGSize(width: 3, height: 3)
            $0.document.editing.canvas.renderSnapshot = undoPresentation.renderSnapshot
            $0.document.editing.canvas.lastCommittedRenderRevision = 1
        }
        await store.receive(.document(.delegate(.presentationApplied)))
    }

    func testUndoClearsPendingStrokePresentationStateAndRunsWhileStrokeStateIsStale() async {
        let pendingSnapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 2,
            height: 2,
            revision: 4,
            compositePixelData: Data(count: 16),
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: Data(count: 16)
                )
            ]
        )
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.application.showsHome = false
                state.document.editing.canvas.stagePendingCommittedSnapshot(pendingSnapshot)
                state.document.editing.canvas.isStrokeActive = true
                return state
            }()
        ) {
            $0.documentRuntime = .stub(
                queryGateway: .stub(presentation: .renderedTestValue(width: 2, height: 2)),
                historyGateway: .stub(undo: { .success(()) })
            )
        }
        store.exhaustivity = .off

        await store.send(.document(.lifecycle(.undoRequested))) {
            $0.document.editing.canvas.pendingCommittedSnapshot = nil
            $0.document.editing.canvas.isStrokeActive = false
            $0.document.editing.canvas.renderSnapshot = PaintDocumentPresentation.renderedTestValue(width: 2, height: 2).renderSnapshot
            $0.document.editing.canvas.lastCommittedRenderRevision = 1
        }
        await store.receive(.document(.delegate(.presentationApplied)))
    }

    func testCrossFeatureIntegrationReducerSaveHistoryRoutesToCatalogRequest() async {
        let activeTab = OpenDocumentTab.testValue()
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.workspace.openTabs = [activeTab]
                state.workspace.activeTabID = activeTab.id
                state.workspace.primarySelectedTabID = activeTab.id
                return state
            }()
        )
        store.exhaustivity = .off

        await store.send(.importExport(.saveHistoryRequested))
        await store.receive(
            .workspaceCatalogRequested(
                .loadSaveHistoryEntries(
                    WorkspaceFeature.WorkspaceSaveHistoryLoadRequest(activeTab: activeTab)
                )
            )
        )
    }

    func testPrimoRootFeatureStateStoresEditorAndImportExportInFeatureSlices() {
        var state = PrimoRootFeature.State()

        state.document.editing.canvas.zoomScale = 2.0
        state.importExport.saveHistory.isPresented = true

        XCTAssertEqual(state.document.editing.canvas.zoomScale, 2.0)
        XCTAssertTrue(state.importExport.saveHistory.isPresented)
    }

    func testDocumentFeatureOwnsCanvasReducerScope() async {
        let store = TestStore(initialState: DocumentFeature.State()) {
            DocumentFeature()
        }

        await store.send(.canvas(.zoomScaleChanged(1.75))) {
            $0.editing.canvas.zoomScale = 1.75
        }
        await store.receive(.canvasEditing(.canvas(.zoomScaleChanged(1.75))))
    }

    func testImportExportDismissalRoutesThroughFeatureSlice() async {
        let store = makeRootStore(
            initialState: {
                var state = PrimoRootFeature.State()
                state.importExport.saveHistory.isPresented = true
                return state
            }()
        )
        store.exhaustivity = .off

        await store.send(.importExport(.saveHistoryDismissed)) {
            $0.importExport.saveHistory.isPresented = false
        }
    }
}
