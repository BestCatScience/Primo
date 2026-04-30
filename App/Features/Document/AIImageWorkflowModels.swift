import Foundation
import PrimoAIImageApplication
import PrimoAIImageDomain

extension DocumentFeature {
    struct AIImageGenerationStart: Equatable, Sendable {
        let descriptor: AIImageEditDescriptor
        let jobID: UUID
        let createdAt: Date
    }

    struct AIImageAppliedEdit: Equatable, Sendable {
        let preview: AIImagePreviewState
        let historyID: UUID
        let createdAt: Date
    }
}
