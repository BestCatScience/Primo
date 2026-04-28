import Foundation
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure

struct GpuOverlayRenderingService: Sendable {
    private let executor: MetalOverlayExecutor

    init(executor: MetalOverlayExecutor = MetalOverlayExecutor()) {
        self.executor = executor
    }

    func selectionOverlayRGBA(
        maskData: Data,
        width: Int,
        height: Int,
        red: UInt8 = 91,
        green: UInt8 = 181,
        blue: UInt8 = 255,
        maximumAlpha: Float = 96.0 / 255.0
    ) -> Data? {
        executor.selectionOverlayRGBA(
            maskData: maskData,
            width: width,
            height: height,
            red: red,
            green: green,
            blue: blue,
            maximumAlpha: maximumAlpha
        )
    }

    func eyedropperLoupeRGBA(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> Data? {
        executor.eyedropperLoupeRGBA(
            sourcePixelData: sourcePixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: centerX,
            centerY: centerY,
            gridSize: gridSize,
            paperStyle: paperStyle,
            blendWithPaper: blendWithPaper
        )
    }
}
