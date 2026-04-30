import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension DocumentFeature {
    static let workspaceSnapshotCoordinator = WorkspaceSnapshotCoordinator()

    struct WorkspaceSnapshotCoordinator {
        func snapshot(
            state: State,
            documentExportGateway: DocumentExportGateway,
            documentGpuOperationGateway: DocumentGpuOperationGateway
        ) -> WorkspaceDocumentSnapshot {
            let paperStyle = canvasToolStateCoordinator.resolvedPaperStyle(for: state)
            let previewSurface = state.canvas.renderSnapshot.map {
                renderedCompositeSurface(
                    snapshot: $0,
                    paperStyle: paperStyle,
                    gpuOperations: documentGpuOperationGateway
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
