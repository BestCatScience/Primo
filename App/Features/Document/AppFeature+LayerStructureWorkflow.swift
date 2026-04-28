import ComposableArchitecture
import Foundation

extension AppIntegrationFeature {
    func handleAddLayer(state: inout State) -> Effect<Action> {
        let layerName = namingPolicy(for: state).defaultLayerName(for: state.layerSidebar)
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.addLayer(
                    named: layerName
                )
            },
            onSuccess: { newLayerIndex, state in
                state.canvas.activateLayerForEditing(newLayerIndex)
            }
        )
    }

    func handleAddFolder(state: inout State) -> Effect<Action> {
        let namingPolicy = namingPolicy(for: state)
        let nextFolderNumber = state.layerSidebar.rows.reduce(into: 0) { partialResult, row in
            if case .folder = row {
                partialResult += 1
            }
        } + 1
        let folderName = namingPolicy.folderName(forOrdinal: nextFolderNumber)
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.createFolder(
                    named: folderName,
                    afterLayerAt: activeLayerIndex
                )
            }
        )
    }

    func handleFolderDeletion(
        state: inout State,
        folderID: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.deleteFolder(folderID)
            }
        )
    }

    func handleLayerDeletion(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                layerWorkflowService.deleteLayer(index)
            }
        )
    }

    func handleLayerDuplication(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        let duplicateName = namingPolicy(for: state).duplicatedLayerName(for: layer.name)
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                layerWorkflowService.duplicateLayer(index, named: duplicateName)
            }
        )
    }

    func handleLayerMove(
        state: inout State,
        index: Int,
        destinationIndex: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                layerWorkflowService.moveLayer(index, to: destinationIndex)
            }
        )
    }

    func handleLayerFolderAssignment(
        state: inout State,
        index: Int,
        folderID: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.assignLayer(index, toFolder: folderID)
            }
        )
    }

    func handleLayerMergeDown(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: {
                layerWorkflowService.mergeLayerDown(index)
            }
        )
    }
}
