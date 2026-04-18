import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoDocumentDomain

public typealias ImportedDocumentStageRequest = PrimoDocumentContracts.ImportedDocumentStageRequest
public typealias ImportedDocumentStageResult = PrimoDocumentContracts.ImportedDocumentStageResult
public typealias ImportedDocumentStageFailure = PrimoDocumentContracts.ImportedDocumentStageFailure

public struct DocumentImportClient: Sendable {
    public var stageImportedDocument: @Sendable (ImportedDocumentStageRequest) -> Result<ImportedDocumentStageResult, ImportedDocumentStageFailure>
    public var discardStagedDocument: @Sendable (DocumentProjectPath) -> Result<Void, ImportedDocumentStageFailure>

    public init(
        stageImportedDocument: @escaping @Sendable (ImportedDocumentStageRequest) -> Result<ImportedDocumentStageResult, ImportedDocumentStageFailure>,
        discardStagedDocument: @escaping @Sendable (DocumentProjectPath) -> Result<Void, ImportedDocumentStageFailure>
    ) {
        self.stageImportedDocument = stageImportedDocument
        self.discardStagedDocument = discardStagedDocument
    }

    public static func live(
        fileClient: FileClient,
        uuidClient: UUIDClient,
        securityScopedResourceClient: SecurityScopedResourceClient
    ) -> DocumentImportClient {
        DocumentImportClient(
            stageImportedDocument: { request in
                let didAccess = securityScopedResourceClient.startAccessing(request.sourceURL)
                defer {
                    if didAccess {
                        securityScopedResourceClient.stopAccessing(request.sourceURL)
                    }
                }
                let stagingRoot = fileClient.temporaryDirectory()
                    .appendingPathComponent("primo-open", isDirectory: true)
                    .appendingPathComponent(uuidClient.generate().uuidString, isDirectory: true)
                let destinationURL = stagingRoot.appendingPathComponent(
                    request.sourceURL.lastPathComponent,
                    isDirectory: true
                )

                do {
                    try fileClient.createDirectory(stagingRoot, true)
                    if fileClient.fileExists(destinationURL.path) {
                        try fileClient.removeItem(destinationURL)
                    }
                    try fileClient.copyItem(request.sourceURL, destinationURL)
                    return .success(
                        ImportedDocumentStageResult(
                            stagedProjectURL: DocumentProjectPath(destinationURL),
                            suggestedTitle: request.sourceURL.deletingPathExtension().lastPathComponent
                        )
                    )
                } catch {
                    return .failure(
                        .stagingFailed(error.localizedDescription)
                    )
                }
            },
            discardStagedDocument: { stagedProjectURL in
                do {
                    if fileClient.fileExists(stagedProjectURL.fileURL.path) {
                        try fileClient.removeItem(stagedProjectURL.fileURL)
                    }
                    return .success(())
                } catch {
                    return .failure(.stagingFailed(error.localizedDescription))
                }
            }
        )
    }
}
