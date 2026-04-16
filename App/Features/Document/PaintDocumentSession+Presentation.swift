import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func applyLifecycleMutation(_ mutation: PaintDocumentLifecycleMutation) {
        switch mutation.thumbnailInvalidation {
        case .none:
            break
        case let .layer(index):
            invalidateThumbnailCache(for: index)
        case .all:
            invalidateThumbnailCache()
        }
        recordTimelapseEvents(mutation.timelapseEvents)
        if mutation.shouldCaptureTimelapseFrame {
            captureTimelapseFrame()
        }
    }

    func lightweightPresentation() -> PaintDocumentPresentation {
        let clock = ContinuousClock()
        let start = clock.now
        let infos = bridgeLayerInfos()
        let folderInfos = bridgeFolderInfos()
        let rows = buildLayerRows(from: infos)
        let duration = start.duration(to: clock.now)
        Self.logger.debug("lightweightPresentation produced \(rows.count) layers in \(String(describing: duration), privacy: .public)")
        return PaintDocumentPresentation(
            canvasSize: bridgeCanvasSize,
            activeLayerIndex: bridgeActiveLayerIndex(),
            layerRows: rows,
            layerSidebarRows: buildSidebarRows(layerInfos: infos, layerRows: rows, folderInfos: folderInfos),
            renderSnapshot: nil
        )
    }

    func presentation() -> PaintDocumentPresentation {
        let clock = ContinuousClock()
        let start = clock.now
        let revision = advancePresentationRevision()
        let infos = bridgeLayerInfos()
        let folderInfos = bridgeFolderInfos()
        let folderVisibilityByID = Dictionary(uniqueKeysWithValues: folderInfos.map { (Int($0.folderID), $0.visible) })
        let compositePixelData = bridgeCompositePixelData()
        let snapshots = infos.enumerated().map { element in
            let index = element.offset
            let info = element.element
            return MetalLayerSnapshot(
                index: index,
                opacity: Float(info.opacity),
                visible: info.visible && (info.folderID < 0 || (folderVisibilityByID[Int(info.folderID)] ?? true)),
                isClipped: info.clipped,
                blendMode: LayerBlendMode(rawValue: info.blendMode) ?? .normal,
                thumbnailData: cachedLayerThumbnailData(index: index),
                pixelData: pixelDataForLayer(index: index)
            )
        }
        let rows = buildLayerRows(from: infos)
        let duration = start.duration(to: clock.now)
        let megabytes = snapshots.reduce(0) { $0 + $1.pixelData.count } / 1_048_576
        Self.logger.debug("presentation produced revision \(revision) with \(snapshots.count) layers and \(megabytes) MB in \(String(describing: duration), privacy: .public)")
        return PaintDocumentPresentation(
            canvasSize: bridgeCanvasSize,
            activeLayerIndex: bridgeActiveLayerIndex(),
            layerRows: rows,
            layerSidebarRows: buildSidebarRows(layerInfos: infos, layerRows: rows, folderInfos: folderInfos),
            renderSnapshot: MetalDocumentSnapshot(
                width: bridgeCanvasWidth,
                height: bridgeCanvasHeight,
                revision: revision,
                compositePixelData: compositePixelData,
                layers: snapshots
            )
        )
    }

    func prewarmDrawingResources() {
        _ = bridgeCompositePixelData()
    }

    func compositePixelData() -> Data {
        bridgeCompositePixelData()
    }

    private func buildLayerRows(from infos: [APPaintLayerInfo]) -> [LayerRowModel] {
        Array(infos.enumerated().map { index, layer in
            LayerRowModel(
                index: index,
                name: layer.name,
                visible: layer.visible,
                opacity: layer.opacity,
                isLocked: layer.locked,
                isAlphaLocked: layer.alphaLocked,
                isClipped: layer.clipped,
                blendMode: LayerBlendMode(rawValue: layer.blendMode) ?? .normal,
                folderID: layer.folderID >= 0 ? Int(layer.folderID) : nil,
                hasMask: layer.hasMask,
                isTextLayer: hasStoredTextLayer(at: index),
                textLayer: storedTextLayer(at: index)
            )
        }.reversed())
    }

    private func buildSidebarRows(
        layerInfos: [APPaintLayerInfo],
        layerRows: [LayerRowModel],
        folderInfos: [APPaintFolderInfo]
    ) -> [LayerSidebarRowModel] {
        let layerRowsByIndex = Dictionary(uniqueKeysWithValues: layerRows.map { ($0.index, $0) })
        let orderedFolders = folderInfos.map { folderInfo in
            let childIndices = layerInfos.enumerated().compactMap { index, layer in
                Int(layer.folderID) == Int(folderInfo.folderID) ? index : nil
            }.sorted(by: >)
            return LayerFolderModel(
                id: Int(folderInfo.folderID),
                name: folderInfo.name,
                visible: folderInfo.visible,
                isExpanded: folderInfo.expanded,
                anchorLayerIndex: folderInfo.anchorLayerIndex >= 0 ? Int(folderInfo.anchorLayerIndex) : nil,
                childLayerIndices: childIndices
            )
        }
        let folders = Dictionary(uniqueKeysWithValues: orderedFolders.map { ($0.id, $0) })

        var emittedFolderIDs = Set<Int>()
        var rows: [LayerSidebarRowModel] = []
        for layer in layerRows {
            for folder in orderedFolders where folder.anchorLayerIndex == layer.index && !emittedFolderIDs.contains(folder.id) {
                rows.append(.folder(folder))
                emittedFolderIDs.insert(folder.id)
                if folder.isExpanded {
                    for childIndex in folder.childLayerIndices {
                        if let childLayer = layerRowsByIndex[childIndex] {
                            rows.append(.layer(childLayer, depth: 1))
                        }
                    }
                }
            }

            if let folderID = layer.folderID {
                if folders[folderID] == nil {
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
