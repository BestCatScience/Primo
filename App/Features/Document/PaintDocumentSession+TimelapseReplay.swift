import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func replayTimelapseOperation(_ operation: TimelapseOperation, folderIDMap: inout [DocumentFolderID: Int]) {
        switch operation {
        case let .stroke(layerIndex, brush, samples):
            guard let first = samples.first else { return }
            setBridgeActiveLayerIndex(layerIndex.rawValue)
            bridgeBeginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: first))
            for sample in samples.dropFirst() {
                bridgeAppendStroke(point: makeStrokePoint(from: sample))
            }
            bridgeEndStroke()
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case let .blurStroke(layerIndex, brush, samples):
            applyBlurStroke(samples: samples, brush: brush, layerIndex: layerIndex.rawValue)
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case let .fill(layerIndex, brush, sample):
            setBridgeActiveLayerIndex(layerIndex.rawValue)
            bridgeFill(at: sample.point, brush: makeBrushDescriptor(from: brush))
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case .undo:
            _ = bridgeUndo()
            invalidateThumbnailCache()

        case .redo:
            _ = bridgeRedo()
            invalidateThumbnailCache()

        case let .addLayer(name):
            setBridgeActiveLayerIndex(bridgeAddLayer(name: name))
            invalidateThumbnailCache()

        case let .duplicateLayer(index, name):
            setBridgeActiveLayerIndex(bridgeDuplicateLayer(index: index.rawValue, name: name))
            invalidateThumbnailCache()

        case let .deleteLayer(index):
            _ = bridgeDeleteLayer(index: index.rawValue)
            invalidateThumbnailCache()

        case let .moveLayer(index, destinationIndex):
            _ = bridgeMoveLayer(from: index.rawValue, to: destinationIndex.rawValue)
            invalidateThumbnailCache()

        case let .createFolder(folderID, name, anchorLayerIndex):
            let createdID = bridgeCreateFolder(name: name, layerIndex: anchorLayerIndex?.rawValue ?? -1)
            folderIDMap[folderID] = createdID

        case let .deleteFolder(folderID):
            if let resolved = folderIDMap[folderID] {
                _ = bridgeDeleteFolder(id: resolved)
                folderIDMap.removeValue(forKey: folderID)
            }

        case let .setFolderVisibility(folderID, isVisible):
            if let resolved = folderIDMap[folderID] {
                bridgeSetFolderVisible(isVisible, folderID: resolved)
            }

        case let .assignLayerToFolder(index, folderID):
            let resolvedFolderID = folderID.flatMap { folderIDMap[$0] } ?? -1
            _ = bridgeSetLayerFolder(index: index.rawValue, folderID: resolvedFolderID)
            invalidateThumbnailCache()

        case let .setLayerVisibility(index, isVisible):
            bridgeSetLayerVisible(isVisible, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerLocked(index, isLocked):
            bridgeSetLayerLocked(isLocked, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerAlphaLocked(index, isAlphaLocked):
            bridgeSetLayerAlphaLocked(isAlphaLocked, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerClipped(index, isClipped):
            bridgeSetLayerClipped(isClipped, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerOpacity(index, opacity):
            bridgeSetLayerOpacity(CGFloat(opacity), index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerBlendMode(index, blendMode):
            bridgeSetLayerBlendMode(blendMode.rawValue, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .replaceLayerPixels(index, data):
            bridgeReplaceLayerPixels(index: index.rawValue, data: data)
            invalidateThumbnailCache(for: index.rawValue)

        case let .replaceLayerMask(index, data):
            bridgeReplaceLayerMask(index: index.rawValue, data: data)
            invalidateThumbnailCache(for: index.rawValue)

        case let .clearLayerMask(index):
            bridgeClearLayerMask(index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .applyLayerMask(index):
            _ = bridgeApplyLayerMask(index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .clearLayer(index):
            bridgeClearLayer(index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setPaperStyle(style):
            setStoredPaperStyle(style)
        }
    }
}
