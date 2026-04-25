import Foundation
import PrimoDocumentMetalStrokeInfrastructure
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentStrokeApplication

public struct DocumentStrokeUseCasesLive: Sendable {
    public let preview: DocumentStrokePreviewUseCase
    public let commit: DocumentStrokeCommitUseCase
    public let session: DocumentStrokeSessionUseCase
    public let resetInteractiveStrokeState: @Sendable () -> Void

    public init(
        preview: DocumentStrokePreviewUseCase,
        commit: DocumentStrokeCommitUseCase,
        session: DocumentStrokeSessionUseCase,
        resetInteractiveStrokeState: @escaping @Sendable () -> Void
    ) {
        self.preview = preview
        self.commit = commit
        self.session = session
        self.resetInteractiveStrokeState = resetInteractiveStrokeState
    }

    public static func live(
        processingService: DocumentStrokeProcessingService = DocumentStrokeProcessingService()
    ) -> Self {
        let renderer = MetalStrokeRenderer(processingService: processingService)
        let preview = DocumentStrokePreviewUseCase(planner: renderer)
        let commit = DocumentStrokeCommitUseCase(renderer: renderer)
        let reset: @Sendable () -> Void = {
            processingService.resetInteractiveStrokeState()
        }
        return Self(
            preview: preview,
            commit: commit,
            session: DocumentStrokeSessionUseCase(
                preview: preview,
                commit: commit,
                resetInteractiveStrokeState: reset
            ),
            resetInteractiveStrokeState: reset
        )
    }
}
