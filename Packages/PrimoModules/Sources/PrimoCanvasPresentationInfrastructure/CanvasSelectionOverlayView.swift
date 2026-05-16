#if canImport(UIKit)
import PrimoCanvasPresentationDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain
import UIKit

@MainActor
final class CanvasSelectionOverlayView: UIView {
    private let selectionWhiteLayer = CAShapeLayer()
    private let selectionBlackLayer = CAShapeLayer()
    private let previewWhiteLayer = CAShapeLayer()
    private let previewBlackLayer = CAShapeLayer()
    private let lassoOriginWhiteLayer = CAShapeLayer()
    private let lassoOriginBlackLayer = CAShapeLayer()

    init(selectionProcessor: any SelectionMaskProcessing) {
        _ = selectionProcessor
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        configureSelectionOutlineLayer(selectionWhiteLayer, color: .white, lineWidth: 2.6)
        configureSelectionOutlineLayer(selectionBlackLayer, color: .black, lineWidth: 1.2)
        configureAntLayer(previewWhiteLayer, color: .white, lineWidth: 1.8, phase: 0)
        configureAntLayer(previewBlackLayer, color: .black, lineWidth: 1.2, phase: 6)

        lassoOriginWhiteLayer.fillColor = UIColor.white.withAlphaComponent(0.85).cgColor
        lassoOriginWhiteLayer.strokeColor = UIColor.clear.cgColor
        lassoOriginBlackLayer.fillColor = UIColor.clear.cgColor
        lassoOriginBlackLayer.strokeColor = UIColor.black.withAlphaComponent(0.75).cgColor
        lassoOriginBlackLayer.lineWidth = 1.2

        [selectionWhiteLayer, selectionBlackLayer, previewWhiteLayer, previewBlackLayer].forEach {
            layer.addSublayer($0)
        }
        layer.addSublayer(lassoOriginWhiteLayer)
        layer.addSublayer(lassoOriginBlackLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        [selectionWhiteLayer, selectionBlackLayer, previewWhiteLayer, previewBlackLayer,
         lassoOriginWhiteLayer, lassoOriginBlackLayer].forEach {
            $0.frame = bounds
        }
    }

    func update(
        selection: CanvasSelection?,
        previewPoints: [CGPoint],
        moveOffset: CGSize,
        currentTool: StudioToolKind,
        selectionMode: SelectionToolMode,
        geometry viewport: CanvasViewportGeometry
    ) {
        frame = viewport.bounds
        updateSelectionOverlay(
            selection,
            moveOffset: moveOffset,
            currentTool: currentTool,
            geometry: viewport
        )
        updateSelectionPreview(
            previewPoints,
            currentTool: currentTool,
            selectionMode: selectionMode,
            geometry: viewport
        )
    }

    private func updateSelectionOverlay(
        _ selection: CanvasSelection?,
        moveOffset: CGSize,
        currentTool: StudioToolKind,
        geometry viewport: CanvasViewportGeometry
    ) {
        guard
            currentTool.showsSelectionOverlay,
            let selection,
            !selection.isEmpty,
            let path = makeSelectionOutlinePath(selection, moveOffset: moveOffset, geometry: viewport)
        else {
            selectionWhiteLayer.path = nil
            selectionBlackLayer.path = nil
            return
        }

        selectionWhiteLayer.path = path
        selectionBlackLayer.path = path
    }

    private func updateSelectionPreview(
        _ points: [CGPoint],
        currentTool: StudioToolKind,
        selectionMode: SelectionToolMode,
        geometry viewport: CanvasViewportGeometry
    ) {
        guard currentTool == .select, points.count >= 2 else {
            previewWhiteLayer.path = nil
            previewBlackLayer.path = nil
            lassoOriginWhiteLayer.path = nil
            lassoOriginBlackLayer.path = nil
            return
        }

        let path: UIBezierPath
        if selectionMode == .rectangle, let first = points.first, let last = points.last {
            path = UIBezierPath(rect: viewport.viewRect(forDocumentRect: CGRect(
                x: min(first.x, last.x),
                y: min(first.y, last.y),
                width: abs(last.x - first.x),
                height: abs(last.y - first.y)
            )))
            lassoOriginWhiteLayer.path = nil
            lassoOriginBlackLayer.path = nil
        } else {
            path = UIBezierPath()
            for (index, point) in points.enumerated() {
                let mapped = viewport.viewPoint(fromDocumentPoint: point)
                if index == 0 {
                    path.move(to: mapped)
                } else {
                    path.addLine(to: mapped)
                }
            }
            // Closing segment: dashed line from last point back to origin
            if let first = points.first, let last = points.last {
                let viewFirst = viewport.viewPoint(fromDocumentPoint: first)
                let viewLast = viewport.viewPoint(fromDocumentPoint: last)
                let closing = UIBezierPath()
                closing.move(to: viewLast)
                closing.addLine(to: viewFirst)
                path.append(closing)
            }
            // Origin indicator: small circle at the start point
            if let first = points.first {
                let viewFirst = viewport.viewPoint(fromDocumentPoint: first)
                let radius: CGFloat = 5
                let circleRect = CGRect(
                    x: viewFirst.x - radius,
                    y: viewFirst.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                let circlePath = UIBezierPath(ovalIn: circleRect).cgPath
                lassoOriginWhiteLayer.path = circlePath
                lassoOriginBlackLayer.path = circlePath
            }
        }
        previewWhiteLayer.path = path.cgPath
        previewBlackLayer.path = path.cgPath
    }

    private func makeSelectionOutlinePath(
        _ selection: CanvasSelection,
        moveOffset: CGSize,
        geometry viewport: CanvasViewportGeometry
    ) -> CGPath? {
        let width = selection.maskWidth
        let height = selection.maskHeight
        guard width > 0, height > 0 else { return nil }
        let expectedCount = width * height
        guard selection.maskData.count == expectedCount else { return nil }
        let mask = [UInt8](selection.maskData)
        let path = UIBezierPath()
        var hasSegments = false

        func selected(_ x: Int, _ y: Int) -> Bool {
            guard (0..<width).contains(x), (0..<height).contains(y) else { return false }
            return mask[(y * width) + x] > 0
        }

        func viewPoint(_ x: Int, _ y: Int) -> CGPoint {
            viewport.viewPoint(
                fromDocumentPoint: CGPoint(
                    x: selection.bounds.minX + CGFloat(x) + moveOffset.width,
                    y: selection.bounds.minY + CGFloat(y) + moveOffset.height
                )
            )
        }

        for y in 0..<height {
            for x in 0..<width where selected(x, y) {
                if !selected(x - 1, y) {
                    hasSegments = true
                    path.move(to: viewPoint(x, y))
                    path.addLine(to: viewPoint(x, y + 1))
                }
                if !selected(x + 1, y) {
                    hasSegments = true
                    path.move(to: viewPoint(x + 1, y))
                    path.addLine(to: viewPoint(x + 1, y + 1))
                }
                if !selected(x, y - 1) {
                    hasSegments = true
                    path.move(to: viewPoint(x, y))
                    path.addLine(to: viewPoint(x + 1, y))
                }
                if !selected(x, y + 1) {
                    hasSegments = true
                    path.move(to: viewPoint(x, y + 1))
                    path.addLine(to: viewPoint(x + 1, y + 1))
                }
            }
        }

        return hasSegments ? path.cgPath : nil
    }

    private func configureAntLayer(_ layer: CAShapeLayer, color: UIColor, lineWidth: CGFloat, phase: CGFloat) {
        layer.strokeColor = color.withAlphaComponent(0.95).cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = lineWidth
        layer.lineCap = .butt
        layer.lineJoin = .round
        layer.lineDashPattern = [6, 6]
        layer.lineDashPhase = phase
    }

    private func configureSelectionOutlineLayer(_ layer: CAShapeLayer, color: UIColor, lineWidth: CGFloat) {
        layer.strokeColor = color.withAlphaComponent(0.98).cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = lineWidth
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.lineDashPattern = nil
        layer.lineDashPhase = 0
    }

}

private extension StudioToolKind {
    var showsSelectionOverlay: Bool {
        self == .select || self == .move
    }
}
#endif
