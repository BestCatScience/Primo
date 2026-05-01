import Foundation
import PrimoDocumentPresentationContracts
import PrimoDocumentGPUContracts
import PrimoDocumentRenderingContracts

public struct CanvasStrokeInteractionService: Sendable {
    private let sessionUseCase: DocumentStrokeSessionUseCase
    private let releasePreviewLease: @Sendable (StrokePreviewLease) -> Void

    public init(
        sessionUseCase: DocumentStrokeSessionUseCase,
        releasePreviewLease: @escaping @Sendable (StrokePreviewLease) -> Void = { _ in }
    ) {
        self.sessionUseCase = sessionUseCase
        self.releasePreviewLease = releasePreviewLease
    }

    public func cancel() -> GpuStrokeSessionOutcome {
        sessionUseCase.execute(.cancel)
    }

    public func discardPreviewLease(_ lease: StrokePreviewLease) {
        releasePreviewLease(lease)
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
