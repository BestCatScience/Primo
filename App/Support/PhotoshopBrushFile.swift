import PrimoBrushFileFormats
import PrimoBrushRuntimeContracts

struct ImportedPhotoshopBrush: Equatable, Sendable {
    let name: String
    let tip: BrushTipRaster
    let preset: BrushPreset
}
