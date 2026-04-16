import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func resizeCanvas(width: Int, height: Int) {
        let targetSize = PaintDocumentCanvasSize(width: width, height: height)
        let sourceSize = PaintDocumentCanvasSize(width: Int(bridge.width), height: Int(bridge.height))
        guard targetSize != sourceSize else { return }

        let layerInfos = bridge.layerInfos()
        let folderInfos = bridge.folderInfos()
        let activeLayerIndex = min(max(Int(bridge.activeLayerIndex), 0), max(layerInfos.count - 1, 0))
        let sourcePixels = layerInfos.indices.map { bridge.pixelDataForLayer(at: $0) as Data }
        let sourceMasks = layerInfos.indices.map { bridge.layerMaskDataForLayer(at: $0) as Data? }
        let sourceTextLayers = sessionState.textLayers.snapshot()
        let widthScale = CGFloat(targetSize.width) / CGFloat(sourceSize.width)
        let heightScale = CGFloat(targetSize.height) / CGFloat(sourceSize.height)
        let textScale = min(widthScale, heightScale)

        let resizeContext = makeResizedBridgeContext(targetSize: targetSize, layerInfos: layerInfos, folderInfos: folderInfos)
        let resizedTextLayers = Dictionary(uniqueKeysWithValues: sourceTextLayers.map { index, textLayer in
            (
                index,
                TextLayerData(
                    text: textLayer.text,
                    positionX: textLayer.positionX * Double(widthScale),
                    positionY: textLayer.positionY * Double(heightScale),
                    fontPostScriptName: textLayer.fontPostScriptName,
                    fontDisplayName: textLayer.fontDisplayName,
                    fontSize: max(1, textLayer.fontSize * Double(textScale)),
                    scale: textLayer.scale,
                    rotationDegrees: textLayer.rotationDegrees,
                    red: textLayer.red,
                    green: textLayer.green,
                    blue: textLayer.blue,
                    alpha: textLayer.alpha
                )
            )
        })

        for (index, info) in layerInfos.enumerated() {
            applyLayerMetadata(info, at: index, to: resizeContext.bridge, folderIDMap: resizeContext.folderIDMap)
            if let resizedPixels = geometryService.scaledLayerPixelData(
                sourcePixels[index],
                from: sourceSize,
                to: targetSize
            ) {
                resizeContext.bridge.replaceLayerPixels(at: index, data: resizedPixels)
            }
            if let maskData = sourceMasks[index],
               let resizedMask = geometryService.scaledLayerMaskData(
                maskData,
                from: sourceSize,
                to: targetSize
               ) {
                resizeContext.bridge.replaceLayerMask(at: index, data: resizedMask)
            }
        }

        finalizeResizedBridge(
            resizeContext.bridge,
            textLayers: resizedTextLayers,
            activeLayerIndex: activeLayerIndex
        )
    }

    func resizeCanvasExtent(width: Int, height: Int) {
        let targetSize = PaintDocumentCanvasSize(width: width, height: height)
        let sourceSize = PaintDocumentCanvasSize(width: Int(bridge.width), height: Int(bridge.height))
        guard targetSize != sourceSize else { return }

        let layerInfos = bridge.layerInfos()
        let folderInfos = bridge.folderInfos()
        let activeLayerIndex = min(max(Int(bridge.activeLayerIndex), 0), max(layerInfos.count - 1, 0))
        let sourcePixels = layerInfos.indices.map { bridge.pixelDataForLayer(at: $0) as Data }
        let sourceMasks = layerInfos.indices.map { bridge.layerMaskDataForLayer(at: $0) as Data? }
        let sourceTextLayers = sessionState.textLayers.snapshot()
        let offsetX = (targetSize.width - sourceSize.width) / 2
        let offsetY = (targetSize.height - sourceSize.height) / 2

        let resizeContext = makeResizedBridgeContext(targetSize: targetSize, layerInfos: layerInfos, folderInfos: folderInfos)
        let shiftedTextLayers = Dictionary(uniqueKeysWithValues: sourceTextLayers.map { index, textLayer in
            (
                index,
                TextLayerData(
                    text: textLayer.text,
                    positionX: textLayer.positionX + Double(offsetX),
                    positionY: textLayer.positionY + Double(offsetY),
                    fontPostScriptName: textLayer.fontPostScriptName,
                    fontDisplayName: textLayer.fontDisplayName,
                    fontSize: textLayer.fontSize,
                    scale: textLayer.scale,
                    rotationDegrees: textLayer.rotationDegrees,
                    red: textLayer.red,
                    green: textLayer.green,
                    blue: textLayer.blue,
                    alpha: textLayer.alpha
                )
            )
        })

        for (index, info) in layerInfos.enumerated() {
            applyLayerMetadata(info, at: index, to: resizeContext.bridge, folderIDMap: resizeContext.folderIDMap)
            if let translatedPixels = geometryService.translatedLayerPixelData(
                sourcePixels[index],
                from: sourceSize,
                to: targetSize,
                offsetX: offsetX,
                offsetY: offsetY
            ) {
                resizeContext.bridge.replaceLayerPixels(at: index, data: translatedPixels)
            }
            if let maskData = sourceMasks[index],
               let translatedMask = geometryService.translatedLayerMaskData(
                maskData,
                from: sourceSize,
                to: targetSize,
                offsetX: offsetX,
                offsetY: offsetY
               ) {
                resizeContext.bridge.replaceLayerMask(at: index, data: translatedMask)
            }
        }

        finalizeResizedBridge(
            resizeContext.bridge,
            textLayers: shiftedTextLayers,
            activeLayerIndex: activeLayerIndex
        )
    }

    private func makeResizedBridgeContext(
        targetSize: PaintDocumentCanvasSize,
        layerInfos: [APPaintLayerInfo],
        folderInfos: [APPaintFolderInfo]
    ) -> (bridge: APPaintDocumentBridge, folderIDMap: [Int: Int]) {
        let resizedBridge = APPaintDocumentBridge(width: targetSize.width, height: targetSize.height)
        if layerInfos.count > 1 {
            for index in 1..<layerInfos.count {
                _ = resizedBridge.addLayer(name: layerInfos[index].name)
            }
        }

        var folderIDMap: [Int: Int] = [:]
        for folder in folderInfos {
            let createdFolderID = Int(
                resizedBridge.createFolder(
                    name: folder.name,
                    layerIndex: folder.anchorLayerIndex >= 0 ? Int(folder.anchorLayerIndex) : -1
                )
            )
            folderIDMap[Int(folder.folderID)] = createdFolderID
            resizedBridge.setFolderVisible(folder.visible, folderID: createdFolderID)
            resizedBridge.setFolderExpanded(folder.expanded, folderID: createdFolderID)
            resizedBridge.setFolderName(folder.name, folderID: createdFolderID)
        }

        return (resizedBridge, folderIDMap)
    }

    private func applyLayerMetadata(
        _ info: APPaintLayerInfo,
        at index: Int,
        to bridge: APPaintDocumentBridge,
        folderIDMap: [Int: Int]
    ) {
        bridge.setLayerName(info.name, at: index)
        bridge.setLayerVisible(info.visible, at: index)
        bridge.setLayerLocked(info.locked, at: index)
        bridge.setLayerAlphaLocked(info.alphaLocked, at: index)
        bridge.setLayerClipped(info.clipped, at: index)
        bridge.setLayerOpacity(info.opacity, at: index)
        bridge.setLayerBlendMode(info.blendMode, at: index)
        if info.folderID >= 0, let mappedFolderID = folderIDMap[Int(info.folderID)] {
            _ = bridge.setLayerFolder(at: index, folderID: mappedFolderID)
        }
    }

    private func finalizeResizedBridge(
        _ resizedBridge: APPaintDocumentBridge,
        textLayers resizedTextLayers: [Int: TextLayerData],
        activeLayerIndex: Int
    ) {
        bridge = resizedBridge
        sessionState.textLayers.replaceAll(with: resizedTextLayers)
        for (index, textLayer) in resizedTextLayers {
            guard let rasterized = rasterizedTextLayerPixelData(textLayer) else { continue }
            bridge.replaceLayerPixels(at: index, data: rasterized)
        }
        bridge.activeLayerIndex = activeLayerIndex
        sessionState.editing.resetAll()
        resetTimelapseHistory()
        applyLifecycleMutation(editingLifecycleService.mutation(invalidating: .all))
    }
}
