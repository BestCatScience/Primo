import ComposableArchitecture
import Foundation
import PrimoBrushFileFormats
import PrimoBrushRuntime
import PrimoCoreTypes
import UniformTypeIdentifiers

struct BrushTipLibraryClient: Sendable {
    let loadRaster: @Sendable (URL) throws -> PrimoBrushFileFormats.BrushTipRaster
    let prepareBrushTipFile: @Sendable (URL) throws -> URL
    let importPhotoshopBrushes: @Sendable (URL) throws -> [ImportedPhotoshopBrush]

    static func live(fileClient: PrimoCoreTypes.FileClient) -> BrushTipLibraryClient {
        let client = PrimoBrushRuntime.BrushTipLibraryClient.live(fileClient: fileClient)
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
