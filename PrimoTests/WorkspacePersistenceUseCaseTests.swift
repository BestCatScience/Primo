import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure
import XCTest
@testable import Primo

final class WorkspacePersistenceUseCaseTests: XCTestCase {
    func testSaveActiveDocumentReturnsSavedResult() {
        let savedURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/saved-document.atelier"))
        let saveProjectCalls = TestRecorder<URL>()
        let saveHistoryTriggers = TestRecorder<SaveHistoryTrigger>()
        let activeTab = OpenDocumentTab.testValue(previewImageData: Data([0xAB]))

        let documentPersistenceGateway = DocumentPersistenceGateway.stub(
            saveProject: { url, _ in
                saveProjectCalls.record(url)
            }
        )
        let documentWorkspaceClient = DocumentWorkspaceClient.stub(
            persistProjectSnapshot: { _, _ in savedURL },
            persistSaveHistorySnapshot: { _, _, trigger in
                saveHistoryTriggers.record(trigger)
            }
        )
        let support = WorkspaceApplicationServices(
            documentPersistenceGateway: documentPersistenceGateway,
            documentWorkspaceClient: documentWorkspaceClient,
            uuidClient: UUIDClient(
                generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")! }
            )
        )

        let request = PrimoRootFeature.WorkspacePersistenceRequest.saveActiveDocument(
            PrimoRootFeature.WorkspaceDocumentSaveRequest(
                activeTab: activeTab,
                paperStyle: .default,
                preferredDestinationURL: nil,
                trigger: .manualSave,
                purpose: .saveDocument
            )
        )

        let result = support.persistenceUseCase.execute(request)

        XCTAssertEqual(
            result,
            .success(
                .activeDocumentSaved(
                    PrimoRootFeature.WorkspaceDocumentSaveResult(
                        activeTabID: activeTab.id,
                        savedURL: savedURL,
                        purpose: .saveDocument,
                        previewImageData: activeTab.previewImageData,
                        canvasSize: activeTab.canvasSize,
                        issues: []
                    )
                )
            )
        )
        XCTAssertEqual(saveProjectCalls.values, [activeTab.backingStoreURL.fileURL])
        XCTAssertEqual(saveHistoryTriggers.values, [.manualSave])
    }

    func testSaveHistoryFailureReturnsCloseSaveIssue() {
        let tab = OpenDocumentTab.testValue()
        let documentWorkspaceClient = DocumentWorkspaceClient.stub(
            persistSaveHistorySnapshot: { _, _, _ in
                throw TestError.expected("save history unavailable")
            }
        )
        let support = WorkspaceApplicationServices(
            documentPersistenceGateway: .stub(),
            documentWorkspaceClient: documentWorkspaceClient,
            uuidClient: UUIDClient(
                generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")! }
            )
        )

        let request = PrimoRootFeature.WorkspacePersistenceRequest.saveTabsForClose(
            PrimoRootFeature.WorkspaceCloseTabsSaveRequest(
                operation: .tab(tab.id),
                tabs: [tab],
                activeTab: nil
            )
        )

        XCTAssertEqual(
            support.persistenceUseCase.execute(request),
            .success(
                .tabsSavedForClose(
                    PrimoRootFeature.WorkspaceCloseTabsSaveResult(
                        operation: .tab(tab.id),
                        issues: [.saveHistoryPersistFailed("save history unavailable")]
                    )
                )
            )
        )
    }

    func testAutosaveCleanupFailureReturnsSaveIssue() {
        let savedURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/saved-document.atelier"))
        let activeTab = OpenDocumentTab.testValue(previewImageData: Data([0xAB]))
        let support = WorkspaceApplicationServices(
            documentPersistenceGateway: .stub(),
            documentWorkspaceClient: .stub(
                discardAutosaveSnapshot: { _ in
                    throw TestError.expected("autosave cleanup failed")
                },
                persistProjectSnapshot: { _, _ in savedURL }
            ),
            uuidClient: UUIDClient(
                generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")! }
            )
        )

        XCTAssertEqual(
            support.persistenceUseCase.execute(
                .saveActiveDocument(
                    PrimoRootFeature.WorkspaceDocumentSaveRequest(
                        activeTab: activeTab,
                        paperStyle: .default,
                        preferredDestinationURL: nil,
                        trigger: .manualSave,
                        purpose: .saveDocument
                    )
                )
            ),
            .success(
                .activeDocumentSaved(
                    PrimoRootFeature.WorkspaceDocumentSaveResult(
                        activeTabID: activeTab.id,
                        savedURL: savedURL,
                        purpose: .saveDocument,
                        previewImageData: activeTab.previewImageData,
                        canvasSize: activeTab.canvasSize,
                        issues: [.autosaveCleanupFailed("autosave cleanup failed")]
                    )
                )
            )
        )
    }

    func testReserveNewTabBackingStoreReturnsPreparedTab() {
        let reservedID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
        let reservedURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/reserved-tab.atelier"))
        let support = WorkspaceApplicationServices(
            documentPersistenceGateway: .stub(),
            documentWorkspaceClient: .stub(
                createTabBackingStoreURL: { _ in reservedURL }
            ),
            uuidClient: UUIDClient(generate: { reservedID })
        )

        let request = PrimoRootFeature.WorkspacePersistenceRequest.reserveNewTabBackingStore(
            PrimoRootFeature.WorkspaceTabReservationRequest(
                title: "Imported",
                sourceProjectURL: nil,
                pane: .secondary
            )
        )

        XCTAssertEqual(
            support.persistenceUseCase.execute(request),
            .success(
                .newTabBackingStoreReserved(
                    PrimoRootFeature.PreparedWorkspaceTab(
                        id: reservedID,
                        title: "Imported",
                        backingStoreURL: reservedURL,
                        sourceProjectURL: nil,
                        pane: .secondary
                    )
                )
            )
        )
    }

    func testReserveNewTabBackingStoreMapsCreateFailure() {
        let reservedID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
        let support = WorkspaceApplicationServices(
            documentPersistenceGateway: .stub(),
            documentWorkspaceClient: .stub(
                createTabBackingStoreURL: { _ in
                    throw TestError.expected("create tab failed")
                }
            ),
            uuidClient: UUIDClient(generate: { reservedID })
        )

        let request = PrimoRootFeature.WorkspacePersistenceRequest.reserveNewTabBackingStore(
            PrimoRootFeature.WorkspaceTabReservationRequest(
                title: "Imported",
                sourceProjectURL: nil,
                pane: .primary
            )
        )

        XCTAssertEqual(
            support.persistenceUseCase.execute(request),
            .failure(
                PrimoRootFeature.WorkspacePersistenceFailure(
                    request: request,
                    reason: .couldNotCreateTab
                )
            )
        )
    }
}
