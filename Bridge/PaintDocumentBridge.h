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

@property (nonatomic) CGFloat radius;
@property (nonatomic) CGFloat hardness;
@property (nonatomic) CGFloat opacity;
@property (nonatomic) CGFloat grainScale;
@property (nonatomic) CGFloat grainContrast;
@property (nonatomic) CGFloat paperScale;
@property (nonatomic) CGFloat paperThreshold;
@property (nonatomic) CGFloat paperStrength;
@property (nonatomic) CGFloat velocityInfluence;
@property (nonatomic) CGFloat tiltInfluence;
@property (nonatomic) CGFloat maxDarkness;
@property (nonatomic) CGFloat pressureSensitivity;
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

- (instancetype)initWithName:(NSString *)name
                     visible:(BOOL)visible
                     opacity:(CGFloat)opacity NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface APPaintDocumentBridge : NSObject

@property (nonatomic, readonly) NSInteger width;
@property (nonatomic, readonly) NSInteger height;
@property (nonatomic) NSInteger activeLayerIndex;

- (instancetype)initWithWidth:(NSInteger)width height:(NSInteger)height NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSInteger)addLayerWithName:(NSString *)name NS_SWIFT_NAME(addLayer(name:));
- (NSArray<APPaintLayerInfo *> *)layers NS_SWIFT_NAME(layerInfos());
- (NSData *)pixelDataForLayerAtIndex:(NSInteger)index NS_SWIFT_NAME(pixelDataForLayer(at:));
- (void)clearLayerAtIndex:(NSInteger)index NS_SWIFT_NAME(clearLayer(at:));
- (void)setLayerVisible:(BOOL)visible atIndex:(NSInteger)index NS_SWIFT_NAME(setLayerVisible(_:at:));
- (void)setLayerOpacity:(CGFloat)opacity atIndex:(NSInteger)index NS_SWIFT_NAME(setLayerOpacity(_:at:));

- (void)beginStrokeWithBrush:(APBrushDescriptor *)brush point:(APStrokePoint *)point NS_SWIFT_NAME(beginStroke(brush:point:));
- (void)appendStroke:(APStrokePoint *)point NS_SWIFT_NAME(appendStroke(point:));
- (void)endStroke NS_SWIFT_NAME(endStroke());

- (CGImageRef _Nullable)createCompositeImage CF_RETURNS_RETAINED NS_SWIFT_NAME(makeCompositeImage());

- (APDirtyRect *)consumeDirtyRect NS_SWIFT_NAME(consumeDirtyRect());
- (NSData *)pixelDataForLayerAtIndex:(NSInteger)index inRect:(APDirtyRect *)rect NS_SWIFT_NAME(pixelDataForLayer(at:in:));

@end

NS_ASSUME_NONNULL_END
