import CoreGraphics
import PrimoCanvasPresentationDomain
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRenderingInfrastructure

package struct GpuCanvasEyedropperSampler: CanvasEyedropperSampling {
    private let sampler = PrimoDocumentRenderingInfrastructure.GpuCanvasEyedropperSampler()

    package init() {}

    package func sampledColor(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        source: EyedropperSamplingSource,
        point: CGPoint,
        paperStyle: CanvasPaperStyle
    ) -> SampledColor? {
        sampler.sampledColor(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            source: source,
            point: point,
            paperStyle: paperStyle
        )
    }
}
