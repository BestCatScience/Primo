#if canImport(UIKit)
import PrimoCanvasPresentationDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import UIKit

final class CanvasSelectionOverlayView: UIView {
    private let selectionOverlayView = CanvasPixelSurfaceView()
    private let selectionOutlineLayer = CAShapeLayer()
    private let selectionPreviewLayer = CAShapeLayer()
    private let selectionProcessor: any SelectionMaskProcessing

    init(selectionProcessor: any SelectionMaskProcessing) {
        self.selectionProcessor = selectionProcessor
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        selectionOverlayView.isUserInteractionEnabled = false
        selectionOverlayView.alpha = 0.55
        addSubview(selectionOverlayView)

        selectionOutlineLayer.strokeColor = UIColor.white.withAlphaComponent(0.92).cgColor
        selectionOutlineLayer.fillColor = UIColor.clear.cgColor
        selectionOutlineLayer.lineWidth = 1.5
        selectionOutlineLayer.lineDashPattern = [6, 4]
        layer.addSublayer(selectionOutlineLayer)

        selectionPreviewLayer.strokeColor = UIColor.white.withAlphaComponent(0.8).cgColor
        selectionPreviewLayer.fillColor = UIColor.clear.cgColor
        selectionPreviewLayer.lineWidth = 1.25
        selectionPreviewLayer.lineDashPattern = [4, 4]
        layer.addSublayer(selectionPreviewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        selectionOutlineLayer.frame = bounds
        selectionPreviewLayer.frame = bounds
    }

    func update(
        selection: CanvasSelection?,
        previewPoints: [CGPoint],
        currentTool: StudioToolKind,
        geometry viewport: CanvasViewportGeometry
    ) {
        frame = viewport.bounds
        updateSelectionOverlay(
            selection,
            currentTool: currentTool,
            geometry: viewport
        )
        updateSelectionPreview(previewPoints, currentTool: currentTool, geometry: viewport)
    }

    private func updateSelectionOverlay(
        _ selection: CanvasSelection?,
        currentTool: StudioToolKind,
        geometry viewport: CanvasViewportGeometry
    ) {
        guard
            currentTool == .select,
            let selection,
            !selection.isEmpty,
            let surface = makeSelectionOverlaySurface(selection)
        else {
            selectionOverlayView.update(surface: nil)
            selectionOverlayView.frame = .zero
            selectionOutlineLayer.path = nil
            return
        }

        let rect = viewport.viewRect(forDocumentRect: selection.bounds)
        selectionOverlayView.update(surface: surface)
        selectionOverlayView.frame = rect
        selectionOutlineLayer.path = UIBezierPath(rect: rect).cgPath
    }

    private func updateSelectionPreview(
        _ points: [CGPoint],
        currentTool: StudioToolKind,
        geometry viewport: CanvasViewportGeometry
    ) {
        guard currentTool == .select, points.count >= 2 else {
            selectionPreviewLayer.path = nil
            return
        }

        let path = UIBezierPath()
        for (index, point) in points.enumerated() {
            let mapped = viewport.viewPoint(fromDocumentPoint: point)
            if index == 0 {
                path.move(to: mapped)
            } else {
                path.addLine(to: mapped)
            }
        }
        selectionPreviewLayer.path = path.cgPath
    }

    private func makeSelectionOverlaySurface(_ selection: CanvasSelection) -> DocumentCompositeSurface? {
        let width = selection.maskWidth
        let height = selection.maskHeight
        guard width > 0, height > 0 else { return nil }
        let expectedCount = width * height
        guard selection.maskData.count == expectedCount else { return nil }
        return selectionProcessor.selectionOverlaySurface(
            maskData: selection.maskData,
            width: width,
            height: height
        )
    }
}
#endif
