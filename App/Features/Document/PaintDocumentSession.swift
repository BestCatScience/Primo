import Accelerate
import CoreGraphics
import Foundation
import os
import UIKit
import simd

final class PaintDocumentSession: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.atelierprime.app", category: "Document")
    private static let maxTimelapseFrames = 20_000
    let bridge: APPaintDocumentBridge
    private var revision: Int = 0
    private var activeStrokeLayerIndex: Int?
    private var timelapseFrames: [TimelapseFrame] = []
    private var layerThumbnailCache: [Int: Data] = [:]
    private var paperStyle: CanvasPaperStyle = .default
    private let timelapseDirectoryURL: URL
    private var nextTimelapseFrameID: Int = 0
    private var activeBlurStrokeLayerIndex: Int?
    private var blurStrokeHasCapturedHistory = false

    init(width: Int = 1152, height: Int = 1536) {
        let clock = ContinuousClock()
        let start = clock.now
        self.bridge = APPaintDocumentBridge(width: width, height: height)
        self.timelapseDirectoryURL = Self.makeTimelapseDirectoryURL()
        try? FileManager.default.createDirectory(at: timelapseDirectoryURL, withIntermediateDirectories: true)
        let duration = start.duration(to: clock.now)
        Self.logger.debug("PaintDocumentSession initialized \(width)x\(height) in \(String(describing: duration), privacy: .public)")
    }

    deinit {
        try? FileManager.default.removeItem(at: timelapseDirectoryURL)
    }

    func lightweightPresentation() -> PaintDocumentPresentation {
        let clock = ContinuousClock()
        let start = clock.now
        let infos = bridge.layerInfos()
        let folderInfos = bridge.folderInfos()
        let rows = buildLayerRows(from: infos)
        let duration = start.duration(to: clock.now)
        Self.logger.debug("lightweightPresentation produced \(rows.count) layers in \(String(describing: duration), privacy: .public)")
        return PaintDocumentPresentation(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            activeLayerIndex: bridge.activeLayerIndex,
            layerRows: rows,
            layerSidebarRows: buildSidebarRows(layerInfos: infos, layerRows: rows, folderInfos: folderInfos),
            renderSnapshot: nil
        )
    }

    func presentation() -> PaintDocumentPresentation {
        let clock = ContinuousClock()
        let start = clock.now
        revision += 1
        let infos = bridge.layerInfos()
        let folderInfos = bridge.folderInfos()
        let folderVisibilityByID = Dictionary(uniqueKeysWithValues: folderInfos.map { (Int($0.folderID), $0.visible) })
        let snapshots = infos.enumerated().map { index, info in
            MetalLayerSnapshot(
                index: index,
                opacity: Float(info.opacity),
                visible: info.visible && (info.folderID < 0 || (folderVisibilityByID[Int(info.folderID)] ?? true)),
                blendMode: LayerBlendMode(rawValue: info.blendMode) ?? .normal,
                thumbnailData: cachedLayerThumbnailData(index: index),
                pixelData: bridge.pixelDataForLayer(at: index) as Data
            )
        }
        let rows = buildLayerRows(from: infos)
        let duration = start.duration(to: clock.now)
        let megabytes = snapshots.reduce(0) { $0 + $1.pixelData.count } / 1_048_576
        Self.logger.debug("presentation produced revision \(self.revision) with \(snapshots.count) layers and \(megabytes) MB in \(String(describing: duration), privacy: .public)")
        return PaintDocumentPresentation(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            activeLayerIndex: bridge.activeLayerIndex,
            layerRows: rows,
            layerSidebarRows: buildSidebarRows(layerInfos: infos, layerRows: rows, folderInfos: folderInfos),
            renderSnapshot: MetalDocumentSnapshot(
                width: bridge.width,
                height: bridge.height,
                revision: revision,
                compositePixelData: bridge.compositePixelData() as Data,
                layers: snapshots
            )
        )
    }

    func prewarmDrawingResources() {
        _ = bridge.compositePixelData()
    }

    func beginStroke(sample: StylusSample, brush: BrushRuntimeSettings) {
        activeStrokeLayerIndex = Int(bridge.activeLayerIndex)
        bridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: sample))
    }

    func appendStroke(sample: StylusSample) {
        bridge.appendStroke(point: makeStrokePoint(from: sample))
    }

    func endStroke() {
        bridge.endStroke()
        invalidateThumbnailCache(for: Int(bridge.activeLayerIndex))
        activeStrokeLayerIndex = nil
        captureTimelapseFrame()
    }

    func fill(sample: StylusSample, brush: BrushRuntimeSettings) {
        bridge.fill(
            at: sample.point,
            brush: makeBrushDescriptor(from: brush)
        )
        invalidateThumbnailCache(for: Int(bridge.activeLayerIndex))
        captureTimelapseFrame()
    }

    func blur(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, captureTimelapse: Bool) {
        guard !samples.isEmpty else { return }
        let width = Int(bridge.width)
        let height = Int(bridge.height)
        let sourceData = bridge.pixelDataForLayer(at: layerIndex) as Data
        guard sourceData.count == width * height * 4 else { return }

        let original = [UInt8](sourceData)
        guard let blurred = boxBlurredPixels(from: original, width: width, height: height, radius: brush.radius) else {
            return
        }

        let blended = blendBlurredPixels(
            original: original,
            blurred: blurred,
            width: width,
            height: height,
            samples: samples,
            brush: brush
        )
        if activeBlurStrokeLayerIndex != layerIndex {
            activeBlurStrokeLayerIndex = layerIndex
            blurStrokeHasCapturedHistory = false
        }
        if blurStrokeHasCapturedHistory {
            bridge.replaceLayerPixelsTransient(at: layerIndex, data: Data(blended))
        } else {
            bridge.replaceLayerPixels(at: layerIndex, data: Data(blended))
            blurStrokeHasCapturedHistory = true
        }
        invalidateThumbnailCache(for: layerIndex)
        if captureTimelapse {
            captureTimelapseFrame()
        }
    }

    func endBlurStroke() {
        activeBlurStrokeLayerIndex = nil
        blurStrokeHasCapturedHistory = false
        captureTimelapseFrame()
    }

    func canUndo() -> Bool {
        bridge.canUndo()
    }

    func canRedo() -> Bool {
        bridge.canRedo()
    }

    @discardableResult
    func undo() -> Bool {
        let didUndo = bridge.undo()
        if didUndo {
            invalidateThumbnailCache()
            captureTimelapseFrame()
        }
        return didUndo
    }

    @discardableResult
    func redo() -> Bool {
        let didRedo = bridge.redo()
        if didRedo {
            invalidateThumbnailCache()
            captureTimelapseFrame()
        }
        return didRedo
    }

    func addLayer(name: String) {
        bridge.activeLayerIndex = bridge.addLayer(name: name)
        invalidateThumbnailCache(for: Int(bridge.activeLayerIndex))
        captureTimelapseFrame()
    }

    @discardableResult
    func deleteLayer(index: Int) -> Bool {
        let didDelete = bridge.deleteLayer(at: index)
        if didDelete {
            invalidateThumbnailCache()
            captureTimelapseFrame()
        }
        return didDelete
    }

    @discardableResult
    func moveLayer(from index: Int, to destinationIndex: Int) -> Bool {
        let didMove = bridge.moveLayer(at: index, to: destinationIndex)
        if didMove {
            invalidateThumbnailCache()
            captureTimelapseFrame()
        }
        return didMove
    }

    @discardableResult
    func createFolder(name: String, layerIndex: Int) -> Int {
        bridge.createFolder(name: name, layerIndex: layerIndex)
    }

    @discardableResult
    func deleteFolder(folderID: Int) -> Bool {
        let didDelete = bridge.deleteFolder(id: folderID)
        if didDelete {
            captureTimelapseFrame()
        }
        return didDelete
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) {
        bridge.setFolderVisible(isVisible, folderID: folderID)
        captureTimelapseFrame()
    }

    func setFolderName(folderID: Int, name: String) {
        bridge.setFolderName(name, folderID: folderID)
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) {
        bridge.setFolderExpanded(isExpanded, folderID: folderID)
    }

    @discardableResult
    func assignLayer(index: Int, toFolder folderID: Int) -> Bool {
        let didAssign = bridge.setLayerFolder(at: index, folderID: folderID)
        if didAssign {
            captureTimelapseFrame()
        }
        return didAssign
    }

    func setActiveLayer(index: Int) {
        bridge.activeLayerIndex = index
    }

    func setLayerName(index: Int, name: String) {
        bridge.setLayerName(name, at: index)
    }

    func setLayerVisibility(index: Int, isVisible: Bool) {
        bridge.setLayerVisible(isVisible, at: index)
        captureTimelapseFrame()
    }

    func revealLayerForEditing(index: Int) {
        bridge.setLayerVisible(true, at: index)
    }

    func setLayerOpacity(index: Int, opacity: Double) {
        bridge.setLayerOpacity(CGFloat(opacity), at: index)
        invalidateThumbnailCache(for: index)
        captureTimelapseFrame()
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) {
        bridge.setLayerBlendMode(blendMode.rawValue, at: index)
        invalidateThumbnailCache(for: index)
        captureTimelapseFrame()
    }

    func replaceLayerPixels(index: Int, data: Data) {
        bridge.replaceLayerPixels(at: index, data: data)
        invalidateThumbnailCache(for: index)
        captureTimelapseFrame()
    }

    func clearLayer(index: Int) {
        bridge.clearLayer(at: index)
        invalidateThumbnailCache(for: index)
        captureTimelapseFrame()
    }

    func setPaperStyle(_ style: CanvasPaperStyle) {
        paperStyle = style
    }

    private func buildLayerRows(from infos: [APPaintLayerInfo]) -> [LayerRowModel] {
        Array(infos.enumerated().map { index, layer in
            LayerRowModel(
                index: index,
                name: layer.name,
                visible: layer.visible,
                opacity: layer.opacity,
                blendMode: LayerBlendMode(rawValue: layer.blendMode) ?? .normal,
                folderID: layer.folderID >= 0 ? Int(layer.folderID) : nil
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

    func compositePNGData(paperStyle: CanvasPaperStyle) -> Data? {
        self.paperStyle = paperStyle
        return renderedCompositeImage(paperStyle: paperStyle)?.pngData()
    }

    func timelapseCapture() -> TimelapseCapture? {
        guard timelapseFrames.count >= 2 else { return nil }
        return TimelapseCapture(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            frames: timelapseFrames,
            framesPerSecond: 24
        )
    }

    func consumeDirtyUpdate() -> IncrementalLayerUpdate? {
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

    private func makeBrushDescriptor(from brush: BrushRuntimeSettings) -> APBrushDescriptor {
        let descriptor = APBrushDescriptor()
        descriptor.tipKind = brush.tipKind.rawValue
        descriptor.radius = brush.radius
        descriptor.sizeSpeedSensitivity = brush.sizeSpeedSensitivity
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
        descriptor.wetness = brush.wetness
        descriptor.wetnessPressureSensitivity = brush.wetnessPressureSensitivity
        descriptor.opacityPressureSensitivity = brush.opacityPressureSensitivity
        descriptor.colorMixStrength = brush.colorMixStrength
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
        descriptor.tiltInfluence = 0.75
        descriptor.maxDarkness = 0.95
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

    private func makeStrokePoint(from sample: StylusSample) -> APStrokePoint {
        let point = APStrokePoint()
        point.x = sample.point.x
        point.y = sample.point.y
        point.pressure = normalizedPressure(sample.pressure)
        point.altitude = sample.altitude
        point.azimuth = sample.azimuth
        point.timestamp = sample.timestamp
        return point
    }

    private func normalizedPressure(_ pressure: CGFloat) -> CGFloat {
        max(0.08, min(max(pressure, 0.0), 1.0))
    }

    private func captureTimelapseFrame() {
        guard let sourceImage = makeTimelapseThumbnail() else { return }
        appendTimelapseFrame(image: sourceImage)
    }

    private func makeTimelapseThumbnail() -> UIImage? {
        guard let sourceImage = renderedCompositeImage(paperStyle: paperStyle) else { return nil }
        let targetSize = timelapseFrameSize(
            for: CGSize(width: bridge.width, height: bridge.height),
            maxDimension: 512
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func appendTimelapseFrame(image: UIImage) {
        guard let jpegData = image.jpegData(compressionQuality: 0.72) else { return }
        let frameURL = timelapseDirectoryURL.appendingPathComponent(String(format: "frame-%06d.jpg", nextTimelapseFrameID))
        nextTimelapseFrameID += 1
        do {
            try jpegData.write(to: frameURL, options: .atomic)
        } catch {
            Self.logger.error("Failed to persist timelapse frame: \(error.localizedDescription, privacy: .public)")
            return
        }

        let frame = TimelapseFrame(imageURL: frameURL, size: image.size)
        timelapseFrames.append(frame)
        if timelapseFrames.count > Self.maxTimelapseFrames {
            let removed = timelapseFrames.remove(at: 1)
            try? FileManager.default.removeItem(at: removed.imageURL)
        }
    }

    private static func makeTimelapseDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("atelierprime-timelapse", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func timelapseFrameSize(for canvasSize: CGSize, maxDimension: CGFloat) -> CGSize {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return CGSize(width: maxDimension, height: maxDimension)
        }
        let scale = min(maxDimension / canvasSize.width, maxDimension / canvasSize.height, 1.0)
        let width = max(2, Int((canvasSize.width * scale).rounded()))
        let height = max(2, Int((canvasSize.height * scale).rounded()))
        return CGSize(width: width, height: height)
    }

    private func renderedCompositeImage(paperStyle: CanvasPaperStyle) -> UIImage? {
        guard let imageRef = bridge.makeCompositeImage() else { return nil }
        let compositeImage = UIImage(cgImage: imageRef)
        let size = CGSize(width: bridge.width, height: bridge.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !paperStyle.isTransparent
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            if !paperStyle.isTransparent {
                UIColor(
                    red: CGFloat(paperStyle.red),
                    green: CGFloat(paperStyle.green),
                    blue: CGFloat(paperStyle.blue),
                    alpha: CGFloat(paperStyle.alpha)
                ).setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            compositeImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func cachedLayerThumbnailData(index: Int) -> Data? {
        if let cached = layerThumbnailCache[index] {
            return cached
        }
        let thumbnail = makeLayerThumbnailData(index: index)
        layerThumbnailCache[index] = thumbnail
        return thumbnail
    }

    private func makeLayerThumbnailData(index: Int) -> Data? {
        guard let imageRef = bridge.makeImageForLayer(at: index) else { return nil }
        let sourceImage = UIImage(cgImage: imageRef)
        let targetSize = timelapseFrameSize(
            for: CGSize(width: bridge.width, height: bridge.height),
            maxDimension: 96
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let thumbnail = renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return thumbnail.pngData()
    }

    private func invalidateThumbnailCache(for index: Int? = nil) {
        if let index {
            layerThumbnailCache.removeValue(forKey: index)
        } else {
            layerThumbnailCache.removeAll(keepingCapacity: true)
        }
    }

    private func boxBlurredPixels(from original: [UInt8], width: Int, height: Int, radius: Double) -> [UInt8]? {
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
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: width * 4
                    )
                    var destinationBuffer = vImage_Buffer(
                        data: destinationBytes.baseAddress!,
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: width * 4
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

    private func blendBlurredPixels(
        original: [UInt8],
        blurred: [UInt8],
        width: Int,
        height: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> [UInt8] {
        var output = original
        let influenceRadius = max(4.0, brush.radius * 1.35)
        let blurStrength = max(0.08, min(brush.flow, 1.0))
        let softness = max(0.12, 1.0 - brush.hardness)
        let sampleXs = samples.map { Double($0.point.x) }
        let sampleYs = samples.map { Double($0.point.y) }
        let minX = max(0, Int((sampleXs.min() ?? 0) - influenceRadius - 2))
        let maxX = min(width - 1, Int((sampleXs.max() ?? 0) + influenceRadius + 2))
        let minY = max(0, Int((sampleYs.min() ?? 0) - influenceRadius - 2))
        let maxY = min(height - 1, Int((sampleYs.max() ?? 0) + influenceRadius + 2))

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
                let pixelIndex = ((y * width) + x) * 4
                for channel in 0..<4 {
                    let originalValue = Float(original[pixelIndex + channel])
                    let blurredValue = Float(blurred[pixelIndex + channel])
                    output[pixelIndex + channel] = UInt8(max(0, min(255, Int((originalValue + ((blurredValue - originalValue) * strength)).rounded()))))
                }
            }
        }

        return output
    }
}
