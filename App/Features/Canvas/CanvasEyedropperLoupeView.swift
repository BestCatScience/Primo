import PrimoDocumentContracts
import PrimoDocumentDomain
import UIKit

final class CanvasEyedropperLoupeView: NSObject, UIGestureRecognizerDelegate {
    private let loupeView = UIView()
    private let surfaceView = CanvasPixelSurfaceView()
    private let ringView = UIView()
    private let focusView = UIView()
    private let longPressRecognizer = UILongPressGestureRecognizer()
    private let canvasImageRenderer: CanvasImageRenderer

    private var context: Context?
    private(set) var isActive = false
    var onSampledColor: ((SampledColor) -> Void)?
    var onBeganSampling: (() -> Void)?

    private let loupeSize = CGSize(width: 102, height: 102)
    private let previewInset: CGFloat = 9
    private let previewGridSize = 17
    private let verticalOffset: CGFloat = 86

    init(canvasImageRenderer: CanvasImageRenderer) {
        self.canvasImageRenderer = canvasImageRenderer
        super.init()
        configureViews()
        configureRecognizer()
    }

    func install(on hostView: UIView) {
        hostView.addSubview(loupeView)
        hostView.addGestureRecognizer(longPressRecognizer)
    }

    func update(context: Context) {
        self.context = context
    }

    func ownsGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === longPressRecognizer
    }

    func hide() {
        hideLoupe()
    }

    func sampledColor(at point: CGPoint, source: EyedropperSamplingSource) -> SampledColor? {
        guard let context else { return nil }
        return sampledColor(
            at: point,
            context: Context(
                snapshot: context.snapshot,
                activeLayerIndex: context.activeLayerIndex,
                paperStyle: context.paperStyle,
                source: source,
                geometry: context.geometry,
                shouldBlockSampling: context.shouldBlockSampling
            )
        )
    }

    private func configureViews() {
        loupeView.isHidden = true
        loupeView.isUserInteractionEnabled = false
        loupeView.bounds = CGRect(origin: .zero, size: loupeSize)
        loupeView.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        loupeView.layer.cornerRadius = loupeSize.width / 2
        loupeView.layer.shadowColor = UIColor.black.cgColor
        loupeView.layer.shadowOpacity = 0.28
        loupeView.layer.shadowRadius = 18
        loupeView.layer.shadowOffset = CGSize(width: 0, height: 8)

        ringView.frame = loupeView.bounds
        ringView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        ringView.backgroundColor = .clear
        ringView.layer.cornerRadius = loupeSize.width / 2
        ringView.layer.borderWidth = 6
        ringView.layer.borderColor = UIColor.white.cgColor
        loupeView.addSubview(ringView)

        let previewFrame = loupeView.bounds.insetBy(dx: previewInset, dy: previewInset)
        surfaceView.frame = previewFrame
        surfaceView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        surfaceView.layer.cornerRadius = previewFrame.width / 2
        surfaceView.layer.masksToBounds = true
        surfaceView.backgroundColor = .white
        surfaceView.layer.borderWidth = 1
        surfaceView.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        loupeView.addSubview(surfaceView)

        focusView.bounds = CGRect(x: 0, y: 0, width: 18, height: 18)
        focusView.center = CGPoint(x: previewFrame.midX, y: previewFrame.midY)
        focusView.autoresizingMask = [
            .flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin
        ]
        focusView.backgroundColor = .clear
        focusView.layer.cornerRadius = 9
        focusView.layer.borderWidth = 1.5
        focusView.layer.borderColor = UIColor.white.withAlphaComponent(0.95).cgColor
        focusView.layer.shadowColor = UIColor.black.cgColor
        focusView.layer.shadowOpacity = 0.16
        focusView.layer.shadowRadius = 2
        focusView.layer.shadowOffset = .zero
        surfaceView.addSubview(focusView)

        let horizontalCrosshair = UIView(frame: CGRect(x: 0, y: 8.5, width: 18, height: 1))
        horizontalCrosshair.autoresizingMask = [.flexibleWidth]
        horizontalCrosshair.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        focusView.addSubview(horizontalCrosshair)

        let verticalCrosshair = UIView(frame: CGRect(x: 8.5, y: 0, width: 1, height: 18))
        verticalCrosshair.autoresizingMask = [.flexibleHeight]
        verticalCrosshair.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        focusView.addSubview(verticalCrosshair)
    }

    private func configureRecognizer() {
        longPressRecognizer.addTarget(self, action: #selector(handleLongPress(_:)))
        longPressRecognizer.minimumPressDuration = 0.34
        longPressRecognizer.allowableMovement = 18
        longPressRecognizer.cancelsTouchesInView = false
        longPressRecognizer.delegate = self
    }

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.numberOfTouches == 1 else {
            hideLoupe()
            return
        }

        let location = recognizer.location(in: recognizer.view)
        switch recognizer.state {
        case .began, .changed:
            updateLoupe(at: location)
        case .ended:
            updateLoupe(at: location)
            hideLoupe()
        case .cancelled, .failed:
            hideLoupe()
        default:
            break
        }
    }

    private func updateLoupe(at viewPoint: CGPoint) {
        guard let context else {
            hideLoupe()
            return
        }
        guard let documentPoint = documentPointForEyedropper(at: viewPoint, context: context) else {
            hideLoupe()
            return
        }
        guard let sampledColor = sampledColor(at: documentPoint, context: context) else {
            hideLoupe()
            return
        }

        isActive = true
        onBeganSampling?()
        onSampledColor?(sampledColor)
        ringView.layer.borderColor = uiColor(from: sampledColor).cgColor
        surfaceView.update(
            surface: makeLoupeSurface(around: documentPoint, context: context),
            filtering: .nearest
        )
        positionLoupe(above: viewPoint, in: context.geometry.bounds)
        if loupeView.isHidden {
            loupeView.alpha = 0
            loupeView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            loupeView.isHidden = false
            UIView.animate(withDuration: 0.14, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
                self.loupeView.alpha = 1
                self.loupeView.transform = .identity
            }
        }
    }

    private func hideLoupe() {
        guard isActive || !loupeView.isHidden else { return }
        isActive = false
        UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .curveEaseIn]) {
            self.loupeView.alpha = 0
            self.loupeView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        } completion: { _ in
            self.loupeView.isHidden = true
            self.loupeView.transform = .identity
            self.surfaceView.update(surface: nil, filtering: .nearest)
        }
    }

    private func documentPointForEyedropper(at viewPoint: CGPoint, context: Context) -> CGPoint? {
        let rect = context.geometry.contentRect
        guard rect.width > 0, rect.height > 0 else { return nil }
        guard rect.insetBy(dx: -18, dy: -18).contains(viewPoint) else { return nil }
        let point = context.geometry.documentPoint(fromViewPoint: viewPoint)
        return CGPoint(
            x: min(max(point.x, 0), max(context.geometry.documentSize.width - 1, 0)),
            y: min(max(point.y, 0), max(context.geometry.documentSize.height - 1, 0))
        )
    }

    private func positionLoupe(above fingerPoint: CGPoint, in bounds: CGRect) {
        let halfWidth = loupeSize.width / 2
        let halfHeight = loupeSize.height / 2
        let minX = bounds.minX + halfWidth + 10
        let maxX = bounds.maxX - halfWidth - 10
        let minY = bounds.minY + halfHeight + 10
        let preferredY = fingerPoint.y - verticalOffset
        let clampedCenter = CGPoint(
            x: min(max(fingerPoint.x, minX), max(maxX, minX)),
            y: max(minY, preferredY)
        )
        loupeView.center = clampedCenter
    }

    private func makeLoupeSurface(around point: CGPoint, context: Context) -> DocumentCompositeSurface? {
        guard previewGridSize > 0, let snapshot = context.snapshot else { return nil }
        let centerX = Int(point.x.rounded())
        let centerY = Int(point.y.rounded())

        let sourcePixelData: Data?
        let blendWithPaper: Bool
        switch context.source {
        case .activeLayer:
            sourcePixelData = snapshot.layers.first(where: { $0.index == context.activeLayerIndex })?.pixelData
            blendWithPaper = false
        case .canvas:
            sourcePixelData = snapshot.compositePixelData
            blendWithPaper = !context.paperStyle.isTransparent
        }

        if let sourcePixelData {
            return canvasImageRenderer.eyedropperLoupeSurface(
                sourcePixelData: sourcePixelData,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                centerX: centerX,
                centerY: centerY,
                gridSize: previewGridSize,
                paperStyle: context.paperStyle,
                blendWithPaper: blendWithPaper
            )
        }

        return nil
    }

    private func sampledColor(at point: CGPoint, context: Context) -> SampledColor? {
        guard
            let snapshot = context.snapshot,
            snapshot.width > 0,
            snapshot.height > 0
        else {
            return nil
        }

        let x = min(max(Int(point.x.rounded()), 0), snapshot.width - 1)
        let y = min(max(Int(point.y.rounded()), 0), snapshot.height - 1)

        switch context.source {
        case .activeLayer:
            guard let layer = snapshot.layers.first(where: { $0.index == context.activeLayerIndex }) else {
                return nil
            }
            return samplePixel(in: layer.pixelData, width: snapshot.width, height: snapshot.height, x: x, y: y)

        case .canvas:
            return sampleCanvasPixel(in: snapshot.compositePixelData, width: snapshot.width, height: snapshot.height, x: x, y: y, paperStyle: context.paperStyle)
        }
    }

    private func samplePixel(in pixelData: Data, width: Int, height: Int, x: Int, y: Int) -> SampledColor? {
        guard width > 0, height > 0, pixelData.count == width * height * 4 else { return nil }
        let offset = ((y * width) + x) * 4
        return pixelData.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            return SampledColor(
                red: source[offset],
                green: source[offset + 1],
                blue: source[offset + 2],
                alpha: source[offset + 3]
            )
        }
    }

    private func sampleCanvasPixel(
        in pixelData: Data,
        width: Int,
        height: Int,
        x: Int,
        y: Int,
        paperStyle: CanvasPaperStyle
    ) -> SampledColor? {
        guard let foreground = samplePixel(in: pixelData, width: width, height: height, x: x, y: y) else {
            return nil
        }
        guard !paperStyle.isTransparent else { return foreground }

        let alpha = CGFloat(foreground.alpha) / 255.0
        let background = SampledColor(
            red: UInt8(max(0, min(255, Int((CGFloat(paperStyle.red) * 255.0).rounded())))),
            green: UInt8(max(0, min(255, Int((CGFloat(paperStyle.green) * 255.0).rounded())))),
            blue: UInt8(max(0, min(255, Int((CGFloat(paperStyle.blue) * 255.0).rounded())))),
            alpha: 255
        )

        return SampledColor(
            red: blendedChannel(source: foreground.red, background: background.red, alpha: alpha),
            green: blendedChannel(source: foreground.green, background: background.green, alpha: alpha),
            blue: blendedChannel(source: foreground.blue, background: background.blue, alpha: alpha),
            alpha: 255
        )
    }

    private func uiColor(from sampledColor: SampledColor) -> UIColor {
        UIColor(
            red: CGFloat(sampledColor.red) / 255.0,
            green: CGFloat(sampledColor.green) / 255.0,
            blue: CGFloat(sampledColor.blue) / 255.0,
            alpha: 1.0
        )
    }

    private func blendedChannel(source: UInt8, background: UInt8, alpha: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, Int((CGFloat(source) * alpha + CGFloat(background) * (1 - alpha)).rounded()))))
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === longPressRecognizer else { return true }
        guard touch.type != .pencil else { return false }
        guard let context else { return false }
        let location = touch.location(in: gestureRecognizer.view)
        guard context.geometry.contentRect.insetBy(dx: -18, dy: -18).contains(location) else { return false }
        if context.shouldBlockSampling(location) { return false }
        return true
    }
}

extension CanvasEyedropperLoupeView {
    struct Context {
        let snapshot: MetalDocumentSnapshot?
        let activeLayerIndex: Int
        let paperStyle: CanvasPaperStyle
        let source: EyedropperSamplingSource
        let geometry: CanvasViewportGeometry
        let shouldBlockSampling: (CGPoint) -> Bool
    }
}
