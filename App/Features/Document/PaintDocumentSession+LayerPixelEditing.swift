import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func mergeLayerDown(index: Int) -> DocumentMutationResult {
        guard index > 0 else {
            return .failure(.invalidLayerIndex(index))
        }
        if let failure = layerMutationFailure(index, requiresUnlocked: true) {
            return .failure(failure)
        }
        if let failure = layerMutationFailure(index - 1, requiresUnlocked: true) {
            return .failure(failure)
        }
        guard let merged = mergedLayerDownPixelData(upperIndex: index, lowerIndex: index - 1) else {
            return .failure(.bridgeMutationFailed("mergeLayerDown"))
        }
        clearTextLayerData(index: index)
        clearTextLayerData(index: index - 1)
        switch replaceLayerPixels(index: index - 1, data: merged) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            break
        }
        return deleteLayer(index: index)
    }

    func applyLayerProcessing(index: Int, request: LayerProcessingRequest) -> DocumentMutationResult {
        switch beginPixelLayerMutation(at: index) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            break
        }
        switch documentGateway.processing.applyLayerProcessingResult(
            index: index,
            request: request,
            operation: "applyLayerProcessing"
        ) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            let pixelData = pixelDataForLayer(index: index)
            applyLayerLifecycleMutation(
                at: index,
                recording: .replaceLayerPixels(index: .unchecked(index), data: pixelData)
            )
            return .success(())
        }
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

    func replaceLayerPixels(index: Int, data: Data, preservesTextLayerMetadata: Bool = false) -> DocumentMutationResult {
        guard !data.isEmpty else {
            return .failure(.emptyInput)
        }
        switch beginPixelLayerMutation(
            at: index,
            preservesTextLayerMetadata: preservesTextLayerMetadata
        ) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            break
        }
        let adjustedData = isLayerAlphaLocked(index: index)
            ? Self.pixelDataByPreservingExistingAlpha(source: data, existing: pixelDataForLayer(index: index))
            : data
        switch documentGateway.processing.applyLayerProcessingResult(
            index: index,
            descriptor: documentGateway.processing.makeReplacePixelsDescriptor(pixelData: adjustedData),
            operation: "replaceLayerPixels"
        ) {
        case .success:
            break
        case .failure:
            documentGateway.layers.replaceLayerPixels(index: index, data: adjustedData, transient: true)
        }
        applyLayerLifecycleMutation(
            at: index,
            recording: .replaceLayerPixels(index: .unchecked(index), data: adjustedData)
        )
        return .success(())
    }

    func replaceLayerMask(index: Int, maskData: Data) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        guard !maskData.isEmpty else {
            return .failure(.emptyInput)
        }
        guard maskData.count == documentGateway.queries.canvasWidth * documentGateway.queries.canvasHeight else {
            return .failure(.bridgeMutationFailed("replaceLayerMask"))
        }
        documentGateway.layers.replaceLayerMask(index: index, data: maskData)
        applyLayerLifecycleMutation(
            at: index,
            recording: .replaceLayerMask(index: .unchecked(index), data: maskData)
        )
        return .success(())
    }

    func clearLayerMask(index: Int) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        guard documentGateway.queries.layerMaskDataForLayer(index: index) != nil else {
            return .failure(.bridgeMutationFailed("clearLayerMask"))
        }
        documentGateway.layers.clearLayerMask(index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .clearLayerMask(index: .unchecked(index))
        )
        return .success(())
    }

    func applyLayerMask(index: Int) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        switch documentGateway.layers.applyLayerMaskResult(index: index) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            break
        }
        let pixelData = pixelDataForLayer(index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: [
                .applyLayerMask(index: .unchecked(index)),
                .replaceLayerPixels(index: .unchecked(index), data: pixelData)
            ]
        )
        return .success(())
    }

    func clearLayer(index: Int) -> DocumentMutationResult {
        switch beginPixelLayerMutation(at: index) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            break
        }
        switch documentGateway.processing.applyLayerProcessingResult(
            index: index,
            descriptor: documentGateway.processing.makeClearLayerDescriptor(),
            operation: "clearLayer"
        ) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            applyLayerLifecycleMutation(
                at: index,
                recording: .clearLayer(index: .unchecked(index))
            )
            return .success(())
        }
    }
}
