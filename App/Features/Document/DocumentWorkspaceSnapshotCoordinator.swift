import Foundation
import PrimoDocumentDomain
import PrimoDocumentPersistenceContracts
import PrimoDocumentRuntime

extension DocumentFeature {
    static let workspaceSnapshotCoordinator = WorkspaceSnapshotCoordinator()

    struct WorkspaceSnapshotCoordinator {
        func snapshot(
            state: DocumentEditingState,
            documentExportGateway: DocumentExportGateway,
            documentRenderingWorkflow: DocumentRenderingWorkflow
        ) -> WorkspaceDocumentSnapshot {
            let paperStyle = canvasToolStateCoordinator.resolvedPaperStyle(for: state)
            let previewSurface = state.canvas.renderSnapshot.flatMap {
                renderedCompositeSurfaceIfAvailable(
                    snapshot: $0,
                    paperStyle: paperStyle,
                    gpuOperations: documentRenderingWorkflow
                )
            } ?? documentExportGateway.compositeSurface(paperStyle)
            return WorkspaceDocumentSnapshot(
                activeTab: nil,
                paperStyle: paperStyle,
                previewSurface: previewSurface,
                canvasSize: state.canvas.canvasSize
            )
        }
    }
}
