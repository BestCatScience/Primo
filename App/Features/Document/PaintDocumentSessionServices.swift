import Accelerate
import CoreGraphics
import Foundation
import UIKit

struct PaintDocumentSessionServices {
    let fileIO: FileClient
    let clock: DateClient
    let ids: UUIDClient
    let persistence: PaintDocumentPersistenceService
    let timelapse: PaintDocumentTimelapseService
    let editingLifecycle: PaintDocumentEditingLifecycleService
    let bridge: PaintDocumentBridgeService
    let geometry: PaintDocumentGeometryService
    let blur: PaintDocumentBlurService

    init(
        fileClient: FileClient,
        dateClient: DateClient,
        uuidClient: UUIDClient
    ) {
        self.fileIO = fileClient
        self.clock = dateClient
        self.ids = uuidClient
        self.persistence = PaintDocumentPersistenceService(fileClient: fileClient)
        self.timelapse = PaintDocumentTimelapseService(fileClient: fileClient, uuidClient: uuidClient)
        self.editingLifecycle = PaintDocumentEditingLifecycleService()
        self.bridge = PaintDocumentBridgeService()
        self.geometry = PaintDocumentGeometryService()
        self.blur = PaintDocumentBlurService()
    }
}

struct PaintDocumentBridgeService {
    func consumeDirtyUpdate(from bridge: APPaintDocumentBridge) -> IncrementalLayerUpdate? {
        let dirtyRect = bridge.consumeDirtyRect()
        guard !dirtyRect.empty else { return nil }
        let pixelData = bridge.compositePixelData(in: dirtyRect) as Data
        guard !pixelData.isEmpty else { return nil }
        return IncrementalLayerUpdate(
            layerIndex: -1,
            originX: Int(dirtyRect.originX),
            originY: Int(dirtyRect.originY),
            width: Int(dirtyRect.width),
            height: Int(dirtyRect.height),
            pixelData: pixelData
        )
    }

    func pixelDataForLayer(index: Int, bridge: APPaintDocumentBridge) -> Data {
        bridge.pixelDataForLayer(at: index) as Data
    }

    func isLayerLocked(index: Int, bridge: APPaintDocumentBridge) -> Bool {
        guard let layer = bridge.layerInfos().enumerated().first(where: { $0.offset == index })?.element else {
            return false
        }
        return layer.locked
    }

    func isLayerAlphaLocked(index: Int, bridge: APPaintDocumentBridge) -> Bool {
        guard let layer = bridge.layerInfos().enumerated().first(where: { $0.offset == index })?.element else {
            return false
        }
        return layer.alphaLocked
    }

    func pixelDataByPreservingExistingAlpha(source: Data, existing: Data) -> Data {
        guard source.count == existing.count else { return source }
        var output = source
        output.withUnsafeMutableBytes { outputBytes in
            existing.withUnsafeBytes { existingBytes in
                guard let dst = outputBytes.bindMemory(to: UInt8.self).baseAddress,
                      let src = existingBytes.bindMemory(to: UInt8.self).baseAddress
                else { return }
                for offset in stride(from: 0, to: source.count, by: 4) {
                    let alpha = src[offset + 3]
                    if alpha == 0 {
                        dst[offset] = 0
                        dst[offset + 1] = 0
                        dst[offset + 2] = 0
                        dst[offset + 3] = 0
                    } else {
                        dst[offset + 3] = alpha
                    }
                }
            }
        }
        return output
    }

    func pixelData(from cgImage: CGImage, size: CGSize) -> Data? {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Data(bytes)
    }

    func makeBrushDescriptor(from brush: BrushRuntimeSettings) -> APBrushDescriptor {
        let descriptor = APBrushDescriptor()
        let usesCircularInkTip =
            brush.tipKind == .ink &&
            brush.customTip == nil &&
            brush.roundness >= 0.98 &&
            abs(brush.roundnessPressureSensitivity) <= 0.001 &&
            abs(brush.roundnessTiltSensitivity) <= 0.001 &&
            abs(brush.anglePressureSensitivity) <= 0.001 &&
            abs(brush.angleTiltSensitivity) <= 0.001 &&
            abs(brush.angleJitter) <= 0.001 &&
            abs(brush.roundnessJitter) <= 0.001
        descriptor.tipKind = brush.tipKind.rawValue
        descriptor.radius = brush.radius
        descriptor.sizeSpeedSensitivity = brush.sizeSpeedSensitivity
        descriptor.taperIn = brush.taperIn
        descriptor.taperOut = brush.taperOut
        descriptor.opacity = brush.opacity
        descriptor.hardness = brush.hardness
        descriptor.roundness = brush.roundness
        descriptor.roundnessPressureSensitivity = brush.roundnessPressureSensitivity
        descriptor.roundnessTiltSensitivity = brush.roundnessTiltSensitivity
        descriptor.angle = brush.angle
        descriptor.anglePressureSensitivity = brush.anglePressureSensitivity
        descriptor.angleTiltSensitivity = brush.angleTiltSensitivity
        descriptor.angleMode = {
            switch brush.angleMode {
            case .fixed: return 0
            case .strokeDirection: return 1
            case .stylusTilt: return 2
            }
        }()
        descriptor.stampSpacing = brush.stampSpacing
        descriptor.spacingJitter = brush.spacingJitter
        descriptor.scatterEnabled = brush.scatterEnabled
        descriptor.scatterMode = brush.scatterMode == .spray ? 1 : 0
        descriptor.scatterLateral = brush.scatterLateral
        descriptor.scatterLinear = brush.scatterLinear
        descriptor.count = brush.count
        descriptor.countJitter = brush.countJitter
        descriptor.countSizeJitter = brush.countSizeJitter
        descriptor.countOpacityJitter = brush.countOpacityJitter
        descriptor.angleJitter = brush.angleJitter
        descriptor.roundnessJitter = brush.roundnessJitter
        descriptor.textureMode = {
            switch brush.textureMode {
            case .off: return 0
            case .strokeLocked: return 1
            case .eachTip: return 2
            case .moving: return 3
            }
        }()
        descriptor.textureStrength = brush.textureStrength
        descriptor.flow = brush.flow
        descriptor.flowPressureSensitivity = brush.flowPressureSensitivity
        descriptor.flowJitter = brush.flowJitter
        descriptor.velocityInfluence = brush.velocityInfluence
        descriptor.colorMixingMode = {
            switch brush.colorMixingMode {
            case .off: return 0
            case .blend: return 1
            case .runningColor: return 2
            case .smear: return 3
            }
        }()
        descriptor.wetness = brush.wetness
        descriptor.wetnessPressureSensitivity = brush.wetnessPressureSensitivity
        descriptor.opacityPressureSensitivity = brush.opacityPressureSensitivity
        descriptor.colorMixStrength = brush.colorMixStrength
        descriptor.smudgeBlurEnabled = brush.smudgeBlurEnabled
        descriptor.smudgeBleed = brush.smudgeBleed
        descriptor.smudgeRadius = brush.smudgeRadius
        descriptor.paintLoad = brush.paintLoad
        descriptor.loadPressureSensitivity = brush.loadPressureSensitivity
        descriptor.dualBrushEnabled = brush.dualBrushEnabled
        descriptor.dualTipKind = brush.dualTipKind.rawValue
        descriptor.dualScale = brush.dualScale
        descriptor.dualSpacing = brush.dualSpacing
        descriptor.dualScatter = brush.dualScatter
        descriptor.dualAngle = brush.dualAngle
        descriptor.dualBlendMode = {
            switch brush.dualBlendMode {
            case .multiply: return 0
            case .darker: return 1
            case .subtract: return 2
            }
        }()
        descriptor.flipX = brush.flipX
        descriptor.flipY = brush.flipY
        descriptor.tipMaskWidth = brush.customTip?.width ?? 0
        descriptor.tipMaskHeight = brush.customTip?.height ?? 0
        descriptor.tipMaskData = brush.customTip?.alphaData
        descriptor.grainScale = brush.grainScale
        descriptor.grainContrast = brush.grainContrast
        descriptor.paperScale = brush.paperScale
        descriptor.paperThreshold = brush.paperThreshold
        descriptor.paperStrength = brush.paperStrength
        descriptor.tiltInfluence = usesCircularInkTip ? 0.0 : 0.75
        descriptor.maxDarkness = 1.0
        descriptor.pressureSensitivity = brush.pressureSensitivity
        descriptor.fillThresholdMode = brush.fillThresholdMode == .opacity ? 0 : 1
        descriptor.fillOpacityTolerance = brush.fillOpacityTolerance
        descriptor.fillColorTolerance = brush.fillColorTolerance
        descriptor.fillExpansion = brush.fillExpansion
        descriptor.red = brush.red
        descriptor.green = brush.green
        descriptor.blue = brush.blue
        descriptor.eraser = brush.isEraser
        return descriptor
    }

    func makeProcessingDescriptor(from request: LayerProcessingRequest) -> APPaintLayerProcessingDescriptor {
        let descriptor = APPaintLayerProcessingDescriptor()
        switch request {
        case let .gradientMap(preset):
            descriptor.kind = APPaintLayerProcessingKind.gradientMap
            switch preset {
            case .graphite:
                descriptor.gradientMapPreset = APPaintGradientMapPreset.graphite
            case .sepia:
                descriptor.gradientMapPreset = APPaintGradientMapPreset.sepia
            case .ocean:
                descriptor.gradientMapPreset = APPaintGradientMapPreset.ocean
            case .sunset:
                descriptor.gradientMapPreset = APPaintGradientMapPreset.sunset
            case .toxic:
                descriptor.gradientMapPreset = APPaintGradientMapPreset.toxic
            }
        case let .hueSaturationBrightness(settings):
            descriptor.kind = APPaintLayerProcessingKind.hueSaturationBrightness
            descriptor.hueDegrees = CGFloat(settings.hueDegrees)
            descriptor.saturation = CGFloat(settings.saturation)
            descriptor.brightness = CGFloat(settings.brightness)
        case let .brightnessContrast(settings):
            descriptor.kind = APPaintLayerProcessingKind.brightnessContrast
            descriptor.brightness = CGFloat(settings.brightness)
            descriptor.contrast = CGFloat(settings.contrast)
        case let .levels(settings):
            descriptor.kind = APPaintLayerProcessingKind.levels
            descriptor.inputBlack = CGFloat(settings.inputBlack)
            descriptor.inputWhite = CGFloat(settings.inputWhite)
            descriptor.gamma = CGFloat(settings.gamma)
            descriptor.outputBlack = CGFloat(settings.outputBlack)
            descriptor.outputWhite = CGFloat(settings.outputWhite)
        case let .toneCurve(settings):
            descriptor.kind = APPaintLayerProcessingKind.toneCurve
            descriptor.shadows = CGFloat(settings.shadows)
            descriptor.midtones = CGFloat(settings.midtones)
            descriptor.highlights = CGFloat(settings.highlights)
        case let .colorBalance(settings):
            descriptor.kind = APPaintLayerProcessingKind.colorBalance
            descriptor.redCyan = CGFloat(settings.redCyan)
            descriptor.greenMagenta = CGFloat(settings.greenMagenta)
            descriptor.blueYellow = CGFloat(settings.blueYellow)
        case let .threshold(settings):
            descriptor.kind = APPaintLayerProcessingKind.threshold
            descriptor.threshold = CGFloat(settings.threshold)
        case let .posterize(settings):
            descriptor.kind = APPaintLayerProcessingKind.posterize
            descriptor.posterizeLevels = CGFloat(settings.levels)
        case let .transform(translation, scale, _, selection):
            descriptor.kind = APPaintLayerProcessingKind.transform
            descriptor.transformTranslateX = Int(translation.width.rounded())
            descriptor.transformTranslateY = Int(translation.height.rounded())
            descriptor.transformScale = scale
            if let selection, !selection.isEmpty {
                descriptor.selectionOriginX = Int(selection.bounds.minX.rounded(.down))
                descriptor.selectionOriginY = Int(selection.bounds.minY.rounded(.down))
                descriptor.selectionWidth = selection.maskWidth
                descriptor.selectionHeight = selection.maskHeight
                descriptor.selectionMaskData = selection.maskData
            }
        }
        return descriptor
    }

    func makeStrokePoint(from sample: StylusSample) -> APStrokePoint {
        let point = APStrokePoint()
        point.x = sample.point.x
        point.y = sample.point.y
        point.pressure = normalizedPressure(sample.pressure)
        point.altitude = sample.altitude
        point.azimuth = sample.azimuth
        point.timestamp = sample.timestamp
        return point
    }

    func normalizedPressure(_ pressure: CGFloat) -> CGFloat {
        max(0.08, min(max(pressure, 0.0), 1.0))
    }
}

struct PaintDocumentCanvasSize: Equatable {
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = max(width, 1)
        self.height = max(height, 1)
    }

    var rgbaByteCount: Int {
        width * height * 4
    }

    var maskByteCount: Int {
        width * height
    }
}

struct PaintDocumentGeometryService {
    func scaledLayerPixelData(
        _ source: Data,
        from sourceSize: PaintDocumentCanvasSize,
        to targetSize: PaintDocumentCanvasSize
    ) -> Data? {
        guard source.count == sourceSize.rgbaByteCount else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: source as CFData),
              let image = CGImage(
                width: sourceSize.width,
                height: sourceSize.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: sourceSize.width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: targetSize.rgbaByteCount)
        guard let context = CGContext(
            data: &bytes,
            width: targetSize.width,
            height: targetSize.height,
            bitsPerComponent: 8,
            bytesPerRow: targetSize.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
        return Data(bytes)
    }

    func scaledLayerMaskData(
        _ source: Data,
        from sourceSize: PaintDocumentCanvasSize,
        to targetSize: PaintDocumentCanvasSize
    ) -> Data? {
        guard source.count == sourceSize.maskByteCount else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: source as CFData),
              let image = CGImage(
                width: sourceSize.width,
                height: sourceSize.height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: sourceSize.width,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: targetSize.maskByteCount)
        guard let context = CGContext(
            data: &bytes,
            width: targetSize.width,
            height: targetSize.height,
            bitsPerComponent: 8,
            bytesPerRow: targetSize.width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
        return Data(bytes)
    }

    func translatedLayerPixelData(
        _ source: Data,
        from sourceSize: PaintDocumentCanvasSize,
        to targetSize: PaintDocumentCanvasSize,
        offsetX: Int,
        offsetY: Int
    ) -> Data? {
        guard source.count == sourceSize.rgbaByteCount else { return nil }
        var bytes = [UInt8](repeating: 0, count: targetSize.rgbaByteCount)
        source.withUnsafeBytes { sourceBytes in
            guard let sourceBase = sourceBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<sourceSize.height {
                let destinationY = y + offsetY
                guard destinationY >= 0, destinationY < targetSize.height else { continue }
                for x in 0..<sourceSize.width {
                    let destinationX = x + offsetX
                    guard destinationX >= 0, destinationX < targetSize.width else { continue }
                    let sourceOffset = ((y * sourceSize.width) + x) * 4
                    let destinationOffset = ((destinationY * targetSize.width) + destinationX) * 4
                    bytes[destinationOffset] = sourceBase[sourceOffset]
                    bytes[destinationOffset + 1] = sourceBase[sourceOffset + 1]
                    bytes[destinationOffset + 2] = sourceBase[sourceOffset + 2]
                    bytes[destinationOffset + 3] = sourceBase[sourceOffset + 3]
                }
            }
        }
        return Data(bytes)
    }

    func translatedLayerMaskData(
        _ source: Data,
        from sourceSize: PaintDocumentCanvasSize,
        to targetSize: PaintDocumentCanvasSize,
        offsetX: Int,
        offsetY: Int
    ) -> Data? {
        guard source.count == sourceSize.maskByteCount else { return nil }
        var bytes = [UInt8](repeating: 0, count: targetSize.maskByteCount)
        source.withUnsafeBytes { sourceBytes in
            guard let sourceBase = sourceBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<sourceSize.height {
                let destinationY = y + offsetY
                guard destinationY >= 0, destinationY < targetSize.height else { continue }
                for x in 0..<sourceSize.width {
                    let destinationX = x + offsetX
                    guard destinationX >= 0, destinationX < targetSize.width else { continue }
                    let sourceOffset = (y * sourceSize.width) + x
                    let destinationOffset = (destinationY * targetSize.width) + destinationX
                    bytes[destinationOffset] = sourceBase[sourceOffset]
                }
            }
        }
        return Data(bytes)
    }
}

struct PaintDocumentBlurService {
    func boxBlurredPixels(
        from original: [UInt8],
        size: PaintDocumentCanvasSize,
        radius: Double
    ) -> [UInt8]? {
        var source = original
        var destination = [UInt8](repeating: 0, count: original.count)
        var kernelSize = max(3, Int((radius * 0.9).rounded()))
        if kernelSize.isMultiple(of: 2) {
            kernelSize += 1
        }
        kernelSize = min(kernelSize, 63)

        for _ in 0..<2 {
            let error: vImage_Error = source.withUnsafeMutableBytes { sourceBytes in
                destination.withUnsafeMutableBytes { destinationBytes in
                    var sourceBuffer = vImage_Buffer(
                        data: sourceBytes.baseAddress!,
                        height: vImagePixelCount(size.height),
                        width: vImagePixelCount(size.width),
                        rowBytes: size.width * 4
                    )
                    var destinationBuffer = vImage_Buffer(
                        data: destinationBytes.baseAddress!,
                        height: vImagePixelCount(size.height),
                        width: vImagePixelCount(size.width),
                        rowBytes: size.width * 4
                    )
                    return vImageBoxConvolve_ARGB8888(
                        &sourceBuffer,
                        &destinationBuffer,
                        nil,
                        0,
                        0,
                        UInt32(kernelSize),
                        UInt32(kernelSize),
                        nil,
                        vImage_Flags(kvImageEdgeExtend)
                    )
                }
            }
            guard error == kvImageNoError else {
                return nil
            }
            swap(&source, &destination)
        }

        return source
    }

    func blendBlurredPixels(
        original: [UInt8],
        blurred: [UInt8],
        size: PaintDocumentCanvasSize,
        samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> [UInt8] {
        var output = original
        let influenceRadius = max(4.0, brush.radius * 1.35)
        let blurStrength = max(0.0, min(brush.flow, 1.0))
        let softness = max(0.12, 1.0 - brush.hardness)
        let sampleXs = samples.map { Double($0.point.x) }
        let sampleYs = samples.map { Double($0.point.y) }
        let minX = max(0, Int((sampleXs.min() ?? 0) - influenceRadius - 2))
        let maxX = min(size.width - 1, Int((sampleXs.max() ?? 0) + influenceRadius + 2))
        let minY = max(0, Int((sampleYs.min() ?? 0) - influenceRadius - 2))
        let maxY = min(size.height - 1, Int((sampleYs.max() ?? 0) + influenceRadius + 2))

        guard minX <= maxX, minY <= maxY else {
            return output
        }

        let maskWidth = maxX - minX + 1
        let maskHeight = maxY - minY + 1
        var mask = [Float](repeating: 0, count: maskWidth * maskHeight)

        for sample in samples {
            let centerX = Double(sample.point.x)
            let centerY = Double(sample.point.y)
            let sampleRadius = influenceRadius * max(0.35, Double(sample.pressure))
            let localMinX = max(minX, Int(floor(centerX - sampleRadius)))
            let localMaxX = min(maxX, Int(ceil(centerX + sampleRadius)))
            let localMinY = max(minY, Int(floor(centerY - sampleRadius)))
            let localMaxY = min(maxY, Int(ceil(centerY + sampleRadius)))

            for y in localMinY...localMaxY {
                let dy = Double(y) - centerY
                for x in localMinX...localMaxX {
                    let dx = Double(x) - centerX
                    let distance = sqrt((dx * dx) + (dy * dy))
                    guard distance <= sampleRadius else { continue }
                    let normalized = max(0.0, 1.0 - (distance / sampleRadius))
                    let feathered = pow(normalized, max(0.75, 2.4 - (softness * 1.6)))
                    let strength = Float(feathered * blurStrength)
                    let maskIndex = ((y - minY) * maskWidth) + (x - minX)
                    mask[maskIndex] = max(mask[maskIndex], strength)
                }
            }
        }

        for y in minY...maxY {
            for x in minX...maxX {
                let maskIndex = ((y - minY) * maskWidth) + (x - minX)
                let strength = max(0, min(mask[maskIndex], 1))
                guard strength > 0.001 else { continue }
                let pixelIndex = ((y * size.width) + x) * 4
                for channel in 0..<4 {
                    let originalValue = Float(original[pixelIndex + channel])
                    let blurredValue = Float(blurred[pixelIndex + channel])
                    output[pixelIndex + channel] = UInt8(
                        max(0, min(255, Int((originalValue + ((blurredValue - originalValue) * strength)).rounded())))
                    )
                }
            }
        }

        return output
    }
}

enum PaintDocumentThumbnailInvalidation {
    case none
    case layer(Int)
    case all
}

struct PaintDocumentLifecycleMutation {
    let thumbnailInvalidation: PaintDocumentThumbnailInvalidation
    let timelapseEvents: [TimelapseOperation]
    let shouldCaptureTimelapseFrame: Bool

    static let none = PaintDocumentLifecycleMutation(
        thumbnailInvalidation: .none,
        timelapseEvents: [],
        shouldCaptureTimelapseFrame: false
    )
}

struct PaintDocumentEditingLifecycleService {
    func mutation(
        recording events: [TimelapseOperation] = [],
        invalidating thumbnails: PaintDocumentThumbnailInvalidation = .none,
        captureFrame: Bool = true
    ) -> PaintDocumentLifecycleMutation {
        PaintDocumentLifecycleMutation(
            thumbnailInvalidation: thumbnails,
            timelapseEvents: events,
            shouldCaptureTimelapseFrame: captureFrame
        )
    }

    func mutation(
        recording event: TimelapseOperation,
        invalidating thumbnails: PaintDocumentThumbnailInvalidation = .none,
        captureFrame: Bool = true
    ) -> PaintDocumentLifecycleMutation {
        mutation(recording: [event], invalidating: thumbnails, captureFrame: captureFrame)
    }

    func resetStrokeState(
        activeLayerIndex: inout Int?,
        activeBrush: inout BrushRuntimeSettings?,
        activeSamples: inout [StylusSample]
    ) {
        activeLayerIndex = nil
        activeBrush = nil
        activeSamples.removeAll(keepingCapacity: true)
    }

    func resetBlurStrokeState(
        activeLayerIndex: inout Int?,
        activeBrush: inout BrushRuntimeSettings?,
        activeSamples: inout [StylusSample],
        blurStrokeHasCapturedHistory: inout Bool
    ) {
        activeLayerIndex = nil
        activeBrush = nil
        activeSamples.removeAll(keepingCapacity: true)
        blurStrokeHasCapturedHistory = false
    }

    func resetActiveEditingState(
        activeStrokeLayerIndex: inout Int?,
        activeStrokeBrush: inout BrushRuntimeSettings?,
        activeStrokeSamples: inout [StylusSample],
        activeBlurStrokeLayerIndex: inout Int?,
        activeBlurStrokeBrush: inout BrushRuntimeSettings?,
        activeBlurStrokeSamples: inout [StylusSample],
        blurStrokeHasCapturedHistory: inout Bool
    ) {
        resetStrokeState(
            activeLayerIndex: &activeStrokeLayerIndex,
            activeBrush: &activeStrokeBrush,
            activeSamples: &activeStrokeSamples
        )
        resetBlurStrokeState(
            activeLayerIndex: &activeBlurStrokeLayerIndex,
            activeBrush: &activeBlurStrokeBrush,
            activeSamples: &activeBlurStrokeSamples,
            blurStrokeHasCapturedHistory: &blurStrokeHasCapturedHistory
        )
    }
}

struct PaintDocumentPersistenceService {
    let fileClient: FileClient

    func prepareProjectDirectory(at url: URL) throws {
        if fileClient.fileExists(url.path) {
            try fileClient.removeItem(url)
        }
        try fileClient.createDirectory(url, true)
    }

    func createProjectSubdirectories(
        in projectURL: URL,
        usesOperationTimelapsePersistence: Bool
    ) throws -> (layersDirectory: URL, timelapseDirectory: URL, timelapseDataDirectory: URL) {
        let layersDirectory = projectURL.appendingPathComponent("Layers", isDirectory: true)
        let timelapseDirectory = projectURL.appendingPathComponent("Timelapse", isDirectory: true)
        let timelapseDataDirectory = projectURL.appendingPathComponent("TimelapseData", isDirectory: true)
        try fileClient.createDirectory(layersDirectory, true)
        if usesOperationTimelapsePersistence {
            try fileClient.createDirectory(timelapseDataDirectory, true)
        } else {
            try fileClient.createDirectory(timelapseDirectory, true)
        }
        return (layersDirectory, timelapseDirectory, timelapseDataDirectory)
    }

    func writeAtomic(_ data: Data, to url: URL) throws {
        try fileClient.writeData(data, url, Data.WritingOptions.atomic)
    }

    func loadData(from url: URL) throws -> Data {
        try fileClient.readData(url)
    }

    func replaceItemIfNeeded(at destinationURL: URL, with sourceURL: URL) throws {
        if fileClient.fileExists(destinationURL.path) {
            try fileClient.removeItem(destinationURL)
        }
        try fileClient.copyItem(sourceURL, destinationURL)
    }
}

struct PaintDocumentTimelapseService {
    let fileClient: FileClient
    let uuidClient: UUIDClient

    func makeDirectoryURL() -> URL {
        fileClient.temporaryDirectory()
            .appendingPathComponent("primo-timelapse", isDirectory: true)
            .appendingPathComponent(uuidClient.generate().uuidString, isDirectory: true)
    }

    func makeFrameURL(in directoryURL: URL, frameID: Int) -> URL {
        directoryURL.appendingPathComponent(String(format: "frame-%06d.jpg", frameID), isDirectory: false)
    }

    func persistFrameData(_ data: Data, to url: URL) throws {
        try fileClient.writeData(data, url, Data.WritingOptions.atomic)
    }

    func removeFrame(at url: URL) throws {
        try fileClient.removeItem(url)
    }

    func removeDirectory(at url: URL) throws {
        try fileClient.removeItem(url)
    }
}
