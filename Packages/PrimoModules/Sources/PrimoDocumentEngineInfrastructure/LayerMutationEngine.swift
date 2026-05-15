import Foundation

enum LayerMutationEngine {
    static func remapFoldersAfterInsertion(in store: SwiftDocumentStore, at insertedIndex: Int) {
        store.update {
            for index in $0.folders.indices {
                if let anchor = $0.folders[index].anchorLayerIndex, anchor >= insertedIndex {
                    $0.folders[index].anchorLayerIndex = anchor + 1
                }
            }
            return true
        }
    }

    static func remapFoldersAfterDeletion(in store: SwiftDocumentStore, of deletedIndex: Int) {
        store.update {
            for index in $0.folders.indices {
                if let anchor = $0.folders[index].anchorLayerIndex {
                    if anchor == deletedIndex {
                        $0.folders[index].anchorLayerIndex = nil
                    } else if anchor > deletedIndex {
                        $0.folders[index].anchorLayerIndex = anchor - 1
                    }
                }
            }
            return true
        }
    }

    static func remapFoldersAfterMove(in store: SwiftDocumentStore, from sourceIndex: Int, to destinationIndex: Int) {
        store.update {
            for index in $0.folders.indices {
                guard let anchor = $0.folders[index].anchorLayerIndex else { continue }
                if anchor == sourceIndex {
                    $0.folders[index].anchorLayerIndex = destinationIndex
                } else if sourceIndex < destinationIndex, anchor > sourceIndex, anchor <= destinationIndex {
                    $0.folders[index].anchorLayerIndex = anchor - 1
                } else if sourceIndex > destinationIndex, anchor >= destinationIndex, anchor < sourceIndex {
                    $0.folders[index].anchorLayerIndex = anchor + 1
                }
            }
            return true
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
