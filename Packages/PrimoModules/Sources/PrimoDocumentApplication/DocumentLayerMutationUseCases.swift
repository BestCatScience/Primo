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
            switch gateway.addLayer(name: name) {
            case let .failure(failure):
                return .failure(failure)
            case let .success(createdIndex):
                switch gateway.setActiveLayerIndex(createdIndex) {
                case let .failure(failure):
                    return .failure(failure)
                case .success:
                    return .success(
                        LayerStructureMutationPlan(
                            resultingIndex: createdIndex,
                            lifecycleEvent: .addLayer(name: name, index: createdIndex)
                        )
                    )
                }
            }

        case let .duplicateLayer(index, name):
            switch gateway.duplicateLayer(index: index, name: name) {
            case let .failure(failure):
                return .failure(failure)
            case let .success(duplicatedIndex):
                return .success(
                    LayerStructureMutationPlan(
                        resultingIndex: duplicatedIndex,
                        indexMutation: .duplication(sourceIndex: index, duplicatedIndex: duplicatedIndex),
                        lifecycleEvent: .duplicateLayer(index: index, duplicatedIndex: duplicatedIndex, name: name)
                    )
                )
            }

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
            switch gateway.createFolder(name: name, anchorLayerIndex: anchorLayerIndex) {
            case let .failure(failure):
                return .failure(failure)
            case let .success(folderID):
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
            }

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
            return gateway.setActiveLayerIndex(index).map { .init() }

        case let .setLayerName(index, name):
            return gateway.setLayerName(name, index: index).map { .init() }

        case let .setLayerVisibility(index, isVisible):
            return gateway.setLayerVisible(isVisible, index: index)
                .map { .init(lifecycleEvent: .setLayerVisibility(index: index, isVisible: isVisible)) }

        case let .setLayerLocked(index, isLocked):
            return gateway.setLayerLocked(isLocked, index: index)
                .map { .init(lifecycleEvent: .setLayerLocked(index: index, isLocked: isLocked)) }

        case let .setLayerAlphaLocked(index, isAlphaLocked):
            return gateway.setLayerAlphaLocked(isAlphaLocked, index: index)
                .map { .init(lifecycleEvent: .setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked)) }

        case let .setLayerClipped(index, isClipped):
            return gateway.setLayerClipped(isClipped, index: index)
                .map { .init(lifecycleEvent: .setLayerClipped(index: index, isClipped: isClipped)) }

        case let .revealLayerForEditing(index):
            return gateway.setLayerVisible(true, index: index).map { .init() }

        case let .setLayerOpacity(index, opacity):
            return gateway.setLayerOpacity(opacity, index: index)
                .map { .init(lifecycleEvent: .setLayerOpacity(index: index, opacity: opacity)) }

        case let .setLayerBlendMode(index, blendMode):
            return gateway.setLayerBlendMode(blendMode, index: index)
                .map { .init(lifecycleEvent: .setLayerBlendMode(index: index, blendMode: blendMode)) }

        case let .setFolderExpanded(folderID, isExpanded):
            return gateway.setFolderExpanded(isExpanded, folderID: folderID).map { .init() }

        case let .setFolderVisibility(folderID, isVisible):
            return gateway.setFolderVisible(isVisible, folderID: folderID)
                .map { .init(lifecycleEvent: .setFolderVisibility(folderID: folderID, isVisible: isVisible)) }

        case let .setFolderName(folderID, name):
            return gateway.setFolderName(name, folderID: folderID).map { .init() }
        }
    }
}
