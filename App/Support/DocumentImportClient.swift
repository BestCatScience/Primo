import ComposableArchitecture
import Foundation

struct ImportedDocumentStageRequest: Equatable, OperationRequest {
    let sourceURL: URL
}

struct ImportedDocumentStageResult: Equatable, OperationResult {
    let stagedProjectURL: DocumentProjectPath
    let suggestedTitle: String
}

enum ImportedDocumentStageFailure: LocalizedError, Equatable, OperationFailure {
    case stagingFailed(String)

    var errorDescription: String? {
        switch self {
        case let .stagingFailed(message):
            return message
        }
    }
}

enum ImportedDocumentStageContract: OperationContract {
    typealias Request = ImportedDocumentStageRequest
    typealias Result = ImportedDocumentStageResult
    typealias Failure = ImportedDocumentStageFailure
}

struct DocumentImportClient: Sendable {
    var stageImportedDocument: @Sendable (ImportedDocumentStageRequest) -> Result<ImportedDocumentStageResult, ImportedDocumentStageFailure>
    var discardStagedDocument: @Sendable (DocumentProjectPath) -> Result<Void, ImportedDocumentStageFailure>

    static func live(
        fileClient: FileClient,
        uuidClient: UUIDClient
    ) -> DocumentImportClient {
        DocumentImportClient(
            stageImportedDocument: { request in
                withSecurityScopedAccess(to: request.sourceURL) {
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
        return .live(fileClient: fileClient, uuidClient: uuidClient)
    }
}

extension DependencyValues {
    var documentImportClient: DocumentImportClient {
        get { self[DocumentImportClientKey.self] }
        set { self[DocumentImportClientKey.self] = newValue }
    }
}
