import Foundation
import PrimoDocumentDomain

public struct LayerStructureUseCase: Sendable {
    private let validator: LayerStructureCommandValidator

    public init(validator: LayerStructureCommandValidator = .init()) {
        self.validator = validator
    }

    public func execute(
        _ command: LayerStructureCommand,
        in context: DocumentLayerMutationContext,
        gateway: any LayerStructureGateway
    ) -> Result<LayerStructureMutationPlan, DocumentLayerMutationFailure> {
        if let failure = validator.validate(command, in: context) {
            return .failure(failure)
        }

        switch command {
        case let .addLayer(name):
            let createdIndex = gateway.addLayer(name: name)
            gateway.setActiveLayerIndex(createdIndex)
            return .success(
                LayerStructureMutationPlan(
                    resultingIndex: createdIndex,
                    lifecycleEvent: .addLayer(name: name, index: createdIndex)
                )
            )

        case let .duplicateLayer(index, name):
            let duplicatedIndex = gateway.duplicateLayer(index: index, name: name)
            guard duplicatedIndex >= 0 else {
                return .failure(.bridgeMutationFailed("duplicateLayer"))
            }
            return .success(
                LayerStructureMutationPlan(
                    resultingIndex: duplicatedIndex,
                    indexMutation: .duplication(sourceIndex: index, duplicatedIndex: duplicatedIndex),
                    lifecycleEvent: .duplicateLayer(index: index, duplicatedIndex: duplicatedIndex, name: name)
                )
            )

        case let .deleteLayer(index):
            switch gateway.deleteLayer(index: index) {
            case let .failure(failure):
                return .failure(failure)
            case .success:
                return .success(
                    LayerStructureMutationPlan(
                        indexMutation: .deletion(index: index),
                        lifecycleEvent: .deleteLayer(index: index)
                    )
                )
            }

        case let .moveLayer(index, destinationIndex):
            switch gateway.moveLayer(from: index, to: destinationIndex) {
            case let .failure(failure):
                return .failure(failure)
            case .success:
                return .success(
                    LayerStructureMutationPlan(
                        indexMutation: .move(sourceIndex: index, destinationIndex: destinationIndex),
                        lifecycleEvent: .moveLayer(index: index, destinationIndex: destinationIndex)
                    )
                )
            }

        case let .createFolder(name, anchorLayerIndex):
            let folderID = gateway.createFolder(name: name, anchorLayerIndex: anchorLayerIndex)
            return .success(
                LayerStructureMutationPlan(
                    resultingIndex: folderID,
                    lifecycleEvent: .createFolder(
                        folderID: folderID,
                        name: name,
                        anchorLayerIndex: anchorLayerIndex >= 0 ? anchorLayerIndex : nil
                    )
                )
            )

        case let .deleteFolder(folderID):
            switch gateway.deleteFolder(id: folderID) {
            case let .failure(failure):
                return .failure(failure)
            case .success:
                return .success(
                    LayerStructureMutationPlan(
                        lifecycleEvent: .deleteFolder(folderID: folderID)
                    )
                )
            }

        case let .assignLayerToFolder(index, folderID):
            switch gateway.assignLayer(index: index, toFolder: folderID) {
            case let .failure(failure):
                return .failure(failure)
            case .success:
                return .success(
                    LayerStructureMutationPlan(
                        lifecycleEvent: .assignLayerToFolder(
                            index: index,
                            folderID: folderID >= 0 ? folderID : nil
                        )
                    )
                )
            }
        }
    }
}

public struct LayerAttributeUseCase: Sendable {
    private let validator: LayerAttributeCommandValidator

    public init(validator: LayerAttributeCommandValidator = .init()) {
        self.validator = validator
    }

    public func execute(
        _ command: LayerAttributeCommand,
        in context: DocumentLayerMutationContext,
        gateway: any LayerAttributeGateway
    ) -> Result<LayerAttributeMutationPlan, DocumentLayerMutationFailure> {
        if let failure = validator.validate(command, in: context) {
            return .failure(failure)
        }

        switch command {
        case let .setActiveLayer(index):
            gateway.setActiveLayerIndex(index)
            return .success(.init())

        case let .setLayerName(index, name):
            gateway.setLayerName(name, index: index)
            return .success(.init())

        case let .setLayerVisibility(index, isVisible):
            gateway.setLayerVisible(isVisible, index: index)
            return .success(.init(lifecycleEvent: .setLayerVisibility(index: index, isVisible: isVisible)))

        case let .setLayerLocked(index, isLocked):
            gateway.setLayerLocked(isLocked, index: index)
            return .success(.init(lifecycleEvent: .setLayerLocked(index: index, isLocked: isLocked)))

        case let .setLayerAlphaLocked(index, isAlphaLocked):
            gateway.setLayerAlphaLocked(isAlphaLocked, index: index)
            return .success(.init(lifecycleEvent: .setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked)))

        case let .setLayerClipped(index, isClipped):
            gateway.setLayerClipped(isClipped, index: index)
            return .success(.init(lifecycleEvent: .setLayerClipped(index: index, isClipped: isClipped)))

        case let .revealLayerForEditing(index):
            gateway.setLayerVisible(true, index: index)
            return .success(.init())

        case let .setLayerOpacity(index, opacity):
            gateway.setLayerOpacity(opacity, index: index)
            return .success(.init(lifecycleEvent: .setLayerOpacity(index: index, opacity: opacity)))

        case let .setLayerBlendMode(index, blendMode):
            gateway.setLayerBlendMode(blendMode, index: index)
            return .success(.init(lifecycleEvent: .setLayerBlendMode(index: index, blendMode: blendMode)))

        case let .setFolderExpanded(folderID, isExpanded):
            gateway.setFolderExpanded(isExpanded, folderID: folderID)
            return .success(.init())

        case let .setFolderVisibility(folderID, isVisible):
            gateway.setFolderVisible(isVisible, folderID: folderID)
            return .success(.init(lifecycleEvent: .setFolderVisibility(folderID: folderID, isVisible: isVisible)))

        case let .setFolderName(folderID, name):
            gateway.setFolderName(name, folderID: folderID)
            return .success(.init())
        }
    }
}
