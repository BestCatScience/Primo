import Foundation
import PrimoDocumentDomain

public typealias DocumentLayerMutationResult = Result<Void, DocumentLayerMutationFailure>
public typealias DocumentLayerIndexedMutationResult = Result<Int, DocumentLayerMutationFailure>

public enum DocumentLayerMutationFailure: Error, Equatable, Sendable {
    case invalidLayerIndex(Int)
    case invalidFolderID(Int)
    case layerLocked(Int)
    case invalidOpacity(Double)
    case bridgeMutationFailed(String)
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
    func setActiveLayerIndex(_ index: Int) -> DocumentLayerMutationResult
    func duplicateLayer(index: Int, name: String) -> DocumentLayerIndexedMutationResult
    func deleteLayer(index: Int) -> DocumentLayerMutationResult
    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentLayerMutationResult
    func createFolder(name: String, anchorLayerIndex: Int) -> DocumentLayerIndexedMutationResult
    func deleteFolder(id folderID: Int) -> DocumentLayerMutationResult
    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentLayerMutationResult
}

public protocol LayerAttributeGateway: Sendable {
    func setActiveLayerIndex(_ index: Int) -> DocumentLayerMutationResult
    func setLayerName(_ name: String, index: Int) -> DocumentLayerMutationResult
    func setLayerVisible(_ isVisible: Bool, index: Int) -> DocumentLayerMutationResult
    func setLayerLocked(_ isLocked: Bool, index: Int) -> DocumentLayerMutationResult
    func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: Int) -> DocumentLayerMutationResult
    func setLayerClipped(_ isClipped: Bool, index: Int) -> DocumentLayerMutationResult
    func setLayerOpacity(_ opacity: Double, index: Int) -> DocumentLayerMutationResult
    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: Int) -> DocumentLayerMutationResult
    func setFolderExpanded(_ isExpanded: Bool, folderID: Int) -> DocumentLayerMutationResult
    func setFolderVisible(_ isVisible: Bool, folderID: Int) -> DocumentLayerMutationResult
    func setFolderName(_ name: String, folderID: Int) -> DocumentLayerMutationResult
}

public struct LayerStructureCommandValidator: Sendable {
    public init() {}

    public func validate(
        _ command: LayerStructureCommand,
        in context: DocumentLayerMutationContext
    ) -> DocumentLayerMutationFailure? {
        switch command {
        case .addLayer:
            return nil
        case let .duplicateLayer(index, _):
            return validateLayer(index: index, in: context)
        case let .deleteLayer(index):
            return validateLayer(index: index, in: context)
        case let .moveLayer(index, destinationIndex):
            return validateLayer(index: index, in: context)
                ?? validateLayer(index: destinationIndex, in: context)
        case let .createFolder(_, anchorLayerIndex):
            return validateAnchor(index: anchorLayerIndex, in: context)
        case let .deleteFolder(folderID):
            return validateFolder(folderID: folderID, in: context)
        case let .assignLayerToFolder(index, folderID):
            return validateLayer(index: index, in: context)
                ?? (folderID >= 0 ? validateFolder(folderID: folderID, in: context) : nil)
        }
    }

    private func validateLayer(
        index: Int,
        in context: DocumentLayerMutationContext
    ) -> DocumentLayerMutationFailure? {
        guard (0..<context.layerCount).contains(index) else {
            return .invalidLayerIndex(index)
        }
        return nil
    }

    private func validateAnchor(
        index: Int,
        in context: DocumentLayerMutationContext
    ) -> DocumentLayerMutationFailure? {
        guard index < 0 || (0..<context.layerCount).contains(index) else {
            return .invalidLayerIndex(index)
        }
        return nil
    }

    private func validateFolder(
        folderID: Int,
        in context: DocumentLayerMutationContext
    ) -> DocumentLayerMutationFailure? {
        guard context.folderIDs.contains(folderID) else {
            return .invalidFolderID(folderID)
        }
        return nil
    }
}

public struct LayerAttributeCommandValidator: Sendable {
    public init() {}

    public func validate(
        _ command: LayerAttributeCommand,
        in context: DocumentLayerMutationContext
    ) -> DocumentLayerMutationFailure? {
        switch command {
        case let .setActiveLayer(index):
            return validateLayer(index: index, in: context)
        case let .setLayerName(index, _):
            return validateLayer(index: index, in: context)
        case let .setLayerVisibility(index, _):
            return validateLayer(index: index, in: context)
        case let .setLayerLocked(index, _):
            return validateLayer(index: index, in: context)
        case let .setLayerAlphaLocked(index, _):
            return validateLayer(index: index, in: context)
        case let .setLayerClipped(index, _):
            return validateLayer(index: index, in: context)
        case let .revealLayerForEditing(index):
            return validateLayer(index: index, in: context)
        case let .setLayerOpacity(index, opacity):
            return validateLayer(index: index, in: context)
                ?? ((0...1).contains(opacity) ? nil : .invalidOpacity(opacity))
        case let .setLayerBlendMode(index, _):
            return validateLayer(index: index, in: context)
        case let .setFolderExpanded(folderID, _):
            return validateFolder(folderID: folderID, in: context)
        case let .setFolderVisibility(folderID, _):
            return validateFolder(folderID: folderID, in: context)
        case let .setFolderName(folderID, _):
            return validateFolder(folderID: folderID, in: context)
        }
    }

    private func validateLayer(
        index: Int,
        in context: DocumentLayerMutationContext
    ) -> DocumentLayerMutationFailure? {
        guard (0..<context.layerCount).contains(index) else {
            return .invalidLayerIndex(index)
        }
        return nil
    }

    private func validateFolder(
        folderID: Int,
        in context: DocumentLayerMutationContext
    ) -> DocumentLayerMutationFailure? {
        guard context.folderIDs.contains(folderID) else {
            return .invalidFolderID(folderID)
        }
        return nil
    }
}
