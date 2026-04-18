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
                        canvasSize: activeTab.canvasSize
                    )
                )
            )
        )
        XCTAssertEqual(saveProjectCalls.values, [activeTab.backingStoreURL.fileURL])
        XCTAssertEqual(saveHistoryTriggers.values, [.manualSave])
    }

    func testSaveHistoryFailureDoesNotFailCloseSave() {
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
                        operation: .tab(tab.id)
                    )
                )
            )
        )
    }
}
