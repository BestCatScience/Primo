import Foundation
import PrimoCoreTypes

public struct PaintDocumentPersistenceService {
    let fileClient: FileClient

    public init(fileClient: FileClient) {
        self.fileClient = fileClient
    }

    public func prepareProjectDirectory(at url: URL) throws {
        if fileClient.fileExists(url.path) {
            try fileClient.removeItem(url)
        }
        try fileClient.createDirectory(url, true)
    }

    public func createProjectSubdirectories(
        in projectURL: URL,
        usesOperationTimelapsePersistence: Bool
    ) throws -> (layersDirectory: URL, timelapseDirectory: URL, timelapseDataDirectory: URL) {
        let layersDirectory = projectURL.appendingPathComponent("Layers", isDirectory: true)
        let timelapseDirectory = projectURL.appendingPathComponent("Timelapse", isDirectory: true)
        let timelapseDataDirectory = projectURL.appendingPathComponent("TimelapseData", isDirectory: true)
        try fileClient.createDirectory(layersDirectory, true)
        if usesOperationTimelapsePersistence {
            try fileClient.createDirectory(timelapseDataDirectory, true)
        } else {
            try fileClient.createDirectory(timelapseDirectory, true)
        }
        return (layersDirectory, timelapseDirectory, timelapseDataDirectory)
    }

    public func writeAtomic(_ data: Data, to url: URL) throws {
        try fileClient.writeData(data, url, Data.WritingOptions.atomic)
    }

    public func loadData(from url: URL) throws -> Data {
        try fileClient.readData(url)
    }

    public func replaceItemIfNeeded(at destinationURL: URL, with sourceURL: URL) throws {
        if fileClient.fileExists(destinationURL.path) {
            try fileClient.removeItem(destinationURL)
        }
        try fileClient.copyItem(sourceURL, destinationURL)
    }
}
