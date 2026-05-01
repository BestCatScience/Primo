import CoreGraphics
import Foundation
import XCTest
@testable import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
@testable import PrimoDocumentDomain
@testable import PrimoWorkspaceDomain

private enum TestError: LocalizedError {
    case expected(String)

    var errorDescription: String? {
        switch self {
        case let .expected(message):
            return message
        }
    }
}

private struct LoadedProject: Equatable, Sendable {
    var name = "loaded"
}

final class WorkspaceDomainTests: XCTestCase {
    func testWorkspaceCatalogMoveFailureRetainsRequestContext() {
        let sourceURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/source.atelier"))
        let request = WorkspaceCatalogRequest.moveSavedProject(
            WorkspaceSavedProjectMoveRequest(
                sourceURL: sourceURL,
                relativeFolderPath: nil,
                openTabID: nil
            )
        )
        let useCase = WorkspaceCatalogUseCase(
            workspaceCatalog: WorkspaceCatalogGateway(
                loadSavedProjects: { [] },
                moveSavedProject: { _, _ in
                    throw TestError.expected("move failed")
                },
                loadAutosaveRecoveryItems: { [] },
                discardAutosaveEntry: { _ in },
                loadSaveHistoryEntries: { _ in [] }
            )
        )

        XCTAssertEqual(
            useCase.execute(request),
            .failure(
                WorkspaceCatalogFailure(
                    request: request,
                    reason: .moveSavedProjectFailed("move failed")
                )
            )
        )
    }

    func testWorkspacePersistenceReserveBackingStoreReturnsPreparedTab() {
        let useCase = WorkspacePersistenceUseCase(
            workspaceBackingStore: WorkspaceBackingStoreGateway(
                saveProject: { _, _ in },
                persistProjectSnapshot: { sourceURL, preferredDestinationURL in preferredDestinationURL ?? sourceURL },
                createTabBackingStoreURL: {
                    DocumentProjectPath(URL(fileURLWithPath: "/tmp/\($0.uuidString).atelier"))
                },
                persistAutosaveSnapshot: { _, _ in },
                discardAutosaveSnapshot: { _ in },
                persistSaveHistorySnapshot: { _, _, _ in },
                removeWorkspaceItem: { _ in }
            ),
            workspaceCatalog: WorkspaceCatalogGateway(
                loadSavedProjects: { [] },
                moveSavedProject: { url, _ in url },
                loadAutosaveRecoveryItems: { [] },
                discardAutosaveEntry: { _ in },
                loadSaveHistoryEntries: { _ in [] }
            ),
            identityGenerator: WorkspaceIdentityGenerator(
                generateTabID: { UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")! }
            )
        )

        let request = WorkspacePersistenceRequest.reserveNewTabBackingStore(
            WorkspaceTabReservationRequest(
                title: "New",
                sourceProjectURL: nil,
                pane: .primary
            )
        )

        XCTAssertEqual(
            useCase.execute(request),
            .success(
                .newTabBackingStoreReserved(
                    PreparedWorkspaceTab(
                        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!,
                        title: "New",
                        backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/00000000-0000-0000-0000-0000000000C1.atelier")),
                        sourceProjectURL: nil,
                        pane: .primary
                    )
                )
            )
        )
    }

    func testWorkspaceProjectLoadImportedCleanupFailureBecomesIssue() {
        let useCase = WorkspaceProjectLoadUseCase(
            projectLoader: ProjectLoadingGateway<LoadedProject>(
                loadProject: { _ in LoadedProject() }
            ),
            documentImport: DocumentImportGateway(
                stageImportedDocument: { _ in
                    .success(
                        ImportedDocumentStageResult(
                            stagedProjectURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/staged.atelier")),
                            suggestedTitle: "Imported"
                        )
                    )
                },
                discardStagedDocument: { _ in
                    .failure(.stagingFailed("cleanup failed"))
                }
            ),
            cleanupService: WorkspaceProjectCleanupService(
                workspaceBackingStore: WorkspaceBackingStoreGateway(
                    saveProject: { _, _ in },
                    persistProjectSnapshot: { sourceURL, preferredDestinationURL in preferredDestinationURL ?? sourceURL },
                    createTabBackingStoreURL: { _ in DocumentProjectPath(URL(fileURLWithPath: "/tmp/tab.atelier")) },
                    persistAutosaveSnapshot: { _, _ in },
                    discardAutosaveSnapshot: { _ in },
                    persistSaveHistorySnapshot: { _, _, _ in },
                    removeWorkspaceItem: { _ in }
                ),
                documentImport: DocumentImportGateway(
                    stageImportedDocument: { _ in .failure(.stagingFailed("unused")) },
                    discardStagedDocument: { _ in .failure(.stagingFailed("cleanup failed")) }
                )
            )
        )

        XCTAssertEqual(
            useCase.execute(
                .imported(
                    WorkspaceImportedProjectLoadOperation(
                        sourceURL: URL(fileURLWithPath: "/tmp/source.atelier")
                    )
                )
            ),
            .success(
                .imported(
                    LoadedProject(),
                    "Imported",
                    [.importedStagingCleanupFailed("cleanup failed")]
                )
            )
        )
    }
}
