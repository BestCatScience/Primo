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
            activeLayerIndex: store.activeLayerIndex,
            activeStroke: store.activeStroke,
            incrementalUpdate: store.pendingIncrementalUpdate,
            adjustmentPreviewPixelData: store.adjustmentPreviewPixelData,
            paperStyle: store.paperStyle,
            previewStyle: store.previewStyle,
            currentTool: store.currentTool,
            selectionMode: store.selectionMode,
            shapeMode: store.shapeMode,
            eyedropperSamplingSource: store.eyedropperSamplingSource,
            selection: store.selection,
            selectionPreviewPoints: store.selectionPreviewPoints,
            transformPreviewOffset: store.transformPreviewOffset,
            transformPreviewScale: store.transformPreviewScale,
            viewportOffset: store.viewportOffset,
            zoomScale: store.zoomScale,
        )
    }
}

final class RasterCanvasContainerView: UIView, InputHandlerDelegate, UIGestureRecognizerDelegate, UIPencilInteractionDelegate {
    var documentSize: CGSize = .zero
    var sendAction: ((CanvasFeature.Action) -> Void)?

    private let metalCanvasView = MetalCanvasView()
    private let selectionOverlayView = UIImageView()
    private let compositePreviewImageView = UIImageView()
    private let shapePreviewImageView = UIImageView()
    private let inputHandler = InputHandler()
    private let selectionOutlineLayer = CAShapeLayer()
    private let selectionPreviewLayer = CAShapeLayer()

    private var viewportOffset: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var currentTool: StudioToolKind = .brush
    private var paperStyle: CanvasPaperStyle = .default
    private var transformPreviewOffset: CGSize = .zero
    private var panStartLocation: CGPoint?
    private var panStartOffset: CGSize = .zero
    private var panDidMove = false
    private var isCanvasPanGestureActive = false
    private var pinchStartScale: CGFloat = 1.0
    private var pinchAnchorDocumentPoint: CGPoint?
    private var isPinchGestureActive = false
    private var lastNavigationGestureEndedAt: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
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

        selectionOverlayView.isUserInteractionEnabled = false
        selectionOverlayView.contentMode = .scaleToFill
        selectionOverlayView.alpha = 0.55
        addSubview(selectionOverlayView)

        compositePreviewImageView.isUserInteractionEnabled = false
        compositePreviewImageView.contentMode = .scaleToFill
        compositePreviewImageView.alpha = 1.0
        addSubview(compositePreviewImageView)

        shapePreviewImageView.isUserInteractionEnabled = false
        shapePreviewImageView.contentMode = .scaleToFill
        shapePreviewImageView.alpha = 1.0
        addSubview(shapePreviewImageView)

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

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        addInteraction(pencilInteraction)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalCanvasView.frame = bounds
        shapePreviewImageView.frame = bounds
        selectionOutlineLayer.frame = bounds
        selectionPreviewLayer.frame = bounds
    }

    func update(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        activeStroke: Stroke?,
        incrementalUpdate: IncrementalLayerUpdate?,
        adjustmentPreviewPixelData: Data?,
        paperStyle: CanvasPaperStyle,
        previewStyle: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        selectionMode: SelectionToolMode,
        shapeMode: ShapeToolMode,
        eyedropperSamplingSource: EyedropperSamplingSource,
        selection: CanvasSelection?,
        selectionPreviewPoints: [CGPoint],
        transformPreviewOffset: CGSize,
        transformPreviewScale: CGFloat,
        viewportOffset: CGSize,
        zoomScale: CGFloat
    ) {
        self.currentTool = currentTool
        self.paperStyle = paperStyle
        self.transformPreviewOffset = transformPreviewOffset
        self.viewportOffset = viewportOffset
        self.zoomScale = zoomScale
        metalCanvasView.currentActiveLayerIndex = activeLayerIndex
        metalCanvasView.updateDocumentSize(documentSize)
        metalCanvasView.update(snapshot: snapshot, viewportOffset: viewportOffset, zoomScale: zoomScale, paperStyle: paperStyle)
        if let incrementalUpdate {
            metalCanvasView.applyIncrementalUpdate(incrementalUpdate)
        }
        inputHandler.tool = currentTool
        inputHandler.selectionMode = selectionMode
        inputHandler.shapeMode = shapeMode
        inputHandler.eyedropperSamplingSource = eyedropperSamplingSource
        inputHandler.brushTipKind = previewStyle.tipKind
        inputHandler.brushSize = Float(previewStyle.radius * 2.0)
        inputHandler.brushColor = previewStyle.simdColor
        inputHandler.strokeStabilization = Float(previewStyle.stabilization)
        updateSelectionOverlay(selection, transformPreviewScale: transformPreviewScale)
        updateSelectionPreview(selectionPreviewPoints)
        updateShapePreview(activeStroke, style: previewStyle)
        updateTransformPreview(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustmentPreviewPixelData: adjustmentPreviewPixelData,
            selection: selection,
            paperStyle: paperStyle,
            transformPreviewScale: transformPreviewScale
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, with: event, phase: .began) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, with: event, phase: .moved) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, with: event, phase: .ended) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, with: event, phase: .cancelled) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    func didUpdateStroke(_ stroke: Stroke) {
        sendAction?(.strokeUpdated(stroke))
    }

    func didEndStroke(_ stroke: Stroke) {
        sendAction?(.strokeEnded(stroke))
    }

    func didCancelStroke() {
        sendAction?(.strokeCancelled)
    }

    func didRequestFill(at sample: StylusSample) {
        sendAction?(.fillRequested(sample))
    }

    func didRequestColorSample(at sample: StylusSample) {
        guard
            let sampledColor = sampledColor(
                at: sample.point,
                source: inputHandler.eyedropperSamplingSource
            )
        else {
            return
        }
        sendAction?(.colorSampled(sampledColor))
    }

    func didUpdateSelectionPath(_ points: [CGPoint]) {
        sendAction?(.selectionPreviewUpdated(points))
    }

    func didEndSelectionPath(_ points: [CGPoint]) {
        sendAction?(.selectionPathEnded(points))
    }

    func didRequestAutoSelection(at sample: StylusSample) {
        sendAction?(.autoSelectionRequested(sample))
    }

    func didBeginTransform() {
        sendAction?(.transformGestureBegan)
    }

    func didUpdateTransform(translation: CGSize) {
        sendAction?(.transformPreviewChanged(translation))
    }

    func didEndTransform(translation: CGSize) {
        sendAction?(.transformEnded(translation))
    }

    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        sendAction?(.pencilInteractionToggleRequested)
    }

    private func canvasPoint(from location: CGPoint, in view: UIView) -> CGPoint {
        let fitted = contentRect()
        guard fitted.width > 0, fitted.height > 0, documentSize.width > 0, documentSize.height > 0 else { return .zero }

        let local = convert(location, from: view)
        let x = ((local.x - fitted.minX) / fitted.width) * documentSize.width
        let y = ((local.y - fitted.minY) / fitted.height) * documentSize.height
        return CGPoint(x: x, y: y)
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

    private func updateSelectionOverlay(_ selection: CanvasSelection?, transformPreviewScale: CGFloat) {
        guard
            currentTool == .select || currentTool == .move,
            let selection,
            !selection.isEmpty,
            let image = makeSelectionOverlayImage(selection)
        else {
            selectionOverlayView.image = nil
            selectionOverlayView.frame = .zero
            selectionOutlineLayer.path = nil
            return
        }

        var rect = viewRect(forDocumentRect: selection.bounds)
        if currentTool == .move {
            rect = transformedRect(for: selection.bounds, translation: transformPreviewOffset, scale: transformPreviewScale)
        }
        selectionOverlayView.image = image
        selectionOverlayView.frame = rect
        selectionOutlineLayer.path = UIBezierPath(rect: rect).cgPath
    }

    private func updateTransformPreview(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        adjustmentPreviewPixelData: Data?,
        selection: CanvasSelection?,
        paperStyle: CanvasPaperStyle,
        transformPreviewScale: CGFloat
    ) {
        guard
            currentTool == .move,
            transformPreviewOffset != .zero || abs(transformPreviewScale - 1.0) > 0.001,
            let snapshot
        else {
            if
                let snapshot,
                let adjustmentPreviewPixelData,
                let image = makeLayerImage(
                    pixelData: adjustmentPreviewPixelData,
                    width: snapshot.width,
                    height: snapshot.height,
                    paperStyle: paperStyle
                )
            {
                compositePreviewImageView.image = image
                compositePreviewImageView.frame = contentRect()
                metalCanvasView.isHidden = true
                return
            }

            compositePreviewImageView.image = nil
            compositePreviewImageView.frame = .zero
            metalCanvasView.isHidden = false
            return
        }

        guard let image = makeCompositePreviewImage(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            selection: selection,
            paperStyle: paperStyle,
            transformPreviewScale: transformPreviewScale
        ) else {
            compositePreviewImageView.image = nil
            compositePreviewImageView.frame = .zero
            metalCanvasView.isHidden = false
            return
        }

        compositePreviewImageView.image = image
        compositePreviewImageView.frame = contentRect()
        metalCanvasView.isHidden = true
    }

    private func updateSelectionPreview(_ points: [CGPoint]) {
        guard currentTool == .select, points.count >= 2 else {
            selectionPreviewLayer.path = nil
            return
        }

        let path = UIBezierPath()
        for (index, point) in points.enumerated() {
            let mapped = viewPoint(fromDocumentPoint: point)
            if index == 0 {
                path.move(to: mapped)
            } else {
                path.addLine(to: mapped)
            }
        }
        selectionPreviewLayer.path = path.cgPath
    }

    private func updateShapePreview(_ stroke: Stroke?, style: PreviewStrokeStyle) {
        guard currentTool == .shape, let stroke, stroke.points.count >= 2 else {
            shapePreviewImageView.image = nil
            shapePreviewImageView.isHidden = true
            return
        }

        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            cgContext.setAllowsAntialiasing(true)
            cgContext.setShouldAntialias(true)
            drawShapePreview(stroke: stroke, style: style, in: cgContext)
        }

        shapePreviewImageView.image = image
        shapePreviewImageView.isHidden = false
    }

    private func drawShapePreview(stroke: Stroke, style: PreviewStrokeStyle, in context: CGContext) {
        let points = stroke.points.map { point in
            (viewPoint(fromDocumentPoint: point.cgPoint), CGFloat(point.pressure))
        }

        guard points.count >= 2 else { return }
        let sampled = denselySampledPreviewPoints(from: points, style: style)
        for index in sampled.indices {
            let point = sampled[index].0
            let pressure = sampled[index].1
            let baseDiameter = max(style.radius * 2.0, 1.0)
            let pressureScale = max(0.35, 1.0 - style.pressureSensitivity + (style.pressureSensitivity * pressure))
            let diameter = max(baseDiameter * pressureScale, 1.0)
            let angle = previewStampAngle(for: sampled, at: index, style: style)
            drawPreviewStamp(
                in: context,
                center: point,
                diameter: diameter,
                angle: angle,
                alpha: previewStampAlpha(style: style),
                style: style
            )
        }
    }

    private func denselySampledPreviewPoints(from points: [(CGPoint, CGFloat)], style: PreviewStrokeStyle) -> [(CGPoint, CGFloat)] {
        guard points.count >= 2 else { return points }

        let baseDiameter = max(style.radius * 2.0, 1.0)
        let spacing = max(baseDiameter * 0.16, 0.75)
        var sampled: [(CGPoint, CGFloat)] = [points[0]]

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let deltaX = current.0.x - previous.0.x
            let deltaY = current.0.y - previous.0.y
            let distance = hypot(deltaX, deltaY)
            let steps = max(1, Int(ceil(distance / spacing)))

            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                sampled.append((
                    CGPoint(
                        x: previous.0.x + deltaX * t,
                        y: previous.0.y + deltaY * t
                    ),
                    previous.1 + ((current.1 - previous.1) * t)
                ))
            }
        }

        return sampled
    }

    private func previewStampAngle(for points: [(CGPoint, CGFloat)], at index: Int, style: PreviewStrokeStyle) -> CGFloat {
        guard style.followsStrokeAngle, points.count >= 2 else { return style.angle }

        let previous = points[max(index - 1, 0)].0
        let next = points[min(index + 1, points.count - 1)].0
        let deltaX = next.x - previous.x
        let deltaY = next.y - previous.y
        guard abs(deltaX) > 0.001 || abs(deltaY) > 0.001 else { return style.angle }
        return atan2(deltaY, deltaX) + style.angle
    }

    private func drawPreviewStamp(
        in context: CGContext,
        center: CGPoint,
        diameter: CGFloat,
        angle: CGFloat,
        alpha: CGFloat,
        style: PreviewStrokeStyle
    ) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angle)

        let size: CGSize = {
            if let customTip = style.customTip, customTip.width > 0, customTip.height > 0 {
                let aspectRatio = CGFloat(customTip.height) / CGFloat(customTip.width)
                return CGSize(width: diameter, height: max(diameter * aspectRatio, 1.0))
            }
            return CGSize(width: diameter, height: max(diameter * style.roundness, diameter * 0.2))
        }()
        let rect = CGRect(
            x: -size.width * 0.5,
            y: -size.height * 0.5,
            width: size.width,
            height: size.height
        )

        if let customTip = style.customTip, let mask = tipMaskImage(for: customTip) {
            context.saveGState()
            context.clip(to: rect, mask: mask)
            context.setFillColor(UIColor(cgColor: style.color).withAlphaComponent(alpha).cgColor)
            context.fill(rect)
            context.restoreGState()
        } else {
            context.setFillColor(UIColor(cgColor: style.color).withAlphaComponent(alpha).cgColor)

            switch style.tipKind {
            case .airbrush:
                context.setShadow(offset: .zero, blur: diameter * (1.0 - style.hardness) * 0.8, color: UIColor(cgColor: style.color).withAlphaComponent(alpha * 0.8).cgColor)
                context.fillEllipse(in: rect)
            case .oil:
                let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height * 0.22)
                context.addPath(path.cgPath)
                context.fillPath()
            case .ink, .pencil:
                context.fillEllipse(in: rect)
            }
        }

        context.restoreGState()
    }

    private func previewStampAlpha(style: PreviewStrokeStyle) -> CGFloat {
        let base = min(max(style.opacity, 0.04), 1.0)
        let flow = min(max(style.flow, 0.04), 1.0)
        let hardnessBias = 0.55 + (style.hardness * 0.45)
        return min(max(base * flow * hardnessBias * 0.55, 0.03), 1.0)
    }

    private func tipMaskImage(for raster: BrushTipRaster) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: raster.alphaData as CFData) else { return nil }
        return CGImage(
            maskWidth: raster.width,
            height: raster.height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: raster.width,
            provider: provider,
            decode: nil,
            shouldInterpolate: true
        ) ?? CGImage(
            width: raster.width,
            height: raster.height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: raster.width,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private func sampledColor(at point: CGPoint, source: EyedropperSamplingSource) -> SampledColor? {
        guard
            let snapshot = metalCanvasView.currentSnapshot,
            snapshot.width > 0,
            snapshot.height > 0
        else {
            return nil
        }

        let x = min(max(Int(point.x.rounded()), 0), snapshot.width - 1)
        let y = min(max(Int(point.y.rounded()), 0), snapshot.height - 1)

        switch source {
        case .activeLayer:
            guard let layer = snapshot.layers.first(where: { $0.index == metalCanvasView.currentActiveLayerIndex }) else {
                return nil
            }
            return samplePixel(in: layer.pixelData, width: snapshot.width, height: snapshot.height, x: x, y: y)

        case .canvas:
            return sampleCanvasPixel(
                in: snapshot.compositePixelData,
                width: snapshot.width,
                height: snapshot.height,
                x: x,
                y: y
            )
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

    private func sampleCanvasPixel(in pixelData: Data, width: Int, height: Int, x: Int, y: Int) -> SampledColor? {
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

    private func blendedChannel(source: UInt8, background: UInt8, alpha: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, Int((CGFloat(source) * alpha + CGFloat(background) * (1 - alpha)).rounded()))))
    }

    private func viewRect(forDocumentRect rect: CGRect) -> CGRect {
        let fitted = contentRect()
        guard fitted.width > 0, fitted.height > 0, documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let minPoint = viewPoint(fromDocumentPoint: rect.origin)
        let maxPoint = viewPoint(fromDocumentPoint: CGPoint(x: rect.maxX, y: rect.maxY))
        return CGRect(
            x: minPoint.x,
            y: minPoint.y,
            width: max(1, maxPoint.x - minPoint.x),
            height: max(1, maxPoint.y - minPoint.y)
        )
    }

    private func transformedRect(for rect: CGRect, translation: CGSize, scale: CGFloat) -> CGRect {
        let anchor = CGPoint(x: rect.midX, y: rect.midY)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ].map { point in
            CGPoint(
                x: anchor.x + ((point.x - anchor.x) * scale) + translation.width,
                y: anchor.y + ((point.y - anchor.y) * scale) + translation.height
            )
        }

        let minX = corners.map(\.x).min() ?? rect.minX
        let maxX = corners.map(\.x).max() ?? rect.maxX
        let minY = corners.map(\.y).min() ?? rect.minY
        let maxY = corners.map(\.y).max() ?? rect.maxY
        return viewRect(forDocumentRect: CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY)))
    }

    private func viewPoint(fromDocumentPoint point: CGPoint) -> CGPoint {
        let fitted = contentRect()
        guard fitted.width > 0, fitted.height > 0, documentSize.width > 0, documentSize.height > 0 else { return .zero }
        return CGPoint(
            x: fitted.minX + ((point.x / documentSize.width) * fitted.width),
            y: fitted.minY + ((point.y / documentSize.height) * fitted.height)
        )
    }

    private func makeSelectionOverlayImage(_ selection: CanvasSelection) -> UIImage? {
        let width = selection.maskWidth
        let height = selection.maskHeight
        guard width > 0, height > 0 else { return nil }
        let expectedCount = width * height
        guard selection.maskData.count == expectedCount else { return nil }

        var rgba = Data(count: expectedCount * 4)
        rgba.withUnsafeMutableBytes { destinationBytes in
            selection.maskData.withUnsafeBytes { sourceBytes in
                guard
                    let destinationBase = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    let sourceBase = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }

                for index in 0..<expectedCount {
                    let alpha = sourceBase[index]
                    let destinationIndex = index * 4
                    destinationBase[destinationIndex] = 91
                    destinationBase[destinationIndex + 1] = 181
                    destinationBase[destinationIndex + 2] = 255
                    destinationBase[destinationIndex + 3] = UInt8((Float(alpha) / 255.0) * 96.0)
                }
            }
        }

        guard let provider = CGDataProvider(data: rgba as CFData) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    private func makeCompositePreviewImage(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        selection: CanvasSelection?,
        paperStyle: CanvasPaperStyle,
        transformPreviewScale: CGFloat
    ) -> UIImage? {
        guard let activeLayer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else {
            return nil
        }

        guard let transformedLayerData = makeTransformedLayerPreview(
            layerData: activeLayer.pixelData,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            selection: selection,
            scale: transformPreviewScale
        ) else {
            return nil
        }

        var composite = Data(count: snapshot.width * snapshot.height * 4)
        composite.withUnsafeMutableBytes { destinationBytes in
            guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for layer in snapshot.layers.sorted(by: { $0.index < $1.index }) where layer.visible {
                let sourceData = layer.index == activeLayerIndex ? transformedLayerData : layer.pixelData
                sourceData.withUnsafeBytes { sourceBytes in
                    guard let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    for pixelIndex in 0..<(snapshot.width * snapshot.height) {
                        let offset = pixelIndex * 4
                        blendPixel(
                            destination: destination + offset,
                            source: source + offset,
                            opacity: CGFloat(layer.opacity),
                            blendMode: layer.blendMode
                        )
                    }
                }
            }
        }

        return makeLayerImage(pixelData: composite, width: snapshot.width, height: snapshot.height, paperStyle: paperStyle)
    }

    private func makeLayerImage(pixelData: Data, width: Int, height: Int, paperStyle: CanvasPaperStyle? = nil) -> UIImage? {
        guard width > 0, height > 0, pixelData.count == width * height * 4 else { return nil }
        if let paperStyle {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
            return renderer.image { context in
                drawPaperBackground(
                    in: CGRect(x: 0, y: 0, width: width, height: height),
                    context: context.cgContext,
                    paperStyle: paperStyle
                )
                if let provider = CGDataProvider(data: pixelData as CFData) {
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    if let image = CGImage(
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bitsPerPixel: 32,
                        bytesPerRow: width * 4,
                        space: colorSpace,
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                        provider: provider,
                        decode: nil,
                        shouldInterpolate: false,
                        intent: .defaultIntent
                    ) {
                        UIImage(cgImage: image).draw(in: CGRect(x: 0, y: 0, width: width, height: height))
                    }
                }
            }
        }
        guard let provider = CGDataProvider(data: pixelData as CFData) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    private func drawPaperBackground(in rect: CGRect, context: CGContext, paperStyle: CanvasPaperStyle) {
        if paperStyle.isTransparent {
            let tileSize: CGFloat = 12
            let light = UIColor(white: 0.94, alpha: 1.0)
            let dark = UIColor(white: 0.82, alpha: 1.0)
            for row in stride(from: CGFloat(0), to: rect.height, by: tileSize) {
                for column in stride(from: CGFloat(0), to: rect.width, by: tileSize) {
                    let isDarkTile = Int((row / tileSize) + (column / tileSize)).isMultiple(of: 2)
                    context.setFillColor((isDarkTile ? dark : light).cgColor)
                    context.fill(CGRect(x: column, y: row, width: tileSize, height: tileSize))
                }
            }
            return
        }

        context.setFillColor(
            UIColor(
                red: CGFloat(paperStyle.red),
                green: CGFloat(paperStyle.green),
                blue: CGFloat(paperStyle.blue),
                alpha: CGFloat(paperStyle.alpha)
            ).cgColor
        )
        context.fill(rect)
    }

    private func makeTransformedLayerPreview(
        layerData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection?,
        scale: CGFloat
    ) -> Data? {
        guard layerData.count == canvasWidth * canvasHeight * 4 else { return nil }
        let source = [UInt8](layerData)
        let dx = Int(transformPreviewOffset.width.rounded())
        let dy = Int(transformPreviewOffset.height.rounded())
        let clampedScale = min(max(scale, 0.2), 6.0)
        guard dx != 0 || dy != 0 || abs(clampedScale - 1.0) > 0.001 else { return layerData }

        let mask = selection.map { expandedMask(for: $0, canvasWidth: canvasWidth, canvasHeight: canvasHeight) }
            ?? alphaMask(from: source, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        guard let bounds = transformationBounds(selection: selection, source: source, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }

        var destination = source
        for index in 0..<(canvasWidth * canvasHeight) where mask[index] != 0 {
            let offset = index * 4
            destination[offset] = 0
            destination[offset + 1] = 0
            destination[offset + 2] = 0
            destination[offset + 3] = 0
        }

        let anchor = CGPoint(x: bounds.midX, y: bounds.midY)
        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                let destinationPoint = CGPoint(
                    x: CGFloat(x) - CGFloat(dx),
                    y: CGFloat(y) - CGFloat(dy)
                )
                let sourceX = ((destinationPoint.x - anchor.x) / clampedScale) + anchor.x
                let sourceY = ((destinationPoint.y - anchor.y) / clampedScale) + anchor.y
                let sourcePixelX = Int(sourceX.rounded())
                let sourcePixelY = Int(sourceY.rounded())
                guard sourcePixelX >= 0, sourcePixelX < canvasWidth, sourcePixelY >= 0, sourcePixelY < canvasHeight else { continue }

                let sourceIndex = (sourcePixelY * canvasWidth) + sourcePixelX
                guard mask[sourceIndex] != 0 else { continue }
                let sourceOffset = sourceIndex * 4
                guard source[sourceOffset + 3] != 0 else { continue }

                let destinationOffset = ((y * canvasWidth) + x) * 4
                destination[destinationOffset] = source[sourceOffset]
                destination[destinationOffset + 1] = source[sourceOffset + 1]
                destination[destinationOffset + 2] = source[sourceOffset + 2]
                destination[destinationOffset + 3] = source[sourceOffset + 3]
            }
        }

        return Data(destination)
    }

    private func expandedMask(for selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        let originX = max(Int(selection.bounds.minX.rounded(.down)), 0)
        let originY = max(Int(selection.bounds.minY.rounded(.down)), 0)
        let width = min(selection.maskWidth, canvasWidth - originX)
        let height = min(selection.maskHeight, canvasHeight - originY)
        guard width > 0, height > 0 else { return result }

        selection.maskData.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let sourceIndex = (y * selection.maskWidth) + x
                    let destinationIndex = ((originY + y) * canvasWidth) + (originX + x)
                    result[destinationIndex] = source[sourceIndex]
                }
            }
        }
        return result
    }

    private func alphaMask(from source: [UInt8], canvasWidth: Int, canvasHeight: Int) -> [UInt8] {
        var mask = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        for index in 0..<(canvasWidth * canvasHeight) where source[index * 4 + 3] != 0 {
            mask[index] = 255
        }
        return mask
    }

    private func transformationBounds(selection: CanvasSelection?, source: [UInt8], canvasWidth: Int, canvasHeight: Int) -> CGRect? {
        if let selection, !selection.isEmpty {
            return selection.bounds
        }

        var minX = canvasWidth
        var minY = canvasHeight
        var maxX = -1
        var maxY = -1
        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                if source[((y * canvasWidth) + x) * 4 + 3] == 0 { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private func blendPixel(
        destination: UnsafeMutablePointer<UInt8>,
        source: UnsafePointer<UInt8>,
        opacity: CGFloat,
        blendMode: LayerBlendMode
    ) {
        let srcAlpha = (CGFloat(source[3]) / 255.0) * opacity
        guard srcAlpha > 0.001 else { return }
        let dstAlpha = CGFloat(destination[3]) / 255.0
        let outAlpha = srcAlpha + (dstAlpha * (1 - srcAlpha))
        guard outAlpha > 0.001 else { return }

        let srcR = CGFloat(source[0]) / 255.0
        let srcG = CGFloat(source[1]) / 255.0
        let srcB = CGFloat(source[2]) / 255.0
        let dstR = CGFloat(destination[0]) / 255.0
        let dstG = CGFloat(destination[1]) / 255.0
        let dstB = CGFloat(destination[2]) / 255.0
        let blended = blendColor(backdrop: (dstR, dstG, dstB), source: (srcR, srcG, srcB), blendMode: blendMode)

        let outR = (
            srcAlpha * ((1 - dstAlpha) * srcR + (dstAlpha * blended.r)) +
            (dstAlpha * (1 - srcAlpha) * dstR)
        ) / outAlpha
        let outG = (
            srcAlpha * ((1 - dstAlpha) * srcG + (dstAlpha * blended.g)) +
            (dstAlpha * (1 - srcAlpha) * dstG)
        ) / outAlpha
        let outB = (
            srcAlpha * ((1 - dstAlpha) * srcB + (dstAlpha * blended.b)) +
            (dstAlpha * (1 - srcAlpha) * dstB)
        ) / outAlpha

        destination[0] = UInt8(max(0, min(255, Int((outR * 255.0).rounded()))))
        destination[1] = UInt8(max(0, min(255, Int((outG * 255.0).rounded()))))
        destination[2] = UInt8(max(0, min(255, Int((outB * 255.0).rounded()))))
        destination[3] = UInt8(max(0, min(255, Int((outAlpha * 255.0).rounded()))))
    }

    private func blendColor(
        backdrop: (r: CGFloat, g: CGFloat, b: CGFloat),
        source: (r: CGFloat, g: CGFloat, b: CGFloat),
        blendMode: LayerBlendMode
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        if blendMode == .darkerColor {
            return luminosity(source) < luminosity(backdrop) ? source : backdrop
        }

        if blendMode == .lighterColor {
            return luminosity(source) > luminosity(backdrop) ? source : backdrop
        }

        if blendMode == .hue {
            var output = source
            output = setSaturation(output, saturation(backdrop))
            output = setLuminosity(output, luminosity(backdrop))
            return (
                r: max(0, min(1, output.r)),
                g: max(0, min(1, output.g)),
                b: max(0, min(1, output.b))
            )
        }

        if blendMode == .saturation {
            var output = backdrop
            output = setSaturation(output, saturation(source))
            output = setLuminosity(output, luminosity(backdrop))
            return (
                r: max(0, min(1, output.r)),
                g: max(0, min(1, output.g)),
                b: max(0, min(1, output.b))
            )
        }

        if blendMode == .color {
            var output = source
            output = setSaturation(output, saturation(source))
            output = setLuminosity(output, luminosity(backdrop))
            return (
                r: max(0, min(1, output.r)),
                g: max(0, min(1, output.g)),
                b: max(0, min(1, output.b))
            )
        }

        if blendMode == .luminosity {
            var output = backdrop
            output = setLuminosity(output, luminosity(source))
            return (
                r: max(0, min(1, output.r)),
                g: max(0, min(1, output.g)),
                b: max(0, min(1, output.b))
            )
        }

        return (
            r: max(0, min(1, blendChannel(backdrop: backdrop.r, source: source.r, blendMode: blendMode))),
            g: max(0, min(1, blendChannel(backdrop: backdrop.g, source: source.g, blendMode: blendMode))),
            b: max(0, min(1, blendChannel(backdrop: backdrop.b, source: source.b, blendMode: blendMode)))
        )
    }

    private func blendChannel(backdrop: CGFloat, source: CGFloat, blendMode: LayerBlendMode) -> CGFloat {
        switch blendMode {
        case .normal:
            return source
        case .darken:
            return min(backdrop, source)
        case .multiply:
            return backdrop * source
        case .colorBurn:
            return source <= 0 ? 0 : max(0, 1 - ((1 - backdrop) / max(0.001, source)))
        case .linearBurn:
            return max(0, backdrop + source - 1)
        case .subtract:
            return max(0, backdrop - source)
        case .lighten:
            return max(backdrop, source)
        case .screen:
            return 1 - ((1 - backdrop) * (1 - source))
        case .add:
            return min(1, backdrop + source)
        case .colorDodge:
            return source >= 1 ? 1 : min(1, backdrop / max(0.001, 1 - source))
        case .glowDodge:
            return source >= 1 ? 1 : min(1, backdrop / max(0.0005, 1 - (source * 0.92)))
        case .overlay:
            return backdrop <= 0.5 ? (2 * backdrop * source) : (1 - 2 * (1 - backdrop) * (1 - source))
        case .softLight:
            return source <= 0.5
                ? (backdrop - ((1 - 2 * source) * backdrop * (1 - backdrop)))
                : (backdrop + ((2 * source - 1) * ((backdrop <= 0.25)
                    ? ((((16 * backdrop - 12) * backdrop) + 4) * backdrop)
                    : sqrt(backdrop)) - backdrop))
        case .hardLight:
            return source <= 0.5 ? (2 * backdrop * source) : (1 - 2 * (1 - backdrop) * (1 - source))
        case .difference:
            return abs(backdrop - source)
        case .vividLight:
            return source <= 0.5
                ? blendChannel(backdrop: backdrop, source: 2 * source, blendMode: .colorBurn)
                : blendChannel(backdrop: backdrop, source: 2 * (source - 0.5), blendMode: .colorDodge)
        case .linearLight:
            return max(0, min(1, backdrop + 2 * source - 1))
        case .pinLight:
            return source <= 0.5 ? min(backdrop, 2 * source) : max(backdrop, 2 * (source - 0.5))
        case .hardMix:
            return blendChannel(backdrop: backdrop, source: source, blendMode: .vividLight) < 0.5 ? 0 : 1
        case .exclusion:
            return backdrop + source - (2 * backdrop * source)
        case .darkerColor, .lighterColor, .hue, .saturation, .color, .luminosity:
            return source
        case .divide:
            return min(1, backdrop / max(0.001, source))
        case .addGlow:
            return min(1, backdrop + source * 1.35)
        }
    }

    private func luminosity(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        (0.3 * color.r) + (0.59 * color.g) + (0.11 * color.b)
    }

    private func saturation(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        max(color.r, color.g, color.b) - min(color.r, color.g, color.b)
    }

    private func clipColor(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let lum = luminosity(color)
        let minimum = min(color.r, color.g, color.b)
        let maximum = max(color.r, color.g, color.b)
        var output = color

        if minimum < 0 {
            let scale = lum / max(0.001, lum - minimum)
            output = (
                r: lum + ((output.r - lum) * scale),
                g: lum + ((output.g - lum) * scale),
                b: lum + ((output.b - lum) * scale)
            )
        }

        if maximum > 1 {
            let adjustedMaximum = max(output.r, output.g, output.b)
            let scale = (1 - lum) / max(0.001, adjustedMaximum - lum)
            output = (
                r: lum + ((output.r - lum) * scale),
                g: lum + ((output.g - lum) * scale),
                b: lum + ((output.b - lum) * scale)
            )
        }

        return output
    }

    private func setLuminosity(_ color: (r: CGFloat, g: CGFloat, b: CGFloat), _ lum: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let delta = lum - luminosity(color)
        return clipColor(
            (
                r: color.r + delta,
                g: color.g + delta,
                b: color.b + delta
            )
        )
    }

    private func setSaturation(_ color: (r: CGFloat, g: CGFloat, b: CGFloat), _ sat: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let original = [color.r, color.g, color.b]
        var components = original
        var minIndex = 0
        var midIndex = 1
        var maxIndex = 2

        if original[minIndex] > original[midIndex] { swap(&minIndex, &midIndex) }
        if original[midIndex] > original[maxIndex] { swap(&midIndex, &maxIndex) }
        if original[minIndex] > original[midIndex] { swap(&minIndex, &midIndex) }

        if original[maxIndex] > original[minIndex] {
            components[midIndex] = ((original[midIndex] - original[minIndex]) * sat) / (original[maxIndex] - original[minIndex])
            components[maxIndex] = sat
        } else {
            components[midIndex] = 0
            components[maxIndex] = 0
        }
        components[minIndex] = 0

        return (r: components[0], g: components[1], b: components[2])
    }

    private enum PanPhase {
        case began
        case moved
        case ended
        case cancelled
    }

    private func handlePanTouchesIfNeeded(_ touches: Set<UITouch>, with event: UIEvent?, phase: PanPhase) -> Bool {
        guard currentTool == .move, let touch = touches.first, touch.type != .pencil else {
            if phase == .ended || phase == .cancelled {
                panStartLocation = nil
                panDidMove = false
                isCanvasPanGestureActive = false
            }
            return false
        }

        let nonPencilTouchCount = event?.allTouches?.filter { $0.type != .pencil }.count ?? 1
        if isPinchGestureActive || nonPencilTouchCount > 1 {
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

        if currentTool == .move {
            switch recognizer.state {
            case .began:
                isPinchGestureActive = true
                sendAction?(.transformScaleGestureBegan)

            case .changed:
                sendAction?(.transformScaleChanged(recognizer.scale))

            case .ended, .cancelled, .failed:
                sendAction?(.transformScaleEnded(recognizer.scale))
                if isPinchGestureActive {
                    lastNavigationGestureEndedAt = CACurrentMediaTime()
                }
                isPinchGestureActive = false

            default:
                break
            }
            return
        }

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
