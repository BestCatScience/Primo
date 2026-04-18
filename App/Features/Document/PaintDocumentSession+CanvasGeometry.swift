import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func resizeCanvas(width: Int, height: Int) -> DocumentMutationResult {
        guard width > 0 && height > 0 else {
            return .failure(.invalidCanvasSize(width: width, height: height))
        }
        let targetSize = PaintDocumentCanvasSize(width: width, height: height)
        let sourceSize = PaintDocumentCanvasSize(
            width: documentGateway.queries.canvasWidth,
            height: documentGateway.queries.canvasHeight
        )
        guard targetSize != sourceSize else {
            return .failure(.bridgeMutationFailed("resizeCanvas"))
        }

        let layerInfos = documentGateway.queries.layerInfos()
        let folderInfos = documentGateway.queries.folderInfos()
        let activeLayerIndex = min(max(documentGateway.queries.activeLayerIndex(), 0), max(layerInfos.count - 1, 0))
        let sourcePixels = layerInfos.indices.map { pixelDataForLayer(index: $0) }
        let sourceMasks = layerInfos.indices.map { documentGateway.queries.layerMaskDataForLayer(index: $0) }
        let sourceTextLayers = storedTextLayerSnapshot()
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
            applyLayerMetadata(info, at: index, to: resizeContext.targetBridge, folderIDMap: resizeContext.folderIDMap)
            if let resizedPixels = geometryService.scaledLayerPixelData(
                sourcePixels[index],
                from: sourceSize,
                to: targetSize
            ) {
                resizeContext.targetBridge.replaceLayerPixels(at: index, data: resizedPixels)
            }
            if let maskData = sourceMasks[index],
               let resizedMask = geometryService.scaledLayerMaskData(
                maskData,
                from: sourceSize,
                to: targetSize
               ) {
                resizeContext.targetBridge.replaceLayerMask(at: index, data: resizedMask)
            }
        }

        finalizeResizedBridge(
            resizeContext.targetBridge,
            textLayers: resizedTextLayers,
            activeLayerIndex: activeLayerIndex
        )
        return .success(())
    }

    func resizeCanvasExtent(width: Int, height: Int) -> DocumentMutationResult {
        guard width > 0 && height > 0 else {
            return .failure(.invalidCanvasSize(width: width, height: height))
        }
        let targetSize = PaintDocumentCanvasSize(width: width, height: height)
        let sourceSize = PaintDocumentCanvasSize(
            width: documentGateway.queries.canvasWidth,
            height: documentGateway.queries.canvasHeight
        )
        guard targetSize != sourceSize else {
            return .failure(.bridgeMutationFailed("resizeCanvasExtent"))
        }

        let layerInfos = documentGateway.queries.layerInfos()
        let folderInfos = documentGateway.queries.folderInfos()
        let activeLayerIndex = min(max(documentGateway.queries.activeLayerIndex(), 0), max(layerInfos.count - 1, 0))
        let sourcePixels = layerInfos.indices.map { pixelDataForLayer(index: $0) }
        let sourceMasks = layerInfos.indices.map { documentGateway.queries.layerMaskDataForLayer(index: $0) }
        let sourceTextLayers = storedTextLayerSnapshot()
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
            applyLayerMetadata(info, at: index, to: resizeContext.targetBridge, folderIDMap: resizeContext.folderIDMap)
            if let translatedPixels = geometryService.translatedLayerPixelData(
                sourcePixels[index],
                from: sourceSize,
                to: targetSize,
                offsetX: offsetX,
                offsetY: offsetY
            ) {
                resizeContext.targetBridge.replaceLayerPixels(at: index, data: translatedPixels)
            }
            if let maskData = sourceMasks[index],
               let translatedMask = geometryService.translatedLayerMaskData(
                maskData,
                from: sourceSize,
                to: targetSize,
                offsetX: offsetX,
                offsetY: offsetY
               ) {
                resizeContext.targetBridge.replaceLayerMask(at: index, data: translatedMask)
            }
        }

        finalizeResizedBridge(
            resizeContext.targetBridge,
            textLayers: shiftedTextLayers,
            activeLayerIndex: activeLayerIndex
        )
        return .success(())
    }

    private func makeResizedBridgeContext(
        targetSize: PaintDocumentCanvasSize,
        layerInfos: [APPaintLayerInfo],
        folderInfos: [APPaintFolderInfo]
    ) -> (targetBridge: APPaintDocumentBridge, folderIDMap: [Int: Int]) {
        let targetBridge = APPaintDocumentBridge(width: targetSize.width, height: targetSize.height)
        if layerInfos.count > 1 {
            for index in 1..<layerInfos.count {
                _ = targetBridge.addLayer(name: layerInfos[index].name)
            }
        }

        var folderIDMap: [Int: Int] = [:]
        for folder in folderInfos {
            let createdFolderID = Int(
                targetBridge.createFolder(
                    name: folder.name,
                    layerIndex: folder.anchorLayerIndex >= 0 ? Int(folder.anchorLayerIndex) : -1
                )
            )
            folderIDMap[Int(folder.folderID)] = createdFolderID
            targetBridge.setFolderVisible(folder.visible, folderID: createdFolderID)
            targetBridge.setFolderExpanded(folder.expanded, folderID: createdFolderID)
            targetBridge.setFolderName(folder.name, folderID: createdFolderID)
        }

        return (targetBridge, folderIDMap)
    }

    private func applyLayerMetadata(
        _ info: APPaintLayerInfo,
        at index: Int,
        to targetBridge: APPaintDocumentBridge,
        folderIDMap: [Int: Int]
    ) {
        targetBridge.setLayerName(info.name, at: index)
        targetBridge.setLayerVisible(info.visible, at: index)
        targetBridge.setLayerLocked(info.locked, at: index)
        targetBridge.setLayerAlphaLocked(info.alphaLocked, at: index)
        targetBridge.setLayerClipped(info.clipped, at: index)
        targetBridge.setLayerOpacity(info.opacity, at: index)
        targetBridge.setLayerBlendMode(info.blendMode, at: index)
        if info.folderID >= 0, let mappedFolderID = folderIDMap[Int(info.folderID)] {
            _ = targetBridge.setLayerFolder(at: index, folderID: mappedFolderID)
        }
    }

    private func finalizeResizedBridge(
        _ resizedBridge: APPaintDocumentBridge,
        textLayers resizedTextLayers: [Int: TextLayerData],
        activeLayerIndex: Int
    ) {
        replaceBridge(with: resizedBridge)
        replaceStoredTextLayers(with: resizedTextLayers)
        for (index, textLayer) in resizedTextLayers {
            guard let rasterized = rasterizedTextLayerPixelData(textLayer) else { continue }
            documentGateway.layers.replaceLayerPixels(index: index, data: rasterized)
        }
        documentGateway.layers.setActiveLayerIndex(activeLayerIndex)
        resetTrackedEditingState()
        resetTimelapseHistory()
        applyLifecycleMutation(editingLifecycleService.mutation(invalidating: .all))
    }
}
