#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface APDirtyRect : NSObject

@property (nonatomic, readonly) NSInteger originX;
@property (nonatomic, readonly) NSInteger originY;
@property (nonatomic, readonly) NSInteger width;
@property (nonatomic, readonly) NSInteger height;
@property (nonatomic, readonly) BOOL empty;

- (instancetype)initWithOriginX:(NSInteger)originX
                        originY:(NSInteger)originY
                          width:(NSInteger)width
                         height:(NSInteger)height NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface APBrushDescriptor : NSObject

@property (nonatomic, copy) NSString *tipKind;
@property (nonatomic) CGFloat radius;
@property (nonatomic) CGFloat sizeSpeedSensitivity;
@property (nonatomic) CGFloat hardness;
@property (nonatomic) CGFloat opacity;
@property (nonatomic) CGFloat roundness;
@property (nonatomic) CGFloat roundnessPressureSensitivity;
@property (nonatomic) CGFloat roundnessTiltSensitivity;
@property (nonatomic) CGFloat angle;
@property (nonatomic) CGFloat anglePressureSensitivity;
@property (nonatomic) CGFloat angleTiltSensitivity;
@property (nonatomic) NSInteger angleMode;
@property (nonatomic) CGFloat stampSpacing;
@property (nonatomic) CGFloat spacingJitter;
@property (nonatomic) BOOL scatterEnabled;
@property (nonatomic) NSInteger scatterMode;
@property (nonatomic) CGFloat scatterLateral;
@property (nonatomic) CGFloat scatterLinear;
@property (nonatomic) NSInteger count;
@property (nonatomic) CGFloat countJitter;
@property (nonatomic) CGFloat countSizeJitter;
@property (nonatomic) CGFloat countOpacityJitter;
@property (nonatomic) CGFloat angleJitter;
@property (nonatomic) CGFloat roundnessJitter;
@property (nonatomic) NSInteger textureMode;
@property (nonatomic) CGFloat textureStrength;
@property (nonatomic) CGFloat flow;
@property (nonatomic) CGFloat flowPressureSensitivity;
@property (nonatomic) CGFloat flowJitter;
@property (nonatomic) CGFloat wetness;
@property (nonatomic) CGFloat wetnessPressureSensitivity;
@property (nonatomic) CGFloat opacityPressureSensitivity;
@property (nonatomic) CGFloat colorMixStrength;
@property (nonatomic) CGFloat paintLoad;
@property (nonatomic) CGFloat loadPressureSensitivity;
@property (nonatomic) BOOL dualBrushEnabled;
@property (nonatomic, copy) NSString *dualTipKind;
@property (nonatomic) CGFloat dualScale;
@property (nonatomic) CGFloat dualSpacing;
@property (nonatomic) CGFloat dualScatter;
@property (nonatomic) CGFloat dualAngle;
@property (nonatomic) NSInteger dualBlendMode;
@property (nonatomic) BOOL flipX;
@property (nonatomic) BOOL flipY;
@property (nonatomic) NSInteger tipMaskWidth;
@property (nonatomic) NSInteger tipMaskHeight;
@property (nonatomic, copy, nullable) NSData *tipMaskData;
@property (nonatomic) CGFloat grainScale;
@property (nonatomic) CGFloat grainContrast;
@property (nonatomic) CGFloat paperScale;
@property (nonatomic) CGFloat paperThreshold;
@property (nonatomic) CGFloat paperStrength;
@property (nonatomic) CGFloat velocityInfluence;
@property (nonatomic) CGFloat tiltInfluence;
@property (nonatomic) CGFloat maxDarkness;
@property (nonatomic) CGFloat pressureSensitivity;
@property (nonatomic) NSInteger fillThresholdMode;
@property (nonatomic) CGFloat fillOpacityTolerance;
@property (nonatomic) CGFloat fillColorTolerance;
@property (nonatomic) NSInteger fillExpansion;
@property (nonatomic) uint8_t red;
@property (nonatomic) uint8_t green;
@property (nonatomic) uint8_t blue;
@property (nonatomic) BOOL eraser;

@end

@interface APStrokePoint : NSObject

@property (nonatomic) CGFloat x;
@property (nonatomic) CGFloat y;
@property (nonatomic) CGFloat pressure;
@property (nonatomic) CGFloat altitude;
@property (nonatomic) CGFloat azimuth;
@property (nonatomic) NSTimeInterval timestamp;

@end

@interface APPaintLayerInfo : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic) BOOL visible;
@property (nonatomic) CGFloat opacity;
@property (nonatomic, copy) NSString *blendMode;
@property (nonatomic) NSInteger folderID;

- (instancetype)initWithName:(NSString *)name
                     visible:(BOOL)visible
                     opacity:(CGFloat)opacity
                   blendMode:(NSString *)blendMode
                    folderID:(NSInteger)folderID NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface APPaintFolderInfo : NSObject

@property (nonatomic) NSInteger folderID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) BOOL visible;
@property (nonatomic) BOOL expanded;
@property (nonatomic) NSInteger anchorLayerIndex;

- (instancetype)initWithFolderID:(NSInteger)folderID
                            name:(NSString *)name
                         visible:(BOOL)visible
                        expanded:(BOOL)expanded
                 anchorLayerIndex:(NSInteger)anchorLayerIndex NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface APPaintDocumentBridge : NSObject

@property (nonatomic, readonly) NSInteger width;
@property (nonatomic, readonly) NSInteger height;
@property (nonatomic) NSInteger activeLayerIndex;

- (instancetype)initWithWidth:(NSInteger)width height:(NSInteger)height NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSInteger)addLayerWithName:(NSString *)name NS_SWIFT_NAME(addLayer(name:));
- (BOOL)deleteLayerAtIndex:(NSInteger)index NS_SWIFT_NAME(deleteLayer(at:));
- (BOOL)moveLayerAtIndex:(NSInteger)index toIndex:(NSInteger)destinationIndex NS_SWIFT_NAME(moveLayer(at:to:));
- (NSInteger)createFolderWithName:(NSString *)name layerIndex:(NSInteger)layerIndex NS_SWIFT_NAME(createFolder(name:layerIndex:));
- (BOOL)deleteFolderWithID:(NSInteger)folderID NS_SWIFT_NAME(deleteFolder(id:));
- (NSArray<APPaintLayerInfo *> *)layers NS_SWIFT_NAME(layerInfos());
- (NSArray<APPaintFolderInfo *> *)folders NS_SWIFT_NAME(folderInfos());
- (NSData *)pixelDataForLayerAtIndex:(NSInteger)index NS_SWIFT_NAME(pixelDataForLayer(at:));
- (void)replaceLayerPixelsAtIndex:(NSInteger)index data:(NSData *)data NS_SWIFT_NAME(replaceLayerPixels(at:data:));
- (void)clearLayerAtIndex:(NSInteger)index NS_SWIFT_NAME(clearLayer(at:));
- (void)setLayerName:(NSString *)name atIndex:(NSInteger)index NS_SWIFT_NAME(setLayerName(_:at:));
- (void)setLayerVisible:(BOOL)visible atIndex:(NSInteger)index NS_SWIFT_NAME(setLayerVisible(_:at:));
- (void)setLayerOpacity:(CGFloat)opacity atIndex:(NSInteger)index NS_SWIFT_NAME(setLayerOpacity(_:at:));
- (void)setLayerBlendMode:(NSString *)blendMode atIndex:(NSInteger)index NS_SWIFT_NAME(setLayerBlendMode(_:at:));
- (void)setFolderVisible:(BOOL)visible folderID:(NSInteger)folderID NS_SWIFT_NAME(setFolderVisible(_:folderID:));
- (void)setFolderName:(NSString *)name folderID:(NSInteger)folderID NS_SWIFT_NAME(setFolderName(_:folderID:));
- (void)setFolderExpanded:(BOOL)expanded folderID:(NSInteger)folderID NS_SWIFT_NAME(setFolderExpanded(_:folderID:));
- (BOOL)setLayerFolderAtIndex:(NSInteger)index folderID:(NSInteger)folderID NS_SWIFT_NAME(setLayerFolder(at:folderID:));

- (void)beginStrokeWithBrush:(APBrushDescriptor *)brush point:(APStrokePoint *)point NS_SWIFT_NAME(beginStroke(brush:point:));
- (void)appendStroke:(APStrokePoint *)point NS_SWIFT_NAME(appendStroke(point:));
- (void)endStroke NS_SWIFT_NAME(endStroke());
- (void)fillAtPoint:(CGPoint)point brush:(APBrushDescriptor *)brush NS_SWIFT_NAME(fill(at:brush:));
- (BOOL)canUndo NS_SWIFT_NAME(canUndo());
- (BOOL)canRedo NS_SWIFT_NAME(canRedo());
- (BOOL)undo NS_SWIFT_NAME(undo());
- (BOOL)redo NS_SWIFT_NAME(redo());

- (CGImageRef _Nullable)createCompositeImage CF_RETURNS_RETAINED NS_SWIFT_NAME(makeCompositeImage());
- (CGImageRef _Nullable)createImageForLayerAtIndex:(NSInteger)index CF_RETURNS_RETAINED NS_SWIFT_NAME(makeImageForLayer(at:));

- (NSData *)compositePixelData NS_SWIFT_NAME(compositePixelData());
- (APDirtyRect *)consumeDirtyRect NS_SWIFT_NAME(consumeDirtyRect());
- (NSData *)compositePixelDataInRect:(APDirtyRect *)rect NS_SWIFT_NAME(compositePixelData(in:));
- (NSData *)pixelDataForLayerAtIndex:(NSInteger)index inRect:(APDirtyRect *)rect NS_SWIFT_NAME(pixelDataForLayer(at:in:));

@end

NS_ASSUME_NONNULL_END
