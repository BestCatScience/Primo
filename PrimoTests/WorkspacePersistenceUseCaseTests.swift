import Foundation
import XCTest
@testable import Primo

final class WorkspacePersistenceUseCaseTests: XCTestCase {
    func testSaveActiveDocumentReturnsSavedResult() {
        let savedURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/saved-document.atelier"))
        let saveProjectCalls = TestRecorder<URL>()
        let saveHistoryTriggers = TestRecorder<SaveHistoryTrigger>()
        let activeTab = OpenDocumentTab.testValue(previewImageData: Data([0xAB]))

        let paintDocumentClient = PaintDocumentClient.stub(
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
        let useCase = AppFeature.WorkspacePersistenceUseCase(
            workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                paintDocumentClient: paintDocumentClient,
                documentWorkspaceClient: documentWorkspaceClient
            ),
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: documentWorkspaceClient
            ),
            workspaceIdentityService: AppFeature.WorkspaceIdentityService(
                uuidClient: UUIDClient(
                    generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")! }
                )
            )
        )

        let request = AppFeature.WorkspacePersistenceRequest.saveActiveDocument(
            AppFeature.WorkspaceDocumentSaveRequest(
                activeTab: activeTab,
                paperStyle: .default,
                preferredDestinationURL: nil,
                trigger: .manualSave,
                purpose: .saveDocument
            )
        )

        let result = useCase.execute(request)

        XCTAssertEqual(
            result,
            .success(
                .activeDocumentSaved(
                    AppFeature.WorkspaceDocumentSaveResult(
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
        let paintDocumentClient = PaintDocumentClient.stub()
        let documentWorkspaceClient = DocumentWorkspaceClient.stub(
            persistSaveHistorySnapshot: { _, _, _ in
                throw TestError.expected("save history unavailable")
            }
        )
        let useCase = AppFeature.WorkspacePersistenceUseCase(
            workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                paintDocumentClient: paintDocumentClient,
                documentWorkspaceClient: documentWorkspaceClient
            ),
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: documentWorkspaceClient
            ),
            workspaceIdentityService: AppFeature.WorkspaceIdentityService(
                uuidClient: UUIDClient(
                    generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")! }
                )
            )
        )

        let request = AppFeature.WorkspacePersistenceRequest.saveTabsForClose(
            AppFeature.WorkspaceCloseTabsSaveRequest(
                operation: .tab(tab.id),
                tabs: [tab],
                activeTab: nil
            )
        )

        XCTAssertEqual(
            useCase.execute(request),
            .success(
                .tabsSavedForClose(
                    AppFeature.WorkspaceCloseTabsSaveResult(
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
        let useCase = AppFeature.WorkspacePersistenceUseCase(
            workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                paintDocumentClient: .stub(),
                documentWorkspaceClient: .stub(
                    persistProjectSnapshot: { _, _ in savedURL },
                    discardAutosaveSnapshot: { _ in
                        throw TestError.expected("autosave cleanup failed")
                    }
                )
            ),
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: .stub()
            ),
            workspaceIdentityService: AppFeature.WorkspaceIdentityService(
                uuidClient: UUIDClient(
                    generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")! }
                )
            )
        )

        XCTAssertEqual(
            useCase.execute(
                .saveActiveDocument(
                    AppFeature.WorkspaceDocumentSaveRequest(
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
                    AppFeature.WorkspaceDocumentSaveResult(
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
        let useCase = AppFeature.WorkspacePersistenceUseCase(
            workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                paintDocumentClient: .stub(),
                documentWorkspaceClient: .stub(
                    createTabBackingStoreURL: { _ in reservedURL }
                )
            ),
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: .stub()
            ),
            workspaceIdentityService: AppFeature.WorkspaceIdentityService(
                uuidClient: UUIDClient(generate: { reservedID })
            )
        )

        let request = AppFeature.WorkspacePersistenceRequest.reserveNewTabBackingStore(
            AppFeature.WorkspaceTabReservationRequest(
                title: "Imported",
                sourceProjectURL: nil,
                pane: .secondary
            )
        )

        XCTAssertEqual(
            useCase.execute(request),
            .success(
                .newTabBackingStoreReserved(
                    AppFeature.PreparedWorkspaceTab(
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
        let useCase = AppFeature.WorkspacePersistenceUseCase(
            workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                paintDocumentClient: .stub(),
                documentWorkspaceClient: .stub(
                    createTabBackingStoreURL: { _ in
                        throw TestError.expected("create tab failed")
                    }
                )
            ),
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: .stub()
            ),
            workspaceIdentityService: AppFeature.WorkspaceIdentityService(
                uuidClient: UUIDClient(generate: { reservedID })
            )
        )

        let request = AppFeature.WorkspacePersistenceRequest.reserveNewTabBackingStore(
            AppFeature.WorkspaceTabReservationRequest(
                title: "Imported",
                sourceProjectURL: nil,
                pane: .primary
            )
        )

        XCTAssertEqual(
            useCase.execute(request),
            .failure(
                AppFeature.WorkspacePersistenceFailure(
                    request: request,
                    feedback: .couldNotCreateTab
                )
            )
        )
    }
}
