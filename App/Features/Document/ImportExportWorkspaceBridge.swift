import ComposableArchitecture

struct ImportExportWorkspaceBridge: Reducer {
    typealias State = PrimoRootFeature.State
    typealias Action = PrimoRootFeature.Action

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .importExport(.delegate(.saveHistoryEntriesRequested)):
            return .send(.workspace(.saveHistoryEntriesRequested))

        case let .importExport(.delegate(.saveActiveDocumentRequested(preferredDestinationURL))):
            return .send(.workspace(.saveActiveDocumentRequested(preferredDestinationURL: preferredDestinationURL)))

        case .importExport(.delegate(.saveDocumentCopyRequested)):
            return .send(.workspace(.saveDocumentCopyRequested))

        case let .importExport(.photoImportReceived(name, data)):
            return .send(.document(.layerWorkflow(.photoImportReceived(name: name, data: data))))

        case let .importExport(.delegate(.newCanvasFromImagePrepared(plan))):
            return .send(.document(.lifecycle(.newCanvasFromImagePreparationCompleted(plan))))

        case let .importExport(.saveHistoryRestoreRequested(projectURL, openInNewTab)):
            return .send(
                .workspace(
                    .saveHistoryProjectLoadRequested(
                        projectURL,
                        openInNewTab: openInNewTab,
                        replacementRequest: nil
                    )
                )
            )

        case let .importExport(.saveHistoryOpened(loaded, projectURL, openInNewTab, issues)):
            return .send(.workspace(.saveHistoryProjectOpened(loaded, projectURL, openInNewTab, issues)))

        case let .workspace(.delegate(.saveHistoryLoaded(entries))):
            return .send(.importExport(.saveHistoryLoaded(entries)))

        case let .workspace(.delegate(.saveHistoryLoadFailed(feedback))):
            return .send(.importExport(.saveHistoryLoadFailedFeedback(feedback)))

        case let .workspace(.delegate(.saveHistoryProjectOpened(loaded, projectURL, openInNewTab, issues))):
            return .send(.importExport(.saveHistoryOpened(loaded, projectURL, openInNewTab, issues)))

        case .workspace(.delegate(.saveHistoryRestoreCompleted)):
            return .send(.importExport(.saveHistoryRestoreCompleted))

        default:
            return .none
        }
    }
}
