import ComposableArchitecture
import Foundation
import PrimoAIImageApplication
import PrimoAIImageDomain
import PrimoDocumentApplication
import PrimoDocumentRuntime

struct AIImageWorkflowReducer: Reducer {
    typealias State = DocumentFeature.State
    typealias AIImageAppliedEdit = DocumentFeature.AIImageAppliedEdit
    typealias AIImageGenerationStart = DocumentFeature.AIImageGenerationStart
    typealias AppliedLayerContentMutation = PrimoDocumentApplication.AppliedLayerContentMutation
    typealias DocumentMutationContract = DocumentFeature.DocumentMutationContract
    typealias DocumentMutationFeedbackMapper = DocumentFeature.DocumentMutationFeedbackMapper
    typealias DocumentNamingPolicy = DocumentFeature.DocumentNamingPolicy
    typealias LayerContentMutationTarget = PrimoDocumentApplication.LayerContentMutationTarget
    typealias LayerContentWorkflowService = any LayerContentWorkflowSubmitting
    typealias LayerMutationFinalization = DocumentFeature.LayerMutationFinalization

    @Dependency(\.aiImageEditUseCase) var aiImageEditUseCase
    @Dependency(\.appLanguageClient) var appLanguageClient
    @Dependency(\.dateClient) var dateClient
    @Dependency(\.layerWorkflowEnvironment) var layerWorkflowEnvironment

    var documentContentService: any LayerContentWorkflowSubmitting {
        layerWorkflowEnvironment.contentService
    }

    var documentRenderingWorkflow: DocumentRenderingWorkflow {
        layerWorkflowEnvironment.renderingWorkflow
    }

    var documentPresentationReader: DocumentPresentationReader {
        layerWorkflowEnvironment.presentationReader
    }

    var documentTextLayerService: LayerEditingRuntime {
        layerWorkflowEnvironment.textLayerService
    }

    var selectionWorkflowService: any SelectionWorkflowRequesting {
        layerWorkflowEnvironment.selectionWorkflowService
    }
    @Dependency(\.uuidClient) var uuidClient

    enum Action: Equatable {
        case aiImageEditRequested(SubmitAIImageEditCommand)
        case aiImagePreviewPrepared(jobID: UUID, preview: AIImagePreviewState)
        case aiImagePreviewPreparationFailed(jobID: UUID, feedback: ApplicationFeature.Feedback)
        case aiImageCancelRequested
        case delegate(DocumentFeature.Action.Delegate)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .aiImageEditRequested(request):
            return handleAIImageEditRequest(state: &state, request: request)
        case let .aiImagePreviewPrepared(jobID, preview):
            guard state.activeAIImageJobID == jobID else { return .none }
            return handleAIImageEditSucceeded(state: &state, preview: preview)
        case let .aiImagePreviewPreparationFailed(jobID, feedback):
            guard state.activeAIImageJobID == jobID else { return .none }
            return handleAIImageEditFailed(state: &state, feedback: feedback)
        case .aiImageCancelRequested:
            return handleAIImageCancelRequested(state: &state)
        case .delegate:
            return .none
        }
    }
}
