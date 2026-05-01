import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication

public extension DocumentImportClient {
    private static let maxImportedPackageByteCount = 2 * 1024 * 1024 * 1024
    private static let maxImportedPackageFileCount = 300_000
    private static let maxImportedSingleFileByteCount = 512 * 1024 * 1024

    static func infrastructureLive(
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
                    try validateImportedPackageFootprint(at: request.sourceURL, fileClient: fileClient)
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

    private static func validateImportedPackageFootprint(at sourceURL: URL, fileClient: FileClient) throws {
        let urls = fileClient.enumerateURLs(
            sourceURL,
            [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            []
        )
        guard urls.count <= maxImportedPackageFileCount else {
            throw ImportedDocumentStageFailure.stagingFailed("Imported project contains too many files.")
        }
        var totalBytes = 0
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values?.isSymbolicLink != true else {
                throw ImportedDocumentStageFailure.stagingFailed("Imported project contains symbolic links.")
            }
            guard values?.isRegularFile == true else { continue }
            let fileSize = values?.fileSize ?? 0
            guard fileSize <= maxImportedSingleFileByteCount else {
                throw ImportedDocumentStageFailure.stagingFailed("Imported project contains an oversized file.")
            }
            let nextTotal = totalBytes.addingReportingOverflow(fileSize)
            guard !nextTotal.overflow, nextTotal.partialValue <= maxImportedPackageByteCount else {
                throw ImportedDocumentStageFailure.stagingFailed("Imported project is too large.")
            }
            totalBytes = nextTotal.partialValue
        }
    }
}
