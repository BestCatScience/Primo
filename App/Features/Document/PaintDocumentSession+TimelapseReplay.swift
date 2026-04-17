import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func replayTimelapseOperation(_ operation: TimelapseOperation, folderIDMap: inout [DocumentFolderID: Int]) {
        switch operation {
        case let .stroke(layerIndex, brush, samples):
            guard let first = samples.first else { return }
            documentGateway.layers.setActiveLayerIndex(layerIndex.rawValue)
            documentGateway.strokes.begin(sample: first, brush: brush)
            for sample in samples.dropFirst() {
                documentGateway.strokes.append(sample: sample)
            }
            documentGateway.strokes.end()
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case let .blurStroke(layerIndex, brush, samples):
            applyBlurStroke(samples: samples, brush: brush, layerIndex: layerIndex.rawValue)
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case let .fill(layerIndex, brush, sample):
            documentGateway.layers.setActiveLayerIndex(layerIndex.rawValue)
            documentGateway.strokes.fill(sample: sample, brush: brush)
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case .undo:
            _ = documentGateway.history.undo()
            invalidateThumbnailCache()

        case .redo:
            _ = documentGateway.history.redo()
            invalidateThumbnailCache()

        case let .addLayer(name):
            documentGateway.layers.setActiveLayerIndex(documentGateway.layers.addLayer(name: name))
            invalidateThumbnailCache()

        case let .duplicateLayer(index, name):
            documentGateway.layers.setActiveLayerIndex(documentGateway.layers.duplicateLayer(index: index.rawValue, name: name))
            invalidateThumbnailCache()

        case let .deleteLayer(index):
            _ = documentGateway.layers.deleteLayer(index: index.rawValue)
            invalidateThumbnailCache()

        case let .moveLayer(index, destinationIndex):
            _ = documentGateway.layers.moveLayer(from: index.rawValue, to: destinationIndex.rawValue)
            invalidateThumbnailCache()

        case let .createFolder(folderID, name, anchorLayerIndex):
            let createdID = documentGateway.layers.createFolder(name: name, layerIndex: anchorLayerIndex?.rawValue ?? -1)
            folderIDMap[folderID] = createdID

        case let .deleteFolder(folderID):
            if let resolved = folderIDMap[folderID] {
                _ = documentGateway.layers.deleteFolder(id: resolved)
                folderIDMap.removeValue(forKey: folderID)
            }

        case let .setFolderVisibility(folderID, isVisible):
            if let resolved = folderIDMap[folderID] {
                documentGateway.layers.setFolderVisible(isVisible, folderID: resolved)
            }

        case let .assignLayerToFolder(index, folderID):
            let resolvedFolderID = folderID.flatMap { folderIDMap[$0] } ?? -1
            _ = documentGateway.layers.setLayerFolder(index: index.rawValue, folderID: resolvedFolderID)
            invalidateThumbnailCache()

        case let .setLayerVisibility(index, isVisible):
            documentGateway.layers.setLayerVisible(isVisible, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerLocked(index, isLocked):
            documentGateway.layers.setLayerLocked(isLocked, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerAlphaLocked(index, isAlphaLocked):
            documentGateway.layers.setLayerAlphaLocked(isAlphaLocked, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerClipped(index, isClipped):
            documentGateway.layers.setLayerClipped(isClipped, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerOpacity(index, opacity):
            documentGateway.layers.setLayerOpacity(CGFloat(opacity), index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerBlendMode(index, blendMode):
            documentGateway.layers.setLayerBlendMode(blendMode.rawValue, index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .replaceLayerPixels(index, data):
            documentGateway.layers.replaceLayerPixels(index: index.rawValue, data: data)
            invalidateThumbnailCache(for: index.rawValue)

        case let .replaceLayerMask(index, data):
            documentGateway.layers.replaceLayerMask(index: index.rawValue, data: data)
            invalidateThumbnailCache(for: index.rawValue)

        case let .clearLayerMask(index):
            documentGateway.layers.clearLayerMask(index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .applyLayerMask(index):
            _ = documentGateway.layers.applyLayerMask(index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .clearLayer(index):
            documentGateway.layers.clearLayer(index: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setPaperStyle(style):
            setStoredPaperStyle(style)
        }
    }
}
