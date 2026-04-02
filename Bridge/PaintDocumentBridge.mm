#import "PaintDocumentBridge.h"

#import <UIKit/UIKit.h>

#include "../Engine/include/PaintEngine.hpp"
#include <cmath>
#include <memory>

namespace {

atelierprime::Layer::BlendMode APBlendModeFromString(NSString *blendMode) {
    if ([blendMode isEqualToString:@"darken"]) {
        return atelierprime::Layer::BlendMode::Darken;
    }
    if ([blendMode isEqualToString:@"multiply"]) {
        return atelierprime::Layer::BlendMode::Multiply;
    }
    if ([blendMode isEqualToString:@"colorBurn"]) {
        return atelierprime::Layer::BlendMode::ColorBurn;
    }
    if ([blendMode isEqualToString:@"linearBurn"]) {
        return atelierprime::Layer::BlendMode::LinearBurn;
    }
    if ([blendMode isEqualToString:@"subtract"]) {
        return atelierprime::Layer::BlendMode::Subtract;
    }
    if ([blendMode isEqualToString:@"lighten"]) {
        return atelierprime::Layer::BlendMode::Lighten;
    }
    if ([blendMode isEqualToString:@"screen"]) {
        return atelierprime::Layer::BlendMode::Screen;
    }
    if ([blendMode isEqualToString:@"add"]) {
        return atelierprime::Layer::BlendMode::Add;
    }
    if ([blendMode isEqualToString:@"colorDodge"]) {
        return atelierprime::Layer::BlendMode::ColorDodge;
    }
    if ([blendMode isEqualToString:@"glowDodge"]) {
        return atelierprime::Layer::BlendMode::GlowDodge;
    }
    if ([blendMode isEqualToString:@"overlay"]) {
        return atelierprime::Layer::BlendMode::Overlay;
    }
    if ([blendMode isEqualToString:@"softLight"]) {
        return atelierprime::Layer::BlendMode::SoftLight;
    }
    if ([blendMode isEqualToString:@"hardLight"]) {
        return atelierprime::Layer::BlendMode::HardLight;
    }
    if ([blendMode isEqualToString:@"difference"]) {
        return atelierprime::Layer::BlendMode::Difference;
    }
    if ([blendMode isEqualToString:@"vividLight"]) {
        return atelierprime::Layer::BlendMode::VividLight;
    }
    if ([blendMode isEqualToString:@"linearLight"]) {
        return atelierprime::Layer::BlendMode::LinearLight;
    }
    if ([blendMode isEqualToString:@"pinLight"]) {
        return atelierprime::Layer::BlendMode::PinLight;
    }
    if ([blendMode isEqualToString:@"hardMix"]) {
        return atelierprime::Layer::BlendMode::HardMix;
    }
    if ([blendMode isEqualToString:@"exclusion"]) {
        return atelierprime::Layer::BlendMode::Exclusion;
    }
    if ([blendMode isEqualToString:@"darkerColor"]) {
        return atelierprime::Layer::BlendMode::DarkerColor;
    }
    if ([blendMode isEqualToString:@"lighterColor"]) {
        return atelierprime::Layer::BlendMode::LighterColor;
    }
    if ([blendMode isEqualToString:@"divide"]) {
        return atelierprime::Layer::BlendMode::Divide;
    }
    if ([blendMode isEqualToString:@"hue"]) {
        return atelierprime::Layer::BlendMode::Hue;
    }
    if ([blendMode isEqualToString:@"saturation"]) {
        return atelierprime::Layer::BlendMode::Saturation;
    }
    if ([blendMode isEqualToString:@"color"]) {
        return atelierprime::Layer::BlendMode::Color;
    }
    if ([blendMode isEqualToString:@"addGlow"]) {
        return atelierprime::Layer::BlendMode::AddGlow;
    }
    if ([blendMode isEqualToString:@"luminosity"]) {
        return atelierprime::Layer::BlendMode::Luminosity;
    }
    return atelierprime::Layer::BlendMode::Normal;
}

NSString *APStringFromBlendMode(atelierprime::Layer::BlendMode blendMode) {
    switch (blendMode) {
        case atelierprime::Layer::BlendMode::Darken:
            return @"darken";
        case atelierprime::Layer::BlendMode::Multiply:
            return @"multiply";
        case atelierprime::Layer::BlendMode::ColorBurn:
            return @"colorBurn";
        case atelierprime::Layer::BlendMode::LinearBurn:
            return @"linearBurn";
        case atelierprime::Layer::BlendMode::Subtract:
            return @"subtract";
        case atelierprime::Layer::BlendMode::Lighten:
            return @"lighten";
        case atelierprime::Layer::BlendMode::Screen:
            return @"screen";
        case atelierprime::Layer::BlendMode::Add:
            return @"add";
        case atelierprime::Layer::BlendMode::ColorDodge:
            return @"colorDodge";
        case atelierprime::Layer::BlendMode::GlowDodge:
            return @"glowDodge";
        case atelierprime::Layer::BlendMode::Overlay:
            return @"overlay";
        case atelierprime::Layer::BlendMode::SoftLight:
            return @"softLight";
        case atelierprime::Layer::BlendMode::HardLight:
            return @"hardLight";
        case atelierprime::Layer::BlendMode::Difference:
            return @"difference";
        case atelierprime::Layer::BlendMode::VividLight:
            return @"vividLight";
        case atelierprime::Layer::BlendMode::LinearLight:
            return @"linearLight";
        case atelierprime::Layer::BlendMode::PinLight:
            return @"pinLight";
        case atelierprime::Layer::BlendMode::HardMix:
            return @"hardMix";
        case atelierprime::Layer::BlendMode::Exclusion:
            return @"exclusion";
        case atelierprime::Layer::BlendMode::DarkerColor:
            return @"darkerColor";
        case atelierprime::Layer::BlendMode::LighterColor:
            return @"lighterColor";
        case atelierprime::Layer::BlendMode::Divide:
            return @"divide";
        case atelierprime::Layer::BlendMode::Hue:
            return @"hue";
        case atelierprime::Layer::BlendMode::Saturation:
            return @"saturation";
        case atelierprime::Layer::BlendMode::Color:
            return @"color";
        case atelierprime::Layer::BlendMode::AddGlow:
            return @"addGlow";
        case atelierprime::Layer::BlendMode::Luminosity:
            return @"luminosity";
        case atelierprime::Layer::BlendMode::Normal:
            return @"normal";
    }
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
        _hardness = 0.82;
        _opacity = 0.9;
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
                     opacity:(CGFloat)opacity
                   blendMode:(NSString *)blendMode {
    self = [super init];
    if (self) {
        _name = [name copy];
        _visible = visible;
        _opacity = opacity;
        _blendMode = [blendMode copy];
    }
    return self;
}

@end

@interface APPaintDocumentBridge () {
    std::unique_ptr<atelierprime::PaintDocument> _document;
}
@end

@implementation APPaintDocumentBridge

- (instancetype)initWithWidth:(NSInteger)width height:(NSInteger)height {
    self = [super init];
    if (self) {
        _document = std::make_unique<atelierprime::PaintDocument>((int)width, (int)height);
        _width = width;
        _height = height;
    }
    return self;
}

- (NSInteger)addLayerWithName:(NSString *)name {
    return _document->addLayer(name.UTF8String);
}

- (NSArray<APPaintLayerInfo *> *)layers {
    NSMutableArray<APPaintLayerInfo *> *items = [NSMutableArray array];
    for (int index = 0; index < _document->layerCount(); ++index) {
        const auto &layer = _document->layer(index);
        NSString *name = [NSString stringWithUTF8String:layer.name.c_str()];
        APPaintLayerInfo *info = [[APPaintLayerInfo alloc] initWithName:name
                                                                visible:layer.visible
                                                                opacity:layer.opacity
                                                              blendMode:APStringFromBlendMode(layer.blendMode)];
        [items addObject:info];
    }
    return items;
}

- (NSData *)pixelDataForLayerAtIndex:(NSInteger)index {
    const auto &layer = _document->layer((int)index);
    return [NSData dataWithBytes:layer.pixels.data() length:layer.pixels.size()];
}

- (void)replaceLayerPixelsAtIndex:(NSInteger)index data:(NSData *)data {
    const auto *bytes = static_cast<const uint8_t *>(data.bytes);
    if (bytes == nullptr) {
        return;
    }
    _document->replaceLayerPixels((int)index, std::span<const uint8_t>(bytes, data.length));
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

- (void)setLayerVisible:(BOOL)visible atIndex:(NSInteger)index {
    _document->setLayerVisibility((int)index, visible);
}

- (void)setLayerOpacity:(CGFloat)opacity atIndex:(NSInteger)index {
    _document->setLayerOpacity((int)index, (float)opacity);
}

- (void)setLayerBlendMode:(NSString *)blendMode atIndex:(NSInteger)index {
    _document->setLayerBlendMode((int)index, APBlendModeFromString(blendMode));
}

- (void)beginStrokeWithBrush:(APBrushDescriptor *)brush point:(APStrokePoint *)point {
    atelierprime::BrushSettings settings;
    settings.radius = (float)brush.radius;
    settings.tipKind = std::string(brush.tipKind.UTF8String ?: "pencil");
    settings.hardness = (float)brush.hardness;
    settings.opacity = (float)brush.opacity;
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

    atelierprime::StrokePoint startPoint;
    startPoint.x = (float)point.x;
    startPoint.y = (float)point.y;
    startPoint.pressure = (float)point.pressure;
    startPoint.altitude = (float)point.altitude;
    startPoint.azimuth = (float)point.azimuth;
    startPoint.timestamp = (float)point.timestamp;

    _document->beginStroke(settings, startPoint);
}

- (void)appendStroke:(APStrokePoint *)point {
    atelierprime::StrokePoint strokePoint;
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

- (void)fillAtPoint:(CGPoint)point brush:(APBrushDescriptor *)brush {
    atelierprime::BrushSettings settings;
    settings.radius = (float)brush.radius;
    settings.tipKind = std::string(brush.tipKind.UTF8String ?: "pencil");
    settings.hardness = (float)brush.hardness;
    settings.opacity = (float)brush.opacity;
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

- (CGImageRef)createCompositeImage {
    const auto composite = _document->composite();
    NSData *data = [NSData dataWithBytes:composite.data() length:composite.size()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
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
    NSData *data = [NSData dataWithBytes:layer.pixels.data() length:layer.pixels.size()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
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
    atelierprime::DirtyRect engineRect;
    engineRect.minX = (int)rect.originX;
    engineRect.minY = (int)rect.originY;
    engineRect.maxX = (int)(rect.originX + rect.width - 1);
    engineRect.maxY = (int)(rect.originY + rect.height - 1);
    auto pixels = _document->compositePixelDataForRect(engineRect);
    return [NSData dataWithBytes:pixels.data() length:pixels.size()];
}

- (NSData *)pixelDataForLayerAtIndex:(NSInteger)index inRect:(APDirtyRect *)rect {
    atelierprime::DirtyRect engineRect;
    engineRect.minX = (int)rect.originX;
    engineRect.minY = (int)rect.originY;
    engineRect.maxX = (int)(rect.originX + rect.width - 1);
    engineRect.maxY = (int)(rect.originY + rect.height - 1);
    auto pixels = _document->pixelDataForRect((int)index, engineRect);
    return [NSData dataWithBytes:pixels.data() length:pixels.size()];
}

@end
