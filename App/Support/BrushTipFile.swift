import ComposableArchitecture
import CryptoKit
import Foundation
import PrimoBrushFileFormats
import UniformTypeIdentifiers

typealias BrushTipRaster = PrimoBrushFileFormats.BrushTipRaster
typealias BrushTipFile = PrimoBrushFileFormats.BrushTipFile
typealias BrushTipFileError = PrimoBrushFileFormats.BrushTipFileError

struct BrushTipLibraryClient: Sendable {
    var loadRaster: @Sendable (URL) throws -> BrushTipRaster
    var prepareBrushTipFile: @Sendable (URL) throws -> URL
    var importPhotoshopBrushes: @Sendable (URL) throws -> [ImportedPhotoshopBrush]

    static func live(fileClient: FileClient) -> BrushTipLibraryClient {
        let storage = BrushTipLibraryStorage(fileClient: fileClient)
        return BrushTipLibraryClient(
            loadRaster: { try storage.loadRaster(from: $0) },
            prepareBrushTipFile: { try storage.prepareBrushTipFile(from: $0) },
            importPhotoshopBrushes: { try storage.importPhotoshopBrushes(from: $0) }
        )
    }
}

private enum BrushTipLibraryClientKey: DependencyKey {
    static var liveValue: BrushTipLibraryClient {
        @Dependency(\.fileClient) var fileClient
        return .live(fileClient: fileClient)
    }
}

extension DependencyValues {
    var brushTipLibraryClient: BrushTipLibraryClient {
        get { self[BrushTipLibraryClientKey.self] }
        set { self[BrushTipLibraryClientKey.self] = newValue }
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
        let fileHash = SHA256.hash(data: pngData).compactMap { String(format: "%02x", $0) }.joined()
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

    func importPhotoshopBrushes(from sourceURL: URL) throws -> [ImportedPhotoshopBrush] {
        try PrimoBrushFileFormats.PhotoshopBrushFile.importABR(
            from: sourceURL,
            fileClient: fileClient
        ).map { sample in
            let preset = BrushPreset.photoshopImported(name: sample.name, tip: sample.tip)
            return ImportedPhotoshopBrush(name: sample.name, tip: sample.tip, preset: preset)
        }
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
