import Foundation
import os
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts

struct UndoHistoryCoordinator: Sendable {
    private var policy: UndoSnapshotPolicy

    init(maxUndoEntryCount: Int, maxUndoRetainedBytes: Int) {
        self.policy = UndoSnapshotPolicy(
            limits: UndoSnapshotPolicy.Limits(
                maxEntryCount: maxUndoEntryCount,
                maxRetainedBytes: maxUndoRetainedBytes
            )
        )
    }

    var canUndo: Bool { policy.canUndo }
    var canRedo: Bool { policy.canRedo }

    mutating func restoreUndo(current: SwiftDocumentStoreSnapshot) -> Result<SwiftDocumentStoreSnapshot, DocumentMutationFailure> {
        policy.restoreUndo(current: current)
    }

    mutating func restoreRedo(current: SwiftDocumentStoreSnapshot) -> Result<SwiftDocumentStoreSnapshot, DocumentMutationFailure> {
        policy.restoreRedo(current: current)
    }

    mutating func recordMutation(
        before: SwiftDocumentStoreSnapshot,
        after: SwiftDocumentStoreSnapshot,
        changedLayerIndex: Int?,
        dirtyRect: LayerPixelRect?
    ) -> UndoSnapshotPolicy.DebugStats {
        policy.recordMutation(
            before: before,
            after: after,
            changedLayerIndex: changedLayerIndex,
            dirtyRect: dirtyRect
        )
    }

    mutating func trimForMemoryPressure() -> UndoSnapshotPolicy.DebugStats {
        policy.trimForMemoryPressure()
    }

    mutating func clear() {
        policy.clear()
    }
}
