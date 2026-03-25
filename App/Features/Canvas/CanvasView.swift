import ComposableArchitecture
import SwiftUI
import UIKit

struct CanvasView: UIViewRepresentable {
    let store: StoreOf<CanvasFeature>

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> PaintCanvasContainerView {
        let view = PaintCanvasContainerView()
        view.sendAction = { context.coordinator.viewStore.send($0) }
        return view
    }

    func updateUIView(_ uiView: PaintCanvasContainerView, context: Context) {
        let state = context.coordinator.viewStore.state
        uiView.documentSize = state.canvasSize
        uiView.update(snapshot: state.renderSnapshot, predictedPreview: state.predictedPreview)
    }

    final class Coordinator {
        let viewStore: ViewStore<CanvasFeature.State, CanvasFeature.Action>

        init(store: StoreOf<CanvasFeature>) {
            self.viewStore = ViewStore(store, observe: { $0 })
        }
    }
}

final class PaintCanvasContainerView: UIView {
    var documentSize: CGSize = .zero
    var sendAction: ((CanvasFeature.Action) -> Void)?

    private let rendererView = MetalCanvasView()
    private let previewLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        isMultipleTouchEnabled = false

        rendererView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rendererView)
        NSLayoutConstraint.activate([
            rendererView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rendererView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rendererView.topAnchor.constraint(equalTo: topAnchor),
            rendererView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        previewLayer.strokeColor = UIColor.black.withAlphaComponent(0.18).cgColor
        previewLayer.fillColor = UIColor.clear.cgColor
        previewLayer.lineWidth = 1.5
        previewLayer.lineCap = .round
        previewLayer.lineJoin = .round
        layer.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }

    func update(snapshot: MetalDocumentSnapshot?, predictedPreview: [PreviewStrokePoint]) {
        rendererView.update(snapshot: snapshot)
        updatePreview(predictedPreview)
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
        let fitted = rendererView.contentRect(for: bounds.size, documentSize: documentSize)
        guard fitted.width > 0, fitted.height > 0, documentSize.width > 0, documentSize.height > 0 else { return .zero }

        let x = ((location.x - fitted.minX) / fitted.width) * documentSize.width
        let y = ((location.y - fitted.minY) / fitted.height) * documentSize.height
        return CGPoint(
            x: min(max(0, x), documentSize.width - 1),
            y: min(max(0, y), documentSize.height - 1)
        )
    }

    private func updatePreview(_ points: [PreviewStrokePoint]) {
        guard points.count > 1 else {
            previewLayer.path = nil
            return
        }

        let fitted = rendererView.contentRect(for: bounds.size, documentSize: documentSize)
        let path = UIBezierPath()
        for (index, preview) in points.enumerated() {
            let point = CGPoint(
                x: fitted.minX + ((preview.point.x / max(documentSize.width, 1)) * fitted.width),
                y: fitted.minY + ((preview.point.y / max(documentSize.height, 1)) * fitted.height)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        previewLayer.path = path.cgPath
    }
}
