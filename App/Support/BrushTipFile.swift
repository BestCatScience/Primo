import ComposableArchitecture
import Foundation
import PrimoBrushFileFormats
import PrimoBrushInfrastructure
import UniformTypeIdentifiers

typealias BrushTipRaster = PrimoBrushFileFormats.BrushTipRaster
typealias BrushTipFile = PrimoBrushFileFormats.BrushTipFile
typealias BrushTipFileError = PrimoBrushFileFormats.BrushTipFileError

struct BrushTipLibraryClient: Sendable {
    var loadRaster: @Sendable (URL) throws -> BrushTipRaster
    var prepareBrushTipFile: @Sendable (URL) throws -> URL
    var importPhotoshopBrushes: @Sendable (URL) throws -> [ImportedPhotoshopBrush]

    static func live(fileClient: FileClient) -> BrushTipLibraryClient {
        let client = PrimoBrushInfrastructure.BrushTipLibraryClient.live(fileClient: fileClient)
        return BrushTipLibraryClient(
            loadRaster: client.loadRaster,
            prepareBrushTipFile: client.prepareBrushTipFile,
            importPhotoshopBrushes: { url in
                try client.importPhotoshopBrushSamples(url).map { sample in
                    let preset = BrushPreset.photoshopImported(name: sample.name, tip: sample.tip)
                    return ImportedPhotoshopBrush(name: sample.name, tip: sample.tip, preset: preset)
                }
            }
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
