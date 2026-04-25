import Foundation
import PrimoDocumentMetalStrokeInfrastructure
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentStrokeApplication

public struct DocumentStrokeUseCasesLive: Sendable {
    public let preview: DocumentStrokePreviewUseCase
    public let commit: DocumentStrokeCommitUseCase
    public let resetInteractiveStrokeState: @Sendable () -> Void

    public init(
        preview: DocumentStrokePreviewUseCase,
        commit: DocumentStrokeCommitUseCase,
        resetInteractiveStrokeState: @escaping @Sendable () -> Void
    ) {
        self.preview = preview
        self.commit = commit
        self.resetInteractiveStrokeState = resetInteractiveStrokeState
    }

    public static func live(
        processingService: DocumentStrokeProcessingService = DocumentStrokeProcessingService()
    ) -> Self {
        let renderer = MetalStrokeRenderer(processingService: processingService)
        return Self(
            preview: DocumentStrokePreviewUseCase(planner: renderer),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {
                processingService.resetInteractiveStrokeState()
            }
        )
    }
}
