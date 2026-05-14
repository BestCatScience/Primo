import Foundation
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoDocumentPersistenceInfrastructure
import Testing

struct ProjectPackageFileAccessTests {
    @Test
    func enumerateFilesRejectsSymlinkEntries() throws {
        let packageURL = try makePackageDirectory()
        defer { try? FileManager.default.removeItem(at: packageURL) }
        let outsideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("primo-package-outside-\(UUID().uuidString).bin", isDirectory: false)
        try Data([1]).write(to: outsideURL)
        defer { try? FileManager.default.removeItem(at: outsideURL) }
        try FileManager.default.createSymbolicLink(
            at: packageURL.appendingPathComponent("linked.bin", isDirectory: false),
            withDestinationURL: outsideURL
        )

        let reader = ProjectPackageReader.live(fileClient: .live)
        let package = ProjectPackagePath(DocumentProjectPath(packageURL))

        #expect(throws: PaintDocumentPersistenceError.self) {
            _ = try reader.enumerateFiles(package)
        }
    }

    @Test
    func enumerateFilesSkipsDirectoryEntries() throws {
        let packageURL = try makePackageDirectory()
        defer { try? FileManager.default.removeItem(at: packageURL) }
        try FileManager.default.createDirectory(
            at: packageURL.appendingPathComponent("Nested", isDirectory: true),
            withIntermediateDirectories: false
        )

        let reader = ProjectPackageReader.live(fileClient: .live)
        let package = ProjectPackagePath(DocumentProjectPath(packageURL))

        #expect(try reader.enumerateFiles(package).isEmpty)
    }

    @Test
    func enumerateFilesReturnsCanonicalRelativeRegularFiles() throws {
        let packageURL = try makePackageDirectory()
        defer { try? FileManager.default.removeItem(at: packageURL) }
        let nestedURL = packageURL.appendingPathComponent("Layers", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: false)
        try Data([1, 2, 3]).write(to: nestedURL.appendingPathComponent("layer.bin", isDirectory: false))

        let reader = ProjectPackageReader.live(fileClient: .live)
        let package = ProjectPackagePath(DocumentProjectPath(packageURL))

        let files = try reader.enumerateFiles(package)

        #expect(files.map(\.relativePath) == ["Layers/layer.bin"])
        #expect(files.map(\.fileURL.standardizedFileURL) == [
            nestedURL.appendingPathComponent("layer.bin", isDirectory: false).standardizedFileURL,
        ])
    }

    private func makePackageDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("primo-package-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }
}
