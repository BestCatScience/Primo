import Foundation
import PrimoCoreTypes

public struct PaintDocumentTimelapseService {
    let fileClient: FileClient
    let uuidClient: UUIDClient

    public init(fileClient: FileClient, uuidClient: UUIDClient) {
        self.fileClient = fileClient
        self.uuidClient = uuidClient
    }

    public func makeDirectoryURL() -> URL {
        fileClient.temporaryDirectory()
            .appendingPathComponent("primo-timelapse", isDirectory: true)
            .appendingPathComponent(uuidClient.generate().uuidString, isDirectory: true)
    }

    public func makeFrameURL(in directoryURL: URL, frameID: Int) -> URL {
        directoryURL.appendingPathComponent(String(format: "frame-%06d.jpg", frameID), isDirectory: false)
    }

    public func persistFrameData(_ data: Data, to url: URL) throws {
        try fileClient.writeData(data, url, Data.WritingOptions.atomic)
    }

    public func removeFrame(at url: URL) throws {
        try fileClient.removeItem(url)
    }

    public func removeDirectory(at url: URL) throws {
        try fileClient.removeItem(url)
    }
}
