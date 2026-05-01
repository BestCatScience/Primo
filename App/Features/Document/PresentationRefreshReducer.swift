import ComposableArchitecture
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication

struct PresentationRefreshReducer: Reducer {
    typealias State = DocumentEditingState
    typealias WorkspaceDocumentSnapshot = DocumentFeature.WorkspaceDocumentSnapshot

    @Dependency(\.documentExportGateway) var documentExportGateway
    @Dependency(\.documentRenderingWorkflow) var documentRenderingWorkflow
    @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway
    @Dependency(\.documentPresentationReader) var documentPresentationReader
    @Dependency(\.processEnvironmentClient) var processEnvironmentClient

    enum Action: Equatable {
        case startupPresentationBootstrapRequested
        case deferredPresentationLoadRequested
        case deferredPresentationRefreshRequested
        case presentationRefreshRequested
        case paperStyleSyncRequested(CanvasPaperStyle)
        case bootstrapPresentationLoaded(PaintDocumentPresentation)
        case presentationLoaded(PaintDocumentPresentation)
        case workspaceSnapshotRequested(DocumentFeature.WorkspaceSnapshotPurpose)
        case applyLoadedProjectRequested(LoadedPaintProject)
        case delegate(DocumentFeature.Action.Delegate)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startupPresentationBootstrapRequested:
            let paperStyle = DocumentFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: state)
            return .merge(
                synchronizePaperStyleEffect(paperStyle),
                startupPresentationBootstrapEffect()
            )

        case .deferredPresentationLoadRequested:
            return deferredPresentationLoadEffect()

        case .deferredPresentationRefreshRequested:
            return deferredPresentationRefreshEffect()

        case .presentationRefreshRequested:
            let paperStyle = DocumentFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: state)
            return .merge(
                synchronizePaperStyleEffect(paperStyle),
                deferredPresentationRefreshEffect()
            )

        case let .paperStyleSyncRequested(paperStyle):
            return synchronizePaperStyleEffect(paperStyle)

        case let .bootstrapPresentationLoaded(presentation):
            return applyPresentation(presentation, to: &state)

        case let .presentationLoaded(presentation):
            guard !state.canvas.isStrokeActive else { return .none }
            guard shouldApplyAsynchronousPresentation(presentation, to: state) else { return .none }
            return applyPresentation(presentation, to: &state)

        case let .workspaceSnapshotRequested(purpose):
            return .send(
                .delegate(
                    .workspaceSnapshotPrepared(
                        purpose,
                        workspaceDocumentSnapshot(state: state)
                    )
                )
            )

        case let .applyLoadedProjectRequested(loaded):
            guard DocumentFeature.canvasPresentationStateCoordinator.applyLoadedProject(loaded, to: &state) else {
                return .send(.delegate(.loadedProjectApplySkipped))
            }
            return .send(.delegate(.loadedProjectApplied))

        case .delegate:
            return .none
        }
    }

    private func shouldApplyAsynchronousPresentation(
        _ presentation: PaintDocumentPresentation,
        to state: State
    ) -> Bool {
        guard let incomingRevision = presentation.renderSnapshot?.revision else {
            return true
        }
        let visibleRevision = max(
            state.canvas.renderSnapshot?.revision ?? -1,
            state.canvas.pendingCommittedSnapshot?.revision ?? -1,
            state.canvas.lastCommittedRenderRevision
        )
        return incomingRevision >= visibleRevision
    }
}
