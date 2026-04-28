import ComposableArchitecture
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import XCTest
@testable import Primo

final class WorkspacePersistenceCoordinatorTests: XCTestCase {
    private func previewSurface(bytes: [UInt8]) -> DocumentCompositeSurface {
        DocumentCompositeSurface(
            width: 1,
            height: 1,
            pixelData: Data(bytes)
        )
    }

    func testLoadedWorkspaceFollowUpRequestMarksDirtyAndBuildsPersistenceRequest() {
        let expectedPreviewData = DocumentRasterImageService.pngData(
            from: previewSurface(bytes: [0xAB, 0xCD, 0xEF, 0xFF])
        )
        let tab = OpenDocumentTab.testValue(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            previewImageData: nil
        )
        let plan = DocumentFeatureRuntimeReducer.LoadedWorkspaceProjectPlan(
            destination: .activeTab(title: "Updated", sourceProjectURL: tab.sourceProjectURL),
            followUp: .init(
                marksTabDirty: true,
                persistsToBackingStore: false,
                persistsAutosave: true
            ),
            successEffects: .init(completion: .openedDocument(layerCount: 1))
        )

        let result = withDependencies {
            $0.documentExportGateway = .stub(
                compositeSurface: { _ in self.previewSurface(bytes: [0xAB, 0xCD, 0xEF, 0xFF]) }
            )
        } operation: {
            let feature = DocumentFeatureRuntimeReducer()
            var state = PrimoRootFeature.State()
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
        XCTAssertEqual(updatedTab.previewImageData, expectedPreviewData)

        XCTAssertEqual(
            request,
            .loadedWorkspaceFollowUp(
                DocumentFeatureRuntimeReducer.LoadedWorkspaceFollowUpPersistenceRequest(
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
        let expectedPreviewData = DocumentRasterImageService.pngData(
            from: previewSurface(bytes: [0x01, 0x02, 0x03, 0xFF])
        )
        let tab = OpenDocumentTab.testValue(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
            previewImageData: Data([0x01])
        )
        let plan = DocumentFeatureRuntimeReducer.LoadedWorkspaceProjectPlan(
            destination: .selectedTab(tabID: tab.id, pane: .primary),
            followUp: .init(
                marksTabDirty: true,
                persistsToBackingStore: false,
                persistsAutosave: false
            )
        )

        let result = withDependencies {
            $0.documentExportGateway = .stub(
                compositeSurface: { _ in self.previewSurface(bytes: [0x01, 0x02, 0x03, 0xFF]) }
            )
        } operation: {
            let feature = DocumentFeatureRuntimeReducer()
            var state = PrimoRootFeature.State()
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
        XCTAssertEqual(updatedTab.previewImageData, expectedPreviewData)
    }
}
