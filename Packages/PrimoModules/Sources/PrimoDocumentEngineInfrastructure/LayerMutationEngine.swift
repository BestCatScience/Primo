import Foundation

enum LayerMutationEngine {
    static func remapFoldersAfterInsertion(in store: SwiftDocumentStore, at insertedIndex: Int) {
        for index in store.snapshot.folders.indices {
            if let anchor = store.snapshot.folders[index].anchorLayerIndex, anchor >= insertedIndex {
                store.snapshot.folders[index].anchorLayerIndex = anchor + 1
            }
        }
    }

    static func remapFoldersAfterDeletion(in store: SwiftDocumentStore, of deletedIndex: Int) {
        for index in store.snapshot.folders.indices {
            if let anchor = store.snapshot.folders[index].anchorLayerIndex {
                if anchor == deletedIndex {
                    store.snapshot.folders[index].anchorLayerIndex = nil
                } else if anchor > deletedIndex {
                    store.snapshot.folders[index].anchorLayerIndex = anchor - 1
                }
            }
        }
    }

    static func remapFoldersAfterMove(in store: SwiftDocumentStore, from sourceIndex: Int, to destinationIndex: Int) {
        for index in store.snapshot.folders.indices {
            guard let anchor = store.snapshot.folders[index].anchorLayerIndex else { continue }
            if anchor == sourceIndex {
                store.snapshot.folders[index].anchorLayerIndex = destinationIndex
            } else if sourceIndex < destinationIndex, anchor > sourceIndex, anchor <= destinationIndex {
                store.snapshot.folders[index].anchorLayerIndex = anchor - 1
            } else if sourceIndex > destinationIndex, anchor >= destinationIndex, anchor < sourceIndex {
                store.snapshot.folders[index].anchorLayerIndex = anchor + 1
            }
        }
    }

    static func preserveExistingAlphaIfNeeded(_ source: Data, existing: Data, isAlphaLocked: Bool) -> Data {
        isAlphaLocked ? preserveExistingAlpha(source: source, existing: existing) : source
    }

    private static func preserveExistingAlpha(source: Data, existing: Data) -> Data {
        guard source.count == existing.count, source.count.isMultiple(of: 4) else { return source }
        var output = [UInt8](source)
        existing.withUnsafeBytes { existingBytes in
            guard let existingBase = existingBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for offset in stride(from: 0, to: output.count, by: 4) {
                output[offset + 3] = existingBase[offset + 3]
            }
        }
        return Data(output)
    }
}
