import CoreGraphics
import PrimoCanvasPresentationInfrastructure
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure
import UIKit

final class CanvasRenderSurfaceView: UIView {
    private let backend = PrimoMetalCanvasView()
    private let driver = CanvasRenderSurfaceDriver()
    private(set) var currentActiveLayerIndex: Int = 0

    var currentSnapshot: MetalDocumentSnapshot? {
        backend.currentSnapshot
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backend.isUserInteractionEnabled = false
        addSubview(backend)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backend.frame = bounds
    }

    func render(_ update: RenderFrameUpdate) {
        driver.render(update, into: backend)
        currentActiveLayerIndex = driver.currentActiveLayerIndex
    }

    func contentRect(
        for viewSize: CGSize,
        documentSize: CGSize,
        viewportOffset: CGSize,
        zoomScale: CGFloat
    ) -> CGRect {
        backend.contentRect(
            for: viewSize,
            documentSize: documentSize,
            viewportOffset: viewportOffset,
            zoomScale: zoomScale
        )
    }
}

final class CanvasPixelSurfaceView: UIView {
    private let backend = PrimoMetalCanvasView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backend.isUserInteractionEnabled = false
        addSubview(backend)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backend.frame = bounds
    }

    func update(
        surface: DocumentCompositeSurface?,
        opacity: CGFloat = 1.0,
        filtering: PrimoMetalSurfaceFiltering = .linear
    ) {
        backend.updateSurface(surface, opacity: Float(opacity), filtering: filtering)
        isHidden = surface == nil
    }
}

struct CanvasImageRenderer {
    static let live = CanvasImageRenderer()

    func eyedropperLoupeSurface(
        gpuOperations: DocumentGpuOperationGateway,
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        guard let rgba = gpuOperations.eyedropperLoupeRGBA(
            sourcePixelData,
            canvasWidth,
            canvasHeight,
            centerX,
            centerY,
            gridSize,
            paperStyle,
            blendWithPaper
        ) else {
            return nil
        }
        return DocumentCompositeSurface(width: gridSize, height: gridSize, pixelData: rgba)
    }

    func selectionOverlaySurface(
        gpuOperations: DocumentGpuOperationGateway,
        maskData: Data,
        width: Int,
        height: Int
    ) -> DocumentCompositeSurface? {
        guard let rgba = gpuOperations.selectionOverlayRGBA(maskData, width, height) else {
            return nil
        }
        return DocumentCompositeSurface(width: width, height: height, pixelData: rgba)
    }

    func compositePreviewImageData(
        gpuOperations: DocumentGpuOperationGateway,
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        gpuOperations.compositedPreviewPixelData(snapshot, activeLayerIndex, adjustedActiveLayerPixels)
    }

    func paperCompositeSurface(
        gpuOperations: DocumentGpuOperationGateway,
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> DocumentCompositeSurface? {
        guard let rgba = gpuOperations.compositedPaperPreviewRGBA(pixelData, width, height, paperStyle) else {
            return nil
        }
        return DocumentCompositeSurface(width: width, height: height, pixelData: rgba)
    }

    func shapePreviewSurface(
        gpuOperations: DocumentGpuOperationGateway,
        stroke: Stroke,
        style: PreviewStrokeStyle,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        let samples = stroke.points.map(\.stylusSample)
        guard !samples.isEmpty else { return nil }
        let brush = brushSettings(for: style)
        return gpuOperations.shapePreviewSurface(samples, brush, canvasWidth, canvasHeight)
    }

    func transformedTextPreviewSurface(
        gpuOperations: DocumentGpuOperationGateway,
        textLayer: TextLayerData,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        gpuOperations.textLayerSurface(
            textLayer,
            CGSize(width: canvasWidth, height: canvasHeight)
        )
    }

    func transformedTextLayoutRect(
        gpuOperations: DocumentGpuOperationGateway,
        textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> CGRect? {
        gpuOperations.textLayoutRect(textLayer, canvasSize)
    }

    private func brushSettings(for style: PreviewStrokeStyle) -> BrushRuntimeSettings {
        let components = style.color.components ?? [0, 0, 0, 1]
        let red = UInt8(max(0, min(255, Int((components[safe: 0] ?? 0) * 255.0))))
        let green = UInt8(max(0, min(255, Int((components[safe: 1] ?? 0) * 255.0))))
        let blue = UInt8(max(0, min(255, Int((components[safe: 2] ?? 0) * 255.0))))
        return BrushRuntimeSettings(
            tipKind: style.tipKind,
            radius: Double(style.radius),
            opacity: Double(style.opacity),
            hardness: Double(style.hardness),
            roundness: Double(style.roundness),
            angle: Double(style.angle),
            angleMode: style.followsStrokeAngle ? .strokeDirection : .fixed,
            stampSpacing: 0.16,
            spacingJitter: 0,
            scatterLateral: 0,
            scatterLinear: 0,
            count: 1,
            countJitter: 0,
            angleJitter: 0,
            roundnessJitter: 0,
            textureMode: .off,
            textureStrength: 0,
            flow: Double(style.flow),
            customTip: style.customTip,
            pressureSensitivity: Double(style.pressureSensitivity),
            stabilization: Double(style.stabilization),
            red: red,
            green: green,
            blue: blue,
            isEraser: style.isEraser
        )
    }
}

private extension Array where Element == CGFloat {
    subscript(safe index: Int) -> CGFloat? {
        indices.contains(index) ? self[index] : nil
    }
}
