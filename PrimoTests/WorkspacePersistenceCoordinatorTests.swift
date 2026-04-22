import ComposableArchitecture
import PrimoWorkspaceApplication
import XCTest
@testable import Primo

final class WorkspacePersistenceCoordinatorTests: XCTestCase {
    func testLoadedWorkspaceFollowUpRequestMarksDirtyAndBuildsPersistenceRequest() {
        let tab = OpenDocumentTab.testValue(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            previewImageData: nil
        )
        let plan = AppFeature.LoadedWorkspaceProjectPlan(
            destination: .activeTab(title: "Updated", sourceProjectURL: tab.sourceProjectURL),
            followUp: .init(
                marksTabDirty: true,
                persistsToBackingStore: false,
                persistsAutosave: true
            ),
            successEffects: .init(completion: .openedDocument(layerCount: 1))
        )

        let result = withDependencies {
            $0.documentExportGateway = .stub(compositePNGData: { _ in Data([0xAB, 0xCD]) })
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            state.workspace.openTabs = [tab]
            state.workspace.activeTabID = tab.id
            state.workspace.primarySelectedTabID = tab.id

            let result = feature.loadedWorkspaceFollowUpRequest(
                plan: plan,
                state: &state
            )
            return (result, state.workspace.activeTab)
        }

        guard case let (.success(.some(request)), updatedTab?) = result else {
            return XCTFail("Expected follow-up persistence request and updated tab")
        }

        XCTAssertTrue(updatedTab.isDirty)
        XCTAssertEqual(updatedTab.previewImageData, Data([0xAB, 0xCD]))

        XCTAssertEqual(
            request,
            .loadedWorkspaceFollowUp(
                AppFeature.LoadedWorkspaceFollowUpPersistenceRequest(
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
            previewImageData: Data([0x01])
        )
        let plan = AppFeature.LoadedWorkspaceProjectPlan(
            destination: .selectedTab(tabID: tab.id, pane: .primary),
            followUp: .init(
                marksTabDirty: true,
                persistsToBackingStore: false,
                persistsAutosave: false
            )
        )

        let result = withDependencies {
            $0.documentExportGateway = .stub(compositePNGData: { _ in Data([0x01]) })
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            state.workspace.openTabs = [tab]
            state.workspace.activeTabID = tab.id
            state.workspace.primarySelectedTabID = tab.id

            let result = feature.loadedWorkspaceFollowUpRequest(
                plan: plan,
                state: &state
            )
            return (result, state.workspace.activeTab)
        }

        guard case let (.success(nil), updatedTab?) = result else {
            return XCTFail("Expected no follow-up persistence request")
        }

        XCTAssertTrue(updatedTab.isDirty)
        XCTAssertEqual(updatedTab.previewImageData, Data([0x01]))
    }
}
