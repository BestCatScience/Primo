import ComposableArchitecture
import AVFoundation
import SwiftUI
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
            liveStroke: store.liveStroke,
            predictedPreview: store.predictedPreview,
            previewStyle: store.previewStyle
        )
    }
}

final class PaintCanvasContainerView: UIView {
    var documentSize: CGSize = .zero
    var sendAction: ((CanvasFeature.Action) -> Void)?

    private var rendererView: MetalCanvasView?
    private let committedStrokeContainerLayer = CALayer()
    private let liveStrokeLayer = CAShapeLayer()
    private let predictedStrokeLayer = CAShapeLayer()
    private var pendingSnapshot: MetalDocumentSnapshot?
    private var hasScheduledRendererInstallation = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        isMultipleTouchEnabled = false

        configureStrokeLayer(liveStrokeLayer, opacity: 1.0)
        configureStrokeLayer(predictedStrokeLayer, opacity: 0.22)
        layer.addSublayer(committedStrokeContainerLayer)
        layer.addSublayer(liveStrokeLayer)
        layer.addSublayer(predictedStrokeLayer)
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
        liveStroke: [PreviewStrokePoint],
        predictedPreview: [PreviewStrokePoint],
        previewStyle: PreviewStrokeStyle
    ) {
        pendingSnapshot = snapshot
        rendererView?.update(snapshot: snapshot)
        updateCommittedStrokeLayers(layerBuffers, showsCommittedOverlay: showsCommittedOverlay)
        updateStrokeLayer(liveStrokeLayer, with: liveStroke, style: previewStyle, opacityMultiplier: 0.85)
        updateStrokeLayer(predictedStrokeLayer, with: predictedPreview, style: previewStyle, opacityMultiplier: 0.28)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        sendAction?(.strokeBegan(makeSample(from: touch)))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let confirmedTouches = event?.coalescedTouches(for: touch) ?? [touch]
        sendAction?(.strokeSamples(confirmedTouches.map { makeSample(from: $0) }))

        let predictedTouches = event?.predictedTouches(for: touch) ?? []
        sendAction?(.predictedPreviewUpdated(predictedTouches.map { makeSample(from: $0) }))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        sendAction?(.strokeEnded)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        sendAction?(.strokeEnded)
    }

    private func effectiveForce(for touch: UITouch) -> CGFloat {
        guard touch.type == .pencil || touch.maximumPossibleForce > 0 else { return 0.65 }
        return touch.force / touch.maximumPossibleForce
    }

    private func makeSample(from touch: UITouch) -> StylusSample {
        let location = canvasPoint(from: touch.location(in: self))
        let altitude = touch.type == .pencil ? max(0.05, touch.altitudeAngle) : (.pi / 2.0)
        let azimuth = touch.type == .pencil ? touch.azimuthAngle(in: self) : 0.0
        return StylusSample(
            point: location,
            pressure: effectiveForce(for: touch),
            altitude: altitude,
            azimuth: azimuth,
            timestamp: touch.timestamp
        )
    }

    private func canvasPoint(from location: CGPoint) -> CGPoint {
        let fitted = contentRect()
        guard fitted.width > 0, fitted.height > 0, documentSize.width > 0, documentSize.height > 0 else { return .zero }

        let x = ((location.x - fitted.minX) / fitted.width) * documentSize.width
        let y = ((location.y - fitted.minY) / fitted.height) * documentSize.height
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
