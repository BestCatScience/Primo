import CoreGraphics
import PrimoCanvasPresentationInfrastructure
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentRenderingInfrastructure
import UIKit

struct CanvasRenderSurfaceUpdate {
    let snapshot: MetalDocumentSnapshot?
    let activeLayerIndex: Int
    let incrementalUpdate: IncrementalLayerUpdate?
    let documentSize: CGSize
    let viewportOffset: CGSize
    let zoomScale: CGFloat
    let paperStyle: CanvasPaperStyle
    let previewResetNonce: Int
}

final class CanvasRenderSurfaceView: UIView {
    private let backend = PrimoMetalCanvasView()
    private let renderSession = CanvasRenderSession()
    private var lastPreviewResetNonce = 0
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

    func render(_ update: CanvasRenderSurfaceUpdate) {
        renderSession.retainResources(
            for: RenderFrameUpdate(
                snapshot: update.snapshot,
                activeLayerIndex: update.activeLayerIndex,
                incrementalUpdate: update.incrementalUpdate,
                documentSize: update.documentSize,
                viewportOffset: update.viewportOffset,
                zoomScale: update.zoomScale,
                paperStyle: update.paperStyle,
                previewResetNonce: update.previewResetNonce
            )
        )
        currentActiveLayerIndex = update.activeLayerIndex
        backend.currentActiveLayerIndex = update.activeLayerIndex
        backend.updateDocumentSize(update.documentSize)
        if update.previewResetNonce != lastPreviewResetNonce {
            backend.reloadSnapshot(update.snapshot)
            lastPreviewResetNonce = update.previewResetNonce
        }
        backend.update(
            snapshot: update.snapshot,
            viewportOffset: update.viewportOffset,
            zoomScale: update.zoomScale,
            paperStyle: update.paperStyle
        )
        if let incrementalUpdate = update.incrementalUpdate {
            backend.applyIncrementalUpdate(incrementalUpdate)
        }
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
    let renderingClient: DocumentRenderingClient
    let textService: MetalTextService

    static let live = CanvasImageRenderer(
        renderingClient: .live,
        textService: MetalTextService()
    )

    func eyedropperLoupeSurface(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        guard let rgba = renderingClient.eyedropperLoupeRGBA(
            sourcePixelData: sourcePixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: centerX,
            centerY: centerY,
            gridSize: gridSize,
            paperStyle: paperStyle,
            blendWithPaper: blendWithPaper
        ) else {
            return nil
        }
        return DocumentCompositeSurface(width: gridSize, height: gridSize, pixelData: rgba)
    }

    func selectionOverlaySurface(
        maskData: Data,
        width: Int,
        height: Int
    ) -> DocumentCompositeSurface? {
        guard let rgba = renderingClient.selectionOverlayRGBA(
            maskData: maskData,
            width: width,
            height: height
        ) else {
            return nil
        }
        return DocumentCompositeSurface(width: width, height: height, pixelData: rgba)
    }

    func compositePreviewImageData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        renderingClient.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    func paperCompositeSurface(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> DocumentCompositeSurface? {
        guard let rgba = renderingClient.compositedPaperPreviewRGBA(
            pixelData: pixelData,
            width: width,
            height: height,
            paperStyle: paperStyle
        ) else {
            return nil
        }
        return DocumentCompositeSurface(width: width, height: height, pixelData: rgba)
    }

    func shapePreviewSurface(
        stroke: Stroke,
        style: PreviewStrokeStyle,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        let samples = stroke.points.map(\.stylusSample)
        guard !samples.isEmpty else { return nil }
        let brush = brushSettings(for: style)
        guard let pixelData = renderingClient.rasterizedStrokePixelData(
            basePixelData: Data(count: canvasWidth * canvasHeight * 4),
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            samples: samples,
            brush: brush,
            mode: .interactive
        ) else {
            return nil
        }
        return DocumentCompositeSurface(width: canvasWidth, height: canvasHeight, pixelData: pixelData)
    }

    func transformedTextPreviewSurface(
        textLayer: TextLayerData,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        textService.rasterizeTextLayer(
            textLayer,
            canvasSize: CGSize(width: canvasWidth, height: canvasHeight)
        ).flatMap { payload in
            let pixelData = payload.fullPixelData ?? payload.rectPixelData
            return DocumentCompositeSurface(width: canvasWidth, height: canvasHeight, pixelData: pixelData)
        }
    }

    func transformedTextLayoutRect(
        textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> CGRect? {
        textService.textLayoutRect(
            for: textLayer,
            canvasSize: canvasSize
        )
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
