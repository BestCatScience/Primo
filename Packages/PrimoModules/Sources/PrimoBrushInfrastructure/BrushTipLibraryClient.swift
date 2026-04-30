import Foundation
import PrimoBrushFileFormats
import PrimoCoreTypes

public struct BrushTipLibraryClient: Sendable {
    public let loadRaster: @Sendable (URL) throws -> BrushTipRaster
    public let prepareBrushTipFile: @Sendable (URL) throws -> URL
    public let importPhotoshopBrushSamples: @Sendable (URL) throws -> [ImportedPhotoshopBrushSample]

    public init(
        loadRaster: @escaping @Sendable (URL) throws -> BrushTipRaster,
        prepareBrushTipFile: @escaping @Sendable (URL) throws -> URL,
        importPhotoshopBrushSamples: @escaping @Sendable (URL) throws -> [ImportedPhotoshopBrushSample]
    ) {
        self.loadRaster = loadRaster
        self.prepareBrushTipFile = prepareBrushTipFile
        self.importPhotoshopBrushSamples = importPhotoshopBrushSamples
    }

    public static func live(fileClient: FileClient) -> BrushTipLibraryClient {
        let storage = BrushTipLibraryStorage(fileClient: fileClient)
        return BrushTipLibraryClient(
            loadRaster: { try storage.loadRaster(from: $0) },
            prepareBrushTipFile: { try storage.prepareBrushTipFile(from: $0) },
            importPhotoshopBrushSamples: { try storage.importPhotoshopBrushSamples(from: $0) }
        )
    }
}

private struct BrushTipLibraryStorage {
    let fileClient: FileClient

    func loadRaster(from sourceURL: URL) throws -> BrushTipRaster {
        let resolvedURL = try prepareBrushTipFile(from: sourceURL)
        let data = try fileClient.readData(resolvedURL)
        return try BrushTipFile.decode(from: data).raster
    }

    func prepareBrushTipFile(from sourceURL: URL) throws -> URL {
        if sourceURL.pathExtension.lowercased() == BrushTipFile.fileExtension {
            return sourceURL
        }

        guard sourceURL.pathExtension.lowercased() == "png" else {
            throw BrushTipFileError.invalidPNG
        }

        let pngData = try fileClient.readData(sourceURL)
        let fileHash = pngData.primoDeterministicHash
        let sanitizedName = sourceURL.deletingPathExtension().lastPathComponent
        let fileName = "\(sanitizedName)-\(fileHash.prefix(12)).\(BrushTipFile.fileExtension)"
        let targetURL = try brushTipCacheDirectory().appendingPathComponent(fileName, isDirectory: false)
        if fileClient.fileExists(targetURL.path) {
            return targetURL
        }

        let brushTipFile = try BrushTipFile.importPNG(data: pngData, suggestedName: sanitizedName)
        try fileClient.writeData(brushTipFile.encodedData(), targetURL, .atomic)
        return targetURL
    }

    func importPhotoshopBrushSamples(from sourceURL: URL) throws -> [ImportedPhotoshopBrushSample] {
        try PrimoBrushFileFormats.PhotoshopBrushFile.importABR(
            from: sourceURL,
            fileClient: fileClient
        )
    }

    private func brushTipCacheDirectory() throws -> URL {
        let base = fileClient.urls(.applicationSupportDirectory, .userDomainMask)[0]
        let directory = base
            .appendingPathComponent("primo", isDirectory: true)
            .appendingPathComponent("BrushTips", isDirectory: true)
        try fileClient.createDirectory(directory, true)
        return directory
    }
}

private extension Data {
    var primoDeterministicHash: String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in self {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}
