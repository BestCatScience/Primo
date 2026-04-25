import PrimoDocumentContracts
import PrimoDocumentDomain
import UIKit

final class CanvasSelectionOverlayView: UIView {
    private let selectionOverlayView = CanvasPixelSurfaceView()
    private let selectionOutlineLayer = CAShapeLayer()
    private let selectionPreviewLayer = CAShapeLayer()
    private let canvasImageRenderer: CanvasImageRenderer
    var documentGpuOperationGateway: DocumentGpuOperationGateway?

    init(canvasImageRenderer: CanvasImageRenderer) {
        self.canvasImageRenderer = canvasImageRenderer
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
        geometry viewport: CanvasViewportGeometry,
        transformQuad: ((CGRect) -> TransformQuad)?,
        hidesTransformedOverlayImage: Bool
    ) {
        frame = viewport.bounds
        updateSelectionOverlay(
            selection,
            currentTool: currentTool,
            geometry: viewport,
            transformQuad: transformQuad,
            hidesTransformedOverlayImage: hidesTransformedOverlayImage
        )
        updateSelectionPreview(previewPoints, currentTool: currentTool, geometry: viewport)
    }

    private func updateSelectionOverlay(
        _ selection: CanvasSelection?,
        currentTool: StudioToolKind,
        geometry viewport: CanvasViewportGeometry,
        transformQuad: ((CGRect) -> TransformQuad)?,
        hidesTransformedOverlayImage: Bool
    ) {
        guard
            currentTool == .select || currentTool == .move,
            let selection,
            !selection.isEmpty,
            let surface = makeSelectionOverlaySurface(selection)
        else {
            selectionOverlayView.update(surface: nil)
            selectionOverlayView.frame = .zero
            selectionOutlineLayer.path = nil
            return
        }

        var rect = viewport.viewRect(forDocumentRect: selection.bounds)
        if currentTool == .move, let transformQuad {
            rect = transformedRect(for: transformQuad(selection.bounds), geometry: viewport)
        }

        let shouldHideOverlayImage = currentTool == .move && hidesTransformedOverlayImage
        selectionOverlayView.update(surface: shouldHideOverlayImage ? nil : surface)
        selectionOverlayView.frame = shouldHideOverlayImage ? .zero : rect

        if currentTool == .move, shouldHideOverlayImage, let transformQuad {
            let corners = transformQuad(selection.bounds).points.map(viewport.viewPoint(fromDocumentPoint:))
            let path = UIBezierPath()
            if let first = corners.first {
                path.move(to: first)
                for corner in corners.dropFirst() {
                    path.addLine(to: corner)
                }
                path.close()
            }
            selectionOutlineLayer.path = path.cgPath
        } else {
            selectionOutlineLayer.path = UIBezierPath(rect: rect).cgPath
        }
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

    private func transformedRect(for quad: TransformQuad, geometry viewport: CanvasViewportGeometry) -> CGRect {
        let corners = quad.points.map(viewport.viewPoint(fromDocumentPoint:))
        let minX = corners.map(\.x).min() ?? 0
        let maxX = corners.map(\.x).max() ?? 0
        let minY = corners.map(\.y).min() ?? 0
        let maxY = corners.map(\.y).max() ?? 0
        return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
    }

    private func makeSelectionOverlaySurface(_ selection: CanvasSelection) -> DocumentCompositeSurface? {
        let width = selection.maskWidth
        let height = selection.maskHeight
        guard width > 0, height > 0 else { return nil }
        let expectedCount = width * height
        guard selection.maskData.count == expectedCount, let documentGpuOperationGateway else { return nil }
        return canvasImageRenderer.selectionOverlaySurface(
            gpuOperations: documentGpuOperationGateway,
            maskData: selection.maskData,
            width: width,
            height: height
        )
    }
}
