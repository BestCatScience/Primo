import Foundation

struct PaintDocumentTimelapseService {
    let fileClient: FileClient
    let uuidClient: UUIDClient

    func makeDirectoryURL() -> URL {
        fileClient.temporaryDirectory()
            .appendingPathComponent("primo-timelapse", isDirectory: true)
            .appendingPathComponent(uuidClient.generate().uuidString, isDirectory: true)
    }

    func makeFrameURL(in directoryURL: URL, frameID: Int) -> URL {
        directoryURL.appendingPathComponent(String(format: "frame-%06d.jpg", frameID), isDirectory: false)
    }

    func persistFrameData(_ data: Data, to url: URL) throws {
        try fileClient.writeData(data, url, Data.WritingOptions.atomic)
    }

    func removeFrame(at url: URL) throws {
        try fileClient.removeItem(url)
    }

    func removeDirectory(at url: URL) throws {
        try fileClient.removeItem(url)
    }
}
