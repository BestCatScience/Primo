import PrimoBrushRuntimeContracts
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication

protocol StrokePreviewLeasing: Sendable {
    func cancel() -> GpuStrokeSessionOutcome
    func discardPreviewLease(_ lease: StrokePreviewLease)
    func previewLease(for mutation: GpuCommitMutation) -> StrokePreviewLease
}

protocol StrokePreviewResolving: Sendable {
    func beginPreview(
        sample: StylusSample,
        baseSnapshot: MetalDocumentSnapshot?,
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome

    func appendPreview(
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome

    func finish(
        renderState: StrokeSessionRenderState?,
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        samples: [StylusSample],
        context: DocumentStrokeContext,
        allowsApproximatePreviewCommit: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> GpuStrokeSessionOutcome
}

protocol StrokePreviewPort: StrokePreviewLeasing, StrokePreviewResolving {}

protocol StrokeMutationSubmitting: Sendable {
    func cancelStroke()
    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult
    func endBlurStroke() -> DocumentMutationResult
    func cancelBlurStroke()
    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult
    func fill(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult
}

protocol StrokeCommitPort: Sendable {
    func cancelStroke()
    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult
    func endBlurStroke() -> DocumentMutationResult
    func cancelBlurStroke()
    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult
}
