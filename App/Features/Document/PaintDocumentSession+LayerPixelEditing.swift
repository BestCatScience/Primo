import CoreGraphics
import Foundation

extension PaintDocumentSession {
    @discardableResult
    func mergeLayerDown(index: Int) -> Bool {
        guard index > 0 else { return false }
        guard !isLayerLocked(index: index), !isLayerLocked(index: index - 1) else { return false }
        guard let merged = mergedLayerDownPixelData(upperIndex: index, lowerIndex: index - 1) else {
            return false
        }
        clearTextLayerData(index: index)
        clearTextLayerData(index: index - 1)
        guard replaceLayerPixels(index: index - 1, data: merged) else {
            return false
        }
        return deleteLayer(index: index)
    }

    @discardableResult
    func applyLayerProcessing(index: Int, request: LayerProcessingRequest) -> Bool {
        guard beginPixelLayerMutation(at: index) else { return false }
        let didApply = documentGateway.processing.applyLayerProcessing(index: index, request: request)
        if didApply {
            let pixelData = pixelDataForLayer(index: index)
            applyLayerLifecycleMutation(
                at: index,
                recording: .replaceLayerPixels(index: .unchecked(index), data: pixelData)
            )
        }
        return didApply
    }

    func mergedLayerDownPixelData(upperIndex: Int, lowerIndex: Int) -> Data? {
        let infos = documentGateway.queries.layerInfos()
        guard infos.indices.contains(upperIndex), infos.indices.contains(lowerIndex) else {
            return nil
        }
        let upperInfo = infos[upperIndex]
        let lowerInfo = infos[lowerIndex]
        let lowerPixels = pixelDataForLayer(index: lowerIndex)
        let upperPixels = pixelDataForLayer(index: upperIndex)
        guard lowerPixels.count == upperPixels.count else { return nil }

        let upperMask = documentGateway.queries.layerMaskDataForLayer(index: upperIndex)
        var maskedUpper = upperPixels
        if let upperMask, upperMask.count * 4 == upperPixels.count {
            maskedUpper.withUnsafeMutableBytes { upperBytes in
                upperMask.withUnsafeBytes { maskBytes in
                    guard let upperBase = upperBytes.bindMemory(to: UInt8.self).baseAddress,
                          let maskBase = maskBytes.bindMemory(to: UInt8.self).baseAddress
                    else { return }
                    for pixelIndex in 0..<upperMask.count {
                        let alphaOffset = (pixelIndex * 4) + 3
                        let sourceAlpha = Int(upperBase[alphaOffset])
                        let maskAlpha = Int(maskBase[pixelIndex])
                        upperBase[alphaOffset] = UInt8((sourceAlpha * maskAlpha) / 255)
                    }
                }
            }
        }

        var output = lowerPixels
        output.withUnsafeMutableBytes { outputBytes in
            maskedUpper.withUnsafeBytes { upperBytes in
                guard let dst = outputBytes.bindMemory(to: UInt8.self).baseAddress,
                      let src = upperBytes.bindMemory(to: UInt8.self).baseAddress
                else { return }
                for offset in stride(from: 0, to: lowerPixels.count, by: 4) {
                    AppFeature.blendPreviewPixel(
                        destination: dst + offset,
                        source: src + offset,
                        opacity: CGFloat(upperInfo.opacity),
                        blendMode: LayerBlendMode(rawValue: upperInfo.blendMode) ?? .normal
                    )
                }
            }
        }

        return lowerInfo.alphaLocked
            ? Self.pixelDataByPreservingExistingAlpha(source: output, existing: lowerPixels)
            : output
    }

    @discardableResult
    func replaceLayerPixels(index: Int, data: Data, preservesTextLayerMetadata: Bool = false) -> Bool {
        guard beginPixelLayerMutation(
            at: index,
            preservesTextLayerMetadata: preservesTextLayerMetadata
        ) else { return false }
        let adjustedData = isLayerAlphaLocked(index: index)
            ? Self.pixelDataByPreservingExistingAlpha(source: data, existing: pixelDataForLayer(index: index))
            : data
        let didApply = documentGateway.processing.applyLayerProcessing(
            index: index,
            descriptor: documentGateway.processing.makeReplacePixelsDescriptor(pixelData: adjustedData)
        )
        if !didApply {
            documentGateway.layers.replaceLayerPixels(index: index, data: adjustedData, transient: true)
        }
        applyLayerLifecycleMutation(
            at: index,
            recording: .replaceLayerPixels(index: .unchecked(index), data: adjustedData)
        )
        return true
    }

    @discardableResult
    func replaceLayerMask(index: Int, maskData: Data) -> Bool {
        guard containsLayerIndex(index) else { return false }
        guard maskData.count == documentGateway.queries.canvasWidth * documentGateway.queries.canvasHeight else {
            return false
        }
        documentGateway.layers.replaceLayerMask(index: index, data: maskData)
        applyLayerLifecycleMutation(
            at: index,
            recording: .replaceLayerMask(index: .unchecked(index), data: maskData)
        )
        return true
    }

    @discardableResult
    func clearLayerMask(index: Int) -> Bool {
        guard containsLayerIndex(index) else { return false }
        guard documentGateway.queries.layerMaskDataForLayer(index: index) != nil else {
            return false
        }
        documentGateway.layers.clearLayerMask(index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .clearLayerMask(index: .unchecked(index))
        )
        return true
    }

    @discardableResult
    func applyLayerMask(index: Int) -> Bool {
        guard containsLayerIndex(index) else { return false }
        guard documentGateway.layers.applyLayerMask(index: index) else {
            return false
        }
        let pixelData = pixelDataForLayer(index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: [
                .applyLayerMask(index: .unchecked(index)),
                .replaceLayerPixels(index: .unchecked(index), data: pixelData)
            ]
        )
        return true
    }

    @discardableResult
    func clearLayer(index: Int) -> Bool {
        guard beginPixelLayerMutation(at: index) else { return false }
        let didApply = documentGateway.processing.applyLayerProcessing(
            index: index,
            descriptor: documentGateway.processing.makeClearLayerDescriptor()
        )
        if didApply {
            applyLayerLifecycleMutation(
                at: index,
                recording: .clearLayer(index: .unchecked(index))
            )
        }
        return didApply
    }
}
