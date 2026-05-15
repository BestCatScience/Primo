import Foundation
import PrimoCoreTypes
import PrimoSystemClients
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure
import Testing

struct DocumentImportClientTests {
    @Test
    func stageImportedDocumentCopiesProjectIntoTemporaryStagingDirectory() throws {
        let sourceRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceURL = sourceRoot.appendingPathComponent("Sample.project", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: sourceURL.appendingPathComponent("payload.txt"))

        let client = DocumentImportClient.infrastructureLive(
            fileClient: .live,
            uuidClient: UUIDClient(generate: { UUID(uuidString: "00000000-0000-0000-0000-000000000111")! }),
            securityScopedResourceClient: SecurityScopedResourceClient(
                startAccessing: { _ in true },
                stopAccessing: { _ in }
            )
        )

        let result = client.stageImportedDocument(
            ImportedDocumentStageRequest(sourceURL: sourceURL)
        )

        switch result {
        case let .success(staged):
            #expect(staged.suggestedTitle == "Sample")
            #expect(FileManager.default.fileExists(atPath: staged.stagedProjectURL.fileURL.path))
            #expect(
                FileManager.default.fileExists(
                    atPath: staged.stagedProjectURL.fileURL.appendingPathComponent("payload.txt").path
                )
            )
            _ = client.discardStagedDocument(staged.stagedProjectURL)
        case let .failure(failure):
            Issue.record("Unexpected staging failure: \(failure.localizedDescription)")
        }

        try? FileManager.default.removeItem(at: sourceRoot)
    }

    @Test
    func discardStagedDocumentRemovesCopiedDirectory() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let stagedURL = root.appendingPathComponent("Staged.project", isDirectory: true)
        try FileManager.default.createDirectory(at: stagedURL, withIntermediateDirectories: true)

        let client = DocumentImportClient.infrastructureLive(
            fileClient: .live,
            uuidClient: .live,
            securityScopedResourceClient: SecurityScopedResourceClient(
                startAccessing: { _ in true },
                stopAccessing: { _ in }
            )
        )

        let result = client.discardStagedDocument(.init(stagedURL))

        switch result {
        case .success:
            #expect(FileManager.default.fileExists(atPath: stagedURL.path) == false)
        case let .failure(failure):
            Issue.record("Unexpected discard failure: \(failure.localizedDescription)")
        }
    }
}
