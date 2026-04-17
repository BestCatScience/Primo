import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func replayTimelapseOperation(_ operation: TimelapseOperation, folderIDMap: inout [DocumentFolderID: Int]) {
        switch operation {
        case let .stroke(layerIndex, brush, samples):
            guard let first = samples.first else { return }
            layerBridge.setActiveLayerIndex(layerIndex.rawValue)
            strokeBridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: first))
            for sample in samples.dropFirst() {
                strokeBridge.appendStroke(point: makeStrokePoint(from: sample))
            }
            strokeBridge.endStroke()
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case let .blurStroke(layerIndex, brush, samples):
            applyBlurStroke(samples: samples, brush: brush, layerIndex: layerIndex.rawValue)
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case let .fill(layerIndex, brush, sample):
            layerBridge.setActiveLayerIndex(layerIndex.rawValue)
            strokeBridge.fill(at: sample.point, brush: makeBrushDescriptor(from: brush))
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case .undo:
            _ = historyBridge.undo()
            invalidateThumbnailCache()

        case .redo:
            _ = historyBridge.redo()
            invalidateThumbnailCache()

        case let .addLayer(name):
            layerBridge.setActiveLayerIndex(layerBridge.addLayer(name: name))
            invalidateThumbnailCache()

        case let .duplicateLayer(index, name):
            layerBridge.setActiveLayerIndex(layerBridge.duplicateLayer(index: index.rawValue, name: name))
            invalidateThumbnailCache()

        case let .deleteLayer(index):
            _ = layerBridge.deleteLayer(index: index.rawValue)
            invalidateThumbnailCache()

        case let .moveLayer(index, destinationIndex):
            _ = layerBridge.moveLayer(from: index.rawValue, to: destinationIndex.rawValue)
            invalidateThumbnailCache()

        case let .createFolder(folderID, name, anchorLayerIndex):
            let createdID = layerBridge.createFolder(name: name, layerIndex: anchorLayerIndex?.rawValue ?? -1)
            folderIDMap[folderID] = createdID

        case let .deleteFolder(folderID):
            if let resolved = folderIDMap[folderID] {
                _ = layerBridge.deleteFolder(id: resolved)
                folderIDMap.removeValue(forKey: folderID)
            }

        case let .setFolderVisibility(folderID, isVisible):
            if let resolved = folderIDMap[folderID] {
                layerBridge.setFolderVisible(isVisible, folderID: resolved)
            }

        case let .assignLayerToFolder(index, folderID):
            let resolvedFolderID = folderID.flatMap { folderIDMap[$0] } ?? -1
            _ = layerBridge.setLayerFolder(index: index.rawValue, folderID: resolvedFolderID)
            invalidateThumbnailCache()

        case let .setLayerVisibility(index, isVisible):
            layerBridge.setLayerVisible(isVisible, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerLocked(index, isLocked):
            layerBridge.setLayerLocked(isLocked, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerAlphaLocked(index, isAlphaLocked):
            layerBridge.setLayerAlphaLocked(isAlphaLocked, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerClipped(index, isClipped):
            layerBridge.setLayerClipped(isClipped, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerOpacity(index, opacity):
            layerBridge.setLayerOpacity(CGFloat(opacity), index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerBlendMode(index, blendMode):
            layerBridge.setLayerBlendMode(blendMode.rawValue, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .replaceLayerPixels(index, data):
            layerBridge.replaceLayerPixels(index: index.rawValue, data: data)
            invalidateThumbnailCache(for: index.rawValue)

        case let .replaceLayerMask(index, data):
            layerBridge.replaceLayerMask(index: index.rawValue, data: data)
            invalidateThumbnailCache(for: index.rawValue)

        case let .clearLayerMask(index):
            layerBridge.clearLayerMask(index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .applyLayerMask(index):
            _ = layerBridge.applyLayerMask(index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .clearLayer(index):
            layerBridge.clearLayer(index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setPaperStyle(style):
            setStoredPaperStyle(style)
        }
    }
}
