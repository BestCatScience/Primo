import Foundation
import PrimoDocumentDomain

public typealias DocumentLayerMutationResult = Result<Void, DocumentLayerMutationFailure>
public typealias DocumentLayerIndexedMutationResult = Result<Int, DocumentLayerMutationFailure>

public enum DocumentLayerMutationFailure: Error, Equatable, Sendable {
    case invalidLayerIndex(Int)
    case invalidFolderID(Int)
    case layerLocked(Int)
    case alphaLocked(Int)
    case invalidCanvasSize(width: Int, height: Int)
    case invalidOpacity(Double)
    case emptyInput
    case noUndoState
    case noRedoState
    case bridgeMutationFailed(String)
    case incompatibleLayerType(Int)
    indirect case transactionFailure(primary: DocumentLayerMutationFailure, rollback: DocumentLayerMutationFailure)
}

public struct DocumentLayerMutationContext: Sendable {
    public let layerCount: Int
    public let folderIDs: Set<Int>
    public let isLayerLocked: @Sendable (Int) -> Bool

    public init(
        layerCount: Int,
        folderIDs: Set<Int>,
        isLayerLocked: @escaping @Sendable (Int) -> Bool
    ) {
        self.layerCount = layerCount
        self.folderIDs = folderIDs
        self.isLayerLocked = isLayerLocked
    }

    public func existingLayerIndex(_ rawValue: Int) -> ExistingLayerIndex? {
        guard (0..<layerCount).contains(rawValue) else { return nil }
        return ExistingLayerIndex(rawValue)
    }

    public func existingFolderID(_ rawValue: Int) -> ExistingFolderID? {
        guard folderIDs.contains(rawValue) else { return nil }
        return ExistingFolderID(rawValue)
    }

    public func anchorLayerIndex(_ rawValue: Int) -> LayerAnchorIndex? {
        guard rawValue >= 0 else { return LayerAnchorIndex(nil) }
        return existingLayerIndex(rawValue).map { LayerAnchorIndex($0) }
    }
}

public struct ExistingLayerIndex: Hashable, Sendable {
    public let rawValue: Int

    package init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct ExistingFolderID: Hashable, Sendable {
    public let rawValue: Int

    package init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct LayerAnchorIndex: Hashable, Sendable {
    public let rawValue: Int?

    package init(_ layerIndex: ExistingLayerIndex?) {
        self.rawValue = layerIndex?.rawValue
    }
}

public struct ValidatedLayerOpacity: Equatable, Sendable {
    public let rawValue: Double

    package init(_ rawValue: Double) {
        self.rawValue = rawValue
    }
}

public enum LayerStructureCommand: Equatable, Sendable {
    case addLayer(name: String)
    case duplicateLayer(index: Int, name: String)
    case deleteLayer(index: Int)
    case moveLayer(index: Int, destinationIndex: Int)
    case createFolder(name: String, anchorLayerIndex: Int)
    case deleteFolder(folderID: Int)
    case assignLayerToFolder(index: Int, folderID: Int)
}

public enum LayerAttributeCommand: Equatable, Sendable {
    case setActiveLayer(index: Int)
    case setLayerName(index: Int, name: String)
    case setLayerVisibility(index: Int, isVisible: Bool)
    case setLayerLocked(index: Int, isLocked: Bool)
    case setLayerAlphaLocked(index: Int, isAlphaLocked: Bool)
    case setLayerClipped(index: Int, isClipped: Bool)
    case revealLayerForEditing(index: Int)
    case setLayerOpacity(index: Int, opacity: Double)
    case setLayerBlendMode(index: Int, blendMode: LayerBlendMode)
    case setFolderExpanded(folderID: Int, isExpanded: Bool)
    case setFolderVisibility(folderID: Int, isVisible: Bool)
    case setFolderName(folderID: Int, name: String)
}

public enum ValidatedLayerStructureCommand: Equatable, Sendable {
    case addLayer(name: String)
    case duplicateLayer(index: ExistingLayerIndex, name: String)
    case deleteLayer(index: ExistingLayerIndex)
    case moveLayer(index: ExistingLayerIndex, destinationIndex: ExistingLayerIndex)
    case createFolder(name: String, anchorLayerIndex: LayerAnchorIndex)
    case deleteFolder(folderID: ExistingFolderID)
    case assignLayerToFolder(index: ExistingLayerIndex, folderID: ExistingFolderID?)
}

public enum ValidatedLayerAttributeCommand: Equatable, Sendable {
    case setActiveLayer(index: ExistingLayerIndex)
    case setLayerName(index: ExistingLayerIndex, name: String)
    case setLayerVisibility(index: ExistingLayerIndex, isVisible: Bool)
    case setLayerLocked(index: ExistingLayerIndex, isLocked: Bool)
    case setLayerAlphaLocked(index: ExistingLayerIndex, isAlphaLocked: Bool)
    case setLayerClipped(index: ExistingLayerIndex, isClipped: Bool)
    case revealLayerForEditing(index: ExistingLayerIndex)
    case setLayerOpacity(index: ExistingLayerIndex, opacity: ValidatedLayerOpacity)
    case setLayerBlendMode(index: ExistingLayerIndex, blendMode: LayerBlendMode)
    case setFolderExpanded(folderID: ExistingFolderID, isExpanded: Bool)
    case setFolderVisibility(folderID: ExistingFolderID, isVisible: Bool)
    case setFolderName(folderID: ExistingFolderID, name: String)
}

public enum DocumentLayerMutationEvent: Equatable, Sendable {
    case addLayer(name: String, index: Int)
    case duplicateLayer(index: Int, duplicatedIndex: Int, name: String)
    case deleteLayer(index: Int)
    case moveLayer(index: Int, destinationIndex: Int)
    case createFolder(folderID: Int, name: String, anchorLayerIndex: Int?)
    case deleteFolder(folderID: Int)
    case assignLayerToFolder(index: Int, folderID: Int?)
    case setLayerVisibility(index: Int, isVisible: Bool)
    case setLayerLocked(index: Int, isLocked: Bool)
    case setLayerAlphaLocked(index: Int, isAlphaLocked: Bool)
    case setLayerClipped(index: Int, isClipped: Bool)
    case setLayerOpacity(index: Int, opacity: Double)
    case setLayerBlendMode(index: Int, blendMode: LayerBlendMode)
    case setFolderVisibility(folderID: Int, isVisible: Bool)
}

public enum DocumentLayerIndexMutation: Equatable, Sendable {
    case duplication(sourceIndex: Int, duplicatedIndex: Int)
    case deletion(index: Int)
    case move(sourceIndex: Int, destinationIndex: Int)
}

public struct LayerStructureMutationPlan: Equatable, Sendable {
    public let resultingIndex: Int?
    public let indexMutation: DocumentLayerIndexMutation?
    public let lifecycleEvent: DocumentLayerMutationEvent?

    public init(
        resultingIndex: Int? = nil,
        indexMutation: DocumentLayerIndexMutation? = nil,
        lifecycleEvent: DocumentLayerMutationEvent? = nil
    ) {
        self.resultingIndex = resultingIndex
        self.indexMutation = indexMutation
        self.lifecycleEvent = lifecycleEvent
    }
}

public struct LayerAttributeMutationPlan: Equatable, Sendable {
    public let lifecycleEvent: DocumentLayerMutationEvent?

    public init(lifecycleEvent: DocumentLayerMutationEvent? = nil) {
        self.lifecycleEvent = lifecycleEvent
    }
}

public protocol LayerStructureGateway: Sendable {
    func addLayer(name: String) -> DocumentLayerIndexedMutationResult
    func setActiveLayerIndex(_ index: ExistingLayerIndex) -> DocumentLayerMutationResult
    func duplicateLayer(index: ExistingLayerIndex, name: String) -> DocumentLayerIndexedMutationResult
    func deleteLayer(index: ExistingLayerIndex) -> DocumentLayerMutationResult
    func moveLayer(from index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentLayerMutationResult
    func createFolder(name: String, anchorLayerIndex: LayerAnchorIndex) -> DocumentLayerIndexedMutationResult
    func deleteFolder(id folderID: ExistingFolderID) -> DocumentLayerMutationResult
    func assignLayer(index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentLayerMutationResult
}

public protocol LayerAttributeGateway: Sendable {
    func setActiveLayerIndex(_ index: ExistingLayerIndex) -> DocumentLayerMutationResult
    func setLayerName(_ name: String, index: ExistingLayerIndex) -> DocumentLayerMutationResult
    func setLayerVisible(_ isVisible: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult
    func setLayerLocked(_ isLocked: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult
    func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult
    func setLayerClipped(_ isClipped: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult
    func setLayerOpacity(_ opacity: ValidatedLayerOpacity, index: ExistingLayerIndex) -> DocumentLayerMutationResult
    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: ExistingLayerIndex) -> DocumentLayerMutationResult
    func setFolderExpanded(_ isExpanded: Bool, folderID: ExistingFolderID) -> DocumentLayerMutationResult
    func setFolderVisible(_ isVisible: Bool, folderID: ExistingFolderID) -> DocumentLayerMutationResult
    func setFolderName(_ name: String, folderID: ExistingFolderID) -> DocumentLayerMutationResult
}

public struct LayerStructureCommandValidator: Sendable {
    public init() {}

    public func validated(
        _ command: LayerStructureCommand,
        in context: DocumentLayerMutationContext
    ) -> Result<ValidatedLayerStructureCommand, DocumentLayerMutationFailure> {
        switch command {
        case let .addLayer(name):
            return .success(.addLayer(name: name))
        case let .duplicateLayer(index, name):
            guard let index = context.existingLayerIndex(index) else {
                return .failure(.invalidLayerIndex(index))
            }
            return .success(.duplicateLayer(index: index, name: name))
        case let .deleteLayer(index):
            guard let index = context.existingLayerIndex(index) else {
                return .failure(.invalidLayerIndex(index))
            }
            return .success(.deleteLayer(index: index))
        case let .moveLayer(index, destinationIndex):
            guard let index = context.existingLayerIndex(index) else {
                return .failure(.invalidLayerIndex(index))
            }
            guard let destinationIndex = context.existingLayerIndex(destinationIndex) else {
                return .failure(.invalidLayerIndex(destinationIndex))
            }
            return .success(.moveLayer(index: index, destinationIndex: destinationIndex))
        case let .createFolder(name, anchorLayerIndex):
            guard let anchorLayerIndex = context.anchorLayerIndex(anchorLayerIndex) else {
                return .failure(.invalidLayerIndex(anchorLayerIndex))
            }
            return .success(.createFolder(name: name, anchorLayerIndex: anchorLayerIndex))
        case let .deleteFolder(folderID):
            guard let folderID = context.existingFolderID(folderID) else {
                return .failure(.invalidFolderID(folderID))
            }
            return .success(.deleteFolder(folderID: folderID))
        case let .assignLayerToFolder(index, folderID):
            guard let index = context.existingLayerIndex(index) else {
                return .failure(.invalidLayerIndex(index))
            }
            guard folderID >= 0 else {
                return .success(.assignLayerToFolder(index: index, folderID: nil))
            }
            guard let folderID = context.existingFolderID(folderID) else {
                return .failure(.invalidFolderID(folderID))
            }
            return .success(.assignLayerToFolder(index: index, folderID: folderID))
        }
    }

    public func validate(
        _ command: LayerStructureCommand,
        in context: DocumentLayerMutationContext
    ) -> DocumentLayerMutationFailure? {
        validated(command, in: context).failure
    }
}

public struct LayerAttributeCommandValidator: Sendable {
    public init() {}

    public func validated(
        _ command: LayerAttributeCommand,
        in context: DocumentLayerMutationContext
    ) -> Result<ValidatedLayerAttributeCommand, DocumentLayerMutationFailure> {
        switch command {
        case let .setActiveLayer(index):
            return existingLayer(index, in: context).map { .setActiveLayer(index: $0) }
        case let .setLayerName(index, name):
            return existingLayer(index, in: context).map { .setLayerName(index: $0, name: name) }
        case let .setLayerVisibility(index, isVisible):
            return existingLayer(index, in: context).map { .setLayerVisibility(index: $0, isVisible: isVisible) }
        case let .setLayerLocked(index, isLocked):
            return existingLayer(index, in: context).map { .setLayerLocked(index: $0, isLocked: isLocked) }
        case let .setLayerAlphaLocked(index, isAlphaLocked):
            return existingLayer(index, in: context).map { .setLayerAlphaLocked(index: $0, isAlphaLocked: isAlphaLocked) }
        case let .setLayerClipped(index, isClipped):
            return existingLayer(index, in: context).map { .setLayerClipped(index: $0, isClipped: isClipped) }
        case let .revealLayerForEditing(index):
            return existingLayer(index, in: context).map { .revealLayerForEditing(index: $0) }
        case let .setLayerOpacity(index, opacity):
            guard let index = context.existingLayerIndex(index) else {
                return .failure(.invalidLayerIndex(index))
            }
            guard (0...1).contains(opacity) else {
                return .failure(.invalidOpacity(opacity))
            }
            return .success(.setLayerOpacity(index: index, opacity: ValidatedLayerOpacity(opacity)))
        case let .setLayerBlendMode(index, blendMode):
            return existingLayer(index, in: context).map { .setLayerBlendMode(index: $0, blendMode: blendMode) }
        case let .setFolderExpanded(folderID, isExpanded):
            return existingFolder(folderID, in: context).map { .setFolderExpanded(folderID: $0, isExpanded: isExpanded) }
        case let .setFolderVisibility(folderID, isVisible):
            return existingFolder(folderID, in: context).map { .setFolderVisibility(folderID: $0, isVisible: isVisible) }
        case let .setFolderName(folderID, name):
            return existingFolder(folderID, in: context).map { .setFolderName(folderID: $0, name: name) }
        }
    }

    public func validate(
        _ command: LayerAttributeCommand,
        in context: DocumentLayerMutationContext
    ) -> DocumentLayerMutationFailure? {
        validated(command, in: context).failure
    }

    private func existingLayer(
        _ index: Int,
        in context: DocumentLayerMutationContext
    ) -> Result<ExistingLayerIndex, DocumentLayerMutationFailure> {
        guard let index = context.existingLayerIndex(index) else {
            return .failure(.invalidLayerIndex(index))
        }
        return .success(index)
    }

    private func existingFolder(
        _ folderID: Int,
        in context: DocumentLayerMutationContext
    ) -> Result<ExistingFolderID, DocumentLayerMutationFailure> {
        guard let folderID = context.existingFolderID(folderID) else {
            return .failure(.invalidFolderID(folderID))
        }
        return .success(folderID)
    }
}

private extension Result {
    var failure: Failure? {
        switch self {
        case .success:
            return nil
        case let .failure(failure):
            return failure
        }
    }
}
