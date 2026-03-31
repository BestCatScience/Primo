import AVFoundation
import ComposableArchitecture
import SwiftUI
import UIKit
import simd

struct CanvasView: UIViewRepresentable {
    let store: StoreOf<CanvasFeature>

    func makeUIView(context: Context) -> RasterCanvasContainerView {
        let view = RasterCanvasContainerView()
        view.sendAction = { store.send($0) }
        return view
    }

    func updateUIView(_ uiView: RasterCanvasContainerView, context: Context) {
        uiView.documentSize = store.canvasSize
        uiView.update(
            snapshot: store.renderSnapshot,
            activeStroke: store.activeStroke,
            previewStyle: store.previewStyle,
            currentTool: store.currentTool,
            viewportOffset: store.viewportOffset,
            zoomScale: store.zoomScale
        )
    }
}

final class RasterCanvasContainerView: UIView, InputHandlerDelegate, UIGestureRecognizerDelegate {
    var documentSize: CGSize = .zero
    var sendAction: ((CanvasFeature.Action) -> Void)?

    private let imageView = UIImageView()
    private let committedImageView = UIImageView()
    private let inFlightImageView = UIImageView()
    private let inputHandler = InputHandler()

    private var viewportOffset: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var currentTool: StudioToolKind = .brush
    private var panStartLocation: CGPoint?
    private var panStartOffset: CGSize = .zero
    private var pinchStartScale: CGFloat = 1.0
    private var pinchAnchorDocumentPoint: CGPoint?

    private var cachedRevision: Int = -1
    private var cachedCompositeImage: UIImage?
    private var committedRasterImage: UIImage?
    private var inFlightRasterImage: UIImage?
    private var currentPreviewStyle = PreviewStrokeStyle(
        radius: 3.0,
        opacity: 0.9,
        color: CGColor(red: 31.0 / 255.0, green: 31.0 / 255.0, blue: 34.0 / 255.0, alpha: 1.0)
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        isMultipleTouchEnabled = true
        clipsToBounds = true

        inputHandler.delegate = self
        inputHandler.pointMapper = { [weak self] location, view in
            guard let self else { return SIMD2(Float(location.x), Float(location.y)) }
            let point = self.canvasPoint(from: location, in: view)
            return SIMD2(Float(point.x), Float(point.y))
        }

        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)

        committedImageView.contentMode = .scaleToFill
        committedImageView.isUserInteractionEnabled = false
        addSubview(committedImageView)

        inFlightImageView.contentMode = .scaleToFill
        inFlightImageView.isUserInteractionEnabled = false
        addSubview(inFlightImageView)

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchRecognizer.delegate = self
        pinchRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(pinchRecognizer)

        addInteraction(UIPencilInteraction())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentRect()
        committedImageView.frame = contentRect()
        inFlightImageView.frame = contentRect()
    }

    func update(
        snapshot: MetalDocumentSnapshot?,
        activeStroke: Stroke?,
        previewStyle: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        viewportOffset: CGSize,
        zoomScale: CGFloat
    ) {
        self.currentTool = currentTool
        self.currentPreviewStyle = previewStyle
        self.viewportOffset = viewportOffset
        self.zoomScale = zoomScale

        let frame = contentRect()
        imageView.frame = frame
        committedImageView.frame = frame
        inFlightImageView.frame = frame
        inputHandler.tool = currentTool
        inputHandler.brushSize = Float(previewStyle.radius * 2.0)
        inputHandler.brushColor = previewStyle.simdColor
        if activeStroke == nil, inFlightRasterImage != nil {
            inFlightRasterImage = nil
            inFlightImageView.image = nil
        }

        guard let snapshot else {
            committedImageView.image = committedRasterImage
            return
        }

        if snapshot.revision != cachedRevision {
            cachedRevision = snapshot.revision
            cachedCompositeImage = renderCompositeImage(from: snapshot)
            if committedRasterImage == nil {
                committedRasterImage = cachedCompositeImage
            }
        }
        imageView.image = nil
        committedImageView.image = committedRasterImage
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .began) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .moved) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .ended) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .cancelled) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    func didUpdateStroke(_ stroke: Stroke) {
        let points = stroke.confirmedPreviewPoints
        guard !points.isEmpty else { return }
        guard documentSize.width > 0, documentSize.height > 0 else { return }
        inFlightRasterImage = rasterizedStrokeSegment(
            points: points,
            style: currentPreviewStyle,
            onto: nil,
            documentSize: documentSize,
            includesLeadingPoint: true
        )
        inFlightImageView.image = inFlightRasterImage
        sendAction?(.strokeUpdated(stroke))
    }

    func didEndStroke(_ stroke: Stroke) {
        defer {
            sendAction?(.strokeEnded(stroke))
        }
        defer {
            inFlightRasterImage = nil
            inFlightImageView.image = nil
        }
        guard documentSize.width > 0, documentSize.height > 0 else { return }

        if let inFlightRasterImage {
            committedRasterImage = compositedRaster(
                base: committedRasterImage,
                overlay: inFlightRasterImage,
                documentSize: documentSize
            )
        } else if !stroke.confirmedPreviewPoints.isEmpty {
            committedRasterImage = rasterizedCommittedStroke(
                points: stroke.confirmedPreviewPoints,
                style: currentPreviewStyle,
                onto: committedRasterImage,
                documentSize: documentSize
            )
        }
        committedImageView.image = committedRasterImage
    }

    private func rasterizedStrokeSegment(
        points: [PreviewStrokePoint],
        style: PreviewStrokeStyle,
        onto base: UIImage?,
        documentSize: CGSize,
        includesLeadingPoint: Bool
    ) -> UIImage? {
        let pixelWidth = max(1, Int(documentSize.width))
        let pixelHeight = max(1, Int(documentSize.height))
        let bounds = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)

        let strokeAlpha = min(max(style.opacity, 0.0), 1.0)
        let strokeStamp = UIGraphicsImageRenderer(size: bounds.size, format: format).image { stampContext in
            let stampCG = stampContext.cgContext
            let opaqueColor = UIColor(cgColor: style.color).withAlphaComponent(1.0).cgColor
            stampCG.setFillColor(opaqueColor)
            drawPressureSensitiveDabs(
                points: points,
                baseRadius: max(0.6, style.radius),
                in: stampCG,
                includesLeadingPoint: includesLeadingPoint
            )
        }

        return renderer.image { context in
            base?.draw(in: bounds)

            strokeStamp.draw(in: bounds, blendMode: .normal, alpha: strokeAlpha)
        }
    }

    private func rasterizedCommittedStroke(
        points: [PreviewStrokePoint],
        style: PreviewStrokeStyle,
        onto base: UIImage?,
        documentSize: CGSize
    ) -> UIImage? {
        rasterizedStrokeSegment(
            points: points,
            style: style,
            onto: base,
            documentSize: documentSize,
            includesLeadingPoint: true
        )
    }

    private func compositedRaster(base: UIImage?, overlay: UIImage, documentSize: CGSize) -> UIImage? {
        let pixelWidth = max(1, Int(documentSize.width))
        let pixelHeight = max(1, Int(documentSize.height))
        let bounds = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)

        return renderer.image { _ in
            base?.draw(in: bounds)
            overlay.draw(in: bounds)
        }
    }

    private func drawPressureSensitiveDabs(
        points: [PreviewStrokePoint],
        baseRadius: CGFloat,
        in cg: CGContext,
        includesLeadingPoint: Bool
    ) {
        guard !points.isEmpty else { return }

        func clampedPressure(_ pressure: CGFloat) -> CGFloat {
            min(max(pressure, 0.08), 1.0)
        }

        func drawDab(at point: CGPoint, radius: CGFloat) {
            let r = max(0.4, radius)
            cg.fillEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2.0, height: r * 2.0))
        }

        if points.count == 1 {
            guard includesLeadingPoint else { return }
            let p = points[0]
            drawDab(at: p.point, radius: baseRadius * clampedPressure(p.pressure))
            return
        }

        if includesLeadingPoint {
            let p = points[0]
            drawDab(at: p.point, radius: baseRadius * clampedPressure(p.pressure))
        }

        for index in 1..<points.count {
            let from = points[index - 1]
            let to = points[index]

            let fromRadius = baseRadius * clampedPressure(from.pressure)
            let toRadius = baseRadius * clampedPressure(to.pressure)
            let dx = to.point.x - from.point.x
            let dy = to.point.y - from.point.y
            let distance = hypot(dx, dy)

            let spacing = max(0.4, min(fromRadius, toRadius) * 0.45)
            let steps = max(1, Int(ceil(distance / spacing)))
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let point = CGPoint(x: from.point.x + dx * t, y: from.point.y + dy * t)
                let radius = fromRadius + (toRadius - fromRadius) * t
                drawDab(at: point, radius: radius)
            }
        }
    }

    private func renderCompositeImage(from snapshot: MetalDocumentSnapshot) -> UIImage? {
        let width = snapshot.width
        let height = snapshot.height
        guard width > 0, height > 0 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(UIColor(red: 0.93, green: 0.92, blue: 0.89, alpha: 1.0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        for layer in snapshot.layers where layer.visible {
            guard let image = makeLayerImage(pixelData: layer.pixelData, width: width, height: height) else { continue }
            context.saveGState()
            context.setAlpha(CGFloat(layer.opacity))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            context.restoreGState()
        }

        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func makeLayerImage(pixelData: Data, width: Int, height: Int) -> CGImage? {
        guard pixelData.count == width * height * 4 else { return nil }
        guard let provider = CGDataProvider(data: pixelData as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private func canvasPoint(from location: CGPoint, in view: UIView) -> CGPoint {
        let fitted = contentRect()
        guard fitted.width > 0, fitted.height > 0, documentSize.width > 0, documentSize.height > 0 else { return .zero }

        let local = convert(location, from: view)
        let x = ((local.x - fitted.minX) / fitted.width) * documentSize.width
        let y = ((local.y - fitted.minY) / fitted.height) * documentSize.height
        return CGPoint(
            x: min(max(0, x), documentSize.width - 1),
            y: min(max(0, y), documentSize.height - 1)
        )
    }

    private func contentRect() -> CGRect {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fittedRect = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fittedRect.width * zoomScale, height: fittedRect.height * zoomScale)
        return CGRect(
            x: fittedRect.midX - (scaledSize.width / 2) + viewportOffset.width,
            y: fittedRect.midY - (scaledSize.height / 2) + viewportOffset.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    private enum PanPhase {
        case began
        case moved
        case ended
        case cancelled
    }

    private func handlePanTouchesIfNeeded(_ touches: Set<UITouch>, phase: PanPhase) -> Bool {
        guard currentTool == .move, let touch = touches.first else {
            if phase == .ended || phase == .cancelled {
                panStartLocation = nil
            }
            return false
        }

        let location = touch.preciseLocation(in: self)
        switch phase {
        case .began:
            panStartLocation = location
            panStartOffset = viewportOffset
        case .moved:
            guard let panStartLocation else { return true }
            let nextOffset = CGSize(
                width: panStartOffset.width + (location.x - panStartLocation.x),
                height: panStartOffset.height + (location.y - panStartLocation.y)
            )
            let clampedOffset = clampedViewportOffset(nextOffset)
            sendAction?(.viewportOffsetChanged(clampedOffset))
        case .ended, .cancelled:
            panStartLocation = nil
        }
        return true
    }

    private func clampedViewportOffset(_ proposedOffset: CGSize) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        let fitted = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledWidth = fitted.width * zoomScale
        let scaledHeight = fitted.height * zoomScale
        let horizontalLimit = max(0, (scaledWidth - drawableRect.width) / 2 + 120)
        let verticalLimit = max(0, (scaledHeight - drawableRect.height) / 2 + 120)
        return CGSize(
            width: min(max(proposedOffset.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposedOffset.height, -verticalLimit), verticalLimit)
        )
    }

    @objc
    private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard documentSize.width > 0, documentSize.height > 0 else { return }

        let location = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            pinchStartScale = zoomScale
            pinchAnchorDocumentPoint = documentPoint(at: location, in: contentRect())

        case .changed:
            guard let pinchAnchorDocumentPoint else { return }
            let newScale = min(max(pinchStartScale * recognizer.scale, 0.6), 4.0)
            let newOffset = offsetKeepingDocumentPointStable(
                pinchAnchorDocumentPoint,
                at: location,
                zoomScale: newScale
            )
            sendAction?(.zoomScaleChanged(newScale))
            sendAction?(.viewportOffsetChanged(newOffset))

        case .ended, .cancelled, .failed:
            pinchAnchorDocumentPoint = nil

        default:
            break
        }
    }

    private func documentPoint(at viewPoint: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: ((viewPoint.x - rect.minX) / max(rect.width, 1)) * documentSize.width,
            y: ((viewPoint.y - rect.minY) / max(rect.height, 1)) * documentSize.height
        )
    }

    private func offsetKeepingDocumentPointStable(_ documentPoint: CGPoint, at viewPoint: CGPoint, zoomScale: CGFloat) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        let fittedRect = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fittedRect.width * zoomScale, height: fittedRect.height * zoomScale)
        let normalizedX = documentPoint.x / max(documentSize.width, 1)
        let normalizedY = documentPoint.y / max(documentSize.height, 1)
        let desiredOrigin = CGPoint(
            x: viewPoint.x - (normalizedX * scaledSize.width),
            y: viewPoint.y - (normalizedY * scaledSize.height)
        )
        let baseOrigin = CGPoint(
            x: fittedRect.midX - (scaledSize.width / 2),
            y: fittedRect.midY - (scaledSize.height / 2)
        )
        return clampedViewportOffset(
            CGSize(width: desiredOrigin.x - baseOrigin.x, height: desiredOrigin.y - baseOrigin.y),
            zoomScale: zoomScale
        )
    }

    private func clampedViewportOffset(_ proposedOffset: CGSize, zoomScale: CGFloat) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        let fitted = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledWidth = fitted.width * zoomScale
        let scaledHeight = fitted.height * zoomScale
        let horizontalLimit = max(0, (scaledWidth - drawableRect.width) / 2 + 120)
        let verticalLimit = max(0, (scaledHeight - drawableRect.height) / 2 + 120)
        return CGSize(
            width: min(max(proposedOffset.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposedOffset.height, -verticalLimit), verticalLimit)
        )
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

private extension PreviewStrokeStyle {
    var simdColor: SIMD4<Float> {
        guard let components = color.components else {
            return SIMD4(0, 0, 0, 1)
        }

        switch components.count {
        case 4:
            return SIMD4(Float(components[0]), Float(components[1]), Float(components[2]), Float(components[3]))
        case 2:
            return SIMD4(Float(components[0]), Float(components[0]), Float(components[0]), Float(components[1]))
        default:
            return SIMD4(0, 0, 0, 1)
        }
    }
}
