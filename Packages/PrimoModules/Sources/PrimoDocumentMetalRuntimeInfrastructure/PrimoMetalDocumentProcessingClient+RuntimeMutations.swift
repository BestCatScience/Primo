import CoreGraphics
import Foundation
import Metal
import PrimoDocumentContracts
import PrimoDocumentDomain

#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
private typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
private typealias PlatformColor = NSColor
private typealias PlatformFont = NSFont
#endif

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
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
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
    static let transform: UInt32 = 8
}

extension PrimoMetalDocumentProcessingClient {
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
            let textMask = renderTextMask(textLayer, canvasSize: canvasSize),
            let maskBuffer = makeBuffer(textMask),
            let outputBuffer = device?.makeBuffer(length: width * height * 4, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalTextComposeDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    red: Float(textLayer.red),
                    green: Float(textLayer.green),
                    blue: Float(textLayer.blue),
                    alpha: Float(textLayer.alpha)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(maskBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let fullPixelData = bytes(from: outputBuffer, count: width * height * 4)
        let dirtyRect = LayerPixelRect(originX: 0, originY: 0, width: width, height: height)
        return DocumentLayerMutationPayload(
            canvasWidth: width,
            canvasHeight: height,
            dirtyRect: dirtyRect,
            rectPixelData: fullPixelData,
            fullPixelData: fullPixelData
        )
    }

    public func textLayoutRect(
        for textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> CGRect? {
        resolvedTextDrawRect(for: textLayer, canvasSize: canvasSize)
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
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        var currentFill = firstFillBuffer
        var nextFill = secondFillBuffer
        for _ in 0..<(canvasWidth * canvasHeight) {
            changeFlagBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee = 0
            guard let propagationCommandBuffer = commandQueue.makeCommandBuffer(),
                  let propagationEncoder = propagationCommandBuffer.makeComputeCommandEncoder()
            else {
                return nil
            }
            propagationEncoder.setComputePipelineState(propagationPipeline)
            propagationEncoder.setBuffer(eligibleBuffer, offset: 0, index: 0)
            propagationEncoder.setBuffer(currentFill, offset: 0, index: 1)
            propagationEncoder.setBuffer(nextFill, offset: 0, index: 2)
            propagationEncoder.setBuffer(changeFlagBuffer, offset: 0, index: 3)
            propagationEncoder.setBuffer(descriptorBuffer, offset: 0, index: 4)
            dispatch2D(encoder: propagationEncoder, pipeline: propagationPipeline, width: canvasWidth, height: canvasHeight)
            propagationEncoder.endEncoding()
            propagationCommandBuffer.commit()
            propagationCommandBuffer.waitUntilCompleted()
            guard propagationCommandBuffer.status == .completed else { return nil }

            swap(&currentFill, &nextFill)
            if changeFlagBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee == 0 {
                break
            }
        }

        if brush.fillExpansion > 0 {
            for _ in 0..<brush.fillExpansion {
                guard let expansionCommandBuffer = commandQueue.makeCommandBuffer(),
                      let expansionEncoder = expansionCommandBuffer.makeComputeCommandEncoder()
                else {
                    return nil
                }
                expansionEncoder.setComputePipelineState(expansionPipeline)
                expansionEncoder.setBuffer(currentFill, offset: 0, index: 0)
                expansionEncoder.setBuffer(nextFill, offset: 0, index: 1)
                expansionEncoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
                dispatch2D(encoder: expansionEncoder, pipeline: expansionPipeline, width: canvasWidth, height: canvasHeight)
                expansionEncoder.endEncoding()
                expansionCommandBuffer.commit()
                expansionCommandBuffer.waitUntilCompleted()
                guard expansionCommandBuffer.status == .completed else { return nil }
                swap(&currentFill, &nextFill)
            }
        }

        guard let composeCommandBuffer = commandQueue.makeCommandBuffer(),
              let composeEncoder = composeCommandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }
        composeEncoder.setComputePipelineState(composePipeline)
        composeEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        composeEncoder.setBuffer(currentFill, offset: 0, index: 1)
        composeEncoder.setBuffer(outputBuffer, offset: 0, index: 2)
        composeEncoder.setBuffer(descriptorBuffer, offset: 0, index: 3)
        dispatch2D(encoder: composeEncoder, pipeline: composePipeline, width: canvasWidth, height: canvasHeight)
        composeEncoder.endEncoding()
        composeCommandBuffer.commit()
        composeCommandBuffer.waitUntilCompleted()
        guard composeCommandBuffer.status == .completed else { return nil }

        let fullPixelData = bytes(from: outputBuffer, count: pixelData.count)
        return DocumentLayerMutationPayload(
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            dirtyRect: fullRect,
            rectPixelData: fullPixelData,
            fullPixelData: fullPixelData
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
        case .gradientMap:
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

    #if canImport(UIKit) || canImport(AppKit)
    private func resolvedTextDrawRect(
        for textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> CGRect? {
        guard
            !textLayer.text.isEmpty,
            canvasSize.width > 0,
            canvasSize.height > 0
        else {
            return nil
        }
        let font = PlatformFont(name: textLayer.fontPostScriptName, size: textLayer.fontSize) ?? systemFont(ofSize: textLayer.fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: PlatformColor(white: 1.0, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]
        let constraintRect = CGSize(
            width: max(canvasSize.width - textLayer.position.x - 12, textLayer.fontSize),
            height: max(canvasSize.height - textLayer.position.y - 12, textLayer.fontSize * 2.0)
        )
        let measuredBounds = (textLayer.text as NSString).boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).integral
        return CGRect(
            origin: textLayer.position,
            size: CGSize(
                width: max(measuredBounds.width, textLayer.fontSize * 0.5),
                height: max(measuredBounds.height, textLayer.fontSize * 1.2)
            )
        )
    }

    private func renderTextMask(_ textLayer: TextLayerData, canvasSize: CGSize) -> Data? {
        guard let drawRect = resolvedTextDrawRect(for: textLayer, canvasSize: canvasSize) else { return nil }
        let width = max(Int(canvasSize.width.rounded()), 1)
        let height = max(Int(canvasSize.height.rounded()), 1)
        let font = PlatformFont(name: textLayer.fontPostScriptName, size: textLayer.fontSize) ?? systemFont(ofSize: textLayer.fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: PlatformColor(white: 1.0, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]
        var data = Data(count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let rendered = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return false
            }
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let anchor = CGPoint(x: drawRect.midX, y: drawRect.midY)
            let scale = CGFloat(min(max(textLayer.scale, 0.2), 6.0))
            context.saveGState()
            context.translateBy(x: anchor.x, y: anchor.y)
            context.rotate(by: CGFloat(textLayer.rotationDegrees * .pi / 180.0))
            context.scaleBy(x: scale, y: scale)
            let localRect = CGRect(
                x: -(drawRect.width / 2),
                y: -(drawRect.height / 2),
                width: drawRect.width,
                height: drawRect.height
            )
            pushGraphicsContext(context)
            (textLayer.text as NSString).draw(in: localRect, withAttributes: attributes)
            popGraphicsContext()
            context.restoreGState()
            return true
        }
        return rendered ? data : nil
    }

    private func systemFont(ofSize size: Double) -> PlatformFont {
        #if canImport(UIKit)
        PlatformFont.systemFont(ofSize: size, weight: .regular)
        #else
        PlatformFont.systemFont(ofSize: size)
        #endif
    }

    private func pushGraphicsContext(_ context: CGContext) {
        #if canImport(UIKit)
        UIGraphicsPushContext(context)
        #elseif canImport(AppKit)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        #endif
    }

    private func popGraphicsContext() {
        #if canImport(UIKit)
        UIGraphicsPopContext()
        #elseif canImport(AppKit)
        NSGraphicsContext.restoreGraphicsState()
        #endif
    }
    #else
    private func resolvedTextDrawRect(for textLayer: TextLayerData, canvasSize: CGSize) -> CGRect? { nil }
    private func renderTextMask(_ textLayer: TextLayerData, canvasSize: CGSize) -> Data? { nil }
    #endif
}
