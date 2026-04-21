import CoreGraphics
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentRuntimeInfrastructure
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

struct CanvasImageRenderer {
    let renderingClient: DocumentRenderingClient

    static let live = CanvasImageRenderer(renderingClient: .live)

    func eyedropperLoupeImage(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool,
        imageBuilder: (Data, Int) -> UIImage?
    ) -> UIImage? {
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
        return imageBuilder(rgba, gridSize)
    }

    func selectionOverlayImage(
        maskData: Data,
        width: Int,
        height: Int,
        imageBuilder: (Data, Int, Int) -> UIImage?
    ) -> UIImage? {
        guard let rgba = renderingClient.selectionOverlayRGBA(
            maskData: maskData,
            width: width,
            height: height
        ) else {
            return nil
        }
        return imageBuilder(rgba, width, height)
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

    func paperCompositeImage(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle,
        imageBuilder: (Data, Int, Int) -> UIImage?
    ) -> UIImage? {
        guard let rgba = renderingClient.compositedPaperPreviewRGBA(
            pixelData: pixelData,
            width: width,
            height: height,
            paperStyle: paperStyle
        ) else {
            return nil
        }
        return imageBuilder(rgba, width, height)
    }
}
