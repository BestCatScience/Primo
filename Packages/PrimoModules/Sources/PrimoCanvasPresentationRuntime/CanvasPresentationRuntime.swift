import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
import PrimoCanvasPresentationInfrastructure
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentPresentationContracts

public enum PrimoMetalSurfaceFiltering: Sendable {
    case linear
    case nearest
}

private extension PrimoDocumentMetalRuntimeInfrastructure.PrimoMetalSurfaceFiltering {
    init(_ filtering: PrimoMetalSurfaceFiltering) {
        switch filtering {
        case .linear:
            self = .linear
        case .nearest:
            self = .nearest
        }
    }
}

#if canImport(UIKit)
import UIKit

@MainActor
public final class CanvasPresentationContainerView: UIView {
    private let content: PrimoCanvasPresentationInfrastructure.CanvasPresentationContainerView

    public var documentSize: CGSize {
        get { content.documentSize }
        set { content.documentSize = newValue }
    }

    public var actionSink: CanvasPresentationActionSink? {
        get { content.actionSink }
        set { content.actionSink = newValue }
    }

    public init(environment: CanvasPresentationEnvironment) {
        self.content = PrimoCanvasPresentationInfrastructure.CanvasPresentationContainerView(environment: environment)
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = true
        addSubview(content)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds
    }

    public func update(_ state: CanvasPresentationState) {
        content.update(state)
    }
}

@MainActor
public final class CanvasPixelSurfaceView: UIView {
    private let content = PrimoCanvasPresentationInfrastructure.CanvasPixelSurfaceView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(content)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds
    }

    public func update(
        surface: DocumentCompositeSurface?,
        opacity: CGFloat = 1.0,
        filtering: PrimoMetalSurfaceFiltering = .linear
    ) {
        content.update(
            surface: surface,
            opacity: opacity,
            filtering: PrimoDocumentMetalRuntimeInfrastructure.PrimoMetalSurfaceFiltering(filtering)
        )
        isHidden = surface == nil
    }
}

#endif
