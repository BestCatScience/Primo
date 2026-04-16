import CoreGraphics
import Foundation

enum TimelapseOperation: Equatable, Sendable {
    case stroke(layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])
    case blurStroke(layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])
    case fill(layerIndex: Int, brush: BrushRuntimeSettings, sample: StylusSample)
    case undo
    case redo
    case addLayer(name: String)
    case duplicateLayer(index: Int, name: String)
    case deleteLayer(index: Int)
    case moveLayer(index: Int, destinationIndex: Int)
    case createFolder(folderID: Int, name: String, anchorLayerIndex: Int?)
    case deleteFolder(folderID: Int)
    case setFolderVisibility(folderID: Int, isVisible: Bool)
    case assignLayerToFolder(index: Int, folderID: Int?)
    case setLayerVisibility(index: Int, isVisible: Bool)
    case setLayerLocked(index: Int, isLocked: Bool)
    case setLayerAlphaLocked(index: Int, isAlphaLocked: Bool)
    case setLayerClipped(index: Int, isClipped: Bool)
    case setLayerOpacity(index: Int, opacity: Double)
    case setLayerBlendMode(index: Int, blendMode: LayerBlendMode)
    case replaceLayerPixels(index: Int, data: Data)
    case replaceLayerMask(index: Int, data: Data)
    case clearLayerMask(index: Int)
    case applyLayerMask(index: Int)
    case clearLayer(index: Int)
    case setPaperStyle(CanvasPaperStyle)

    func storedRepresentation(index: Int, dataDirectory: URL, fileClient: FileClient = .live) throws -> StoredTimelapseOperation {
        let dataFilename: String?
        switch self {
        case let .replaceLayerPixels(_, data):
            let filename = String(format: "replace-layer-%06d.rgba", index)
            try fileClient.writeData(data, dataDirectory.appendingPathComponent(filename, isDirectory: false), .atomic)
            dataFilename = "TimelapseData/\(filename)"
        case let .replaceLayerMask(_, data):
            let filename = String(format: "replace-mask-%06d.mask", index)
            try fileClient.writeData(data, dataDirectory.appendingPathComponent(filename, isDirectory: false), .atomic)
            dataFilename = "TimelapseData/\(filename)"
        default:
            dataFilename = nil
        }

        switch self {
        case let .stroke(layerIndex, brush, samples):
            return StoredTimelapseOperation(
                kind: .stroke,
                layerIndex: layerIndex,
                brush: StoredBrushRuntimeSettings(brush),
                samples: samples.map(StoredStylusSample.init),
                dataFilename: nil
            )
        case let .blurStroke(layerIndex, brush, samples):
            return StoredTimelapseOperation(
                kind: .blurStroke,
                layerIndex: layerIndex,
                brush: StoredBrushRuntimeSettings(brush),
                samples: samples.map(StoredStylusSample.init),
                dataFilename: nil
            )
        case let .fill(layerIndex, brush, sample):
            return StoredTimelapseOperation(
                kind: .fill,
                layerIndex: layerIndex,
                brush: StoredBrushRuntimeSettings(brush),
                sample: StoredStylusSample(sample),
                dataFilename: nil
            )
        case .undo:
            return StoredTimelapseOperation(kind: .undo)
        case .redo:
            return StoredTimelapseOperation(kind: .redo)
        case let .addLayer(name):
            return StoredTimelapseOperation(kind: .addLayer, name: name)
        case let .duplicateLayer(index, name):
            return StoredTimelapseOperation(kind: .duplicateLayer, layerIndex: index, name: name)
        case let .deleteLayer(index):
            return StoredTimelapseOperation(kind: .deleteLayer, layerIndex: index)
        case let .moveLayer(index, destinationIndex):
            return StoredTimelapseOperation(kind: .moveLayer, layerIndex: index, destinationIndex: destinationIndex)
        case let .createFolder(folderID, name, anchorLayerIndex):
            return StoredTimelapseOperation(
                kind: .createFolder,
                folderID: folderID,
                anchorLayerIndex: anchorLayerIndex,
                name: name
            )
        case let .deleteFolder(folderID):
            return StoredTimelapseOperation(kind: .deleteFolder, folderID: folderID)
        case let .setFolderVisibility(folderID, isVisible):
            return StoredTimelapseOperation(kind: .setFolderVisibility, folderID: folderID, isVisible: isVisible)
        case let .assignLayerToFolder(index, folderID):
            return StoredTimelapseOperation(kind: .assignLayerToFolder, layerIndex: index, folderID: folderID)
        case let .setLayerVisibility(index, isVisible):
            return StoredTimelapseOperation(kind: .setLayerVisibility, layerIndex: index, isVisible: isVisible)
        case let .setLayerLocked(index, isLocked):
            return StoredTimelapseOperation(kind: .setLayerLocked, layerIndex: index, isLocked: isLocked)
        case let .setLayerAlphaLocked(index, isAlphaLocked):
            return StoredTimelapseOperation(kind: .setLayerAlphaLocked, layerIndex: index, isAlphaLocked: isAlphaLocked)
        case let .setLayerClipped(index, isClipped):
            return StoredTimelapseOperation(kind: .setLayerClipped, layerIndex: index, isClipped: isClipped)
        case let .setLayerOpacity(index, opacity):
            return StoredTimelapseOperation(kind: .setLayerOpacity, layerIndex: index, opacity: opacity)
        case let .setLayerBlendMode(index, blendMode):
            return StoredTimelapseOperation(kind: .setLayerBlendMode, layerIndex: index, blendMode: blendMode.rawValue)
        case let .replaceLayerPixels(index, _):
            return StoredTimelapseOperation(kind: .replaceLayerPixels, layerIndex: index, dataFilename: dataFilename)
        case let .replaceLayerMask(index, _):
            return StoredTimelapseOperation(kind: .replaceLayerMask, layerIndex: index, dataFilename: dataFilename)
        case let .clearLayerMask(index):
            return StoredTimelapseOperation(kind: .clearLayerMask, layerIndex: index)
        case let .applyLayerMask(index):
            return StoredTimelapseOperation(kind: .applyLayerMask, layerIndex: index)
        case let .clearLayer(index):
            return StoredTimelapseOperation(kind: .clearLayer, layerIndex: index)
        case let .setPaperStyle(style):
            return StoredTimelapseOperation(kind: .setPaperStyle, paperStyle: StoredPrimoDocument.PaperStyle(
                red: Double(style.red),
                green: Double(style.green),
                blue: Double(style.blue),
                alpha: Double(style.alpha),
                isTransparent: style.isTransparent
            ))
        }
    }

    init(
        stored: StoredTimelapseOperation,
        baseURL: URL,
        fileClient: FileClient = .live
    ) throws {
        switch stored.kind {
        case .stroke:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let samples = stored.samples?.map(\.stylusSample)
            else { throw PrimoDocumentError.invalidDocument }
            self = .stroke(layerIndex: layerIndex, brush: brush, samples: samples)
        case .blurStroke:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let samples = stored.samples?.map(\.stylusSample)
            else { throw PrimoDocumentError.invalidDocument }
            self = .blurStroke(layerIndex: layerIndex, brush: brush, samples: samples)
        case .fill:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let sample = stored.sample?.stylusSample
            else { throw PrimoDocumentError.invalidDocument }
            self = .fill(layerIndex: layerIndex, brush: brush, sample: sample)
        case .undo:
            self = .undo
        case .redo:
            self = .redo
        case .addLayer:
            guard let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .addLayer(name: name)
        case .duplicateLayer:
            guard let layerIndex = stored.layerIndex, let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .duplicateLayer(index: layerIndex, name: name)
        case .deleteLayer:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .deleteLayer(index: layerIndex)
        case .moveLayer:
            guard let layerIndex = stored.layerIndex, let destinationIndex = stored.destinationIndex else {
                throw PrimoDocumentError.invalidDocument
            }
            self = .moveLayer(index: layerIndex, destinationIndex: destinationIndex)
        case .createFolder:
            guard let folderID = stored.folderID, let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .createFolder(folderID: folderID, name: name, anchorLayerIndex: stored.anchorLayerIndex)
        case .deleteFolder:
            guard let folderID = stored.folderID else { throw PrimoDocumentError.invalidDocument }
            self = .deleteFolder(folderID: folderID)
        case .setFolderVisibility:
            guard let folderID = stored.folderID, let isVisible = stored.isVisible else { throw PrimoDocumentError.invalidDocument }
            self = .setFolderVisibility(folderID: folderID, isVisible: isVisible)
        case .assignLayerToFolder:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .assignLayerToFolder(index: layerIndex, folderID: stored.folderID)
        case .setLayerVisibility:
            guard let layerIndex = stored.layerIndex, let isVisible = stored.isVisible else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerVisibility(index: layerIndex, isVisible: isVisible)
        case .setLayerLocked:
            guard let layerIndex = stored.layerIndex, let isLocked = stored.isLocked else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerLocked(index: layerIndex, isLocked: isLocked)
        case .setLayerAlphaLocked:
            guard let layerIndex = stored.layerIndex, let isAlphaLocked = stored.isAlphaLocked else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerAlphaLocked(index: layerIndex, isAlphaLocked: isAlphaLocked)
        case .setLayerClipped:
            guard let layerIndex = stored.layerIndex, let isClipped = stored.isClipped else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerClipped(index: layerIndex, isClipped: isClipped)
        case .setLayerOpacity:
            guard let layerIndex = stored.layerIndex, let opacity = stored.opacity else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerOpacity(index: layerIndex, opacity: opacity)
        case .setLayerBlendMode:
            guard let layerIndex = stored.layerIndex,
                  let blendModeRaw = stored.blendMode,
                  let blendMode = LayerBlendMode(rawValue: blendModeRaw)
            else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerBlendMode(index: layerIndex, blendMode: blendMode)
        case .replaceLayerPixels:
            guard let layerIndex = stored.layerIndex, let dataFilename = stored.dataFilename else {
                throw PrimoDocumentError.invalidDocument
            }
            let data = try fileClient.readData(baseURL.appendingPathComponent(dataFilename, isDirectory: false))
            self = .replaceLayerPixels(index: layerIndex, data: data)
        case .replaceLayerMask:
            guard let layerIndex = stored.layerIndex, let dataFilename = stored.dataFilename else {
                throw PrimoDocumentError.invalidDocument
            }
            let data = try fileClient.readData(baseURL.appendingPathComponent(dataFilename, isDirectory: false))
            self = .replaceLayerMask(index: layerIndex, data: data)
        case .clearLayerMask:
            guard let layerIndex: Int = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .clearLayerMask(index: layerIndex)
        case .applyLayerMask:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .applyLayerMask(index: layerIndex)
        case .clearLayer:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .clearLayer(index: layerIndex)
        case .setPaperStyle:
            guard let paperStyle = stored.paperStyle else { throw PrimoDocumentError.invalidDocument }
            self = .setPaperStyle(
                CanvasPaperStyle(
                    red: Float(paperStyle.red),
                    green: Float(paperStyle.green),
                    blue: Float(paperStyle.blue),
                    alpha: Float(paperStyle.alpha),
                    isTransparent: paperStyle.isTransparent
                )
            )
        }
    }
}

struct StoredPrimoDocument: Codable {
    struct PaperStyle: Codable, Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        let isTransparent: Bool
    }

    struct Layer: Codable {
        let index: Int
        let name: String
        let visible: Bool
        let locked: Bool
        let alphaLocked: Bool
        let clipped: Bool
        let opacity: Double
        let blendMode: String
        let folderID: Int?
        let textLayer: TextLayerData?
        let pixelFilename: String
        let maskFilename: String?

        enum CodingKeys: String, CodingKey {
            case index
            case name
            case visible
            case locked
            case alphaLocked
            case clipped
            case opacity
            case blendMode
            case folderID
            case textLayer
            case pixelFilename
            case maskFilename
        }

        init(
            index: Int,
            name: String,
            visible: Bool,
            locked: Bool,
            alphaLocked: Bool,
            clipped: Bool,
            opacity: Double,
            blendMode: String,
            folderID: Int?,
            textLayer: TextLayerData?,
            pixelFilename: String,
            maskFilename: String?
        ) {
            self.index = index
            self.name = name
            self.visible = visible
            self.locked = locked
            self.alphaLocked = alphaLocked
            self.clipped = clipped
            self.opacity = opacity
            self.blendMode = blendMode
            self.folderID = folderID
            self.textLayer = textLayer
            self.pixelFilename = pixelFilename
            self.maskFilename = maskFilename
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            index = try container.decode(Int.self, forKey: .index)
            name = try container.decode(String.self, forKey: .name)
            visible = try container.decode(Bool.self, forKey: .visible)
            locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
            alphaLocked = try container.decodeIfPresent(Bool.self, forKey: .alphaLocked) ?? false
            clipped = try container.decodeIfPresent(Bool.self, forKey: .clipped) ?? false
            opacity = try container.decode(Double.self, forKey: .opacity)
            blendMode = try container.decode(String.self, forKey: .blendMode)
            folderID = try container.decodeIfPresent(Int.self, forKey: .folderID)
            textLayer = try container.decodeIfPresent(TextLayerData.self, forKey: .textLayer)
            pixelFilename = try container.decode(String.self, forKey: .pixelFilename)
            maskFilename = try container.decodeIfPresent(String.self, forKey: .maskFilename)
        }
    }

    struct Folder: Codable {
        let id: Int
        let name: String
        let visible: Bool
        let expanded: Bool
        let anchorLayerIndex: Int?
    }

    struct TimelapseFrame: Codable {
        let filename: String
        let width: Double
        let height: Double
    }

    let version: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let activeLayerIndex: Int
    let paperStyle: PaperStyle
    let layers: [Layer]
    let folders: [Folder]
    let timelapseFrames: [TimelapseFrame]
    let timelapseOperations: [StoredTimelapseOperation]

    enum CodingKeys: String, CodingKey {
        case version
        case canvasWidth
        case canvasHeight
        case activeLayerIndex
        case paperStyle
        case layers
        case folders
        case timelapseFrames
        case timelapseOperations
    }

    init(
        version: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        activeLayerIndex: Int,
        paperStyle: PaperStyle,
        layers: [Layer],
        folders: [Folder],
        timelapseFrames: [TimelapseFrame],
        timelapseOperations: [StoredTimelapseOperation]
    ) {
        self.version = version
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.activeLayerIndex = activeLayerIndex
        self.paperStyle = paperStyle
        self.layers = layers
        self.folders = folders
        self.timelapseFrames = timelapseFrames
        self.timelapseOperations = timelapseOperations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        canvasWidth = try container.decode(Int.self, forKey: .canvasWidth)
        canvasHeight = try container.decode(Int.self, forKey: .canvasHeight)
        activeLayerIndex = try container.decode(Int.self, forKey: .activeLayerIndex)
        paperStyle = try container.decode(PaperStyle.self, forKey: .paperStyle)
        layers = try container.decode([Layer].self, forKey: .layers)
        folders = try container.decodeIfPresent([Folder].self, forKey: .folders) ?? []
        timelapseFrames = try container.decodeIfPresent([TimelapseFrame].self, forKey: .timelapseFrames) ?? []
        timelapseOperations = try container.decodeIfPresent([StoredTimelapseOperation].self, forKey: .timelapseOperations) ?? []
    }
}

struct StoredStylusSample: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let pressure: Double
    let altitude: Double
    let azimuth: Double
    let timestamp: Double

    init(_ sample: StylusSample) {
        x = Double(sample.point.x)
        y = Double(sample.point.y)
        pressure = Double(sample.pressure)
        altitude = Double(sample.altitude)
        azimuth = Double(sample.azimuth)
        timestamp = sample.timestamp
    }

    var stylusSample: StylusSample {
        StylusSample(
            point: CGPoint(x: CGFloat(x), y: CGFloat(y)),
            pressure: CGFloat(pressure),
            altitude: CGFloat(altitude),
            azimuth: CGFloat(azimuth),
            timestamp: timestamp
        )
    }
}

struct StoredBrushTipRaster: Codable, Equatable, Sendable {
    let width: Int
    let height: Int
    let alphaData: Data

    init(_ raster: BrushTipRaster) {
        width = raster.width
        height = raster.height
        alphaData = raster.alphaData
    }

    var raster: BrushTipRaster {
        BrushTipRaster(width: width, height: height, alphaData: alphaData)
    }
}

struct StoredBrushRuntimeSettings: Codable, Equatable, Sendable {
    let tipKind: String
    let radius: Double
    let sizeSpeedSensitivity: Double
    let taperIn: Double
    let taperOut: Double
    let opacity: Double
    let hardness: Double
    let roundness: Double
    let roundnessPressureSensitivity: Double
    let roundnessTiltSensitivity: Double
    let angle: Double
    let anglePressureSensitivity: Double
    let angleTiltSensitivity: Double
    let angleMode: String
    let stampSpacing: Double
    let spacingJitter: Double
    let scatterEnabled: Bool
    let scatterMode: String
    let scatterLateral: Double
    let scatterLinear: Double
    let count: Int
    let countJitter: Double
    let countSizeJitter: Double
    let countOpacityJitter: Double
    let angleJitter: Double
    let roundnessJitter: Double
    let textureMode: String
    let textureStrength: Double
    let flow: Double
    let flowPressureSensitivity: Double
    let flowJitter: Double
    let velocityInfluence: Double
    let colorMixingMode: String?
    let wetness: Double
    let wetnessPressureSensitivity: Double
    let opacityPressureSensitivity: Double
    let colorMixStrength: Double
    let smudgeBlurEnabled: Bool
    let smudgeBleed: Double
    let smudgeRadius: Double
    let paintLoad: Double
    let loadPressureSensitivity: Double
    let dualBrushEnabled: Bool
    let dualTipKind: String
    let dualScale: Double
    let dualSpacing: Double
    let dualScatter: Double
    let dualAngle: Double
    let dualBlendMode: String
    let grainScale: Double
    let grainContrast: Double
    let paperScale: Double
    let paperStrength: Double
    let paperThreshold: Double
    let flipX: Bool
    let flipY: Bool
    let customTip: StoredBrushTipRaster?
    let pressureSensitivity: Double
    let stabilization: Double
    let fillThresholdMode: String
    let fillOpacityTolerance: Double
    let fillColorTolerance: Double
    let fillExpansion: Int
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let isEraser: Bool

    init(_ brush: BrushRuntimeSettings) {
        tipKind = brush.tipKind.rawValue
        radius = brush.radius
        sizeSpeedSensitivity = brush.sizeSpeedSensitivity
        taperIn = brush.taperIn
        taperOut = brush.taperOut
        opacity = brush.opacity
        hardness = brush.hardness
        roundness = brush.roundness
        roundnessPressureSensitivity = brush.roundnessPressureSensitivity
        roundnessTiltSensitivity = brush.roundnessTiltSensitivity
        angle = brush.angle
        anglePressureSensitivity = brush.anglePressureSensitivity
        angleTiltSensitivity = brush.angleTiltSensitivity
        angleMode = brush.angleMode.rawValue
        stampSpacing = brush.stampSpacing
        spacingJitter = brush.spacingJitter
        scatterEnabled = brush.scatterEnabled
        scatterMode = brush.scatterMode.rawValue
        scatterLateral = brush.scatterLateral
        scatterLinear = brush.scatterLinear
        count = brush.count
        countJitter = brush.countJitter
        countSizeJitter = brush.countSizeJitter
        countOpacityJitter = brush.countOpacityJitter
        angleJitter = brush.angleJitter
        roundnessJitter = brush.roundnessJitter
        textureMode = brush.textureMode.rawValue
        textureStrength = brush.textureStrength
        flow = brush.flow
        flowPressureSensitivity = brush.flowPressureSensitivity
        flowJitter = brush.flowJitter
        velocityInfluence = brush.velocityInfluence
        colorMixingMode = brush.colorMixingMode.rawValue
        wetness = brush.wetness
        wetnessPressureSensitivity = brush.wetnessPressureSensitivity
        opacityPressureSensitivity = brush.opacityPressureSensitivity
        colorMixStrength = brush.colorMixStrength
        smudgeBlurEnabled = brush.smudgeBlurEnabled
        smudgeBleed = brush.smudgeBleed
        smudgeRadius = brush.smudgeRadius
        paintLoad = brush.paintLoad
        loadPressureSensitivity = brush.loadPressureSensitivity
        dualBrushEnabled = brush.dualBrushEnabled
        dualTipKind = brush.dualTipKind.rawValue
        dualScale = brush.dualScale
        dualSpacing = brush.dualSpacing
        dualScatter = brush.dualScatter
        dualAngle = brush.dualAngle
        dualBlendMode = brush.dualBlendMode.rawValue
        grainScale = brush.grainScale
        grainContrast = brush.grainContrast
        paperScale = brush.paperScale
        paperStrength = brush.paperStrength
        paperThreshold = brush.paperThreshold
        flipX = brush.flipX
        flipY = brush.flipY
        customTip = brush.customTip.map(StoredBrushTipRaster.init)
        pressureSensitivity = brush.pressureSensitivity
        stabilization = brush.stabilization
        fillThresholdMode = brush.fillThresholdMode.rawValue
        fillOpacityTolerance = brush.fillOpacityTolerance
        fillColorTolerance = brush.fillColorTolerance
        fillExpansion = brush.fillExpansion
        red = brush.red
        green = brush.green
        blue = brush.blue
        isEraser = brush.isEraser
    }

    var runtimeSettings: BrushRuntimeSettings? {
        guard let tipKind = BrushTipKind(rawValue: tipKind),
              let angleMode = BrushAngleMode(rawValue: angleMode),
              let scatterMode = BrushScatterMode(rawValue: scatterMode),
              let textureMode = BrushTextureMode(rawValue: textureMode),
              let dualTipKind = BrushTipKind(rawValue: dualTipKind),
              let dualBlendMode = BrushDualBlendMode(rawValue: dualBlendMode),
              let fillThresholdMode = FillThresholdMode(rawValue: fillThresholdMode)
        else {
            return nil
        }
        let resolvedColorMixingMode = BrushColorMixingMode(rawValue: colorMixingMode ?? "") ?? BrushColorMixingMode.inferred(
            wetness: wetness,
            colorMixStrength: colorMixStrength,
            smudgeBlurEnabled: smudgeBlurEnabled,
            smudgeBleed: smudgeBleed,
            smudgeRadius: smudgeRadius,
            paintLoad: paintLoad
        )

        return BrushRuntimeSettings(
            tipKind: tipKind,
            radius: radius,
            sizeSpeedSensitivity: sizeSpeedSensitivity,
            taperIn: taperIn,
            taperOut: taperOut,
            opacity: opacity,
            hardness: hardness,
            roundness: roundness,
            roundnessPressureSensitivity: roundnessPressureSensitivity,
            roundnessTiltSensitivity: roundnessTiltSensitivity,
            angle: angle,
            anglePressureSensitivity: anglePressureSensitivity,
            angleTiltSensitivity: angleTiltSensitivity,
            angleMode: angleMode,
            stampSpacing: stampSpacing,
            spacingJitter: spacingJitter,
            scatterEnabled: scatterEnabled,
            scatterMode: scatterMode,
            scatterLateral: scatterLateral,
            scatterLinear: scatterLinear,
            count: count,
            countJitter: countJitter,
            countSizeJitter: countSizeJitter,
            countOpacityJitter: countOpacityJitter,
            angleJitter: angleJitter,
            roundnessJitter: roundnessJitter,
            textureMode: textureMode,
            textureStrength: textureStrength,
            flow: flow,
            flowPressureSensitivity: flowPressureSensitivity,
            flowJitter: flowJitter,
            velocityInfluence: velocityInfluence,
            colorMixingMode: resolvedColorMixingMode,
            wetness: wetness,
            wetnessPressureSensitivity: wetnessPressureSensitivity,
            opacityPressureSensitivity: opacityPressureSensitivity,
            colorMixStrength: colorMixStrength,
            smudgeBlurEnabled: smudgeBlurEnabled,
            smudgeBleed: smudgeBleed,
            smudgeRadius: smudgeRadius,
            paintLoad: paintLoad,
            loadPressureSensitivity: loadPressureSensitivity,
            dualBrushEnabled: dualBrushEnabled,
            dualTipKind: dualTipKind,
            dualScale: dualScale,
            dualSpacing: dualSpacing,
            dualScatter: dualScatter,
            dualAngle: dualAngle,
            dualBlendMode: dualBlendMode,
            grainScale: grainScale,
            grainContrast: grainContrast,
            paperScale: paperScale,
            paperStrength: paperStrength,
            paperThreshold: paperThreshold,
            flipX: flipX,
            flipY: flipY,
            customTip: customTip?.raster,
            pressureSensitivity: pressureSensitivity,
            stabilization: stabilization,
            fillThresholdMode: fillThresholdMode,
            fillOpacityTolerance: fillOpacityTolerance,
            fillColorTolerance: fillColorTolerance,
            fillExpansion: fillExpansion,
            red: red,
            green: green,
            blue: blue,
            isEraser: isEraser
        )
    }
}

struct StoredTimelapseOperation: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Equatable, Sendable {
        case stroke
        case blurStroke
        case fill
        case undo
        case redo
        case addLayer
        case duplicateLayer
        case deleteLayer
        case moveLayer
        case createFolder
        case deleteFolder
        case setFolderVisibility
        case assignLayerToFolder
        case setLayerVisibility
        case setLayerLocked
        case setLayerAlphaLocked
        case setLayerClipped
        case setLayerOpacity
        case setLayerBlendMode
        case replaceLayerPixels
        case replaceLayerMask
        case clearLayerMask
        case applyLayerMask
        case clearLayer
        case setPaperStyle
    }

    let kind: Kind
    var layerIndex: Int?
    var destinationIndex: Int?
    var folderID: Int?
    var anchorLayerIndex: Int?
    var name: String?
    var isVisible: Bool?
    var isLocked: Bool?
    var isAlphaLocked: Bool?
    var isClipped: Bool?
    var opacity: Double?
    var blendMode: String?
    var brush: StoredBrushRuntimeSettings?
    var samples: [StoredStylusSample]?
    var sample: StoredStylusSample?
    var dataFilename: String?
    var paperStyle: StoredPrimoDocument.PaperStyle?

    init(
        kind: Kind,
        layerIndex: Int? = nil,
        destinationIndex: Int? = nil,
        folderID: Int? = nil,
        anchorLayerIndex: Int? = nil,
        name: String? = nil,
        isVisible: Bool? = nil,
        isLocked: Bool? = nil,
        isAlphaLocked: Bool? = nil,
        isClipped: Bool? = nil,
        opacity: Double? = nil,
        blendMode: String? = nil,
        brush: StoredBrushRuntimeSettings? = nil,
        samples: [StoredStylusSample]? = nil,
        sample: StoredStylusSample? = nil,
        dataFilename: String? = nil,
        paperStyle: StoredPrimoDocument.PaperStyle? = nil
    ) {
        self.kind = kind
        self.layerIndex = layerIndex
        self.destinationIndex = destinationIndex
        self.folderID = folderID
        self.anchorLayerIndex = anchorLayerIndex
        self.name = name
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.isAlphaLocked = isAlphaLocked
        self.isClipped = isClipped
        self.opacity = opacity
        self.blendMode = blendMode
        self.brush = brush
        self.samples = samples
        self.sample = sample
        self.dataFilename = dataFilename
        self.paperStyle = paperStyle
    }
}

enum PrimoDocumentError: LocalizedError {
    case invalidDocument

    var errorDescription: String? {
        "The selected Primo document is invalid."
    }
}
