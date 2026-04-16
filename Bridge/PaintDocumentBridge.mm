#import "PaintDocumentBridge.h"

#import <UIKit/UIKit.h>

#include "../Engine/include/PaintEngine.hpp"
#include <cmath>
#include <memory>

namespace {

primo::Layer::BlendMode APBlendModeFromString(NSString *blendMode) {
    if ([blendMode isEqualToString:@"darken"]) {
        return primo::Layer::BlendMode::Darken;
    }
    if ([blendMode isEqualToString:@"multiply"]) {
        return primo::Layer::BlendMode::Multiply;
    }
    if ([blendMode isEqualToString:@"colorBurn"]) {
        return primo::Layer::BlendMode::ColorBurn;
    }
    if ([blendMode isEqualToString:@"linearBurn"]) {
        return primo::Layer::BlendMode::LinearBurn;
    }
    if ([blendMode isEqualToString:@"subtract"]) {
        return primo::Layer::BlendMode::Subtract;
    }
    if ([blendMode isEqualToString:@"lighten"]) {
        return primo::Layer::BlendMode::Lighten;
    }
    if ([blendMode isEqualToString:@"screen"]) {
        return primo::Layer::BlendMode::Screen;
    }
    if ([blendMode isEqualToString:@"add"]) {
        return primo::Layer::BlendMode::Add;
    }
    if ([blendMode isEqualToString:@"colorDodge"]) {
        return primo::Layer::BlendMode::ColorDodge;
    }
    if ([blendMode isEqualToString:@"glowDodge"]) {
        return primo::Layer::BlendMode::GlowDodge;
    }
    if ([blendMode isEqualToString:@"overlay"]) {
        return primo::Layer::BlendMode::Overlay;
    }
    if ([blendMode isEqualToString:@"softLight"]) {
        return primo::Layer::BlendMode::SoftLight;
    }
    if ([blendMode isEqualToString:@"hardLight"]) {
        return primo::Layer::BlendMode::HardLight;
    }
    if ([blendMode isEqualToString:@"difference"]) {
        return primo::Layer::BlendMode::Difference;
    }
    if ([blendMode isEqualToString:@"vividLight"]) {
        return primo::Layer::BlendMode::VividLight;
    }
    if ([blendMode isEqualToString:@"linearLight"]) {
        return primo::Layer::BlendMode::LinearLight;
    }
    if ([blendMode isEqualToString:@"pinLight"]) {
        return primo::Layer::BlendMode::PinLight;
    }
    if ([blendMode isEqualToString:@"hardMix"]) {
        return primo::Layer::BlendMode::HardMix;
    }
    if ([blendMode isEqualToString:@"exclusion"]) {
        return primo::Layer::BlendMode::Exclusion;
    }
    if ([blendMode isEqualToString:@"darkerColor"]) {
        return primo::Layer::BlendMode::DarkerColor;
    }
    if ([blendMode isEqualToString:@"lighterColor"]) {
        return primo::Layer::BlendMode::LighterColor;
    }
    if ([blendMode isEqualToString:@"divide"]) {
        return primo::Layer::BlendMode::Divide;
    }
    if ([blendMode isEqualToString:@"hue"]) {
        return primo::Layer::BlendMode::Hue;
    }
    if ([blendMode isEqualToString:@"saturation"]) {
        return primo::Layer::BlendMode::Saturation;
    }
    if ([blendMode isEqualToString:@"color"]) {
        return primo::Layer::BlendMode::Color;
    }
    if ([blendMode isEqualToString:@"addGlow"]) {
        return primo::Layer::BlendMode::AddGlow;
    }
    if ([blendMode isEqualToString:@"luminosity"]) {
        return primo::Layer::BlendMode::Luminosity;
    }
    return primo::Layer::BlendMode::Normal;
}

NSString *APStringFromBlendMode(primo::Layer::BlendMode blendMode) {
    switch (blendMode) {
        case primo::Layer::BlendMode::Darken:
            return @"darken";
        case primo::Layer::BlendMode::Multiply:
            return @"multiply";
        case primo::Layer::BlendMode::ColorBurn:
            return @"colorBurn";
        case primo::Layer::BlendMode::LinearBurn:
            return @"linearBurn";
        case primo::Layer::BlendMode::Subtract:
            return @"subtract";
        case primo::Layer::BlendMode::Lighten:
            return @"lighten";
        case primo::Layer::BlendMode::Screen:
            return @"screen";
        case primo::Layer::BlendMode::Add:
            return @"add";
        case primo::Layer::BlendMode::ColorDodge:
            return @"colorDodge";
        case primo::Layer::BlendMode::GlowDodge:
            return @"glowDodge";
        case primo::Layer::BlendMode::Overlay:
            return @"overlay";
        case primo::Layer::BlendMode::SoftLight:
            return @"softLight";
        case primo::Layer::BlendMode::HardLight:
            return @"hardLight";
        case primo::Layer::BlendMode::Difference:
            return @"difference";
        case primo::Layer::BlendMode::VividLight:
            return @"vividLight";
        case primo::Layer::BlendMode::LinearLight:
            return @"linearLight";
        case primo::Layer::BlendMode::PinLight:
            return @"pinLight";
        case primo::Layer::BlendMode::HardMix:
            return @"hardMix";
        case primo::Layer::BlendMode::Exclusion:
            return @"exclusion";
        case primo::Layer::BlendMode::DarkerColor:
            return @"darkerColor";
        case primo::Layer::BlendMode::LighterColor:
            return @"lighterColor";
        case primo::Layer::BlendMode::Divide:
            return @"divide";
        case primo::Layer::BlendMode::Hue:
            return @"hue";
        case primo::Layer::BlendMode::Saturation:
            return @"saturation";
        case primo::Layer::BlendMode::Color:
            return @"color";
        case primo::Layer::BlendMode::AddGlow:
            return @"addGlow";
        case primo::Layer::BlendMode::Luminosity:
            return @"luminosity";
        case primo::Layer::BlendMode::Normal:
            return @"normal";
    }
}

primo::LayerProcessingKind APProcessingKind(APPaintLayerProcessingKind kind) {
    switch (kind) {
        case APPaintLayerProcessingKindReplacePixels:
            return primo::LayerProcessingKind::ReplacePixels;
        case APPaintLayerProcessingKindClear:
            return primo::LayerProcessingKind::Clear;
        case APPaintLayerProcessingKindGradientMap:
            return primo::LayerProcessingKind::GradientMap;
        case APPaintLayerProcessingKindHueSaturationBrightness:
            return primo::LayerProcessingKind::HueSaturationBrightness;
        case APPaintLayerProcessingKindBrightnessContrast:
            return primo::LayerProcessingKind::BrightnessContrast;
        case APPaintLayerProcessingKindLevels:
            return primo::LayerProcessingKind::Levels;
        case APPaintLayerProcessingKindToneCurve:
            return primo::LayerProcessingKind::ToneCurve;
        case APPaintLayerProcessingKindColorBalance:
            return primo::LayerProcessingKind::ColorBalance;
        case APPaintLayerProcessingKindThreshold:
            return primo::LayerProcessingKind::Threshold;
        case APPaintLayerProcessingKindPosterize:
            return primo::LayerProcessingKind::Posterize;
        case APPaintLayerProcessingKindTransform:
            return primo::LayerProcessingKind::Transform;
    }

    return primo::LayerProcessingKind::ReplacePixels;
}

primo::LayerProcessing APProcessingFromDescriptor(APPaintLayerProcessingDescriptor *descriptor) {
    primo::LayerProcessing processing;
    processing.kind = APProcessingKind(descriptor.kind);
    processing.gradientMapPreset = (int)descriptor.gradientMapPreset;
    processing.hueDegrees = descriptor.hueDegrees;
    processing.saturation = descriptor.saturation;
    processing.brightness = descriptor.brightness;
    processing.contrast = descriptor.contrast;
    processing.inputBlack = descriptor.inputBlack;
    processing.inputWhite = descriptor.inputWhite;
    processing.gamma = descriptor.gamma;
    processing.outputBlack = descriptor.outputBlack;
    processing.outputWhite = descriptor.outputWhite;
    processing.shadows = descriptor.shadows;
    processing.midtones = descriptor.midtones;
    processing.highlights = descriptor.highlights;
    processing.redCyan = descriptor.redCyan;
    processing.greenMagenta = descriptor.greenMagenta;
    processing.blueYellow = descriptor.blueYellow;
    processing.threshold = descriptor.threshold;
    processing.posterizeLevels = descriptor.posterizeLevels;
    processing.transformTranslateX = (int)descriptor.transformTranslateX;
    processing.transformTranslateY = (int)descriptor.transformTranslateY;
    processing.transformScale = descriptor.transformScale;
    processing.selectionOriginX = (int)descriptor.selectionOriginX;
    processing.selectionOriginY = (int)descriptor.selectionOriginY;
    processing.selectionWidth = (int)descriptor.selectionWidth;
    processing.selectionHeight = (int)descriptor.selectionHeight;

    if (descriptor.selectionMaskData.length > 0) {
        const auto *bytes = static_cast<const uint8_t *>(descriptor.selectionMaskData.bytes);
        processing.selectionMask.assign(bytes, bytes + descriptor.selectionMaskData.length);
    }
    if (descriptor.pixelData.length > 0) {
        const auto *bytes = static_cast<const uint8_t *>(descriptor.pixelData.bytes);
        processing.pixelData.assign(bytes, bytes + descriptor.pixelData.length);
    }

    return processing;
}

}  // namespace

@implementation APDirtyRect

- (instancetype)initWithOriginX:(NSInteger)originX
                        originY:(NSInteger)originY
                          width:(NSInteger)width
                         height:(NSInteger)height {
    self = [super init];
    if (self) {
        _originX = originX;
        _originY = originY;
        _width = width;
        _height = height;
        _empty = (width <= 0 || height <= 0);
    }
    return self;
}

@end

@implementation APBrushDescriptor

- (instancetype)init {
    self = [super init];
    if (self) {
        _tipKind = @"pencil";
        _radius = 3.0;
        _sizeSpeedSensitivity = 0.0;
        _taperIn = 0.0;
        _taperOut = 0.0;
        _hardness = 0.82;
        _opacity = 0.9;
        _roundness = 1.0;
        _roundnessPressureSensitivity = 0.0;
        _roundnessTiltSensitivity = 0.0;
        _angle = 0.0;
        _anglePressureSensitivity = 0.0;
        _angleTiltSensitivity = 0.0;
        _angleMode = 1;
        _stampSpacing = 0.28;
        _spacingJitter = 0.0;
        _scatterEnabled = NO;
        _scatterMode = 0;
        _scatterLateral = 0.0;
        _scatterLinear = 0.0;
        _count = 1;
        _countJitter = 0.0;
        _countSizeJitter = 0.0;
        _countOpacityJitter = 0.0;
        _angleJitter = 0.0;
        _roundnessJitter = 0.0;
        _textureMode = 2;
        _textureStrength = 0.32;
        _flow = 1.0;
        _flowPressureSensitivity = 0.0;
        _flowJitter = 0.0;
        _colorMixingMode = 0;
        _wetness = 0.0;
        _wetnessPressureSensitivity = 0.0;
        _opacityPressureSensitivity = 0.0;
        _colorMixStrength = 0.0;
        _smudgeBlurEnabled = NO;
        _smudgeBleed = 0.0;
        _smudgeRadius = 0.0;
        _paintLoad = 1.0;
        _loadPressureSensitivity = 0.0;
        _dualBrushEnabled = NO;
        _dualTipKind = @"ink";
        _dualScale = 0.72;
        _dualSpacing = 0.26;
        _dualScatter = 0.18;
        _dualAngle = 0.0;
        _dualBlendMode = 0;
        _flipX = NO;
        _flipY = NO;
        _tipMaskWidth = 0;
        _tipMaskHeight = 0;
        _tipMaskData = nil;
        _grainScale = 1.35;
        _grainContrast = 1.7;
        _paperScale = 0.12;
        _paperThreshold = 0.42;
        _paperStrength = 0.32;
        _velocityInfluence = 0.012;
        _tiltInfluence = 0.75;
        _maxDarkness = 0.95;
        _pressureSensitivity = 0.4;
        _fillThresholdMode = 0;
        _fillOpacityTolerance = 0.08;
        _fillColorTolerance = 0.12;
        _fillExpansion = 0;
        _eraser = NO;
    }
    return self;
}
@end

@implementation APStrokePoint
@end

@implementation APPaintLayerInfo

- (instancetype)initWithName:(NSString *)name
                     visible:(BOOL)visible
                      locked:(BOOL)locked
                 alphaLocked:(BOOL)alphaLocked
                     clipped:(BOOL)clipped
                     opacity:(CGFloat)opacity
                   blendMode:(NSString *)blendMode
                    folderID:(NSInteger)folderID
                     hasMask:(BOOL)hasMask {
    self = [super init];
    if (self) {
        _name = [name copy];
        _visible = visible;
        _locked = locked;
        _alphaLocked = alphaLocked;
        _clipped = clipped;
        _opacity = opacity;
        _blendMode = [blendMode copy];
        _folderID = folderID;
        _hasMask = hasMask;
    }
    return self;
}

@end

@implementation APPaintFolderInfo

- (instancetype)initWithFolderID:(NSInteger)folderID
                            name:(NSString *)name
                         visible:(BOOL)visible
                        expanded:(BOOL)expanded
                 anchorLayerIndex:(NSInteger)anchorLayerIndex {
    self = [super init];
    if (self) {
        _folderID = folderID;
        _name = [name copy];
        _visible = visible;
        _expanded = expanded;
        _anchorLayerIndex = anchorLayerIndex;
    }
    return self;
}

@end

@implementation APPaintLayerProcessingDescriptor

- (instancetype)init {
    self = [super init];
    if (self) {
        _kind = APPaintLayerProcessingKindReplacePixels;
        _gradientMapPreset = APPaintGradientMapPresetGraphite;
        _saturation = 1.0;
        _contrast = 1.0;
        _inputWhite = 1.0;
        _gamma = 1.0;
        _outputWhite = 1.0;
        _threshold = 0.5;
        _posterizeLevels = 6.0;
        _transformScale = 1.0;
    }
    return self;
}

@end

@interface APPaintDocumentBridge () {
    std::unique_ptr<primo::PaintDocument> _document;
}
@end

@implementation APPaintDocumentBridge

- (instancetype)initWithWidth:(NSInteger)width height:(NSInteger)height {
    self = [super init];
    if (self) {
        _document = std::make_unique<primo::PaintDocument>((int)width, (int)height);
        _width = width;
        _height = height;
    }
    return self;
}

- (NSInteger)addLayerWithName:(NSString *)name {
    return _document->addLayer(name.UTF8String);
}

- (NSInteger)duplicateLayerAtIndex:(NSInteger)index name:(NSString *)name {
    return _document->duplicateLayer((int)index, name.UTF8String);
}

- (BOOL)deleteLayerAtIndex:(NSInteger)index {
    return _document->deleteLayer((int)index);
}

- (BOOL)moveLayerAtIndex:(NSInteger)index toIndex:(NSInteger)destinationIndex {
    return _document->moveLayer((int)index, (int)destinationIndex);
}

- (NSInteger)createFolderWithName:(NSString *)name layerIndex:(NSInteger)layerIndex {
    return _document->createFolder(name.UTF8String, (int)layerIndex);
}

- (BOOL)deleteFolderWithID:(NSInteger)folderID {
    return _document->deleteFolder((int)folderID);
}

- (NSArray<APPaintLayerInfo *> *)layers {
    NSMutableArray<APPaintLayerInfo *> *items = [NSMutableArray array];
    for (int index = 0; index < _document->layerCount(); ++index) {
        const auto &layer = _document->layer(index);
        NSString *name = [NSString stringWithUTF8String:layer.name.c_str()];
        APPaintLayerInfo *info = [[APPaintLayerInfo alloc] initWithName:name
                                                                visible:layer.visible
                                                                 locked:layer.locked
                                                            alphaLocked:layer.alphaLocked
                                                                clipped:layer.clipped
                                                                opacity:layer.opacity
                                                              blendMode:APStringFromBlendMode(layer.blendMode)
                                                               folderID:_document->layerFolderID(index)
                                                                hasMask:_document->hasLayerMask(index)];
        [items addObject:info];
    }
    return items;
}

- (NSArray<APPaintFolderInfo *> *)folders {
    NSMutableArray<APPaintFolderInfo *> *items = [NSMutableArray array];
    for (int position = 0; position < _document->folderCount(); ++position) {
        const auto &folder = _document->folderAt(position);
        NSString *name = [NSString stringWithUTF8String:folder.name.c_str()];
        APPaintFolderInfo *info = [[APPaintFolderInfo alloc] initWithFolderID:folder.id
                                                                         name:name
                                                                      visible:folder.visible
                                                                     expanded:folder.expanded
                                                              anchorLayerIndex:folder.anchorLayerIndex];
        [items addObject:info];
    }
    return items;
}

- (NSData *)pixelDataForLayerAtIndex:(NSInteger)index {
    const auto &layer = _document->layer((int)index);
    return [NSData dataWithBytes:layer.pixels.data() length:layer.pixels.size()];
}

- (NSData *)layerMaskDataForLayerAtIndex:(NSInteger)index {
    const auto mask = _document->layerMaskData((int)index);
    if (mask.empty()) {
        return nil;
    }
    return [NSData dataWithBytes:mask.data() length:mask.size()];
}

- (BOOL)applyLayerProcessingAtIndex:(NSInteger)index descriptor:(APPaintLayerProcessingDescriptor *)descriptor {
    return _document->applyLayerProcessing((int)index, APProcessingFromDescriptor(descriptor));
}

- (void)replaceLayerPixelsAtIndex:(NSInteger)index data:(NSData *)data {
    const auto *bytes = static_cast<const uint8_t *>(data.bytes);
    if (bytes == nullptr) {
        return;
    }
    _document->replaceLayerPixels((int)index, std::span<const uint8_t>(bytes, data.length));
}

- (void)replaceLayerPixelsTransientAtIndex:(NSInteger)index data:(NSData *)data {
    const auto *bytes = static_cast<const uint8_t *>(data.bytes);
    if (bytes == nullptr) {
        return;
    }
    _document->replaceLayerPixelsTransient((int)index, std::span<const uint8_t>(bytes, data.length));
}

- (void)replaceLayerMaskAtIndex:(NSInteger)index data:(NSData *)data {
    const auto *bytes = static_cast<const uint8_t *>(data.bytes);
    if (bytes == nullptr) {
        return;
    }
    _document->replaceLayerMask((int)index, std::span<const uint8_t>(bytes, data.length));
}

- (void)clearLayerMaskAtIndex:(NSInteger)index {
    _document->clearLayerMask((int)index);
}

- (BOOL)applyLayerMaskAtIndex:(NSInteger)index {
    return _document->applyLayerMask((int)index);
}

- (NSInteger)activeLayerIndex {
    return _document->activeLayerIndex();
}

- (void)setActiveLayerIndex:(NSInteger)activeLayerIndex {
    _document->setActiveLayerIndex((int)activeLayerIndex);
}

- (void)clearLayerAtIndex:(NSInteger)index {
    _document->clearLayer((int)index);
}

- (void)setLayerName:(NSString *)name atIndex:(NSInteger)index {
    _document->setLayerName((int)index, name.UTF8String);
}

- (void)setLayerVisible:(BOOL)visible atIndex:(NSInteger)index {
    _document->setLayerVisibility((int)index, visible);
}

- (void)setLayerLocked:(BOOL)locked atIndex:(NSInteger)index {
    _document->setLayerLocked((int)index, locked);
}

- (void)setLayerAlphaLocked:(BOOL)alphaLocked atIndex:(NSInteger)index {
    _document->setLayerAlphaLocked((int)index, alphaLocked);
}

- (void)setLayerClipped:(BOOL)clipped atIndex:(NSInteger)index {
    _document->setLayerClipped((int)index, clipped);
}

- (void)setLayerOpacity:(CGFloat)opacity atIndex:(NSInteger)index {
    _document->setLayerOpacity((int)index, (float)opacity);
}

- (void)setLayerBlendMode:(NSString *)blendMode atIndex:(NSInteger)index {
    _document->setLayerBlendMode((int)index, APBlendModeFromString(blendMode));
}

- (void)setFolderVisible:(BOOL)visible folderID:(NSInteger)folderID {
    _document->setFolderVisibility((int)folderID, visible);
}

- (void)setFolderName:(NSString *)name folderID:(NSInteger)folderID {
    _document->setFolderName((int)folderID, name.UTF8String);
}

- (void)setFolderExpanded:(BOOL)expanded folderID:(NSInteger)folderID {
    _document->setFolderExpanded((int)folderID, expanded);
}

- (BOOL)setLayerFolderAtIndex:(NSInteger)index folderID:(NSInteger)folderID {
    return _document->setLayerFolder((int)index, (int)folderID);
}

- (void)beginStrokeWithBrush:(APBrushDescriptor *)brush point:(APStrokePoint *)point {
    primo::BrushSettings settings;
    settings.radius = (float)brush.radius;
    settings.sizeSpeedSensitivity = (float)brush.sizeSpeedSensitivity;
    settings.taperIn = (float)brush.taperIn;
    settings.taperOut = (float)brush.taperOut;
    settings.tipKind = std::string(brush.tipKind.UTF8String ?: "pencil");
    settings.hardness = (float)brush.hardness;
    settings.opacity = (float)brush.opacity;
    settings.roundness = (float)brush.roundness;
    settings.roundnessPressureSensitivity = (float)brush.roundnessPressureSensitivity;
    settings.roundnessTiltSensitivity = (float)brush.roundnessTiltSensitivity;
    settings.angle = (float)brush.angle;
    settings.anglePressureSensitivity = (float)brush.anglePressureSensitivity;
    settings.angleTiltSensitivity = (float)brush.angleTiltSensitivity;
    settings.angleMode = (int)brush.angleMode;
    settings.stampSpacing = (float)brush.stampSpacing;
    settings.spacingJitter = (float)brush.spacingJitter;
    settings.scatterEnabled = brush.scatterEnabled;
    settings.scatterMode = (int)brush.scatterMode;
    settings.scatterLateral = (float)brush.scatterLateral;
    settings.scatterLinear = (float)brush.scatterLinear;
    settings.count = (int)brush.count;
    settings.countJitter = (float)brush.countJitter;
    settings.countSizeJitter = (float)brush.countSizeJitter;
    settings.countOpacityJitter = (float)brush.countOpacityJitter;
    settings.angleJitter = (float)brush.angleJitter;
    settings.roundnessJitter = (float)brush.roundnessJitter;
    settings.textureMode = (int)brush.textureMode;
    settings.textureStrength = (float)brush.textureStrength;
    settings.flow = (float)brush.flow;
    settings.flowPressureSensitivity = (float)brush.flowPressureSensitivity;
    settings.flowJitter = (float)brush.flowJitter;
    settings.colorMixingMode = (int)brush.colorMixingMode;
    settings.wetness = (float)brush.wetness;
    settings.wetnessPressureSensitivity = (float)brush.wetnessPressureSensitivity;
    settings.opacityPressureSensitivity = (float)brush.opacityPressureSensitivity;
    settings.colorMixStrength = (float)brush.colorMixStrength;
    settings.smudgeBlurEnabled = brush.smudgeBlurEnabled;
    settings.smudgeBleed = (float)brush.smudgeBleed;
    settings.smudgeRadius = (float)brush.smudgeRadius;
    settings.paintLoad = (float)brush.paintLoad;
    settings.loadPressureSensitivity = (float)brush.loadPressureSensitivity;
    settings.dualBrushEnabled = brush.dualBrushEnabled;
    settings.dualTipKind = std::string(brush.dualTipKind.UTF8String ?: "ink");
    settings.dualScale = (float)brush.dualScale;
    settings.dualSpacing = (float)brush.dualSpacing;
    settings.dualScatter = (float)brush.dualScatter;
    settings.dualAngle = (float)brush.dualAngle;
    settings.dualBlendMode = (int)brush.dualBlendMode;
    settings.flipX = brush.flipX;
    settings.flipY = brush.flipY;
    settings.tipMaskWidth = (int)brush.tipMaskWidth;
    settings.tipMaskHeight = (int)brush.tipMaskHeight;
    if (brush.tipMaskData.length > 0) {
        const auto *bytes = static_cast<const uint8_t *>(brush.tipMaskData.bytes);
        settings.tipMaskAlpha.assign(bytes, bytes + brush.tipMaskData.length);
    }
    settings.grainScale = (float)brush.grainScale;
    settings.grainContrast = (float)brush.grainContrast;
    settings.paperScale = (float)brush.paperScale;
    settings.paperThreshold = (float)brush.paperThreshold;
    settings.paperStrength = (float)brush.paperStrength;
    settings.velocityInfluence = (float)brush.velocityInfluence;
    settings.tiltInfluence = (float)brush.tiltInfluence;
    settings.maxDarkness = (float)brush.maxDarkness;
    settings.pressureSensitivity = (float)brush.pressureSensitivity;
    settings.fillThresholdMode = (int)brush.fillThresholdMode;
    settings.fillOpacityTolerance = (float)brush.fillOpacityTolerance;
    settings.fillColorTolerance = (float)brush.fillColorTolerance;
    settings.fillExpansion = (int)brush.fillExpansion;
    settings.red = brush.red;
    settings.green = brush.green;
    settings.blue = brush.blue;
    settings.eraser = brush.eraser;

    primo::StrokePoint startPoint;
    startPoint.x = (float)point.x;
    startPoint.y = (float)point.y;
    startPoint.pressure = (float)point.pressure;
    startPoint.altitude = (float)point.altitude;
    startPoint.azimuth = (float)point.azimuth;
    startPoint.timestamp = (float)point.timestamp;

    _document->beginStroke(settings, startPoint);
}

- (void)appendStroke:(APStrokePoint *)point {
    primo::StrokePoint strokePoint;
    strokePoint.x = (float)point.x;
    strokePoint.y = (float)point.y;
    strokePoint.pressure = (float)point.pressure;
    strokePoint.altitude = (float)point.altitude;
    strokePoint.azimuth = (float)point.azimuth;
    strokePoint.timestamp = (float)point.timestamp;
    _document->appendStroke(strokePoint);
}

- (void)endStroke {
    _document->endStroke();
}

- (void)cancelStroke {
    _document->cancelStroke();
}

- (void)fillAtPoint:(CGPoint)point brush:(APBrushDescriptor *)brush {
    primo::BrushSettings settings;
    settings.radius = (float)brush.radius;
    settings.sizeSpeedSensitivity = (float)brush.sizeSpeedSensitivity;
    settings.taperIn = (float)brush.taperIn;
    settings.taperOut = (float)brush.taperOut;
    settings.tipKind = std::string(brush.tipKind.UTF8String ?: "pencil");
    settings.hardness = (float)brush.hardness;
    settings.opacity = (float)brush.opacity;
    settings.roundness = (float)brush.roundness;
    settings.roundnessPressureSensitivity = (float)brush.roundnessPressureSensitivity;
    settings.roundnessTiltSensitivity = (float)brush.roundnessTiltSensitivity;
    settings.angle = (float)brush.angle;
    settings.anglePressureSensitivity = (float)brush.anglePressureSensitivity;
    settings.angleTiltSensitivity = (float)brush.angleTiltSensitivity;
    settings.angleMode = (int)brush.angleMode;
    settings.stampSpacing = (float)brush.stampSpacing;
    settings.spacingJitter = (float)brush.spacingJitter;
    settings.scatterEnabled = brush.scatterEnabled;
    settings.scatterMode = (int)brush.scatterMode;
    settings.scatterLateral = (float)brush.scatterLateral;
    settings.scatterLinear = (float)brush.scatterLinear;
    settings.count = (int)brush.count;
    settings.countJitter = (float)brush.countJitter;
    settings.countSizeJitter = (float)brush.countSizeJitter;
    settings.countOpacityJitter = (float)brush.countOpacityJitter;
    settings.angleJitter = (float)brush.angleJitter;
    settings.roundnessJitter = (float)brush.roundnessJitter;
    settings.textureMode = (int)brush.textureMode;
    settings.textureStrength = (float)brush.textureStrength;
    settings.flow = (float)brush.flow;
    settings.flowPressureSensitivity = (float)brush.flowPressureSensitivity;
    settings.flowJitter = (float)brush.flowJitter;
    settings.colorMixingMode = (int)brush.colorMixingMode;
    settings.wetness = (float)brush.wetness;
    settings.wetnessPressureSensitivity = (float)brush.wetnessPressureSensitivity;
    settings.opacityPressureSensitivity = (float)brush.opacityPressureSensitivity;
    settings.colorMixStrength = (float)brush.colorMixStrength;
    settings.smudgeBlurEnabled = brush.smudgeBlurEnabled;
    settings.smudgeBleed = (float)brush.smudgeBleed;
    settings.smudgeRadius = (float)brush.smudgeRadius;
    settings.paintLoad = (float)brush.paintLoad;
    settings.loadPressureSensitivity = (float)brush.loadPressureSensitivity;
    settings.dualBrushEnabled = brush.dualBrushEnabled;
    settings.dualTipKind = std::string(brush.dualTipKind.UTF8String ?: "ink");
    settings.dualScale = (float)brush.dualScale;
    settings.dualSpacing = (float)brush.dualSpacing;
    settings.dualScatter = (float)brush.dualScatter;
    settings.dualAngle = (float)brush.dualAngle;
    settings.dualBlendMode = (int)brush.dualBlendMode;
    settings.flipX = brush.flipX;
    settings.flipY = brush.flipY;
    settings.tipMaskWidth = (int)brush.tipMaskWidth;
    settings.tipMaskHeight = (int)brush.tipMaskHeight;
    if (brush.tipMaskData.length > 0) {
        const auto *bytes = static_cast<const uint8_t *>(brush.tipMaskData.bytes);
        settings.tipMaskAlpha.assign(bytes, bytes + brush.tipMaskData.length);
    }
    settings.grainScale = (float)brush.grainScale;
    settings.grainContrast = (float)brush.grainContrast;
    settings.paperScale = (float)brush.paperScale;
    settings.paperThreshold = (float)brush.paperThreshold;
    settings.paperStrength = (float)brush.paperStrength;
    settings.velocityInfluence = (float)brush.velocityInfluence;
    settings.tiltInfluence = (float)brush.tiltInfluence;
    settings.maxDarkness = (float)brush.maxDarkness;
    settings.pressureSensitivity = (float)brush.pressureSensitivity;
    settings.fillThresholdMode = (int)brush.fillThresholdMode;
    settings.fillOpacityTolerance = (float)brush.fillOpacityTolerance;
    settings.fillColorTolerance = (float)brush.fillColorTolerance;
    settings.fillExpansion = (int)brush.fillExpansion;
    settings.red = brush.red;
    settings.green = brush.green;
    settings.blue = brush.blue;
    settings.eraser = brush.eraser;

    _document->fill((int)std::lround(point.x), (int)std::lround(point.y), settings);
}

- (BOOL)canUndo {
    return _document->canUndo();
}

- (BOOL)canRedo {
    return _document->canRedo();
}

- (BOOL)undo {
    return _document->undo();
}

- (BOOL)redo {
    return _document->redo();
}

- (void)clearHistory {
    _document->clearHistory();
}

- (CGImageRef)createCompositeImage {
    const auto composite = _document->composite();
    NSData *data = [NSData dataWithBytes:composite.data() length:composite.size()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // PaintEngine stores straight-alpha RGBA; exporting as premultiplied darkens semi-transparent inks.
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaLast;
    CGImageRef image = CGImageCreate((size_t)_document->width(),
                                     (size_t)_document->height(),
                                     8,
                                     32,
                                     (size_t)_document->width() * 4U,
                                     colorSpace,
                                     bitmapInfo,
                                     provider,
                                     nullptr,
                                     false,
                                     kCGRenderingIntentDefault);

    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    return image;
}

- (CGImageRef)createImageForLayerAtIndex:(NSInteger)index {
    if (index < 0 || index >= _document->layerCount()) {
        return nil;
    }

    const auto &layer = _document->layer((int)index);
    NSMutableData *workingData = [NSMutableData dataWithBytes:layer.pixels.data() length:layer.pixels.size()];
    const auto mask = _document->layerMaskData((int)index);
    if (!mask.empty()) {
        auto *bytes = static_cast<uint8_t *>(workingData.mutableBytes);
        for (size_t pixelIndex = 0; pixelIndex < mask.size(); ++pixelIndex) {
            const size_t alphaOffset = (pixelIndex * 4U) + 3U;
            const float baseAlpha = static_cast<float>(bytes[alphaOffset]) / 255.0F;
            const float maskAlpha = static_cast<float>(mask[pixelIndex]) / 255.0F;
            bytes[alphaOffset] = static_cast<uint8_t>(std::clamp(std::lround(baseAlpha * maskAlpha * 255.0F), 0L, 255L));
        }
    }
    NSData *data = workingData;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaLast;
    CGImageRef image = CGImageCreate((size_t)_document->width(),
                                     (size_t)_document->height(),
                                     8,
                                     32,
                                     (size_t)_document->width() * 4U,
                                     colorSpace,
                                     bitmapInfo,
                                     provider,
                                     nullptr,
                                     false,
                                     kCGRenderingIntentDefault);

    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    return image;
}

- (NSData *)compositePixelData {
    const auto composite = _document->composite();
    return [NSData dataWithBytes:composite.data() length:composite.size()];
}

- (APDirtyRect *)consumeDirtyRect {
    auto rect = _document->consumeDirtyRect();
    if (rect.empty()) {
        return [[APDirtyRect alloc] initWithOriginX:0 originY:0 width:0 height:0];
    }
    return [[APDirtyRect alloc] initWithOriginX:rect.minX
                                       originY:rect.minY
                                        width:rect.width()
                                       height:rect.height()];
}

- (NSData *)compositePixelDataInRect:(APDirtyRect *)rect {
    primo::DirtyRect engineRect;
    engineRect.minX = (int)rect.originX;
    engineRect.minY = (int)rect.originY;
    engineRect.maxX = (int)(rect.originX + rect.width - 1);
    engineRect.maxY = (int)(rect.originY + rect.height - 1);
    auto pixels = _document->compositePixelDataForRect(engineRect);
    return [NSData dataWithBytes:pixels.data() length:pixels.size()];
}

- (NSData *)pixelDataForLayerAtIndex:(NSInteger)index inRect:(APDirtyRect *)rect {
    primo::DirtyRect engineRect;
    engineRect.minX = (int)rect.originX;
    engineRect.minY = (int)rect.originY;
    engineRect.maxX = (int)(rect.originX + rect.width - 1);
    engineRect.maxY = (int)(rect.originY + rect.height - 1);
    auto pixels = _document->pixelDataForRect((int)index, engineRect);
    return [NSData dataWithBytes:pixels.data() length:pixels.size()];
}

@end
