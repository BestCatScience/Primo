import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts

final class DocumentPresentationBuilder: @unchecked Sendable {
    private var thumbnailSurfaceCache: [Int: DocumentCompositeSurface] = [:]

    func lightweightPresentation(
        snapshot: SwiftDocumentStoreSnapshot,
        canvasSize: CGSize
    ) -> PaintDocumentPresentation {
        guard let presentation = PaintDocumentPresentation(
            canvasSize: canvasSize,
            activeLayerIndex: snapshot.activeLayerIndex,
            layerRows: buildLayerRows(from: snapshot),
            layerSidebarRows: buildSidebarRows(from: snapshot),
            renderSnapshot: nil,
            revision: DocumentRevision(snapshot.revision)
        ) else {
            preconditionFailure("SwiftDocumentStore produced an invalid lightweight presentation")
        }
        return presentation
    }

    func presentation(
        snapshot: SwiftDocumentStoreSnapshot,
        canvasSize: CGSize,
        renderSnapshot: MetalDocumentSnapshot?
    ) -> PaintDocumentPresentation {
        guard let presentation = PaintDocumentPresentation(
            canvasSize: canvasSize,
            activeLayerIndex: snapshot.activeLayerIndex,
            layerRows: buildLayerRows(from: snapshot),
            layerSidebarRows: buildSidebarRows(from: snapshot),
            renderSnapshot: renderSnapshot,
            revision: DocumentRevision(snapshot.revision)
        ) else {
            preconditionFailure("SwiftDocumentStore produced an invalid presentation")
        }
        return presentation
    }

    func makeRenderSnapshot(
        baseSnapshot: MetalDocumentSnapshot,
        compositeHandle: MetalBufferHandle?,
        fallbackComposite: DocumentCompositeSurface?,
        thumbnailSurface: (Int) -> DocumentCompositeSurface?
    ) -> MetalDocumentSnapshot? {
        MetalDocumentSnapshot.unsafeUnchecked(
            width: baseSnapshot.width,
            height: baseSnapshot.height,
            revision: baseSnapshot.revision,
            compositeBufferHandle: compositeHandle,
            compositePixelData: fallbackComposite?.pixelData ?? Data(),
            layers: baseSnapshot.layers.enumerated().map { index, layer in
                MetalLayerSnapshot.unsafeUnchecked(
                    index: layer.index,
                    opacity: layer.opacity,
                    visible: layer.visible,
                    isClipped: layer.isClipped,
                    blendMode: layer.blendMode,
                    thumbnailSurface: thumbnailSurface(index),
                    thumbnailData: nil,
                    gpuBufferHandle: layer.gpuBufferHandle,
                    pixelData: layer.pixelData
                )
            }
        )
    }

    func cachedLayerThumbnailSurface(
        index: Int,
        snapshot: SwiftDocumentStoreSnapshot,
        canvasSize: CGSize,
        gpuServices: DocumentRuntimeGpuServices,
        currentPixelData: (Int) -> Data
    ) -> DocumentCompositeSurface? {
        if let cached = thumbnailSurfaceCache[index] {
            return cached
        }
        guard snapshot.layers.indices.contains(index) else { return nil }
        let targetSize = timelapseFrameSize(for: canvasSize, maxDimension: 96)
        let targetWidth = max(Int(targetSize.width.rounded()), 1)
        let targetHeight = max(Int(targetSize.height.rounded()), 1)
        guard let scaled = gpuServices.scaledPixelData(
            currentPixelData(index),
            sourceWidth: snapshot.canvasWidth,
            sourceHeight: snapshot.canvasHeight,
            targetWidth: targetWidth,
            targetHeight: targetHeight
        ) else {
            return nil
        }
        let surface = DocumentCompositeSurface(
            unsafeUncheckedWidth: targetWidth,
            height: targetHeight,
            pixelData: scaled
        )
        thumbnailSurfaceCache[index] = surface
        return surface
    }

    func invalidateThumbnail(for index: Int, in store: SwiftDocumentStore) {
        store.update {
            $0.thumbnailCache[index] = nil
            return true
        }
        thumbnailSurfaceCache[index] = nil
    }

    func invalidateAllThumbnails(in store: SwiftDocumentStore) {
        store.update {
            $0.thumbnailCache.removeAll(keepingCapacity: true)
            return true
        }
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
    }

    func clearThumbnailSurfaces() {
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
    }

    func timelapseFrameSize(for canvasSize: CGSize, maxDimension: CGFloat) -> CGSize {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return CGSize(width: maxDimension, height: maxDimension)
        }
        let scale = min(maxDimension / canvasSize.width, maxDimension / canvasSize.height, 1.0)
        return CGSize(width: max(2, Int((canvasSize.width * scale).rounded())), height: max(2, Int((canvasSize.height * scale).rounded())))
    }

    private func buildLayerRows(from snapshot: SwiftDocumentStoreSnapshot) -> [LayerRowModel] {
        snapshot.layers.enumerated().map { index, layer in
            guard let opacity = layer.validatedOpacity()?.value else {
                preconditionFailure("SwiftDocumentStore produced an invalid layer opacity")
            }
            return LayerRowModel(
                unsafeUncheckedIndex: index,
                name: layer.name,
                visible: layer.visible,
                opacity: opacity,
                isLocked: layer.locked,
                isAlphaLocked: layer.alphaLocked,
                isClipped: layer.clipped,
                blendMode: layer.blendMode,
                folderID: layer.folderID,
                hasMask: layer.maskData != nil,
                isTextLayer: layer.textLayer != nil,
                textLayer: layer.textLayer
            )
        }.reversed()
    }

    private func buildSidebarRows(from snapshot: SwiftDocumentStoreSnapshot) -> [LayerSidebarRowModel] {
        let layerRows = buildLayerRows(from: snapshot)
        let layerRowsByIndex = Dictionary(uniqueKeysWithValues: layerRows.map { ($0.index, $0) })
        let orderedFolders = snapshot.folders.map { folder in
            LayerFolderModel(
                id: folder.id,
                name: folder.name,
                visible: folder.visible,
                isExpanded: folder.expanded,
                anchorLayerIndex: folder.anchorLayerIndex,
                childLayerIndices: snapshot.layers.enumerated().compactMap { index, layer in
                    layer.folderID == folder.id ? index : nil
                }.sorted(by: >)
            )
        }
        var emittedFolderIDs = Set<Int>()
        var rows: [LayerSidebarRowModel] = []
        for layer in layerRows {
            for folder in orderedFolders where folder.anchorLayerIndex == layer.index && !emittedFolderIDs.contains(folder.id) {
                rows.append(.folder(folder))
                emittedFolderIDs.insert(folder.id)
                if folder.isExpanded {
                    for childIndex in folder.childLayerIndices {
                        if let child = layerRowsByIndex[childIndex] {
                            rows.append(.layer(child, depth: 1))
                        }
                    }
                }
            }
            if let folderID = layer.folderID {
                if !orderedFolders.contains(where: { $0.id == folderID }) {
                    rows.append(.layer(layer, depth: 0))
                }
            } else {
                rows.append(.layer(layer, depth: 0))
            }
        }
        for folder in orderedFolders where !emittedFolderIDs.contains(folder.id) {
            rows.append(.folder(folder))
        }
        return rows
    }
}
