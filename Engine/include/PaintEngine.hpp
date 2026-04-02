#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace atelierprime {

struct BrushSettings {
    std::string tipKind = "pencil";
    float radius = 3.0F;
    float hardness = 0.82F;
    float opacity = 0.9F;
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

    std::string name;
    bool visible = true;
    float opacity = 1.0F;
    BlendMode blendMode = BlendMode::Normal;
    std::vector<uint8_t> pixels;
};

class PaintDocument {
public:
    PaintDocument(int width, int height);

    int width() const noexcept;
    int height() const noexcept;

    int layerCount() const noexcept;
    int activeLayerIndex() const noexcept;
    void setActiveLayerIndex(int index);

    int addLayer(const std::string& name);
    void clearLayer(int index);
    void setLayerVisibility(int index, bool visible);
    void setLayerOpacity(int index, float opacity);
    void setLayerBlendMode(int index, Layer::BlendMode blendMode);
    void replaceLayerPixels(int index, std::span<const uint8_t> pixels);
    const Layer& layer(int index) const;

    void beginStroke(const BrushSettings& brush, StrokePoint point);
    void appendStroke(StrokePoint point);
    void endStroke();
    void fill(int x, int y, const BrushSettings& brush);
    bool canUndo() const noexcept;
    bool canRedo() const noexcept;
    bool undo();
    bool redo();

    DirtyRect consumeDirtyRect() noexcept;
    std::vector<uint8_t> pixelDataForRect(int layerIndex, const DirtyRect& rect) const;
    std::vector<uint8_t> compositePixelDataForRect(const DirtyRect& rect) const;

    std::span<const uint8_t> composite() const noexcept;

private:
    struct HistorySnapshot {
        int activeLayerIndex = 0;
        std::vector<Layer> layers;
    };

    static constexpr size_t kMaxHistoryDepth = 24;

    int width_ = 0;
    int height_ = 0;
    int activeLayerIndex_ = 0;
    BrushSettings activeBrush_;
    StrokePoint previousPoint_{};
    bool strokeInFlight_ = false;
    DirtyRect dirtyRect_;
    std::vector<Layer> layers_;
    std::vector<HistorySnapshot> undoStack_;
    std::vector<HistorySnapshot> redoStack_;
    mutable std::vector<uint8_t> compositeBuffer_;
    mutable bool compositeDirty_ = true;

    void pushHistorySnapshot();
    void markEntireDocumentDirty() noexcept;
    void stampDab(Layer& layer, const StrokePoint& point);
    void blendPixel(uint8_t* dst, uint8_t r, uint8_t g, uint8_t b, float alpha);
    void rebuildComposite() const;
};

}  // namespace atelierprime
