import ComposableArchitecture
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoWorkspaceApplication

struct PresentationRefreshReducer: Reducer {
    typealias State = DocumentEditingState
    typealias WorkspaceDocumentSnapshot = DocumentFeature.WorkspaceDocumentSnapshot

    @Dependency(\.documentPresentationCapability) var documentPresentationCapability
    @Dependency(\.processEnvironmentClient) var processEnvironmentClient

    var documentExportGateway: DocumentExportGateway {
        documentPresentationCapability.exportGateway
    }

    var documentRenderingWorkflow: DocumentRenderingWorkflow {
        documentPresentationCapability.renderingWorkflow
    }

    var documentPersistenceGateway: DocumentPersistenceGateway {
        documentPresentationCapability.persistenceGateway
    }

    var documentPresentationReader: DocumentPresentationReader {
        documentPresentationCapability.presentationReader
    }

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
