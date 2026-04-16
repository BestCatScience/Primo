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
        replaceLayerPixels(index: index - 1, data: merged)
        return deleteLayer(index: index)
    }

    @discardableResult
    func applyLayerProcessing(index: Int, request: LayerProcessingRequest) -> Bool {
        guard !isLayerLocked(index: index) else { return false }
        clearTextLayerData(index: index)
        let descriptor = makeProcessingDescriptor(from: request)
        let didApply = bridge.applyLayerProcessing(at: index, descriptor: descriptor)
        if didApply {
            let pixelData = bridge.pixelDataForLayer(at: index) as Data
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .replaceLayerPixels(index: index, data: pixelData),
                    invalidating: .layer(index)
                )
            )
        }
        return didApply
    }

    func mergedLayerDownPixelData(upperIndex: Int, lowerIndex: Int) -> Data? {
        let infos = bridge.layerInfos()
        guard infos.indices.contains(upperIndex), infos.indices.contains(lowerIndex) else {
            return nil
        }
        let upperInfo = infos[upperIndex]
        let lowerInfo = infos[lowerIndex]
        let lowerPixels = bridge.pixelDataForLayer(at: lowerIndex) as Data
        let upperPixels = bridge.pixelDataForLayer(at: upperIndex) as Data
        guard lowerPixels.count == upperPixels.count else { return nil }

        let upperMask = bridge.layerMaskDataForLayer(at: upperIndex) as Data?
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

    func replaceLayerPixels(index: Int, data: Data, preservesTextLayerMetadata: Bool = false) {
        guard !isLayerLocked(index: index) else { return }
        if !preservesTextLayerMetadata {
            clearTextLayerData(index: index)
        }
        let descriptor = APPaintLayerProcessingDescriptor()
        descriptor.kind = APPaintLayerProcessingKind.replacePixels
        let adjustedData = isLayerAlphaLocked(index: index)
            ? Self.pixelDataByPreservingExistingAlpha(source: data, existing: bridge.pixelDataForLayer(at: index) as Data)
            : data
        descriptor.pixelData = adjustedData
        let didApply = bridge.applyLayerProcessing(at: index, descriptor: descriptor)
        if !didApply {
            bridge.replaceLayerPixelsTransient(at: index, data: adjustedData)
        }
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .replaceLayerPixels(index: index, data: adjustedData),
                invalidating: .layer(index)
            )
        )
    }

    @discardableResult
    func replaceLayerMask(index: Int, maskData: Data) -> Bool {
        guard maskData.count == Int(bridge.width * bridge.height) else {
            return false
        }
        bridge.replaceLayerMask(at: index, data: maskData)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .replaceLayerMask(index: index, data: maskData),
                invalidating: .layer(index)
            )
        )
        return true
    }

    @discardableResult
    func clearLayerMask(index: Int) -> Bool {
        guard bridge.layerMaskDataForLayer(at: index) != nil else {
            return false
        }
        bridge.clearLayerMask(at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .clearLayerMask(index: index),
                invalidating: .layer(index)
            )
        )
        return true
    }

    @discardableResult
    func applyLayerMask(index: Int) -> Bool {
        guard bridge.applyLayerMask(at: index) else {
            return false
        }
        let pixelData = bridge.pixelDataForLayer(at: index) as Data
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: [
                    .applyLayerMask(index: index),
                    .replaceLayerPixels(index: index, data: pixelData)
                ],
                invalidating: .layer(index)
            )
        )
        return true
    }

    func clearLayer(index: Int) {
        guard !isLayerLocked(index: index) else { return }
        clearTextLayerData(index: index)
        let descriptor = APPaintLayerProcessingDescriptor()
        descriptor.kind = APPaintLayerProcessingKind.clear
        let didApply = bridge.applyLayerProcessing(at: index, descriptor: descriptor)
        if didApply {
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .clearLayer(index: index),
                    invalidating: .layer(index)
                )
            )
        }
    }
}
