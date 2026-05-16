import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication

struct DocumentStrokePreviewAdapter: StrokePreviewPort {
    private let runtime: StrokeEditingRuntime

    init(runtime: StrokeEditingRuntime) {
        self.runtime = runtime
    }
}

struct DocumentStrokeCommitAdapter: StrokeCommitPort {
    private let runtime: StrokeEditingRuntime

    init(runtime: StrokeEditingRuntime) {
        self.runtime = runtime
    }
}

extension StrokeEditingRuntime {
    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult {
        blurStroke(
            command.samples,
            command.brush,
            layerIndex: command.layer.layerIndex,
            clearSelectionAfterBlur: command.clearSelectionAfterBlur
        )
    }

    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult {
        fill(command.sample, command.brush)
    }
}

struct DocumentStrokeCommandMutationSubmitter: StrokeMutationSubmitting, StrokeCommitPort {
    let service: DocumentStrokeCommandService

    func cancelStroke() {
        _ = service.cancelStroke()
    }

    func endBlurStroke() -> DocumentMutationResult {
        service.endBlurStroke()
    }

    func cancelBlurStroke() {
        _ = service.cancelBlurStroke()
    }

    func fill(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult {
        service.fill(sample, brush)
    }

    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult {
        service.blurStroke(
            command.samples,
            command.brush,
            command.layer.layerIndex.rawValue,
            command.clearSelectionAfterBlur
        )
    }

    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult {
        service.fill(command.sample, command.brush)
    }
}

extension DocumentStrokePreviewAdapter {
    func cancel() -> GpuStrokeSessionOutcome {
        runtime.cancel()
    }

    func discardPreviewLease(_ lease: StrokePreviewLease) {
        runtime.discardPreviewLease(lease)
    }

    func previewLease(for mutation: GpuCommitMutation) -> StrokePreviewLease {
        runtime.previewLease(for: mutation)
    }

    func beginPreview(
        sample: StylusSample,
        baseSnapshot: MetalDocumentSnapshot?,
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome {
        runtime.beginPreview(
            sample: sample,
            baseSnapshot: baseSnapshot,
            context: context,
            usesResponsivePreview: usesResponsivePreview
        )
    }

    func appendPreview(
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome {
        runtime.appendPreview(
            baseSnapshot: baseSnapshot,
            renderSnapshot: renderSnapshot,
            renderState: renderState,
            samples: samples,
            fullSamples: fullSamples,
            context: context,
            usesResponsivePreview: usesResponsivePreview
        )
    }

    func finish(
        renderState: StrokeSessionRenderState?,
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        samples: [StylusSample],
        context: DocumentStrokeContext,
        allowsApproximatePreviewCommit: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> GpuStrokeSessionOutcome {
        runtime.finish(
            renderState: renderState,
            baseSnapshot: baseSnapshot,
            renderSnapshot: renderSnapshot,
            samples: samples,
            context: context,
            allowsApproximatePreviewCommit: allowsApproximatePreviewCommit,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation
        )
    }
}

extension DocumentStrokeCommitAdapter {
    func cancelStroke() {
        _ = runtime.cancelStroke()
    }

    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult {
        runtime.blurStroke(command)
    }

    func endBlurStroke() -> DocumentMutationResult {
        runtime.endBlurStroke()
    }

    func cancelBlurStroke() {
        _ = runtime.cancelBlurStroke()
    }

    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult {
        runtime.fill(command)
    }
}
