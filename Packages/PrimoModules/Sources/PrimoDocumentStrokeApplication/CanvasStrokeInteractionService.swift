import Foundation
import PrimoDocumentPresentationContracts
import PrimoDocumentGPUContracts

public struct CanvasStrokeInteractionService: Sendable {
    private let sessionUseCase: DocumentStrokeSessionUseCase

    public init(sessionUseCase: DocumentStrokeSessionUseCase) {
        self.sessionUseCase = sessionUseCase
    }

    public func cancel() -> GpuStrokeSessionOutcome {
        sessionUseCase.execute(.cancel)
    }

    public func beginPreview(
        sample: StylusSample,
        baseSnapshot: MetalDocumentSnapshot?,
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome {
        sessionUseCase.execute(
            .begin(
                sample: sample,
                baseSnapshot: baseSnapshot,
                context: context,
                usesResponsivePreview: usesResponsivePreview
            )
        )
    }

    public func appendPreview(
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome {
        sessionUseCase.execute(
            .append(
                baseSnapshot: baseSnapshot,
                renderSnapshot: renderSnapshot,
                renderState: renderState,
                samples: samples,
                fullSamples: fullSamples,
                context: context,
                usesResponsivePreview: usesResponsivePreview
            )
        )
    }

    public func finish(
        renderState: StrokeSessionRenderState?,
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        samples: [StylusSample],
        context: DocumentStrokeContext,
        allowsApproximatePreviewCommit: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> GpuStrokeSessionOutcome {
        sessionUseCase.execute(
            .finish(
                renderState: renderState,
                baseSnapshot: baseSnapshot,
                renderSnapshot: renderSnapshot,
                samples: samples,
                context: context,
                allowsApproximatePreviewCommit: allowsApproximatePreviewCommit,
                refreshViaDirtyPresentation: refreshViaDirtyPresentation
            )
        )
    }
}
