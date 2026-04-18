import Foundation
import XCTest
@testable import Primo

final class WorkspaceProjectLoadUseCaseTests: XCTestCase {
    func testPrepareReplacementFailureStopsBeforeLoad() {
        let activeTab = OpenDocumentTab.testValue()
        let loadCalls = TestRecorder<URL>()
        let paintDocumentClient = PaintDocumentClient.stub(
            saveProject: { _, _ in
                throw TestError.expected("prepare replacement failed")
            },
            loadProject: { url in
                loadCalls.record(url)
                return .testValue()
            }
        )
        let documentWorkspaceClient = DocumentWorkspaceClient.stub()
        let loadingService = AppFeature.WorkspaceProjectLoadingService(
            preparationUseCase: AppFeature.WorkspaceProjectPreparationUseCase(
                workspacePersistenceUseCase: AppFeature.WorkspacePersistenceUseCase(
                    workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                        paintDocumentClient: paintDocumentClient,
                        documentWorkspaceClient: documentWorkspaceClient
                    ),
                    workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                        documentWorkspaceClient: documentWorkspaceClient
                    ),
                    workspaceIdentityService: AppFeature.WorkspaceIdentityService(
                        uuidClient: UUIDClient(
                            generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")! }
                        )
                    )
                )
            ),
            loadUseCase: AppFeature.WorkspaceProjectLoadUseCase(
                paintDocumentClient: paintDocumentClient,
                documentImportClient: .stub(),
                cleanupService: AppFeature.WorkspaceProjectCleanupService(
                    workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                        paintDocumentClient: paintDocumentClient,
                        documentWorkspaceClient: documentWorkspaceClient
                    ),
                    documentImportClient: .stub()
                )
            )
        )

        XCTAssertEqual(
            loadingService.execute(
                AppFeature.WorkspaceProjectLoadCommand(
                    loadRequest: .project(
                        AppFeature.WorkspaceProjectLoadOperation(
                            fileURL: URL(fileURLWithPath: "/tmp/open-target.atelier"),
                            removeWorkspaceItemOnSuccess: nil
                        )
                    ),
                    prepareDocumentReplacementRequest: AppFeature.WorkspaceDocumentReplacementRequest(
                        activeTab: activeTab,
                        paperStyle: .default
                    )
                )
            ),
            .failure(
                AppFeature.WorkspaceProjectLoadFailure(
                    request: .project(
                        AppFeature.WorkspaceProjectLoadOperation(
                            fileURL: URL(fileURLWithPath: "/tmp/open-target.atelier"),
                            removeWorkspaceItemOnSuccess: nil
                        )
                    ),
                    reason: .prepareDocumentReplacementFailed(.saveFailed("prepare replacement failed"))
                )
            )
        )
        XCTAssertTrue(loadCalls.values.isEmpty)
    }

    func testImportedProjectLoadSuccessDiscardsStagedDocument() {
        let stagedURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/staged-import.atelier"))
        let discardCalls = TestRecorder<DocumentProjectPath>()
        let loadedProject = LoadedPaintProject.testValue()
        let paintDocumentClient = PaintDocumentClient.stub(
            loadProject: { _ in loadedProject }
        )
        let documentImportClient = DocumentImportClient.stub(
            stageImportedDocument: { _ in
                .success(
                    ImportedDocumentStageResult(
                        stagedProjectURL: stagedURL,
                        suggestedTitle: "Imported"
                    )
                )
            },
            discardStagedDocument: { url in
                discardCalls.record(url)
                return .success(())
            }
        )
        let useCase = AppFeature.WorkspaceProjectLoadUseCase(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: documentImportClient,
            cleanupService: AppFeature.WorkspaceProjectCleanupService(
                workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                    paintDocumentClient: paintDocumentClient,
                    documentWorkspaceClient: .stub()
                ),
                documentImportClient: documentImportClient
            )
        )

        let result = useCase.execute(
            .imported(
                AppFeature.WorkspaceImportedProjectLoadOperation(
                    sourceURL: URL(fileURLWithPath: "/tmp/import-source.atelier")
                )
            )
        )

        XCTAssertEqual(result, .success(.imported(loadedProject, "Imported", [])))
        XCTAssertEqual(discardCalls.values, [stagedURL])
    }

    func testImportedCleanupFailureReturnsLoadIssue() {
        let loadedProject = LoadedPaintProject.testValue()
        let paintDocumentClient = PaintDocumentClient.stub(
            loadProject: { _ in loadedProject }
        )
        let documentImportClient = DocumentImportClient.stub(
            stageImportedDocument: { _ in
                .success(
                    ImportedDocumentStageResult(
                        stagedProjectURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/staged-import.atelier")),
                        suggestedTitle: "Imported"
                    )
                )
            },
            discardStagedDocument: { _ in
                .failure(.stagingFailed("cleanup failed"))
            }
        )
        let useCase = AppFeature.WorkspaceProjectLoadUseCase(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: documentImportClient,
            cleanupService: AppFeature.WorkspaceProjectCleanupService(
                workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                    paintDocumentClient: paintDocumentClient,
                    documentWorkspaceClient: .stub()
                ),
                documentImportClient: documentImportClient
            )
        )

        XCTAssertEqual(
            useCase.execute(
                .imported(
                    AppFeature.WorkspaceImportedProjectLoadOperation(
                        sourceURL: URL(fileURLWithPath: "/tmp/import-source.atelier")
                    )
                )
            ),
            .success(
                .imported(
                    loadedProject,
                    "Imported",
                    [.importedStagingCleanupFailed("cleanup failed")]
                )
            )
        )
    }

    func testStagedWorkspaceCleanupFailureReturnsLoadIssue() {
        let loadedProject = LoadedPaintProject.testValue()
        let stagedWorkspaceURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/staged-workspace.atelier"))
        let paintDocumentClient = PaintDocumentClient.stub(
            loadProject: { _ in loadedProject }
        )
        let documentWorkspaceClient = DocumentWorkspaceClient.stub(
            removeWorkspaceItem: { _ in
                throw TestError.expected("workspace cleanup failed")
            }
        )
        let useCase = AppFeature.WorkspaceProjectLoadUseCase(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: .stub(),
            cleanupService: AppFeature.WorkspaceProjectCleanupService(
                workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                    paintDocumentClient: paintDocumentClient,
                    documentWorkspaceClient: documentWorkspaceClient
                ),
                documentImportClient: .stub()
            )
        )

        XCTAssertEqual(
            useCase.execute(
                .project(
                    AppFeature.WorkspaceProjectLoadOperation(
                        fileURL: URL(fileURLWithPath: "/tmp/open-target.atelier"),
                        removeWorkspaceItemOnSuccess: stagedWorkspaceURL
                    )
                )
            ),
            .success(
                .project(
                    loadedProject,
                    [.workspaceItemRemovalFailed("workspace cleanup failed")]
                )
            )
        )
    }
}
