import Foundation
import PrimoDocumentMutationContracts

public struct LayerMutationTarget: Equatable, Sendable {
    public let index: Int

    public init(index: Int) {
        self.index = index
    }
}

public struct FolderMutationTarget: Equatable, Sendable {
    public let folderID: Int

    public init(folderID: Int) {
        self.folderID = folderID
    }
}

public struct LayerMutationAnchor: Equatable, Sendable {
    public let index: Int

    public init(index: Int) {
        self.index = index
    }
}

public enum DocumentMutationCommand: Equatable, Sendable {
    case layer(target: LayerMutationTarget, requiresUnlocked: Bool)
    case folder(target: FolderMutationTarget)
    case layerAnchor(LayerMutationAnchor)

    public static func layer(index: Int, requiresUnlocked: Bool = false) -> Self {
        .layer(target: LayerMutationTarget(index: index), requiresUnlocked: requiresUnlocked)
    }

    public static func folder(folderID: Int) -> Self {
        .folder(target: FolderMutationTarget(folderID: folderID))
    }

    public static func layerAnchor(index: Int) -> Self {
        .layerAnchor(LayerMutationAnchor(index: index))
    }
}

public enum DocumentMutationValidationIssue: Error, Equatable, Sendable {
    case invalidLayerIndex(Int)
    case invalidFolderID(Int)
    case layerLocked(Int)
}

public struct DocumentMutationValidationContext: Sendable {
    public let layerIndexes: LayerIndexSet
    public let folderIDs: Set<Int>
    public let isLayerLocked: @Sendable (Int) -> Bool

    public var layerCount: Int {
        layerIndexes.count
    }

    public init(
        layerIndexes: LayerIndexSet,
        folderIDs: Set<Int>,
        isLayerLocked: @escaping @Sendable (Int) -> Bool
    ) {
        self.layerIndexes = layerIndexes
        self.folderIDs = folderIDs
        self.isLayerLocked = isLayerLocked
    }

    public init<S: Sequence>(
        layerIndexes: S,
        folderIDs: Set<Int>,
        isLayerLocked: @escaping @Sendable (Int) -> Bool
    ) where S.Element == Int {
        self.init(
            layerIndexes: LayerIndexSet(layerIndexes),
            folderIDs: folderIDs,
            isLayerLocked: isLayerLocked
        )
    }

    public init(
        layerCount: Int,
        folderIDs: Set<Int>,
        isLayerLocked: @escaping @Sendable (Int) -> Bool
    ) {
        self.init(
            layerIndexes: .contiguous(count: layerCount),
            folderIDs: folderIDs,
            isLayerLocked: isLayerLocked
        )
    }

    public func containsLayerIndex(_ rawValue: Int) -> Bool {
        layerIndexes.contains(rawValue)
    }
}

public struct DocumentMutationValidator: Sendable {
    public init() {}

    public func validate(
        _ command: DocumentMutationCommand,
        in context: DocumentMutationValidationContext
    ) -> DocumentMutationValidationIssue? {
        switch command {
        case let .layer(target, requiresUnlocked):
            guard context.containsLayerIndex(target.index) else {
                return .invalidLayerIndex(target.index)
            }
            if requiresUnlocked, context.isLayerLocked(target.index) {
                return .layerLocked(target.index)
            }
            return nil

        case let .folder(target):
            guard context.folderIDs.contains(target.folderID) else {
                return .invalidFolderID(target.folderID)
            }
            return nil

        case let .layerAnchor(anchor):
            guard anchor.index < 0 || context.containsLayerIndex(anchor.index) else {
                return .invalidLayerIndex(anchor.index)
            }
            return nil
        }
    }
}
