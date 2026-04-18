import Foundation
import XCTest
@testable import Primo

final class WorkspaceProjectLoadUseCaseTests: XCTestCase {
    func testPrepareReplacementFailureStopsProjectLoadBeforeLoading() {
        let loadCalls = TestRecorder<URL>()
        let activeTab = OpenDocumentTab.testValue()
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
        let persistenceUseCase = AppFeature.WorkspacePersistenceUseCase(
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
        let useCase = AppFeature.WorkspaceProjectLoadUseCase(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: .stub(),
            replacementPreparationService: AppFeature.WorkspaceProjectReplacementPreparationService(
                workspacePersistenceUseCase: persistenceUseCase
            ),
            cleanupService: AppFeature.WorkspaceProjectLoadCleanupService(
                workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                    paintDocumentClient: paintDocumentClient,
                    documentWorkspaceClient: documentWorkspaceClient
                ),
                documentImportClient: .stub()
            )
        )
        let request = AppFeature.WorkspaceProjectLoadRequest.project(
            AppFeature.WorkspaceProjectLoadOperation(
                fileURL: URL(fileURLWithPath: "/tmp/open-target.atelier"),
                prepareDocumentReplacementRequest: AppFeature.WorkspaceDocumentReplacementRequest(
                    activeTab: activeTab,
                    paperStyle: .default
                ),
                removeWorkspaceItemOnSuccess: nil
            )
        )

        let result = useCase.execute(request)

        XCTAssertEqual(
            result,
            .failure(
                AppFeature.WorkspaceProjectLoadFailure(
                    request: request,
                    feedback: .saveFailed("prepare replacement failed"),
                    errorMessage: nil
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
        let documentWorkspaceClient = DocumentWorkspaceClient.stub()
        let persistenceUseCase = AppFeature.WorkspacePersistenceUseCase(
            workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                paintDocumentClient: paintDocumentClient,
                documentWorkspaceClient: documentWorkspaceClient
            ),
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: documentWorkspaceClient
            ),
            workspaceIdentityService: AppFeature.WorkspaceIdentityService(
                uuidClient: UUIDClient(
                    generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")! }
                )
            )
        )
        let useCase = AppFeature.WorkspaceProjectLoadUseCase(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: documentImportClient,
            replacementPreparationService: AppFeature.WorkspaceProjectReplacementPreparationService(
                workspacePersistenceUseCase: persistenceUseCase
            ),
            cleanupService: AppFeature.WorkspaceProjectLoadCleanupService(
                workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                    paintDocumentClient: paintDocumentClient,
                    documentWorkspaceClient: documentWorkspaceClient
                ),
                documentImportClient: documentImportClient
            )
        )

        let result = useCase.execute(
            .imported(
                AppFeature.WorkspaceImportedProjectLoadOperation(
                    sourceURL: URL(fileURLWithPath: "/tmp/import-source.atelier"),
                    prepareDocumentReplacementRequest: nil
                )
            )
        )

        XCTAssertEqual(result, .success(.imported(loadedProject, "Imported")))
        XCTAssertEqual(discardCalls.values, [stagedURL])
    }

    func testImportedCleanupFailureKeepsLoadSuccessful() {
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
        let documentWorkspaceClient = DocumentWorkspaceClient.stub()
        let persistenceUseCase = AppFeature.WorkspacePersistenceUseCase(
            workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                paintDocumentClient: paintDocumentClient,
                documentWorkspaceClient: documentWorkspaceClient
            ),
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: documentWorkspaceClient
            ),
            workspaceIdentityService: AppFeature.WorkspaceIdentityService(
                uuidClient: UUIDClient(
                    generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")! }
                )
            )
        )
        let useCase = AppFeature.WorkspaceProjectLoadUseCase(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: documentImportClient,
            replacementPreparationService: AppFeature.WorkspaceProjectReplacementPreparationService(
                workspacePersistenceUseCase: persistenceUseCase
            ),
            cleanupService: AppFeature.WorkspaceProjectLoadCleanupService(
                workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                    paintDocumentClient: paintDocumentClient,
                    documentWorkspaceClient: documentWorkspaceClient
                ),
                documentImportClient: documentImportClient
            )
        )

        XCTAssertEqual(
            useCase.execute(
                .imported(
                    AppFeature.WorkspaceImportedProjectLoadOperation(
                        sourceURL: URL(fileURLWithPath: "/tmp/import-source.atelier"),
                        prepareDocumentReplacementRequest: nil
                    )
                )
            ),
            .success(.imported(loadedProject, "Imported"))
        )
    }

    func testStagedWorkspaceCleanupFailureKeepsProjectLoadSuccessful() {
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
        let persistenceUseCase = AppFeature.WorkspacePersistenceUseCase(
            workspaceBackingStoreService: AppFeature.WorkspaceBackingStoreService(
                paintDocumentClient: paintDocumentClient,
                documentWorkspaceClient: documentWorkspaceClient
            ),
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: documentWorkspaceClient
            ),
            workspaceIdentityService: AppFeature.WorkspaceIdentityService(
                uuidClient: UUIDClient(
                    generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000C4")! }
                )
            )
        )
        let useCase = AppFeature.WorkspaceProjectLoadUseCase(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: .stub(),
            replacementPreparationService: AppFeature.WorkspaceProjectReplacementPreparationService(
                workspacePersistenceUseCase: persistenceUseCase
            ),
            cleanupService: AppFeature.WorkspaceProjectLoadCleanupService(
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
                        prepareDocumentReplacementRequest: nil,
                        removeWorkspaceItemOnSuccess: stagedWorkspaceURL
                    )
                )
            ),
            .success(.project(loadedProject))
        )
    }
}
