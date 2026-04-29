#if canImport(UIKit)
import CoreGraphics
import PrimoCanvasPresentationDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure
import UIKit

public final class CanvasRenderSurfaceView: UIView {
    private let backend = PrimoMetalCanvasView()
    private let driver = CanvasRenderSurfaceDriver()
    public private(set) var currentActiveLayerIndex: Int = 0

    public var currentSnapshot: MetalDocumentSnapshot? {
        backend.currentSnapshot
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backend.isUserInteractionEnabled = false
        addSubview(backend)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        backend.frame = bounds
    }

    public func render(_ update: RenderFrameUpdate) {
        driver.render(update, into: backend)
        currentActiveLayerIndex = driver.currentActiveLayerIndex
    }

    public func contentRect(
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

public final class CanvasPixelSurfaceView: UIView {
    private let backend = PrimoMetalCanvasView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backend.isUserInteractionEnabled = false
        addSubview(backend)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        backend.frame = bounds
    }

    public func update(
        surface: DocumentCompositeSurface?,
        opacity: CGFloat = 1.0,
        filtering: PrimoMetalSurfaceFiltering = .linear
    ) {
        backend.updateSurface(surface, opacity: Float(opacity), filtering: filtering)
        isHidden = surface == nil
    }
}
#endif
