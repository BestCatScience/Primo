#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace atelierprime {

struct BrushSettings {
    std::string tipKind = "pencil";
    float radius = 3.0F;
    float sizeSpeedSensitivity = 0.0F;
    float taperIn = 0.0F;
    float taperOut = 0.0F;
    float hardness = 0.82F;
    float opacity = 0.9F;
    float roundness = 1.0F;
    float roundnessPressureSensitivity = 0.0F;
    float roundnessTiltSensitivity = 0.0F;
    float angle = 0.0F;
    float anglePressureSensitivity = 0.0F;
    float angleTiltSensitivity = 0.0F;
    int angleMode = 1;
    float stampSpacing = 0.28F;
    float spacingJitter = 0.0F;
    bool scatterEnabled = false;
    int scatterMode = 0;
    float scatterLateral = 0.0F;
    float scatterLinear = 0.0F;
    int count = 1;
    float countJitter = 0.0F;
    float countSizeJitter = 0.0F;
    float countOpacityJitter = 0.0F;
    float angleJitter = 0.0F;
    float roundnessJitter = 0.0F;
    int textureMode = 2;
    float textureStrength = 0.32F;
    float flow = 1.0F;
    float flowPressureSensitivity = 0.0F;
    float flowJitter = 0.0F;
    float wetness = 0.0F;
    float wetnessPressureSensitivity = 0.0F;
    float opacityPressureSensitivity = 0.0F;
    float colorMixStrength = 0.0F;
    float paintLoad = 1.0F;
    float loadPressureSensitivity = 0.0F;
    bool dualBrushEnabled = false;
    std::string dualTipKind = "ink";
    float dualScale = 0.72F;
    float dualSpacing = 0.26F;
    float dualScatter = 0.18F;
    float dualAngle = 0.0F;
    int dualBlendMode = 0;
    bool flipX = false;
    bool flipY = false;
    int tipMaskWidth = 0;
    int tipMaskHeight = 0;
    std::vector<uint8_t> tipMaskAlpha;
    float grainScale = 1.35F;
    float grainContrast = 1.7F;
    float paperScale = 0.12F;
    float paperThreshold = 0.42F;
    float paperStrength = 0.32F;
    float velocityInfluence = 0.012F;
    float tiltInfluence = 0.75F;
    float maxDarkness = 0.95F;
    float pressureSensitivity = 0.4F;
    int fillThresholdMode = 0;
    float fillOpacityTolerance = 0.08F;
    float fillColorTolerance = 0.12F;
    int fillExpansion = 0;
    uint8_t red = 24;
    uint8_t green = 24;
    uint8_t blue = 24;
    bool eraser = false;
};

struct StrokePoint {
    float x = 0.0F;
    float y = 0.0F;
    float pressure = 1.0F;
    float altitude = 1.5707963F;
    float azimuth = 0.0F;
    float timestamp = 0.0F;
    float speed = 0.0F;
};

struct DirtyRect {
    int minX = 0;
    int minY = 0;
    int maxX = -1;
    int maxY = -1;

    bool empty() const noexcept { return maxX < minX || maxY < minY; }

    void expand(int x0, int y0, int x1, int y1) noexcept {
        if (empty()) {
            minX = x0;
            minY = y0;
            maxX = x1;
            maxY = y1;
        } else {
            if (x0 < minX) minX = x0;
            if (y0 < minY) minY = y0;
            if (x1 > maxX) maxX = x1;
            if (y1 > maxY) maxY = y1;
        }
    }

    void reset() noexcept {
        minX = 0;
        minY = 0;
        maxX = -1;
        maxY = -1;
    }

    int width() const noexcept { return empty() ? 0 : (maxX - minX + 1); }
    int height() const noexcept { return empty() ? 0 : (maxY - minY + 1); }
};

struct Layer {
    enum class BlendMode {
        Normal,
        Darken,
        Multiply,
        ColorBurn,
        LinearBurn,
        Subtract,
        Lighten,
        Screen,
        Add,
        ColorDodge,
        GlowDodge,
        Overlay,
        SoftLight,
        HardLight,
        Difference,
        VividLight,
        LinearLight,
        PinLight,
        HardMix,
        Exclusion,
        DarkerColor,
        LighterColor,
        Divide,
        Hue,
        Saturation,
        Color,
        AddGlow,
        Luminosity,
    };

    static constexpr int kTileSize = 64;

    std::string name;
    bool visible = true;
    float opacity = 1.0F;
    BlendMode blendMode = BlendMode::Normal;
    int tileColumns = 0;
    int tileRows = 0;
    std::vector<uint8_t> tiles;
    std::vector<uint8_t> mask;
    mutable std::vector<uint8_t> pixels;
    mutable bool pixelsDirty = true;
};

struct LayerFolder {
    int id = -1;
    std::string name;
    bool visible = true;
    bool expanded = true;
    int anchorLayerIndex = -1;
};

enum class LayerProcessingKind {
    ReplacePixels,
    Clear,
    GradientMap,
    HueSaturationBrightness,
    BrightnessContrast,
    Levels,
    ToneCurve,
    ColorBalance,
    Threshold,
    Posterize,
    Transform,
};

struct LayerProcessing {
    LayerProcessingKind kind = LayerProcessingKind::ReplacePixels;
    int gradientMapPreset = 0;
    double hueDegrees = 0.0;
    double saturation = 1.0;
    double brightness = 0.0;
    double contrast = 1.0;
    double inputBlack = 0.0;
    double inputWhite = 1.0;
    double gamma = 1.0;
    double outputBlack = 0.0;
    double outputWhite = 1.0;
    double shadows = 0.0;
    double midtones = 0.0;
    double highlights = 0.0;
    double redCyan = 0.0;
    double greenMagenta = 0.0;
    double blueYellow = 0.0;
    double threshold = 0.5;
    double posterizeLevels = 6.0;
    int transformTranslateX = 0;
    int transformTranslateY = 0;
    double transformScale = 1.0;
    int selectionOriginX = 0;
    int selectionOriginY = 0;
    int selectionWidth = 0;
    int selectionHeight = 0;
    std::vector<uint8_t> selectionMask;
    std::vector<uint8_t> pixelData;
};

class PaintDocumentProcessingApplicator;

class PaintDocument {
public:
    PaintDocument(int width, int height);
    ~PaintDocument();

    int width() const noexcept;
    int height() const noexcept;

    int layerCount() const noexcept;
    int activeLayerIndex() const noexcept;
    void setActiveLayerIndex(int index);

    int addLayer(const std::string& name);
    bool deleteLayer(int index);
    bool moveLayer(int fromIndex, int toIndex);
    int createFolder(const std::string& name, int layerIndex);
    bool deleteFolder(int folderID);
    void setFolderName(int folderID, std::string name);
    void setFolderVisibility(int folderID, bool visible);
    void setFolderExpanded(int folderID, bool expanded);
    bool setLayerFolder(int layerIndex, int folderID);
    int layerFolderID(int layerIndex) const noexcept;
    bool isLayerVisibleEffective(int layerIndex) const noexcept;
    int folderCount() const noexcept;
    const LayerFolder& folderAt(int position) const;
    void clearLayer(int index);
    void setLayerName(int index, std::string name);
    void setLayerVisibility(int index, bool visible);
    void setLayerOpacity(int index, float opacity);
    void setLayerBlendMode(int index, Layer::BlendMode blendMode);
    bool applyLayerProcessing(int index, const LayerProcessing& processing);
    void replaceLayerPixels(int index, std::span<const uint8_t> pixels);
    void replaceLayerPixelsTransient(int index, std::span<const uint8_t> pixels);
    bool hasLayerMask(int index) const noexcept;
    std::vector<uint8_t> layerMaskData(int index) const;
    void replaceLayerMask(int index, std::span<const uint8_t> mask);
    void clearLayerMask(int index);
    bool applyLayerMask(int index);
    const Layer& layer(int index) const;

    void beginStroke(const BrushSettings& brush, StrokePoint point);
    void appendStroke(StrokePoint point);
    void endStroke();
    void cancelStroke();
    void fill(int x, int y, const BrushSettings& brush);
    bool canUndo() const noexcept;
    bool canRedo() const noexcept;
    bool undo();
    bool redo();
    void clearHistory() noexcept;

    DirtyRect consumeDirtyRect() noexcept;
    std::vector<uint8_t> pixelDataForRect(int layerIndex, const DirtyRect& rect) const;
    std::vector<uint8_t> compositePixelDataForRect(const DirtyRect& rect) const;

    std::span<const uint8_t> composite() const noexcept;

private:
    class StrokesQueue;

    struct HistorySnapshot {
        bool capturesEntireDocument = false;
        int activeLayerIndex = 0;
        int layerIndex = -1;
        Layer layer;
        std::vector<Layer> layers;
        std::vector<LayerFolder> folders;
        std::vector<int> layerFolderIDs;
        int nextFolderID = 1;
    };

    static constexpr size_t kMaxHistoryDepth = 24;

    int width_ = 0;
    int height_ = 0;
    int tileColumns_ = 0;
    int tileRows_ = 0;
    int activeLayerIndex_ = 0;
    BrushSettings activeBrush_;
    StrokePoint previousPoint_{};
    StrokePoint lastDabPoint_{};
    StrokePoint strokeOriginPoint_{};
    float strokeAccumulatedDistance_ = 0.0F;
    float distanceUntilNextDab_ = 0.0F;
    bool strokeHasStampedDab_ = false;
    bool strokeInFlight_ = false;
    std::optional<uint64_t> activeQueuedStrokeID_;
    DirtyRect dirtyRect_;
    std::vector<Layer> layers_;
    std::vector<LayerFolder> folders_;
    std::vector<int> layerFolderIDs_;
    std::vector<HistorySnapshot> undoStack_;
    std::vector<HistorySnapshot> redoStack_;
    std::unique_ptr<StrokesQueue> strokesQueue_;
    mutable std::vector<uint8_t> dirtyTileFlags_;
    mutable std::vector<uint8_t> compositeBuffer_;
    mutable bool compositeDirty_ = true;
    int nextFolderID_ = 1;

    friend class PaintDocumentProcessingApplicator;

    void pushHistorySnapshot();
    void pushLayerHistorySnapshot(int layerIndex);
    void beginStrokeImmediate(const BrushSettings& brush, StrokePoint point);
    void appendStrokeImmediate(StrokePoint point);
    void endStrokeImmediate();
    void cancelStrokeImmediate();
    void fillImmediate(int x, int y, const BrushSettings& brush);
    void initializeLayerStorage(Layer& layer);
    void invalidateLayerPixelCache(Layer& layer) noexcept;
    void ensureLayerPixelCache(const Layer& layer) const;
    void loadLayerPixels(Layer& layer, std::span<const uint8_t> pixels);
    size_t tileIndex(int tileX, int tileY) const noexcept;
    void markDirtyRect(int minX, int minY, int maxX, int maxY) noexcept;
    void markEntireDocumentDirty() noexcept;
    uint8_t* tilePixelPointer(Layer& layer, int x, int y) noexcept;
    const uint8_t* tilePixelPointer(const Layer& layer, int x, int y) const noexcept;
    const LayerFolder* folderByID(int folderID) const noexcept;
    void stampDab(Layer& layer, const StrokePoint& point);
    void renderStrokeSegment(Layer& layer, const StrokePoint& start, const StrokePoint& end);
    void renderShortStroke(Layer& layer, const StrokePoint& start, const StrokePoint& end);
    void blendPixel(uint8_t* dst, uint8_t r, uint8_t g, uint8_t b, float alpha, float pressure);
    void rebuildComposite() const;
};

}  // namespace atelierprime
