import ComposableArchitecture
import Foundation
import XCTest
@testable import Primo

@MainActor
final class AppFeatureReducerTests: XCTestCase {
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
            $0.paintDocumentClient = .stub(
                compositePNGData: { _ in previewData }
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
            $0.paintDocumentClient = .stub(
                compositePNGData: { _ in previewData }
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
                        feedback: .restoredAutosave
                    )
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
                feedback: .saveFailed("workspace follow-up failed")
            )
        )

        XCTAssertFalse(state.application.isHydrating)
        XCTAssertFalse(state.application.showsHome)
        XCTAssertEqual(state.application.bannerMessage, "workspace follow-up failed")
    }
}
