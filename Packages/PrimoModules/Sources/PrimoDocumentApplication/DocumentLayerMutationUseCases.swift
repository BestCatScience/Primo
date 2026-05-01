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
        let validatedCommand: ValidatedLayerStructureCommand
        switch validator.validated(command, in: context) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(validated):
            validatedCommand = validated
        }

        switch validatedCommand {
        case let .addLayer(name):
            switch gateway.addLayer(name: name) {
            case let .failure(failure):
                return .failure(failure)
            case let .success(createdIndex):
                switch gateway.setActiveLayerIndex(ExistingLayerIndex(createdIndex)) {
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
                        indexMutation: .duplication(sourceIndex: index.rawValue, duplicatedIndex: duplicatedIndex),
                        lifecycleEvent: .duplicateLayer(index: index.rawValue, duplicatedIndex: duplicatedIndex, name: name)
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
                        indexMutation: .deletion(index: index.rawValue),
                        lifecycleEvent: .deleteLayer(index: index.rawValue)
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
                        indexMutation: .move(sourceIndex: index.rawValue, destinationIndex: destinationIndex.rawValue),
                        lifecycleEvent: .moveLayer(index: index.rawValue, destinationIndex: destinationIndex.rawValue)
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
                            anchorLayerIndex: anchorLayerIndex.rawValue
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
                        lifecycleEvent: .deleteFolder(folderID: folderID.rawValue)
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
                            index: index.rawValue,
                            folderID: folderID?.rawValue
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
        let validatedCommand: ValidatedLayerAttributeCommand
        switch validator.validated(command, in: context) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(validated):
            validatedCommand = validated
        }

        switch validatedCommand {
        case let .setActiveLayer(index):
            return gateway.setActiveLayerIndex(index).map { .init() }

        case let .setLayerName(index, name):
            return gateway.setLayerName(name, index: index).map { .init() }

        case let .setLayerVisibility(index, isVisible):
            return gateway.setLayerVisible(isVisible, index: index)
                .map { .init(lifecycleEvent: .setLayerVisibility(index: index.rawValue, isVisible: isVisible)) }

        case let .setLayerLocked(index, isLocked):
            return gateway.setLayerLocked(isLocked, index: index)
                .map { .init(lifecycleEvent: .setLayerLocked(index: index.rawValue, isLocked: isLocked)) }

        case let .setLayerAlphaLocked(index, isAlphaLocked):
            return gateway.setLayerAlphaLocked(isAlphaLocked, index: index)
                .map { .init(lifecycleEvent: .setLayerAlphaLocked(index: index.rawValue, isAlphaLocked: isAlphaLocked)) }

        case let .setLayerClipped(index, isClipped):
            return gateway.setLayerClipped(isClipped, index: index)
                .map { .init(lifecycleEvent: .setLayerClipped(index: index.rawValue, isClipped: isClipped)) }

        case let .revealLayerForEditing(index):
            return gateway.setLayerVisible(true, index: index).map { .init() }

        case let .setLayerOpacity(index, opacity):
            return gateway.setLayerOpacity(opacity, index: index)
                .map { .init(lifecycleEvent: .setLayerOpacity(index: index.rawValue, opacity: opacity.rawValue)) }

        case let .setLayerBlendMode(index, blendMode):
            return gateway.setLayerBlendMode(blendMode, index: index)
                .map { .init(lifecycleEvent: .setLayerBlendMode(index: index.rawValue, blendMode: blendMode)) }

        case let .setFolderExpanded(folderID, isExpanded):
            return gateway.setFolderExpanded(isExpanded, folderID: folderID).map { .init() }

        case let .setFolderVisibility(folderID, isVisible):
            return gateway.setFolderVisible(isVisible, folderID: folderID)
                .map { .init(lifecycleEvent: .setFolderVisibility(folderID: folderID.rawValue, isVisible: isVisible)) }

        case let .setFolderName(folderID, name):
            return gateway.setFolderName(name, folderID: folderID).map { .init() }
        }
    }
}
