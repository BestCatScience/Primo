import Foundation
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import XCTest
@testable import Primo

final class WorkspacePersistenceCoordinatorTests: XCTestCase {
    func testLoadedWorkspaceFollowUpRequestMarksDirtyAndBuildsPersistenceRequest() {
        let tab = OpenDocumentTab.testValue(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            previewImageData: Data([0xAB, 0xCD, 0xEF, 0xFF])
        )
        let plan = WorkspaceFeature.LoadedWorkspaceProjectPlan(
            destination: .activeTab(title: "Updated", sourceProjectURL: tab.sourceProjectURL),
            followUp: .init(
                marksTabDirty: true,
                persistsToBackingStore: false,
                persistsAutosave: true
            ),
            successEffects: .init(completion: .openedDocument(layerCount: 1))
        )
        let service = WorkspaceApplicationWorkflowService()
        var workspace = WorkspaceFeature.State()
        workspace.openTabs = [tab]
        workspace.activeTabID = tab.id
        workspace.primarySelectedTabID = tab.id

        let result = service.loadedWorkspaceFollowUp(
            plan: plan,
            context: WorkspaceFeature.WorkspaceDocumentContext(
                activeTab: workspace.activeTab,
                paperStyle: .default
            ),
            requiresBackingStorePersistence: false
        )

        guard case let .success(outcome) = result,
              let request = outcome.followUpRequest
        else {
            return XCTFail("Expected follow-up persistence request and updated tab")
        }
        if outcome.marksActiveTabDirty {
            workspace.setActiveTabDirty(true)
        }
        guard let updatedTab = workspace.activeTab else {
            return XCTFail("Expected updated active tab")
        }

        XCTAssertTrue(updatedTab.isDirty)
        XCTAssertEqual(updatedTab.previewImageData, tab.previewImageData)

        XCTAssertEqual(
            request,
            .loadedWorkspaceFollowUp(
                WorkspaceFeature.LoadedWorkspaceFollowUpPersistenceRequest(
                    activeTab: updatedTab,
                    paperStyle: .default,
                    persistsToBackingStore: false,
                    persistsAutosave: true,
                    successEffects: plan.successEffects
                )
            )
        )
    }

    func testLoadedWorkspaceFollowUpRequestCanSkipPersistenceWhileStillMarkingDirty() {
        let tab = OpenDocumentTab.testValue(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
            previewImageData: Data([0x01, 0x02, 0x03, 0xFF])
        )
        let plan = WorkspaceFeature.LoadedWorkspaceProjectPlan(
            destination: .selectedTab(tabID: tab.id, pane: .primary),
            followUp: .init(
                marksTabDirty: true,
                persistsToBackingStore: false,
                persistsAutosave: false
            )
        )
        let service = WorkspaceApplicationWorkflowService()
        var workspace = WorkspaceFeature.State()
        workspace.openTabs = [tab]
        workspace.activeTabID = tab.id
        workspace.primarySelectedTabID = tab.id

        let result = service.loadedWorkspaceFollowUp(
            plan: plan,
            context: WorkspaceFeature.WorkspaceDocumentContext(
                activeTab: workspace.activeTab,
                paperStyle: .default
            ),
            requiresBackingStorePersistence: false
        )

        guard case let .success(outcome) = result,
              outcome.followUpRequest == nil
        else {
            return XCTFail("Expected no follow-up persistence request")
        }
        if outcome.marksActiveTabDirty {
            workspace.setActiveTabDirty(true)
        }
        guard let updatedTab = workspace.activeTab else {
            return XCTFail("Expected updated active tab")
        }

        XCTAssertTrue(updatedTab.isDirty)
        XCTAssertEqual(updatedTab.previewImageData, tab.previewImageData)
    }
}
