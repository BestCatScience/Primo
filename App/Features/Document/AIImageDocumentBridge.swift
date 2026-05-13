import ComposableArchitecture

struct AIImageDocumentBridge: Reducer {
    typealias State = PrimoRootFeature.State
    typealias Action = PrimoRootFeature.Action

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .document(.delegate(.aiImageGenerationStarted(start))):
            return .send(.aiImage(.generationStarted(start)))

        case let .document(.delegate(.aiImageGenerationFailed(feedback, language))):
            return .merge(
                .send(.aiImage(.generationFailedFeedback(feedback, language))),
                .send(.application(.feedbackPresented(feedback)))
            )

        case let .document(.delegate(.aiImageEditApplied(applied))):
            return .send(.aiImage(.generationApplied(applied)))

        case let .aiImage(.delegate(.requestEdit(request))):
            return .send(.document(.aiImageWorkflow(.aiImageEditRequested(request))))

        case .aiImage(.delegate(.cancelEdit)):
            return .send(.document(.aiImageWorkflow(.aiImageCancelRequested)))

        default:
            return .none
        }
    }
}
