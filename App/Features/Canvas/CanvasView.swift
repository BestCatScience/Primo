import ComposableArchitecture
import AVFoundation
import SwiftUI
import simd
import UIKit

struct CanvasView: UIViewRepresentable {
    let store: StoreOf<CanvasFeature>

    func makeUIView(context: Context) -> PaintCanvasContainerView {
        let view = PaintCanvasContainerView()
        view.sendAction = { store.send($0) }
        return view
    }

    func updateUIView(_ uiView: PaintCanvasContainerView, context: Context) {
        uiView.documentSize = store.canvasSize
        uiView.update(
            snapshot: store.renderSnapshot,
            layerBuffers: store.layerBuffers,
            showsCommittedOverlay: true,
            activeStroke: store.activeStroke,
            previewStyle: store.previewStyle
        )
    }
}

final class PaintCanvasContainerView: UIView, InputHandlerDelegate {
    var documentSize: CGSize = .zero
    var sendAction: ((CanvasFeature.Action) -> Void)?

    private var rendererView: MetalCanvasView?
    private let committedStrokeContainerLayer = CALayer()
    private let liveStrokeLayer = CAShapeLayer()
    private let predictedStrokeLayer = CAShapeLayer()
    private var pendingSnapshot: MetalDocumentSnapshot?
    private var hasScheduledRendererInstallation = false
    private let inputHandler = InputHandler()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        isMultipleTouchEnabled = false
        inputHandler.delegate = self
        inputHandler.pointMapper = { [weak self] location, view in
            guard let self else {
                return SIMD2(Float(location.x), Float(location.y))
            }
            let point = self.canvasPoint(from: location, in: view)
            return SIMD2(Float(point.x), Float(point.y))
        }

        configureStrokeLayer(liveStrokeLayer, opacity: 1.0)
        configureStrokeLayer(predictedStrokeLayer, opacity: 0.22)
        layer.addSublayer(committedStrokeContainerLayer)
        layer.addSublayer(liveStrokeLayer)
        layer.addSublayer(predictedStrokeLayer)
        addInteraction(UIPencilInteraction())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        committedStrokeContainerLayer.frame = bounds
        liveStrokeLayer.frame = bounds
        predictedStrokeLayer.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        scheduleRendererInstallationIfNeeded()
    }

    func update(
        snapshot: MetalDocumentSnapshot?,
        layerBuffers: [LayerCanvasBuffer],
        showsCommittedOverlay: Bool,
        activeStroke: Stroke?,
        previewStyle: PreviewStrokeStyle
    ) {
        pendingSnapshot = snapshot
        rendererView?.update(snapshot: snapshot)
        inputHandler.brushSize = Float(previewStyle.radius * 2.0)
        inputHandler.brushColor = previewStyle.simdColor
        updateCommittedStrokeLayers(layerBuffers, showsCommittedOverlay: showsCommittedOverlay)
        updateStrokeLayer(liveStrokeLayer, with: activeStroke?.confirmedPreviewPoints ?? [], style: previewStyle, opacityMultiplier: 0.85)
        updateStrokeLayer(predictedStrokeLayer, with: activeStroke?.predictedPreviewPoints ?? [], style: previewStyle, opacityMultiplier: 0.28)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    func didUpdateStroke(_ stroke: Stroke) {
        sendAction?(.strokeUpdated(stroke))
    }

    func didEndStroke(_ stroke: Stroke) {
        sendAction?(.strokeEnded(stroke))
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

    private func updateStrokeLayer(
        _ strokeLayer: CAShapeLayer,
        with points: [PreviewStrokePoint],
        style: PreviewStrokeStyle,
        opacityMultiplier: CGFloat
    ) {
        guard !points.isEmpty else {
            strokeLayer.path = nil
            return
        }

        let fitted = contentRect()
        let path = UIBezierPath()
        for (index, preview) in points.enumerated() {
            let point = CGPoint(
                x: fitted.minX + ((preview.point.x / max(documentSize.width, 1)) * fitted.width),
                y: fitted.minY + ((preview.point.y / max(documentSize.height, 1)) * fitted.height)
            )
            if index == 0 {
                path.move(to: point)
                if points.count == 1 {
                    path.addLine(to: CGPoint(x: point.x + 0.01, y: point.y + 0.01))
                }
            } else {
                path.addLine(to: point)
            }
        }
        strokeLayer.path = path.cgPath
        if let color = style.color.copy(alpha: style.opacity * opacityMultiplier) {
            strokeLayer.strokeColor = color
        }
        strokeLayer.lineWidth = max(1.0, style.radius * 2.0)
    }

    private func updateCommittedStrokeLayers(_ layerBuffers: [LayerCanvasBuffer], showsCommittedOverlay: Bool) {
        committedStrokeContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard showsCommittedOverlay else { return }

        for buffer in layerBuffers where buffer.visible {
            for stroke in buffer.strokes {
                let strokeLayer = CAShapeLayer()
                configureStrokeLayer(strokeLayer, opacity: 1.0)
                updateStrokeLayer(
                    strokeLayer,
                    with: stroke.points,
                    style: stroke.style,
                    opacityMultiplier: CGFloat(buffer.opacity) * 0.92
                )
                committedStrokeContainerLayer.addSublayer(strokeLayer)
            }
        }
    }

    private func scheduleRendererInstallationIfNeeded() {
        guard window != nil, rendererView == nil, !hasScheduledRendererInstallation else { return }
        hasScheduledRendererInstallation = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.installRendererIfNeeded()
        }
    }

    private func installRendererIfNeeded() {
        guard rendererView == nil else { return }

        let rendererView = MetalCanvasView()
        rendererView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rendererView)
        sendSubviewToBack(rendererView)
        NSLayoutConstraint.activate([
            rendererView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rendererView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rendererView.topAnchor.constraint(equalTo: topAnchor),
            rendererView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        rendererView.update(snapshot: pendingSnapshot)
        self.rendererView = rendererView
    }

    private func configureStrokeLayer(_ strokeLayer: CAShapeLayer, opacity: CGFloat) {
        strokeLayer.strokeColor = UIColor.black.withAlphaComponent(opacity).cgColor
        strokeLayer.fillColor = UIColor.clear.cgColor
        strokeLayer.lineWidth = 1.5
        strokeLayer.lineCap = .round
        strokeLayer.lineJoin = .round
    }

    private func contentRect() -> CGRect {
        if let rendererView {
            return rendererView.contentRect(for: bounds.size, documentSize: documentSize)
        }

        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        return AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
    }
}

private extension PreviewStrokeStyle {
    var simdColor: SIMD4<Float> {
        guard let components = color.components else {
            return SIMD4(0, 0, 0, 1)
        }

        switch components.count {
        case 4:
            return SIMD4(
                Float(components[0]),
                Float(components[1]),
                Float(components[2]),
                Float(components[3])
            )
        case 2:
            return SIMD4(
                Float(components[0]),
                Float(components[0]),
                Float(components[0]),
                Float(components[1])
            )
        default:
            return SIMD4(0, 0, 0, 1)
        }
    }
}
