import Foundation
import PrimoWorkspaceInfrastructure
import XCTest
@testable import Primo

final class WorkspaceProjectLoadUseCaseTests: XCTestCase {
    func testPrepareReplacementFailureStopsBeforeLoad() {
        let activeTab = OpenDocumentTab.testValue()
        let loadCalls = TestRecorder<URL>()
        let documentPersistenceGateway = DocumentPersistenceGateway.stub(
            saveProject: { _, _ in
                throw TestError.expected("prepare replacement failed")
            },
            loadProject: { url in
                loadCalls.record(url)
                return .testValue()
            }
        )
        let documentWorkspaceClient = DocumentWorkspaceClient.stub()
        let support = WorkspaceFeatureSupport(
            documentPersistenceGateway: documentPersistenceGateway,
            documentWorkspaceClient: documentWorkspaceClient,
            uuidClient: UUIDClient(
                generate: { UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")! }
            )
        )
        let loadingService = support.projectLoadingService(
            projectLoader: ProjectLoadingGateway(
                loadProject: { url in
                    try documentPersistenceGateway.loadProject(url)
                }
            ),
            documentImport: DocumentImportGateway(
                stageImportedDocument: { request in
                    DocumentImportClient.stub().stageImportedDocument(
                        ImportedDocumentStageRequest(sourceURL: request.sourceURL)
                    )
                },
                discardStagedDocument: { stagedProjectURL in
                    DocumentImportClient.stub().discardStagedDocument(stagedProjectURL)
                }
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
        let documentPersistenceGateway = DocumentPersistenceGateway.stub(
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
        let support = WorkspaceFeatureSupport(
            documentPersistenceGateway: documentPersistenceGateway,
            documentWorkspaceClient: .stub(),
            uuidClient: UUIDClient(generate: UUID.init)
        )
        let useCase = support.projectLoadUseCase(
            projectLoader: ProjectLoadingGateway(
                loadProject: { url in
                    try documentPersistenceGateway.loadProject(url)
                }
            ),
            documentImport: DocumentImportGateway(
                stageImportedDocument: { request in
                    documentImportClient.stageImportedDocument(
                        ImportedDocumentStageRequest(sourceURL: request.sourceURL)
                    )
                },
                discardStagedDocument: { stagedProjectURL in
                    documentImportClient.discardStagedDocument(stagedProjectURL)
                }
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
        let documentPersistenceGateway = DocumentPersistenceGateway.stub(
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
        let support = WorkspaceFeatureSupport(
            documentPersistenceGateway: documentPersistenceGateway,
            documentWorkspaceClient: .stub(),
            uuidClient: UUIDClient(generate: UUID.init)
        )
        let useCase = support.projectLoadUseCase(
            projectLoader: ProjectLoadingGateway(
                loadProject: { url in
                    try documentPersistenceGateway.loadProject(url)
                }
            ),
            documentImport: DocumentImportGateway(
                stageImportedDocument: { request in
                    documentImportClient.stageImportedDocument(
                        ImportedDocumentStageRequest(sourceURL: request.sourceURL)
                    )
                },
                discardStagedDocument: { stagedProjectURL in
                    documentImportClient.discardStagedDocument(stagedProjectURL)
                }
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
        let documentPersistenceGateway = DocumentPersistenceGateway.stub(
            loadProject: { _ in loadedProject }
        )
        let documentWorkspaceClient = DocumentWorkspaceClient.stub(
            removeWorkspaceItem: { _ in
                throw TestError.expected("workspace cleanup failed")
            }
        )
        let support = WorkspaceFeatureSupport(
            documentPersistenceGateway: documentPersistenceGateway,
            documentWorkspaceClient: documentWorkspaceClient,
            uuidClient: UUIDClient(generate: UUID.init)
        )
        let useCase = support.projectLoadUseCase(
            projectLoader: ProjectLoadingGateway(
                loadProject: { url in
                    try documentPersistenceGateway.loadProject(url)
                }
            ),
            documentImport: DocumentImportGateway(
                stageImportedDocument: { request in
                    DocumentImportClient.stub().stageImportedDocument(
                        ImportedDocumentStageRequest(sourceURL: request.sourceURL)
                    )
                },
                discardStagedDocument: { stagedProjectURL in
                    DocumentImportClient.stub().discardStagedDocument(stagedProjectURL)
                }
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
