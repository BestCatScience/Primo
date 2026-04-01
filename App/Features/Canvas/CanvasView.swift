import AVFoundation
import ComposableArchitecture
import QuartzCore
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
            incrementalUpdate: store.pendingIncrementalUpdate,
            activeStroke: store.activeStroke,
            previewStyle: store.previewStyle,
            currentTool: store.currentTool,
            viewportOffset: store.viewportOffset,
            zoomScale: store.zoomScale,
            rasterResetTicket: store.rasterResetTicket,
            undoTicket: store.localUndoTicket,
            redoTicket: store.localRedoTicket
        )
    }
}

final class RasterCanvasContainerView: UIView, InputHandlerDelegate, UIGestureRecognizerDelegate {
    var documentSize: CGSize = .zero
    var sendAction: ((CanvasFeature.Action) -> Void)?

    private let metalCanvasView = MetalCanvasView()
    private let imageView = UIImageView()
    private let committedImageView = UIImageView()
    private let inFlightImageView = UIImageView()
    private let inputHandler = InputHandler()

    private var viewportOffset: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var currentTool: StudioToolKind = .brush
    private var panStartLocation: CGPoint?
    private var panStartOffset: CGSize = .zero
    private var panDidMove = false
    private var isCanvasPanGestureActive = false
    private var pinchStartScale: CGFloat = 1.0
    private var pinchAnchorDocumentPoint: CGPoint?
    private var isPinchGestureActive = false
    private var lastNavigationGestureEndedAt: CFTimeInterval = 0

    private var cachedRevision: Int = -1
    private var cachedCompositeImage: UIImage?
    private var committedRasterImage: UIImage?
    private var inFlightRasterImage: UIImage?
    private var undoStack: [UIImage?] = []
    private var redoStack: [UIImage?] = []
    private let maxHistoryDepth = 80
    private var appliedUndoTicket: Int = -1
    private var appliedRedoTicket: Int = -1
    private var appliedRasterResetTicket: Int = -1
    private var currentPreviewStyle = PreviewStrokeStyle(
        radius: 3.0,
        opacity: 0.9,
        hardness: 0.82,
        pressureSensitivity: 0.4,
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

        metalCanvasView.isUserInteractionEnabled = false
        addSubview(metalCanvasView)

        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = false
        imageView.isHidden = true
        addSubview(imageView)

        committedImageView.contentMode = .scaleToFill
        committedImageView.isUserInteractionEnabled = false
        committedImageView.isHidden = true
        addSubview(committedImageView)

        inFlightImageView.contentMode = .scaleToFill
        inFlightImageView.isUserInteractionEnabled = false
        inFlightImageView.isHidden = true
        addSubview(inFlightImageView)

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchRecognizer.delegate = self
        pinchRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(pinchRecognizer)

        let undoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerUndoTap(_:)))
        undoTapRecognizer.numberOfTouchesRequired = 2
        undoTapRecognizer.numberOfTapsRequired = 1
        undoTapRecognizer.cancelsTouchesInView = false
        undoTapRecognizer.delegate = self
        undoTapRecognizer.require(toFail: pinchRecognizer)
        addGestureRecognizer(undoTapRecognizer)

        let redoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleThreeFingerRedoTap(_:)))
        redoTapRecognizer.numberOfTouchesRequired = 3
        redoTapRecognizer.numberOfTapsRequired = 1
        redoTapRecognizer.cancelsTouchesInView = false
        redoTapRecognizer.delegate = self
        redoTapRecognizer.require(toFail: pinchRecognizer)
        addGestureRecognizer(redoTapRecognizer)

        addInteraction(UIPencilInteraction())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalCanvasView.frame = bounds
        imageView.frame = contentRect()
        committedImageView.frame = contentRect()
        inFlightImageView.frame = contentRect()
    }

    func update(
        snapshot: MetalDocumentSnapshot?,
        incrementalUpdate: IncrementalLayerUpdate?,
        activeStroke: Stroke?,
        previewStyle: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        viewportOffset: CGSize,
        zoomScale: CGFloat,
        rasterResetTicket: Int,
        undoTicket: Int,
        redoTicket: Int
    ) {
        self.currentTool = currentTool
        self.currentPreviewStyle = previewStyle
        self.viewportOffset = viewportOffset
        self.zoomScale = zoomScale
        applyUndoRedoTickets(undoTicket: undoTicket, redoTicket: redoTicket)
        metalCanvasView.updateDocumentSize(documentSize)
        metalCanvasView.update(snapshot: snapshot, viewportOffset: viewportOffset, zoomScale: zoomScale)
        if let incrementalUpdate {
            metalCanvasView.applyIncrementalUpdate(incrementalUpdate)
        }

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
            if committedRasterImage == nil || snapshotContainsVisibleInk(snapshot) {
                committedRasterImage = cachedCompositeImage
                committedImageView.image = committedRasterImage
                inFlightRasterImage = nil
                inFlightImageView.image = nil
            }
        }
        if appliedRasterResetTicket != rasterResetTicket {
            appliedRasterResetTicket = rasterResetTicket
            committedRasterImage = cachedCompositeImage ?? renderCompositeImage(from: snapshot)
            committedImageView.image = committedRasterImage
            inFlightRasterImage = nil
            inFlightImageView.image = nil
            undoStack.removeAll(keepingCapacity: true)
            redoStack.removeAll(keepingCapacity: true)
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
        sendAction?(.strokeUpdated(stroke))
    }

    func didEndStroke(_ stroke: Stroke) {
        sendAction?(.strokeEnded(stroke))
    }

    private func applyUndoRedoTickets(undoTicket: Int, redoTicket: Int) {
        if appliedUndoTicket != undoTicket {
            appliedUndoTicket = undoTicket
            performLocalUndo()
        }
        if appliedRedoTicket != redoTicket {
            appliedRedoTicket = redoTicket
            performLocalRedo()
        }
    }

    private func performLocalUndo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(committedRasterImage)
        committedRasterImage = undoStack.removeLast()
        committedImageView.image = committedRasterImage
    }

    private func performLocalRedo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(committedRasterImage)
        committedRasterImage = redoStack.removeLast()
        committedImageView.image = committedRasterImage
    }

    private func pushUndoSnapshot() {
        undoStack.append(committedRasterImage)
        if undoStack.count > maxHistoryDepth {
            undoStack.removeFirst(undoStack.count - maxHistoryDepth)
        }
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
                includesLeadingPoint: includesLeadingPoint,
                fillColor: opaqueColor,
                hardness: style.hardness,
                pressureSensitivity: style.pressureSensitivity
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
        includesLeadingPoint: Bool,
        fillColor: CGColor,
        hardness: CGFloat,
        pressureSensitivity: CGFloat
    ) {
        guard !points.isEmpty else { return }

        func clampedPressure(_ pressure: CGFloat) -> CGFloat {
            min(max(pressure, 0.08), 1.0)
        }

        let clampedSensitivity = min(max(pressureSensitivity, 0.0), 1.0)
        func pressureScale(_ pressure: CGFloat) -> CGFloat {
            let p = clampedPressure(pressure)
            return (1.0 - clampedSensitivity) + (p * clampedSensitivity)
        }

        let clampedHardness = min(max(hardness, 0.0), 1.0)
        // Make low-hardness values much softer (airbrush-like) by applying a stronger curve.
        let effectiveHardness = pow(clampedHardness, 3.2)
        let usesSoftEdge = clampedHardness < 0.995
        let fill = UIColor(cgColor: fillColor)
        let gradientStart = fill.withAlphaComponent(1.0).cgColor
        let gradientEnd = fill.withAlphaComponent(0.0).cgColor
        let gradient: CGGradient? = {
            guard usesSoftEdge else { return nil }
            return CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    gradientStart,
                    gradientEnd
                ] as CFArray,
                locations: [effectiveHardness, 1.0]
            )
        }()

        func drawDab(at point: CGPoint, radius: CGFloat) {
            let r = max(0.4, radius)
            let rect = CGRect(x: point.x - r, y: point.y - r, width: r * 2.0, height: r * 2.0)
            guard let gradient else {
                cg.fillEllipse(in: rect)
                return
            }
            cg.saveGState()
            cg.addEllipse(in: rect)
            cg.clip()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let startRadius = r * effectiveHardness
            cg.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: startRadius,
                endCenter: center,
                endRadius: r,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            cg.restoreGState()
        }

        if points.count == 1 {
            guard includesLeadingPoint else { return }
            let p = points[0]
            drawDab(at: p.point, radius: baseRadius * pressureScale(p.pressure))
            return
        }

        if includesLeadingPoint {
            let p = points[0]
            drawDab(at: p.point, radius: baseRadius * pressureScale(p.pressure))
        }

        for index in 1..<points.count {
            let from = points[index - 1]
            let to = points[index]

            let fromRadius = baseRadius * pressureScale(from.pressure)
            let toRadius = baseRadius * pressureScale(to.pressure)
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

    private func snapshotContainsVisibleInk(_ snapshot: MetalDocumentSnapshot) -> Bool {
        snapshot.layers.contains { layer in
            guard layer.visible else { return false }
            return layer.pixelData.withUnsafeBytes { bytes in
                guard let pixels = bytes.bindMemory(to: UInt8.self).baseAddress else { return false }
                let count = layer.pixelData.count / 4
                for index in 0..<count {
                    let alpha = pixels[(index * 4) + 3]
                    if alpha > 8 {
                        return true
                    }
                }
                return false
            }
        }
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
                panDidMove = false
                isCanvasPanGestureActive = false
            }
            return false
        }

        let location = touch.preciseLocation(in: self)
        switch phase {
        case .began:
            panStartLocation = location
            panStartOffset = viewportOffset
            panDidMove = false
            isCanvasPanGestureActive = true
        case .moved:
            guard let panStartLocation else { return true }
            let deltaX = location.x - panStartLocation.x
            let deltaY = location.y - panStartLocation.y
            if hypot(deltaX, deltaY) > 3.0 {
                panDidMove = true
            }
            let nextOffset = CGSize(
                width: panStartOffset.width + deltaX,
                height: panStartOffset.height + deltaY
            )
            let clampedOffset = clampedViewportOffset(nextOffset)
            sendAction?(.viewportOffsetChanged(clampedOffset))
        case .ended, .cancelled:
            if panDidMove {
                lastNavigationGestureEndedAt = CACurrentMediaTime()
            }
            panStartLocation = nil
            panDidMove = false
            isCanvasPanGestureActive = false
        }
        return true
    }

    private func shouldSuppressHistoryTap() -> Bool {
        if isPinchGestureActive || isCanvasPanGestureActive || pinchAnchorDocumentPoint != nil {
            return true
        }
        return (CACurrentMediaTime() - lastNavigationGestureEndedAt) < 0.22
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
    private func handleTwoFingerUndoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard !shouldSuppressHistoryTap() else { return }
        sendAction?(.requestLocalUndo)
    }

    @objc
    private func handleThreeFingerRedoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard !shouldSuppressHistoryTap() else { return }
        sendAction?(.requestLocalRedo)
    }

    @objc
    private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard documentSize.width > 0, documentSize.height > 0 else { return }

        let location = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            isPinchGestureActive = true
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
            if isPinchGestureActive {
                lastNavigationGestureEndedAt = CACurrentMediaTime()
            }
            isPinchGestureActive = false
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
