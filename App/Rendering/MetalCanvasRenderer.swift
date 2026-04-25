import CoreGraphics
import PrimoCanvasPresentationDomain
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
