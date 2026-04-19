import CoreGraphics
import Foundation

struct PaintDocumentBridgeDescriptorService {
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
}
