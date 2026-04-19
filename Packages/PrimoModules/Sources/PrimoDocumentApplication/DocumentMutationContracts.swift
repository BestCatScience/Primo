import Foundation

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

public struct DocumentMutationValidator: Sendable {
    public init() {}

    public func validate(
        _ command: DocumentMutationCommand,
        in context: DocumentMutationValidationContext
    ) -> DocumentMutationValidationIssue? {
        switch command {
        case let .layer(target, requiresUnlocked):
            guard (0..<context.layerCount).contains(target.index) else {
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
            guard anchor.index < 0 || (0..<context.layerCount).contains(anchor.index) else {
                return .invalidLayerIndex(anchor.index)
            }
            return nil
        }
    }
}
