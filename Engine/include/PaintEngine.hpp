#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string>
#include <vector>

namespace atelierprime {

struct BrushSettings {
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
    uint8_t red = 24;
    uint8_t green = 24;
    uint8_t blue = 24;
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

struct Layer {
    std::string name;
    bool visible = true;
    float opacity = 1.0F;
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
    const Layer& layer(int index) const;

    void beginStroke(const BrushSettings& brush, StrokePoint point);
    void appendStroke(StrokePoint point);
    void endStroke();

    std::span<const uint8_t> composite() const noexcept;

private:
    int width_ = 0;
    int height_ = 0;
    int activeLayerIndex_ = 0;
    BrushSettings activeBrush_;
    StrokePoint previousPoint_{};
    bool strokeInFlight_ = false;
    std::vector<Layer> layers_;
    mutable std::vector<uint8_t> compositeBuffer_;
    mutable bool compositeDirty_ = true;

    void stampDab(Layer& layer, const StrokePoint& point);
    void blendPixel(uint8_t* dst, uint8_t r, uint8_t g, uint8_t b, float alpha);
    void rebuildComposite() const;
};

}  // namespace atelierprime
