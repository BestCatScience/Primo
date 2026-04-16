import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func replayTimelapseOperation(_ operation: TimelapseOperation, folderIDMap: inout [DocumentFolderID: Int]) {
        switch operation {
        case let .stroke(layerIndex, brush, samples):
            guard let first = samples.first else { return }
            bridge.activeLayerIndex = layerIndex.rawValue
            bridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: first))
            for sample in samples.dropFirst() {
                bridge.appendStroke(point: makeStrokePoint(from: sample))
            }
            bridge.endStroke()
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case let .blurStroke(layerIndex, brush, samples):
            applyBlurStroke(samples: samples, brush: brush, layerIndex: layerIndex.rawValue)
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case let .fill(layerIndex, brush, sample):
            bridge.activeLayerIndex = layerIndex.rawValue
            bridge.fill(at: sample.point, brush: makeBrushDescriptor(from: brush))
            invalidateThumbnailCache(for: layerIndex.rawValue)

        case .undo:
            _ = bridge.undo()
            invalidateThumbnailCache()

        case .redo:
            _ = bridge.redo()
            invalidateThumbnailCache()

        case let .addLayer(name):
            bridge.activeLayerIndex = bridge.addLayer(name: name)
            invalidateThumbnailCache()

        case let .duplicateLayer(index, name):
            bridge.activeLayerIndex = bridge.duplicateLayer(at: index.rawValue, name: name)
            invalidateThumbnailCache()

        case let .deleteLayer(index):
            _ = bridge.deleteLayer(at: index.rawValue)
            invalidateThumbnailCache()

        case let .moveLayer(index, destinationIndex):
            _ = bridge.moveLayer(at: index.rawValue, to: destinationIndex.rawValue)
            invalidateThumbnailCache()

        case let .createFolder(folderID, name, anchorLayerIndex):
            let createdID = Int(bridge.createFolder(name: name, layerIndex: anchorLayerIndex?.rawValue ?? -1))
            folderIDMap[folderID] = createdID

        case let .deleteFolder(folderID):
            if let resolved = folderIDMap[folderID] {
                _ = bridge.deleteFolder(id: resolved)
                folderIDMap.removeValue(forKey: folderID)
            }

        case let .setFolderVisibility(folderID, isVisible):
            if let resolved = folderIDMap[folderID] {
                bridge.setFolderVisible(isVisible, folderID: resolved)
            }

        case let .assignLayerToFolder(index, folderID):
            let resolvedFolderID = folderID.flatMap { folderIDMap[$0] } ?? -1
            _ = bridge.setLayerFolder(at: index.rawValue, folderID: resolvedFolderID)
            invalidateThumbnailCache()

        case let .setLayerVisibility(index, isVisible):
            bridge.setLayerVisible(isVisible, at: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerLocked(index, isLocked):
            bridge.setLayerLocked(isLocked, at: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerAlphaLocked(index, isAlphaLocked):
            bridge.setLayerAlphaLocked(isAlphaLocked, at: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerClipped(index, isClipped):
            bridge.setLayerClipped(isClipped, at: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerOpacity(index, opacity):
            bridge.setLayerOpacity(CGFloat(opacity), at: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setLayerBlendMode(index, blendMode):
            bridge.setLayerBlendMode(blendMode.rawValue, at: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .replaceLayerPixels(index, data):
            bridge.replaceLayerPixels(at: index.rawValue, data: data)
            invalidateThumbnailCache(for: index.rawValue)

        case let .replaceLayerMask(index, data):
            bridge.replaceLayerMask(at: index.rawValue, data: data)
            invalidateThumbnailCache(for: index.rawValue)

        case let .clearLayerMask(index):
            bridge.clearLayerMask(at: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .applyLayerMask(index):
            _ = bridge.applyLayerMask(at: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .clearLayer(index):
            bridge.clearLayer(at: index.rawValue)
            invalidateThumbnailCache(for: index.rawValue)

        case let .setPaperStyle(style):
            sessionState.presentation.setPaperStyle(style)
        }
    }
}
