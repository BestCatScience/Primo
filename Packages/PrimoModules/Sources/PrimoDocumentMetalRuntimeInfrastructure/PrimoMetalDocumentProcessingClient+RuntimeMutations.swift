import CoreGraphics
import Foundation
import Metal
import PrimoDocumentContracts
import PrimoDocumentDomain

private struct PrimoMetalLayerProcessingDescriptor {
    let width: UInt32
    let height: UInt32
    let requestKind: UInt32
    let gradientStopCount: UInt32
    let param0: Float
    let param1: Float
    let param2: Float
    let param3: Float
    let param4: Float
    let param5: Float
    let param6: Float
    let param7: Float
    let selectionWidth: UInt32
    let selectionHeight: UInt32
    let hasSelection: UInt32
    let padding0: UInt32
}

private struct PrimoMetalGradientStopDescriptor {
    let position: Float
    let red: Float
    let green: Float
    let blue: Float
}

private struct PrimoMetalFillDescriptor {
    let width: UInt32
    let height: UInt32
    let seedX: UInt32
    let seedY: UInt32
    let thresholdMode: UInt32
    let expansion: UInt32
    let tolerance: Float
    let seedRed: Float
    let seedGreen: Float
    let seedBlue: Float
    let seedAlpha: Float
    let targetRed: Float
    let targetGreen: Float
    let targetBlue: Float
    let targetAlpha: Float
}

private struct PrimoMetalBlurDescriptor {
    let width: UInt32
    let height: UInt32
    let radius: UInt32
    let sampleCount: UInt32
    let flow: Float
    let hardness: Float
    let influenceRadius: Float
    let padding0: Float
}

private struct PrimoMetalTextComposeDescriptor {
    let width: UInt32
    let height: UInt32
    let glyphCount: UInt32
    let padding0: UInt32
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
    let rotationRadians: Float
    let layoutCenterX: Float
    let layoutCenterY: Float
    let padding1: Float
}

private struct PrimoMetalTextGlyphDescriptor {
    let originX: Float
    let originY: Float
    let width: Float
    let height: Float
    let atlasBitsLow: UInt32
    let atlasBitsHigh: UInt32
}

private struct PrimoMetalTextLayoutResult {
    let glyphs: [PrimoMetalTextGlyphDescriptor]
    let unrotatedBounds: CGRect
    let rotatedBounds: CGRect
}

private struct PrimoMetalScaleDescriptor {
    let sourceWidth: UInt32
    let sourceHeight: UInt32
    let targetWidth: UInt32
    let targetHeight: UInt32
}

private struct PrimoMetalTranslateDescriptor {
    let sourceWidth: UInt32
    let sourceHeight: UInt32
    let targetWidth: UInt32
    let targetHeight: UInt32
    let offsetX: Int32
    let offsetY: Int32
}

private enum PrimoMetalLayerProcessingKind {
    static let gradientMap: UInt32 = 0
    static let hueSaturationBrightness: UInt32 = 1
    static let brightnessContrast: UInt32 = 2
    static let levels: UInt32 = 3
    static let toneCurve: UInt32 = 4
    static let colorBalance: UInt32 = 5
    static let threshold: UInt32 = 6
    static let posterize: UInt32 = 7
    static let luminanceToAlpha: UInt32 = 8
    static let transform: UInt32 = 9
}

extension PrimoMetalDocumentProcessingClient {
    public func autoSelection(
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        seedX: Int,
        seedY: Int,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> [UInt8]? {
        guard
            isAvailable,
            pixelData.count == canvasWidth * canvasHeight * 4,
            seedX >= 0,
            seedX < canvasWidth,
            seedY >= 0,
            seedY < canvasHeight,
            let commandQueue,
            let eligibilityPipeline = autoSelectionEligibilityPipeline,
            let propagationPipeline = fillPropagationPipeline,
            let expansionPipeline = fillExpansionPipeline
        else {
            return nil
        }

        let seedOffset = ((seedY * canvasWidth) + seedX) * 4
        let seedRed = Float(pixelData[seedOffset]) / 255.0
        let seedGreen = Float(pixelData[seedOffset + 1]) / 255.0
        let seedBlue = Float(pixelData[seedOffset + 2]) / 255.0
        let seedAlpha = Float(pixelData[seedOffset + 3]) / 255.0

        guard
            let sourceBuffer = makeBuffer(pixelData),
            let eligibleBuffer = device?.makeBuffer(length: canvasWidth * canvasHeight, options: .storageModeShared),
            let firstFillBuffer = device?.makeBuffer(length: canvasWidth * canvasHeight, options: .storageModeShared),
            let secondFillBuffer = device?.makeBuffer(length: canvasWidth * canvasHeight, options: .storageModeShared),
            let changeFlagBuffer = device?.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared),
            let eligibilityDescriptorBuffer = makeBuffer(
                PrimoMetalAutoSelectionDescriptor(
                    width: UInt32(canvasWidth),
                    height: UInt32(canvasHeight),
                    seedX: UInt32(seedX),
                    seedY: UInt32(seedY),
                    thresholdMode: thresholdMode == .opacity ? 0 : 1,
                    expansion: UInt32(max(0, expansion)),
                    tolerance: Float(
                        thresholdMode == .opacity
                            ? max(0.0, min(1.0, opacityTolerance))
                            : max(0.0, min(1.0, colorTolerance))
                    ),
                    seedRed: seedRed,
                    seedGreen: seedGreen,
                    seedBlue: seedBlue,
                    seedAlpha: seedAlpha
                )
            ),
            let propagationDescriptorBuffer = makeBuffer(
                PrimoMetalFillDescriptor(
                    width: UInt32(canvasWidth),
                    height: UInt32(canvasHeight),
                    seedX: UInt32(seedX),
                    seedY: UInt32(seedY),
                    thresholdMode: thresholdMode == .opacity ? 0 : 1,
                    expansion: UInt32(max(0, expansion)),
                    tolerance: 0,
                    seedRed: seedRed,
                    seedGreen: seedGreen,
                    seedBlue: seedBlue,
                    seedAlpha: seedAlpha,
                    targetRed: 0,
                    targetGreen: 0,
                    targetBlue: 0,
                    targetAlpha: 0
                )
            )
        else {
            return nil
        }

        memset(firstFillBuffer.contents(), 0, canvasWidth * canvasHeight)
        memset(secondFillBuffer.contents(), 0, canvasWidth * canvasHeight)
        firstFillBuffer.contents().assumingMemoryBound(to: UInt8.self)[seedY * canvasWidth + seedX] = 255

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let eligibilityEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }
        eligibilityEncoder.setComputePipelineState(eligibilityPipeline)
        eligibilityEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        eligibilityEncoder.setBuffer(eligibleBuffer, offset: 0, index: 1)
        eligibilityEncoder.setBuffer(eligibilityDescriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: eligibilityEncoder, pipeline: eligibilityPipeline, width: canvasWidth, height: canvasHeight)
        eligibilityEncoder.endEncoding()

        var currentFill = firstFillBuffer
        var nextFill = secondFillBuffer
        let maxPropagationIterations = max(1, canvasWidth + canvasHeight)
        for _ in 0..<maxPropagationIterations {
            changeFlagBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee = 0
            guard let propagationEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
            propagationEncoder.setComputePipelineState(propagationPipeline)
            propagationEncoder.setBuffer(eligibleBuffer, offset: 0, index: 0)
            propagationEncoder.setBuffer(currentFill, offset: 0, index: 1)
            propagationEncoder.setBuffer(nextFill, offset: 0, index: 2)
            propagationEncoder.setBuffer(changeFlagBuffer, offset: 0, index: 3)
            propagationEncoder.setBuffer(propagationDescriptorBuffer, offset: 0, index: 4)
            dispatch2D(encoder: propagationEncoder, pipeline: propagationPipeline, width: canvasWidth, height: canvasHeight)
            propagationEncoder.endEncoding()
            swap(&currentFill, &nextFill)
        }

        if expansion > 0 {
            for _ in 0..<expansion {
                guard let expansionEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
                expansionEncoder.setComputePipelineState(expansionPipeline)
                expansionEncoder.setBuffer(currentFill, offset: 0, index: 0)
                expansionEncoder.setBuffer(nextFill, offset: 0, index: 1)
                expansionEncoder.setBuffer(propagationDescriptorBuffer, offset: 0, index: 2)
                dispatch2D(encoder: expansionEncoder, pipeline: expansionPipeline, width: canvasWidth, height: canvasHeight)
                expansionEncoder.endEncoding()
                swap(&currentFill, &nextFill)
            }
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return byteArray(from: currentFill, count: canvasWidth * canvasHeight)
    }

    public func scaledPixelData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int
    ) -> Data? {
        guard
            isAvailable,
            source.count == sourceWidth * sourceHeight * 4,
            let commandQueue,
            let pipeline = scaleRGBAPipeline,
            let sourceBuffer = makeBuffer(source),
            let outputBuffer = device?.makeBuffer(length: targetWidth * targetHeight * 4, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalScaleDescriptor(
                    sourceWidth: UInt32(sourceWidth),
                    sourceHeight: UInt32(sourceHeight),
                    targetWidth: UInt32(targetWidth),
                    targetHeight: UInt32(targetHeight)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: targetWidth, height: targetHeight)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: targetWidth * targetHeight * 4)
    }

    public func scaledMaskData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int
    ) -> Data? {
        guard
            isAvailable,
            source.count == sourceWidth * sourceHeight,
            let commandQueue,
            let pipeline = scaleMaskPipeline,
            let sourceBuffer = makeBuffer(source),
            let outputBuffer = device?.makeBuffer(length: targetWidth * targetHeight, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalScaleDescriptor(
                    sourceWidth: UInt32(sourceWidth),
                    sourceHeight: UInt32(sourceHeight),
                    targetWidth: UInt32(targetWidth),
                    targetHeight: UInt32(targetHeight)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: targetWidth, height: targetHeight)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: targetWidth * targetHeight)
    }

    public func translatedPixelData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int,
        offsetX: Int,
        offsetY: Int
    ) -> Data? {
        guard
            isAvailable,
            source.count == sourceWidth * sourceHeight * 4,
            let commandQueue,
            let pipeline = translateRGBAPipeline,
            let sourceBuffer = makeBuffer(source),
            let outputBuffer = device?.makeBuffer(length: targetWidth * targetHeight * 4, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalTranslateDescriptor(
                    sourceWidth: UInt32(sourceWidth),
                    sourceHeight: UInt32(sourceHeight),
                    targetWidth: UInt32(targetWidth),
                    targetHeight: UInt32(targetHeight),
                    offsetX: Int32(offsetX),
                    offsetY: Int32(offsetY)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: targetWidth, height: targetHeight)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: targetWidth * targetHeight * 4)
    }

    public func translatedMaskData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int,
        offsetX: Int,
        offsetY: Int
    ) -> Data? {
        guard
            isAvailable,
            source.count == sourceWidth * sourceHeight,
            let commandQueue,
            let pipeline = translateMaskPipeline,
            let sourceBuffer = makeBuffer(source),
            let outputBuffer = device?.makeBuffer(length: targetWidth * targetHeight, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalTranslateDescriptor(
                    sourceWidth: UInt32(sourceWidth),
                    sourceHeight: UInt32(sourceHeight),
                    targetWidth: UInt32(targetWidth),
                    targetHeight: UInt32(targetHeight),
                    offsetX: Int32(offsetX),
                    offsetY: Int32(offsetY)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: targetWidth, height: targetHeight)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: targetWidth * targetHeight)
    }

    public func compositeDocumentSurface(snapshot: MetalDocumentSnapshot) -> DocumentCompositeSurface? {
        guard isAvailable else { return nil }
        guard let pixelData = compositeDocument(snapshot: snapshot) else { return nil }
        return DocumentCompositeSurface(width: snapshot.width, height: snapshot.height, pixelData: pixelData)
    }

    public func processLayer(
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        request: LayerProcessingRequest
    ) -> DocumentLayerMutationPayload? {
        guard
            isAvailable,
            canvasWidth > 0,
            canvasHeight > 0,
            pixelData.count == canvasWidth * canvasHeight * 4,
            let commandQueue
        else {
            return nil
        }

        switch request {
        case let .transform(translation, scale, rotationDegrees, selection):
            return processLayerTransform(
                pixelData: pixelData,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                translation: translation,
                scale: scale,
                rotationDegrees: rotationDegrees,
                selection: selection,
                commandQueue: commandQueue
            )

        default:
            guard
                let pipeline = layerProcessingPipeline,
                let sourceBuffer = makeBuffer(pixelData),
                let outputBuffer = device?.makeBuffer(length: pixelData.count, options: .storageModeShared)
            else {
                return nil
            }

            let descriptor = makeLayerProcessingDescriptor(
                request: request,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight
            )
            guard let descriptorBuffer = makeBuffer(descriptor) else { return nil }
            let gradientStops = makeGradientStops(for: request)
            let gradientBuffer = makeBuffer(gradientStops)
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeComputeCommandEncoder()
            else {
                return nil
            }

            encoder.setComputePipelineState(pipeline)
            encoder.setBuffer(sourceBuffer, offset: 0, index: 0)
            encoder.setBuffer(outputBuffer, offset: 0, index: 1)
            encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
            encoder.setBuffer(gradientBuffer, offset: 0, index: 3)
            dispatch2D(encoder: encoder, pipeline: pipeline, width: canvasWidth, height: canvasHeight)
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            guard commandBuffer.status == .completed else { return nil }

            let fullPixelData = bytes(from: outputBuffer, count: pixelData.count)
            let dirtyRect = LayerPixelRect(originX: 0, originY: 0, width: canvasWidth, height: canvasHeight)
            return DocumentLayerMutationPayload(
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                dirtyRect: dirtyRect,
                gpuBufferHandle: makeBufferHandle(width: canvasWidth, height: canvasHeight, bytesPerRow: canvasWidth * 4, buffer: outputBuffer),
                rectPixelData: fullPixelData,
                fullPixelData: fullPixelData
            )
        }
    }

    public func rasterizeTextLayer(
        _ textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> DocumentLayerMutationPayload? {
        let width = max(Int(canvasSize.width.rounded()), 1)
        let height = max(Int(canvasSize.height.rounded()), 1)
        guard
            isAvailable,
            let commandQueue,
            let pipeline = textMaskComposePipeline,
            let layout = layoutTextLayer(textLayer, canvasSize: canvasSize),
            let glyphBuffer = makeBuffer(layout.glyphs),
            let outputBuffer = device?.makeBuffer(length: width * height * 4, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalTextComposeDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    glyphCount: UInt32(layout.glyphs.count),
                    padding0: 0,
                    red: Float(textLayer.red),
                    green: Float(textLayer.green),
                    blue: Float(textLayer.blue),
                    alpha: Float(textLayer.alpha),
                    rotationRadians: Float(textLayer.rotationDegrees * .pi / 180.0),
                    layoutCenterX: Float(layout.unrotatedBounds.midX),
                    layoutCenterY: Float(layout.unrotatedBounds.midY),
                    padding1: 0
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(glyphBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let fullPixelData = bytes(from: outputBuffer, count: width * height * 4)
        let dirtyRect = clippedTextDirtyRect(
            bounds: layout.rotatedBounds,
            canvasWidth: width,
            canvasHeight: height
        ) ?? LayerPixelRect(originX: 0, originY: 0, width: width, height: height)
        let rectPixelData = dirtyRect.width == width && dirtyRect.height == height
            ? fullPixelData
            : crop(pixelData: fullPixelData, canvasWidth: width, rect: dirtyRect)
        return DocumentLayerMutationPayload(
            canvasWidth: width,
            canvasHeight: height,
            dirtyRect: dirtyRect,
            gpuBufferHandle: makeBufferHandle(width: width, height: height, bytesPerRow: width * 4, buffer: outputBuffer),
            rectPixelData: rectPixelData,
            fullPixelData: fullPixelData
        )
    }

    public func textLayoutRect(
        for textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> CGRect? {
        layoutTextLayer(textLayer, canvasSize: canvasSize)?.rotatedBounds.integral
    }

    public func blurPixels(
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> DocumentLayerMutationPayload? {
        guard
            isAvailable,
            !samples.isEmpty,
            pixelData.count == canvasWidth * canvasHeight * 4,
            let commandQueue,
            let horizontalPipeline = blurHorizontalPipeline,
            let verticalPipeline = blurVerticalPipeline,
            let blendPipeline = blurBlendPipeline,
            let sourceBuffer = makeBuffer(pixelData),
            let tempBuffer = device?.makeBuffer(
                length: canvasWidth * canvasHeight * MemoryLayout<SIMD4<Float>>.stride,
                options: .storageModeShared
            ),
            let blurredBuffer = device?.makeBuffer(length: pixelData.count, options: .storageModeShared),
            let outputBuffer = device?.makeBuffer(length: pixelData.count, options: .storageModeShared),
            let sampleBuffer = makeBuffer(Self.strokeSampleDescriptors(samples: samples)),
            let descriptorBuffer = makeBuffer(
                PrimoMetalBlurDescriptor(
                    width: UInt32(canvasWidth),
                    height: UInt32(canvasHeight),
                    radius: UInt32(max(1, Int((max(brush.radius * 0.75, 3.0) * 0.9).rounded()))),
                    sampleCount: UInt32(samples.count),
                    flow: Float(max(0.0, min(brush.flow, 1.0))),
                    hardness: Float(max(0.0, min(brush.hardness, 1.0))),
                    influenceRadius: Float(max(4.0, brush.radius * 1.35)),
                    padding0: 0
                )
            )
        else {
            return nil
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let horizontalEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        horizontalEncoder.setComputePipelineState(horizontalPipeline)
        horizontalEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        horizontalEncoder.setBuffer(tempBuffer, offset: 0, index: 1)
        horizontalEncoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: horizontalEncoder, pipeline: horizontalPipeline, width: canvasWidth, height: canvasHeight)
        horizontalEncoder.endEncoding()

        guard let verticalEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        verticalEncoder.setComputePipelineState(verticalPipeline)
        verticalEncoder.setBuffer(tempBuffer, offset: 0, index: 0)
        verticalEncoder.setBuffer(blurredBuffer, offset: 0, index: 1)
        verticalEncoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: verticalEncoder, pipeline: verticalPipeline, width: canvasWidth, height: canvasHeight)
        verticalEncoder.endEncoding()

        guard let blendEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        blendEncoder.setComputePipelineState(blendPipeline)
        blendEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        blendEncoder.setBuffer(blurredBuffer, offset: 0, index: 1)
        blendEncoder.setBuffer(sampleBuffer, offset: 0, index: 2)
        blendEncoder.setBuffer(outputBuffer, offset: 0, index: 3)
        blendEncoder.setBuffer(descriptorBuffer, offset: 0, index: 4)
        dispatch2D(encoder: blendEncoder, pipeline: blendPipeline, width: canvasWidth, height: canvasHeight)
        blendEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let fullPixelData = bytes(from: outputBuffer, count: pixelData.count)
        let dirtyRect = blurDirtyRect(samples: samples, brush: brush, width: canvasWidth, height: canvasHeight)
        let rectPixelData = crop(pixelData: fullPixelData, canvasWidth: canvasWidth, rect: dirtyRect)
        return DocumentLayerMutationPayload(
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            dirtyRect: dirtyRect,
            gpuBufferHandle: makeBufferHandle(width: canvasWidth, height: canvasHeight, bytesPerRow: canvasWidth * 4, buffer: outputBuffer),
            rectPixelData: rectPixelData,
            fullPixelData: fullPixelData
        )
    }

    public func fillPixels(
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        sample: StylusSample,
        brush: BrushRuntimeSettings
    ) -> DocumentLayerMutationPayload? {
        guard
            isAvailable,
            pixelData.count == canvasWidth * canvasHeight * 4,
            let commandQueue,
            let eligibilityPipeline = fillEligibilityPipeline,
            let propagationPipeline = fillPropagationPipeline,
            let expansionPipeline = fillExpansionPipeline,
            let composePipeline = fillComposePipeline
        else {
            return nil
        }

        let x = Int(sample.point.x.rounded())
        let y = Int(sample.point.y.rounded())
        let fullRect = LayerPixelRect(originX: 0, originY: 0, width: canvasWidth, height: canvasHeight)
        guard x >= 0, x < canvasWidth, y >= 0, y < canvasHeight else {
            return DocumentLayerMutationPayload(
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                dirtyRect: fullRect,
                rectPixelData: pixelData,
                fullPixelData: pixelData
            )
        }

        let offset = ((y * canvasWidth) + x) * 4
        let seedRed = Float(pixelData[offset]) / 255.0
        let seedGreen = Float(pixelData[offset + 1]) / 255.0
        let seedBlue = Float(pixelData[offset + 2]) / 255.0
        let seedAlpha = Float(pixelData[offset + 3]) / 255.0
        let targetAlpha = Float(max(0.0, min(1.0, brush.opacity)))
        if pixelData[offset] == brush.red,
           pixelData[offset + 1] == brush.green,
           pixelData[offset + 2] == brush.blue,
           abs(seedAlpha - targetAlpha) < 0.0001 {
            return DocumentLayerMutationPayload(
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                dirtyRect: fullRect,
                rectPixelData: pixelData,
                fullPixelData: pixelData
            )
        }

        guard
            let sourceBuffer = makeBuffer(pixelData),
            let eligibleBuffer = device?.makeBuffer(length: canvasWidth * canvasHeight, options: .storageModeShared),
            let firstFillBuffer = device?.makeBuffer(length: canvasWidth * canvasHeight, options: .storageModeShared),
            let secondFillBuffer = device?.makeBuffer(length: canvasWidth * canvasHeight, options: .storageModeShared),
            let outputBuffer = device?.makeBuffer(length: pixelData.count, options: .storageModeShared),
            let changeFlagBuffer = device?.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared)
        else {
            return nil
        }

        let descriptor = PrimoMetalFillDescriptor(
            width: UInt32(canvasWidth),
            height: UInt32(canvasHeight),
            seedX: UInt32(x),
            seedY: UInt32(y),
            thresholdMode: brush.fillThresholdMode == .opacity ? 0 : 1,
            expansion: UInt32(max(0, brush.fillExpansion)),
            tolerance: Float(
                brush.fillThresholdMode == .opacity
                    ? max(0.0, min(1.0, brush.fillOpacityTolerance))
                    : max(0.0, min(1.0, brush.fillColorTolerance))
            ),
            seedRed: seedRed,
            seedGreen: seedGreen,
            seedBlue: seedBlue,
            seedAlpha: seedAlpha,
            targetRed: Float(brush.red) / 255.0,
            targetGreen: Float(brush.green) / 255.0,
            targetBlue: Float(brush.blue) / 255.0,
            targetAlpha: targetAlpha
        )
        guard let descriptorBuffer = makeBuffer(descriptor) else { return nil }

        memset(firstFillBuffer.contents(), 0, canvasWidth * canvasHeight)
        memset(secondFillBuffer.contents(), 0, canvasWidth * canvasHeight)
        firstFillBuffer.contents().assumingMemoryBound(to: UInt8.self)[y * canvasWidth + x] = 255

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let eligibilityEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }
        eligibilityEncoder.setComputePipelineState(eligibilityPipeline)
        eligibilityEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        eligibilityEncoder.setBuffer(eligibleBuffer, offset: 0, index: 1)
        eligibilityEncoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: eligibilityEncoder, pipeline: eligibilityPipeline, width: canvasWidth, height: canvasHeight)
        eligibilityEncoder.endEncoding()

        var currentFill = firstFillBuffer
        var nextFill = secondFillBuffer
        let maxPropagationIterations = max(1, canvasWidth + canvasHeight)
        for _ in 0..<maxPropagationIterations {
            changeFlagBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee = 0
            guard let propagationEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
            propagationEncoder.setComputePipelineState(propagationPipeline)
            propagationEncoder.setBuffer(eligibleBuffer, offset: 0, index: 0)
            propagationEncoder.setBuffer(currentFill, offset: 0, index: 1)
            propagationEncoder.setBuffer(nextFill, offset: 0, index: 2)
            propagationEncoder.setBuffer(changeFlagBuffer, offset: 0, index: 3)
            propagationEncoder.setBuffer(descriptorBuffer, offset: 0, index: 4)
            dispatch2D(encoder: propagationEncoder, pipeline: propagationPipeline, width: canvasWidth, height: canvasHeight)
            propagationEncoder.endEncoding()
            swap(&currentFill, &nextFill)
        }

        if brush.fillExpansion > 0 {
            for _ in 0..<brush.fillExpansion {
                guard let expansionEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
                expansionEncoder.setComputePipelineState(expansionPipeline)
                expansionEncoder.setBuffer(currentFill, offset: 0, index: 0)
                expansionEncoder.setBuffer(nextFill, offset: 0, index: 1)
                expansionEncoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
                dispatch2D(encoder: expansionEncoder, pipeline: expansionPipeline, width: canvasWidth, height: canvasHeight)
                expansionEncoder.endEncoding()
                swap(&currentFill, &nextFill)
            }
        }

        guard let composeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        composeEncoder.setComputePipelineState(composePipeline)
        composeEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        composeEncoder.setBuffer(currentFill, offset: 0, index: 1)
        composeEncoder.setBuffer(outputBuffer, offset: 0, index: 2)
        composeEncoder.setBuffer(descriptorBuffer, offset: 0, index: 3)
        dispatch2D(encoder: composeEncoder, pipeline: composePipeline, width: canvasWidth, height: canvasHeight)
        composeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let fullPixelData = bytes(from: outputBuffer, count: pixelData.count)
        return DocumentLayerMutationPayload(
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            dirtyRect: fullRect,
            gpuBufferHandle: makeBufferHandle(width: canvasWidth, height: canvasHeight, bytesPerRow: canvasWidth * 4, buffer: outputBuffer),
            rectPixelData: fullPixelData,
            fullPixelData: fullPixelData
        )
    }

    public func applyInpaintCrop(
        editedCropPixelData: Data,
        to baseLayerPixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        cropWidth: Int,
        cropHeight: Int,
        originX: Int,
        originY: Int,
        selectionMask: [UInt8],
        featherRadius: Int
    ) -> Data? {
        guard
            isAvailable,
            canvasWidth > 0,
            canvasHeight > 0,
            cropWidth > 0,
            cropHeight > 0,
            baseLayerPixelData.count == canvasWidth * canvasHeight * 4,
            editedCropPixelData.count == cropWidth * cropHeight * 4,
            selectionMask.count == cropWidth * cropHeight,
            let commandQueue,
            let composePipeline = inpaintCompositePipeline,
            let baseBuffer = makeBuffer(baseLayerPixelData),
            let editedBuffer = makeBuffer(editedCropPixelData),
            let outputBuffer = device?.makeBuffer(length: baseLayerPixelData.count, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalInpaintCompositeDescriptor(
                    canvasWidth: UInt32(canvasWidth),
                    canvasHeight: UInt32(canvasHeight),
                    cropWidth: UInt32(cropWidth),
                    cropHeight: UInt32(cropHeight),
                    originX: Int32(originX),
                    originY: Int32(originY)
                )
            )
        else {
            return nil
        }

        let maskBuffer: MTLBuffer
        if featherRadius > 0 {
            guard
                let horizontalPipeline = featherHorizontalPipeline,
                let verticalPipeline = featherVerticalPipeline,
                let sourceMaskBuffer = makeBuffer(selectionMask),
                let temporary = device?.makeBuffer(length: selectionMask.count * MemoryLayout<Float>.stride, options: .storageModeShared),
                let outputMaskBuffer = device?.makeBuffer(length: selectionMask.count, options: .storageModeShared),
                let maskDescriptorBuffer = makeBuffer(
                    PrimoMetalMaskKernelDescriptor(
                        width: UInt32(cropWidth),
                        height: UInt32(cropHeight),
                        radius: UInt32(featherRadius)
                    )
                ),
                let featherCommandBuffer = commandQueue.makeCommandBuffer(),
                let horizontalEncoder = featherCommandBuffer.makeComputeCommandEncoder()
            else {
                return nil
            }

            horizontalEncoder.setComputePipelineState(horizontalPipeline)
            horizontalEncoder.setBuffer(sourceMaskBuffer, offset: 0, index: 0)
            horizontalEncoder.setBuffer(temporary, offset: 0, index: 1)
            horizontalEncoder.setBuffer(maskDescriptorBuffer, offset: 0, index: 2)
            dispatch2D(encoder: horizontalEncoder, pipeline: horizontalPipeline, width: cropWidth, height: cropHeight)
            horizontalEncoder.endEncoding()

            guard let verticalEncoder = featherCommandBuffer.makeComputeCommandEncoder() else { return nil }
            verticalEncoder.setComputePipelineState(verticalPipeline)
            verticalEncoder.setBuffer(temporary, offset: 0, index: 0)
            verticalEncoder.setBuffer(outputMaskBuffer, offset: 0, index: 1)
            verticalEncoder.setBuffer(maskDescriptorBuffer, offset: 0, index: 2)
            dispatch2D(encoder: verticalEncoder, pipeline: verticalPipeline, width: cropWidth, height: cropHeight)
            verticalEncoder.endEncoding()

            featherCommandBuffer.commit()
            featherCommandBuffer.waitUntilCompleted()
            guard featherCommandBuffer.status == .completed else { return nil }
            maskBuffer = outputMaskBuffer
        } else {
            guard let sourceMaskBuffer = makeBuffer(selectionMask) else { return nil }
            maskBuffer = sourceMaskBuffer
        }

        guard let composeCommandBuffer = commandQueue.makeCommandBuffer(),
              let composeEncoder = composeCommandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }
        composeEncoder.setComputePipelineState(composePipeline)
        composeEncoder.setBuffer(baseBuffer, offset: 0, index: 0)
        composeEncoder.setBuffer(editedBuffer, offset: 0, index: 1)
        composeEncoder.setBuffer(maskBuffer, offset: 0, index: 2)
        composeEncoder.setBuffer(outputBuffer, offset: 0, index: 3)
        composeEncoder.setBuffer(descriptorBuffer, offset: 0, index: 4)
        dispatch2D(encoder: composeEncoder, pipeline: composePipeline, width: canvasWidth, height: canvasHeight)
        composeEncoder.endEncoding()
        composeCommandBuffer.commit()
        composeCommandBuffer.waitUntilCompleted()
        guard composeCommandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: baseLayerPixelData.count)
    }

    public func inpaintCropPayload(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selectionBounds: CGRect,
        expandedMask: [UInt8],
        padding: Int = 64
    ) -> PrimoMetalInpaintCropPayload? {
        guard
            isAvailable,
            canvasWidth > 0,
            canvasHeight > 0,
            source.count == canvasWidth * canvasHeight * 4,
            expandedMask.count == canvasWidth * canvasHeight
        else {
            return nil
        }

        let minX = max(Int(selectionBounds.minX.rounded(.down)) - padding, 0)
        let minY = max(Int(selectionBounds.minY.rounded(.down)) - padding, 0)
        let maxX = min(Int(selectionBounds.maxX.rounded(.up)) + padding, canvasWidth)
        let maxY = min(Int(selectionBounds.maxY.rounded(.up)) + padding, canvasHeight)
        let cropWidth = maxX - minX
        let cropHeight = maxY - minY
        guard
            cropWidth > 0,
            cropHeight > 0,
            let commandQueue,
            let rgbaPipeline = inpaintCropRGBAPipeline,
            let maskPipeline = inpaintCropMaskPipeline,
            let sourceBuffer = makeBuffer(source),
            let maskSourceBuffer = makeBuffer(expandedMask),
            let cropPixelBuffer = device?.makeBuffer(length: cropWidth * cropHeight * 4, options: .storageModeShared),
            let cropMaskBuffer = device?.makeBuffer(length: cropWidth * cropHeight, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalInpaintCropDescriptor(
                    canvasWidth: UInt32(canvasWidth),
                    canvasHeight: UInt32(canvasHeight),
                    cropWidth: UInt32(cropWidth),
                    cropHeight: UInt32(cropHeight),
                    originX: Int32(minX),
                    originY: Int32(minY)
                )
            )
        else {
            return nil
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let rgbaEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        rgbaEncoder.setComputePipelineState(rgbaPipeline)
        rgbaEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        rgbaEncoder.setBuffer(cropPixelBuffer, offset: 0, index: 1)
        rgbaEncoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: rgbaEncoder, pipeline: rgbaPipeline, width: cropWidth, height: cropHeight)
        rgbaEncoder.endEncoding()

        guard let maskEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        maskEncoder.setComputePipelineState(maskPipeline)
        maskEncoder.setBuffer(maskSourceBuffer, offset: 0, index: 0)
        maskEncoder.setBuffer(cropMaskBuffer, offset: 0, index: 1)
        maskEncoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: maskEncoder, pipeline: maskPipeline, width: cropWidth, height: cropHeight)
        maskEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let cropPixelData = bytes(from: cropPixelBuffer, count: cropWidth * cropHeight * 4)
        let selectionMask = bytes(from: cropMaskBuffer, count: cropWidth * cropHeight)

        return PrimoMetalInpaintCropPayload(
            pixelData: cropPixelData,
            width: cropWidth,
            height: cropHeight,
            originX: minX,
            originY: minY,
            selectionMask: [UInt8](selectionMask)
        )
    }

    private func processLayerTransform(
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        translation: CGSize,
        scale: CGFloat,
        rotationDegrees: Double,
        selection: CanvasSelection?,
        commandQueue: MTLCommandQueue
    ) -> DocumentLayerMutationPayload? {
        guard
            let pipeline = layerTransformPipeline,
            let sourceBuffer = makeBuffer(pixelData),
            let outputBuffer = device?.makeBuffer(length: pixelData.count, options: .storageModeShared),
            let selectionBuffer = makeBuffer(selection?.maskData ?? Data(count: canvasWidth * canvasHeight))
        else {
            return nil
        }

        let pivot = selection.map { CGPoint(x: $0.bounds.midX, y: $0.bounds.midY) }
            ?? CGPoint(x: CGFloat(canvasWidth) * 0.5, y: CGFloat(canvasHeight) * 0.5)
        let descriptor = PrimoMetalLayerProcessingDescriptor(
            width: UInt32(canvasWidth),
            height: UInt32(canvasHeight),
            requestKind: PrimoMetalLayerProcessingKind.transform,
            gradientStopCount: 0,
            param0: Float(translation.width),
            param1: Float(translation.height),
            param2: Float(scale),
            param3: Float(pivot.x),
            param4: Float(pivot.y),
            param5: Float(rotationDegrees * .pi / 180.0),
            param6: 0,
            param7: 0,
            selectionWidth: UInt32(selection?.maskWidth ?? canvasWidth),
            selectionHeight: UInt32(selection?.maskHeight ?? canvasHeight),
            hasSelection: selection == nil ? 0 : 1,
            padding0: 0
        )
        guard let descriptorBuffer = makeBuffer(descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        encoder.setBuffer(selectionBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 3)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: canvasWidth, height: canvasHeight)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let fullPixelData = bytes(from: outputBuffer, count: pixelData.count)
        let dirtyRect = LayerPixelRect(originX: 0, originY: 0, width: canvasWidth, height: canvasHeight)
        return DocumentLayerMutationPayload(
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            dirtyRect: dirtyRect,
            rectPixelData: fullPixelData,
            fullPixelData: fullPixelData
        )
    }

    private func makeLayerProcessingDescriptor(
        request: LayerProcessingRequest,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> PrimoMetalLayerProcessingDescriptor {
        switch request {
        case .gradientMap, .gradientMapSettings:
            return PrimoMetalLayerProcessingDescriptor(
                width: UInt32(canvasWidth), height: UInt32(canvasHeight),
                requestKind: PrimoMetalLayerProcessingKind.gradientMap,
                gradientStopCount: UInt32(makeGradientStops(for: request).count),
                param0: 0, param1: 0, param2: 0, param3: 0, param4: 0, param5: 0, param6: 0, param7: 0,
                selectionWidth: 0, selectionHeight: 0, hasSelection: 0, padding0: 0
            )
        case let .hueSaturationBrightness(settings):
            return PrimoMetalLayerProcessingDescriptor(
                width: UInt32(canvasWidth), height: UInt32(canvasHeight),
                requestKind: PrimoMetalLayerProcessingKind.hueSaturationBrightness,
                gradientStopCount: 0,
                param0: Float(settings.hueDegrees / 360.0),
                param1: Float(max(0, settings.saturation)),
                param2: Float(settings.brightness),
                param3: 0, param4: 0, param5: 0, param6: 0, param7: 0,
                selectionWidth: 0, selectionHeight: 0, hasSelection: 0, padding0: 0
            )
        case let .brightnessContrast(settings):
            return PrimoMetalLayerProcessingDescriptor(
                width: UInt32(canvasWidth), height: UInt32(canvasHeight),
                requestKind: PrimoMetalLayerProcessingKind.brightnessContrast,
                gradientStopCount: 0,
                param0: Float(settings.brightness),
                param1: Float(max(0, settings.contrast)),
                param2: 0, param3: 0, param4: 0, param5: 0, param6: 0, param7: 0,
                selectionWidth: 0, selectionHeight: 0, hasSelection: 0, padding0: 0
            )
        case let .levels(settings):
            return PrimoMetalLayerProcessingDescriptor(
                width: UInt32(canvasWidth), height: UInt32(canvasHeight),
                requestKind: PrimoMetalLayerProcessingKind.levels,
                gradientStopCount: 0,
                param0: Float(min(max(settings.inputBlack, 0), 1)),
                param1: Float(max(min(settings.inputWhite, 1), settings.inputBlack + 0.001)),
                param2: Float(max(settings.gamma, 0.01)),
                param3: Float(min(max(settings.outputBlack, 0), 1)),
                param4: Float(max(min(settings.outputWhite, 1), settings.outputBlack)),
                param5: 0, param6: 0, param7: 0,
                selectionWidth: 0, selectionHeight: 0, hasSelection: 0, padding0: 0
            )
        case let .toneCurve(settings):
            return PrimoMetalLayerProcessingDescriptor(
                width: UInt32(canvasWidth), height: UInt32(canvasHeight),
                requestKind: PrimoMetalLayerProcessingKind.toneCurve,
                gradientStopCount: 0,
                param0: Float(settings.shadows),
                param1: Float(settings.midtones),
                param2: Float(settings.highlights),
                param3: 0, param4: 0, param5: 0, param6: 0, param7: 0,
                selectionWidth: 0, selectionHeight: 0, hasSelection: 0, padding0: 0
            )
        case let .colorBalance(settings):
            return PrimoMetalLayerProcessingDescriptor(
                width: UInt32(canvasWidth), height: UInt32(canvasHeight),
                requestKind: PrimoMetalLayerProcessingKind.colorBalance,
                gradientStopCount: 0,
                param0: Float(settings.redCyan * 0.4),
                param1: Float(settings.greenMagenta * 0.4),
                param2: Float(settings.blueYellow * 0.4),
                param3: 0, param4: 0, param5: 0, param6: 0, param7: 0,
                selectionWidth: 0, selectionHeight: 0, hasSelection: 0, padding0: 0
            )
        case let .threshold(settings):
            return PrimoMetalLayerProcessingDescriptor(
                width: UInt32(canvasWidth), height: UInt32(canvasHeight),
                requestKind: PrimoMetalLayerProcessingKind.threshold,
                gradientStopCount: 0,
                param0: Float(min(max(settings.threshold, 0), 1)),
                param1: 0, param2: 0, param3: 0, param4: 0, param5: 0, param6: 0, param7: 0,
                selectionWidth: 0, selectionHeight: 0, hasSelection: 0, padding0: 0
            )
        case let .posterize(settings):
            return PrimoMetalLayerProcessingDescriptor(
                width: UInt32(canvasWidth), height: UInt32(canvasHeight),
                requestKind: PrimoMetalLayerProcessingKind.posterize,
                gradientStopCount: 0,
                param0: Float(settings.levels),
                param1: 0, param2: 0, param3: 0, param4: 0, param5: 0, param6: 0, param7: 0,
                selectionWidth: 0, selectionHeight: 0, hasSelection: 0, padding0: 0
            )
        case .luminanceToAlpha:
            return PrimoMetalLayerProcessingDescriptor(
                width: UInt32(canvasWidth), height: UInt32(canvasHeight),
                requestKind: PrimoMetalLayerProcessingKind.luminanceToAlpha,
                gradientStopCount: 0,
                param0: 0, param1: 0, param2: 0, param3: 0, param4: 0, param5: 0, param6: 0, param7: 0,
                selectionWidth: 0, selectionHeight: 0, hasSelection: 0, padding0: 0
            )
        case .transform:
            return PrimoMetalLayerProcessingDescriptor(
                width: UInt32(canvasWidth), height: UInt32(canvasHeight),
                requestKind: PrimoMetalLayerProcessingKind.transform,
                gradientStopCount: 0,
                param0: 0, param1: 0, param2: 1, param3: Float(canvasWidth) * 0.5, param4: Float(canvasHeight) * 0.5,
                param5: 0, param6: 0, param7: 0, selectionWidth: 0, selectionHeight: 0, hasSelection: 0, padding0: 0
            )
        }
    }

    private func makeGradientStops(for request: LayerProcessingRequest) -> [PrimoMetalGradientStopDescriptor] {
        let stops: [(Double, UInt8, UInt8, UInt8)]
        switch request {
        case let .gradientMap(preset):
            switch preset {
            case .graphite:
                stops = [(0.0, 17, 21, 27), (0.38, 84, 93, 108), (1.0, 243, 244, 246)]
            case .sepia:
                stops = [(0.0, 28, 17, 12), (0.42, 123, 74, 40), (1.0, 241, 220, 184)]
            case .ocean:
                stops = [(0.0, 8, 19, 44), (0.45, 27, 110, 171), (1.0, 192, 241, 255)]
            case .sunset:
                stops = [(0.0, 36, 11, 54), (0.4, 173, 58, 91), (0.72, 244, 142, 68), (1.0, 255, 223, 128)]
            case .toxic:
                stops = [(0.0, 4, 23, 18), (0.44, 35, 172, 106), (1.0, 227, 255, 111)]
            }
        case let .gradientMapSettings(settings):
            var normalized = settings.stops.sorted { $0.position < $1.position }
            if normalized.count < 2 {
                normalized = [
                    GradientMapStopSettings(position: 0.0, red: 0, green: 0, blue: 0),
                    GradientMapStopSettings(position: 1.0, red: 255, green: 255, blue: 255)
                ]
            }
            for index in normalized.indices {
                normalized[index].position = min(max(normalized[index].position, 0.0), 1.0)
            }
            normalized[0].position = 0.0
            normalized[normalized.count - 1].position = 1.0
            if normalized.count > 2 {
                for index in 1..<(normalized.count - 1) {
                    let lowerBound = normalized[index - 1].position + 0.01
                    let upperBound = normalized[index + 1].position - 0.01
                    normalized[index].position = min(max(normalized[index].position, lowerBound), upperBound)
                }
            }
            stops = normalized.map { stop in
                (stop.position, stop.red, stop.green, stop.blue)
            }
        default:
            stops = []
        }
        return stops.map {
            PrimoMetalGradientStopDescriptor(
                position: Float($0.0),
                red: Float($0.1) / 255.0,
                green: Float($0.2) / 255.0,
                blue: Float($0.3) / 255.0
            )
        }
    }

    private func blurDirtyRect(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        width: Int,
        height: Int
    ) -> LayerPixelRect {
        let influenceRadius = max(4.0, brush.radius * 1.35)
        let sampleXs = samples.map(\.point.x)
        let sampleYs = samples.map(\.point.y)
        let minX = max(0, Int((sampleXs.min() ?? 0) - influenceRadius - 2.0))
        let maxX = min(width - 1, Int((sampleXs.max() ?? 0) + influenceRadius + 2.0))
        let minY = max(0, Int((sampleYs.min() ?? 0) - influenceRadius - 2.0))
        let maxY = min(height - 1, Int((sampleYs.max() ?? 0) + influenceRadius + 2.0))
        guard minX <= maxX, minY <= maxY else {
            return LayerPixelRect(originX: 0, originY: 0, width: width, height: height)
        }
        return LayerPixelRect(originX: minX, originY: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private func crop(pixelData: Data, canvasWidth: Int, rect: LayerPixelRect) -> Data {
        guard rect.width > 0, rect.height > 0 else { return Data() }
        var output = Data(count: rect.width * rect.height * 4)
        output.withUnsafeMutableBytes { destinationBytes in
            pixelData.withUnsafeBytes { sourceBytes in
                guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }
                for row in 0..<rect.height {
                    let srcOffset = ((rect.originY + row) * canvasWidth + rect.originX) * 4
                    let dstOffset = row * rect.width * 4
                    memcpy(destination + dstOffset, source + srcOffset, rect.width * 4)
                }
            }
        }
        return output
    }

    private func layoutTextLayer(
        _ textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> PrimoMetalTextLayoutResult? {
        let normalizedText = textLayer.text.replacingOccurrences(of: "\r\n", with: "\n")
        guard !normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let effectiveScale = CGFloat(min(max(textLayer.scale, 0.2), 6.0))
        let effectiveFontSize = max(CGFloat(textLayer.fontSize) * effectiveScale, 6.0)
        let pixelScale = max(effectiveFontSize / 7.0, 1.0)
        let glyphWidth = pixelScale * 5.0
        let glyphHeight = pixelScale * 7.0
        let advanceX = pixelScale * 6.0
        let lineHeight = pixelScale * 8.0
        let origin = CGPoint(x: textLayer.positionX, y: textLayer.positionY)
        let maxLineWidth = max(canvasSize.width - origin.x - 12.0, glyphWidth)

        var cursorX = origin.x
        var cursorY = origin.y
        var maxX = origin.x
        var maxY = origin.y
        var glyphs: [PrimoMetalTextGlyphDescriptor] = []

        for paragraph in normalizedText.split(separator: "\n", omittingEmptySubsequences: false) {
            let tokens = tokenizeTextParagraph(String(paragraph))
            if tokens.isEmpty {
                cursorX = origin.x
                cursorY += lineHeight
                maxY = max(maxY, cursorY)
                continue
            }

            for token in tokens {
                switch token {
                case .spaces(let count):
                    if cursorX > origin.x {
                        cursorX += advanceX * CGFloat(count)
                        maxX = max(maxX, cursorX)
                    }

                case .word(let word):
                    let wordWidth = advanceX * CGFloat(word.count)
                    if cursorX > origin.x, cursorX + wordWidth > origin.x + maxLineWidth {
                        cursorX = origin.x
                        cursorY += lineHeight
                    }

                    for scalar in word.unicodeScalars {
                        if cursorX > origin.x, cursorX + advanceX > origin.x + maxLineWidth {
                            cursorX = origin.x
                            cursorY += lineHeight
                        }

                        let bits = glyphBits(for: scalar)
                        if bits != 0 {
                            glyphs.append(
                                PrimoMetalTextGlyphDescriptor(
                                    originX: Float(cursorX),
                                    originY: Float(cursorY),
                                    width: Float(glyphWidth),
                                    height: Float(glyphHeight),
                                    atlasBitsLow: UInt32(bits & 0xFFFF_FFFF),
                                    atlasBitsHigh: UInt32((bits >> 32) & 0xFFFF_FFFF)
                                )
                            )
                        }
                        cursorX += advanceX
                        maxX = max(maxX, cursorX)
                        maxY = max(maxY, cursorY + glyphHeight)
                    }
                }
            }

            cursorX = origin.x
            cursorY += lineHeight
            maxY = max(maxY, cursorY)
        }

        guard !glyphs.isEmpty else { return nil }
        let unrotatedBounds = CGRect(
            x: origin.x,
            y: origin.y,
            width: max(maxX - origin.x, glyphWidth),
            height: max(maxY - origin.y - (lineHeight - glyphHeight), glyphHeight)
        )
        let rotatedBounds = rotatedBoundingRect(unrotatedBounds, angleRadians: CGFloat(textLayer.rotationDegrees * .pi / 180.0))
        return PrimoMetalTextLayoutResult(
            glyphs: glyphs,
            unrotatedBounds: unrotatedBounds,
            rotatedBounds: rotatedBounds
        )
    }

    private enum TextToken {
        case word(String)
        case spaces(Int)
    }

    private func tokenizeTextParagraph(_ paragraph: String) -> [TextToken] {
        guard !paragraph.isEmpty else { return [] }
        var tokens: [TextToken] = []
        var current = ""
        var collectingSpaces = false

        for character in paragraph {
            if character == " " {
                if !collectingSpaces, !current.isEmpty {
                    tokens.append(.word(current))
                    current.removeAll(keepingCapacity: true)
                }
                collectingSpaces = true
                current.append(character)
            } else {
                if collectingSpaces, !current.isEmpty {
                    tokens.append(.spaces(current.count))
                    current.removeAll(keepingCapacity: true)
                }
                collectingSpaces = false
                current.append(character)
            }
        }

        if !current.isEmpty {
            tokens.append(collectingSpaces ? .spaces(current.count) : .word(current))
        }
        return tokens
    }

    private func rotatedBoundingRect(_ rect: CGRect, angleRadians: CGFloat) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return rect }
        guard abs(angleRadians) > 0.0001 else { return rect.integral }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ].map { point -> CGPoint in
            let translatedX = point.x - center.x
            let translatedY = point.y - center.y
            let rotatedX = (translatedX * cos(angleRadians)) - (translatedY * sin(angleRadians))
            let rotatedY = (translatedX * sin(angleRadians)) + (translatedY * cos(angleRadians))
            return CGPoint(x: center.x + rotatedX, y: center.y + rotatedY)
        }

        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        return CGRect(
            x: xs.min() ?? rect.minX,
            y: ys.min() ?? rect.minY,
            width: (xs.max() ?? rect.maxX) - (xs.min() ?? rect.minX),
            height: (ys.max() ?? rect.maxY) - (ys.min() ?? rect.minY)
        ).integral
    }

    private func clippedTextDirtyRect(
        bounds: CGRect,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> LayerPixelRect? {
        guard canvasWidth > 0, canvasHeight > 0 else { return nil }
        let minX = max(Int(floor(bounds.minX)), 0)
        let minY = max(Int(floor(bounds.minY)), 0)
        let maxX = min(Int(ceil(bounds.maxX)), canvasWidth)
        let maxY = min(Int(ceil(bounds.maxY)), canvasHeight)
        guard maxX > minX, maxY > minY else { return nil }
        return LayerPixelRect(
            originX: minX,
            originY: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private func glyphBits(for scalar: UnicodeScalar) -> UInt64 {
        let value = scalar.properties.isLowercase
            ? (String(scalar).uppercased().unicodeScalars.first ?? scalar)
            : scalar
        return Self.bitmapFont[value.value] ?? Self.bitmapFont[63] ?? 0
    }

    private static let bitmapFont: [UInt32: UInt64] = [
        32: glyphBits([
            "00000","00000","00000","00000","00000","00000","00000"
        ]),
        33: glyphBits([
            "00100","00100","00100","00100","00100","00000","00100"
        ]),
        39: glyphBits([
            "00100","00100","00000","00000","00000","00000","00000"
        ]),
        44: glyphBits([
            "00000","00000","00000","00000","00110","00100","01000"
        ]),
        45: glyphBits([
            "00000","00000","00000","11111","00000","00000","00000"
        ]),
        46: glyphBits([
            "00000","00000","00000","00000","00000","00110","00110"
        ]),
        47: glyphBits([
            "00001","00010","00100","01000","10000","00000","00000"
        ]),
        48: glyphBits([
            "01110","10001","10011","10101","11001","10001","01110"
        ]),
        49: glyphBits([
            "00100","01100","00100","00100","00100","00100","01110"
        ]),
        50: glyphBits([
            "01110","10001","00001","00010","00100","01000","11111"
        ]),
        51: glyphBits([
            "11110","00001","00001","01110","00001","00001","11110"
        ]),
        52: glyphBits([
            "00010","00110","01010","10010","11111","00010","00010"
        ]),
        53: glyphBits([
            "11111","10000","10000","11110","00001","00001","11110"
        ]),
        54: glyphBits([
            "01110","10000","10000","11110","10001","10001","01110"
        ]),
        55: glyphBits([
            "11111","00001","00010","00100","01000","01000","01000"
        ]),
        56: glyphBits([
            "01110","10001","10001","01110","10001","10001","01110"
        ]),
        57: glyphBits([
            "01110","10001","10001","01111","00001","00001","01110"
        ]),
        58: glyphBits([
            "00000","00110","00110","00000","00110","00110","00000"
        ]),
        63: glyphBits([
            "01110","10001","00001","00010","00100","00000","00100"
        ]),
        65: glyphBits([
            "01110","10001","10001","11111","10001","10001","10001"
        ]),
        66: glyphBits([
            "11110","10001","10001","11110","10001","10001","11110"
        ]),
        67: glyphBits([
            "01110","10001","10000","10000","10000","10001","01110"
        ]),
        68: glyphBits([
            "11110","10001","10001","10001","10001","10001","11110"
        ]),
        69: glyphBits([
            "11111","10000","10000","11110","10000","10000","11111"
        ]),
        70: glyphBits([
            "11111","10000","10000","11110","10000","10000","10000"
        ]),
        71: glyphBits([
            "01110","10001","10000","10111","10001","10001","01110"
        ]),
        72: glyphBits([
            "10001","10001","10001","11111","10001","10001","10001"
        ]),
        73: glyphBits([
            "01110","00100","00100","00100","00100","00100","01110"
        ]),
        74: glyphBits([
            "00001","00001","00001","00001","10001","10001","01110"
        ]),
        75: glyphBits([
            "10001","10010","10100","11000","10100","10010","10001"
        ]),
        76: glyphBits([
            "10000","10000","10000","10000","10000","10000","11111"
        ]),
        77: glyphBits([
            "10001","11011","10101","10101","10001","10001","10001"
        ]),
        78: glyphBits([
            "10001","11001","10101","10011","10001","10001","10001"
        ]),
        79: glyphBits([
            "01110","10001","10001","10001","10001","10001","01110"
        ]),
        80: glyphBits([
            "11110","10001","10001","11110","10000","10000","10000"
        ]),
        81: glyphBits([
            "01110","10001","10001","10001","10101","10010","01101"
        ]),
        82: glyphBits([
            "11110","10001","10001","11110","10100","10010","10001"
        ]),
        83: glyphBits([
            "01111","10000","10000","01110","00001","00001","11110"
        ]),
        84: glyphBits([
            "11111","00100","00100","00100","00100","00100","00100"
        ]),
        85: glyphBits([
            "10001","10001","10001","10001","10001","10001","01110"
        ]),
        86: glyphBits([
            "10001","10001","10001","10001","10001","01010","00100"
        ]),
        87: glyphBits([
            "10001","10001","10001","10101","10101","10101","01010"
        ]),
        88: glyphBits([
            "10001","10001","01010","00100","01010","10001","10001"
        ]),
        89: glyphBits([
            "10001","10001","01010","00100","00100","00100","00100"
        ]),
        90: glyphBits([
            "11111","00001","00010","00100","01000","10000","11111"
        ]),
        91: glyphBits([
            "01110","01000","01000","01000","01000","01000","01110"
        ]),
        93: glyphBits([
            "01110","00010","00010","00010","00010","00010","01110"
        ]),
        95: glyphBits([
            "00000","00000","00000","00000","00000","00000","11111"
        ]),
    ]

    private static func glyphBits(_ rows: [String]) -> UInt64 {
        var bits: UInt64 = 0
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, character) in row.enumerated() where character == "1" {
                let bitIndex = (rowIndex * 5) + columnIndex
                bits |= UInt64(1) << UInt64(bitIndex)
            }
        }
        return bits
    }
}
