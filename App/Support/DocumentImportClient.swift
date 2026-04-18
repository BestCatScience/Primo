import ComposableArchitecture
import Foundation
import PrimoDocumentContracts

typealias ImportedDocumentStageRequest = PrimoDocumentContracts.ImportedDocumentStageRequest
typealias ImportedDocumentStageResult = PrimoDocumentContracts.ImportedDocumentStageResult
typealias ImportedDocumentStageFailure = PrimoDocumentContracts.ImportedDocumentStageFailure

struct DocumentImportClient: Sendable {
    var stageImportedDocument: @Sendable (ImportedDocumentStageRequest) -> Result<ImportedDocumentStageResult, ImportedDocumentStageFailure>
    var discardStagedDocument: @Sendable (DocumentProjectPath) -> Result<Void, ImportedDocumentStageFailure>

    static func live(
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

private enum DocumentImportClientKey: DependencyKey {
    static var liveValue: DocumentImportClient {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.uuidClient) var uuidClient
        @Dependency(\.securityScopedResourceClient) var securityScopedResourceClient
        return .live(
            fileClient: fileClient,
            uuidClient: uuidClient,
            securityScopedResourceClient: securityScopedResourceClient
        )
    }
}

extension DependencyValues {
    var documentImportClient: DocumentImportClient {
        get { self[DocumentImportClientKey.self] }
        set { self[DocumentImportClientKey.self] = newValue }
    }
}
