#include "PaintEngine.hpp"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace atelierprime {

namespace {

float clamp01(float value) {
    return std::clamp(value, 0.0F, 1.0F);
}

float lerp(float a, float b, float t) {
    return a + ((b - a) * t);
}

float fract(float value) {
    return value - std::floor(value);
}

float hash2D(float x, float y) {
    return fract(std::sin((x * 127.1F) + (y * 311.7F)) * 43758.5453F);
}

float smoothNoise(float x, float y) {
    const float x0 = std::floor(x);
    const float y0 = std::floor(y);
    const float tx = x - x0;
    const float ty = y - y0;

    const float a = hash2D(x0, y0);
    const float b = hash2D(x0 + 1.0F, y0);
    const float c = hash2D(x0, y0 + 1.0F);
    const float d = hash2D(x0 + 1.0F, y0 + 1.0F);

    const float ux = tx * tx * (3.0F - (2.0F * tx));
    const float uy = ty * ty * (3.0F - (2.0F * ty));

    return lerp(lerp(a, b, ux), lerp(c, d, ux), uy);
}

float evaluatePressureCurve(float pressure, float sensitivity) {
    const float t = clamp01(pressure);
    return std::pow(t, std::max(0.05F, sensitivity));
}

float smoothstep(float edge0, float edge1, float value) {
    if (edge0 == edge1) {
        return value < edge0 ? 0.0F : 1.0F;
    }
    const float t = clamp01((value - edge0) / (edge1 - edge0));
    return t * t * (3.0F - (2.0F * t));
}

}  // namespace

PaintDocument::PaintDocument(int width, int height)
    : width_(width), height_(height), compositeBuffer_(static_cast<size_t>(width) * static_cast<size_t>(height) * 4U, 255U) {
    if (width <= 0 || height <= 0) {
        throw std::invalid_argument("Document dimensions must be positive");
    }

    addLayer("Layer 1");
}

int PaintDocument::width() const noexcept {
    return width_;
}

int PaintDocument::height() const noexcept {
    return height_;
}

int PaintDocument::layerCount() const noexcept {
    return static_cast<int>(layers_.size());
}

int PaintDocument::activeLayerIndex() const noexcept {
    return activeLayerIndex_;
}

void PaintDocument::setActiveLayerIndex(int index) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    activeLayerIndex_ = index;
}

int PaintDocument::addLayer(const std::string& name) {
    Layer layer;
    layer.name = name;
    layer.pixels.assign(static_cast<size_t>(width_) * static_cast<size_t>(height_) * 4U, 0U);
    layers_.push_back(std::move(layer));
    activeLayerIndex_ = layerCount() - 1;
    compositeDirty_ = true;
    return activeLayerIndex_;
}

void PaintDocument::clearLayer(int index) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    std::fill(layers_[index].pixels.begin(), layers_[index].pixels.end(), 0U);
    compositeDirty_ = true;
}

void PaintDocument::setLayerVisibility(int index, bool visible) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    layers_[index].visible = visible;
    compositeDirty_ = true;
}

void PaintDocument::setLayerOpacity(int index, float opacity) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    layers_[index].opacity = clamp01(opacity);
    compositeDirty_ = true;
}

const Layer& PaintDocument::layer(int index) const {
    return layers_.at(static_cast<size_t>(index));
}

void PaintDocument::beginStroke(const BrushSettings& brush, StrokePoint point) {
    activeBrush_ = brush;
    previousPoint_ = point;
    strokeInFlight_ = true;
    point.speed = 0.0F;
    stampDab(layers_[static_cast<size_t>(activeLayerIndex_)], point);
    compositeDirty_ = true;
}

void PaintDocument::appendStroke(StrokePoint point) {
    if (!strokeInFlight_) {
        return;
    }

    auto& layer = layers_[static_cast<size_t>(activeLayerIndex_)];
    const float dx = point.x - previousPoint_.x;
    const float dy = point.y - previousPoint_.y;
    const float distance = std::sqrt((dx * dx) + (dy * dy));
    const float spacing = std::max(0.5F, activeBrush_.radius * 0.28F);
    const int steps = std::max(1, static_cast<int>(std::ceil(distance / spacing)));

    for (int step = 1; step <= steps; ++step) {
        const float t = static_cast<float>(step) / static_cast<float>(steps);
        StrokePoint interpolated;
        interpolated.x = previousPoint_.x + (dx * t);
        interpolated.y = previousPoint_.y + (dy * t);
        interpolated.pressure = previousPoint_.pressure + ((point.pressure - previousPoint_.pressure) * t);
        interpolated.altitude = previousPoint_.altitude + ((point.altitude - previousPoint_.altitude) * t);
        interpolated.azimuth = previousPoint_.azimuth + ((point.azimuth - previousPoint_.azimuth) * t);
        interpolated.timestamp = previousPoint_.timestamp + ((point.timestamp - previousPoint_.timestamp) * t);

        const float timeDelta = std::max(0.001F, interpolated.timestamp - previousPoint_.timestamp);
        const float traveled = std::sqrt(((interpolated.x - previousPoint_.x) * (interpolated.x - previousPoint_.x)) +
                                         ((interpolated.y - previousPoint_.y) * (interpolated.y - previousPoint_.y)));
        interpolated.speed = traveled / timeDelta;
        stampDab(layer, interpolated);
    }

    previousPoint_ = point;
    compositeDirty_ = true;
}

void PaintDocument::endStroke() {
    strokeInFlight_ = false;
}

std::span<const uint8_t> PaintDocument::composite() const noexcept {
    if (compositeDirty_) {
        rebuildComposite();
        compositeDirty_ = false;
    }
    return compositeBuffer_;
}

void PaintDocument::stampDab(Layer& layer, const StrokePoint& point) {
    if (point.pressure <= 0.001F) {
        return;
    }

    const float curvedPressure = evaluatePressureCurve(point.pressure, activeBrush_.pressureSensitivity);
    const float altitude = clamp01(std::sin(std::max(0.05F, point.altitude)));
    const float tiltRatio = std::max(0.18F, altitude);
    const float velocityFactor = std::exp(-point.speed * activeBrush_.velocityInfluence);
    const float effectiveOpacity = clamp01(activeBrush_.opacity * (0.15F + (curvedPressure * 0.85F)) * velocityFactor * lerp(1.0F, tiltRatio, activeBrush_.tiltInfluence * 0.35F));
    const float majorRadius = std::max(0.75F, activeBrush_.radius * (0.08F + (curvedPressure * 1.2F)) / lerp(1.0F, tiltRatio, activeBrush_.tiltInfluence));
    const float minorRadius = std::max(0.6F, majorRadius * lerp(1.0F, tiltRatio, activeBrush_.tiltInfluence));
    const float maxRadius = std::max(majorRadius, minorRadius);
    const int minX = std::max(0, static_cast<int>(std::floor(point.x - maxRadius - 1.0F)));
    const int maxX = std::min(width_ - 1, static_cast<int>(std::ceil(point.x + maxRadius + 1.0F)));
    const int minY = std::max(0, static_cast<int>(std::floor(point.y - maxRadius - 1.0F)));
    const int maxY = std::min(height_ - 1, static_cast<int>(std::ceil(point.y + maxRadius + 1.0F)));
    const float cosAngle = std::cos(point.azimuth);
    const float sinAngle = std::sin(point.azimuth);

    for (int y = minY; y <= maxY; ++y) {
        for (int x = minX; x <= maxX; ++x) {
            const float dx = (static_cast<float>(x) + 0.5F) - point.x;
            const float dy = (static_cast<float>(y) + 0.5F) - point.y;
            const float localX = (dx * cosAngle) + (dy * sinAngle);
            const float localY = (-dx * sinAngle) + (dy * cosAngle);
            const float ellipse = std::sqrt(((localX * localX) / (majorRadius * majorRadius)) +
                                            ((localY * localY) / (minorRadius * minorRadius)));
            const float distance = ellipse;
            if (distance >= 1.0F) {
                continue;
            }

            const float edge = 1.0F - distance;
            const float softness = std::max(0.001F, 1.0F - activeBrush_.hardness);
            const float falloff = std::pow(edge, 1.0F / softness);
            const float grain = std::pow(smoothNoise(static_cast<float>(x) * activeBrush_.grainScale,
                                                     static_cast<float>(y) * activeBrush_.grainScale),
                                         activeBrush_.grainContrast);
            const float paper = smoothNoise(static_cast<float>(x) * activeBrush_.paperScale,
                                            static_cast<float>(y) * activeBrush_.paperScale);
            const float paperMask = lerp(1.0F - activeBrush_.paperStrength,
                                         1.0F,
                                         smoothstep(activeBrush_.paperThreshold, 1.0F, paper));
            const float alpha = clamp01(effectiveOpacity * falloff * lerp(0.65F, 1.0F, grain) * paperMask);
            auto* pixel = &layer.pixels[(static_cast<size_t>(y) * static_cast<size_t>(width_) + static_cast<size_t>(x)) * 4U];
            blendPixel(pixel, activeBrush_.red, activeBrush_.green, activeBrush_.blue, alpha);
        }
    }
}

void PaintDocument::blendPixel(uint8_t* dst, uint8_t r, uint8_t g, uint8_t b, float alpha) {
    const float srcA = clamp01(alpha);
    const float dstA = static_cast<float>(dst[3]) / 255.0F;

    if (activeBrush_.eraser) {
        const float outA = clamp01(dstA * (1.0F - srcA));
        dst[3] = static_cast<uint8_t>(outA * 255.0F);
        if (outA <= 0.001F) {
            dst[0] = 0U;
            dst[1] = 0U;
            dst[2] = 0U;
        }
        return;
    }

    const float outA = std::min(activeBrush_.maxDarkness, dstA + (srcA * (1.0F - (dstA * 0.8F))));
    const float blend = outA <= 0.0F ? 0.0F : (outA - dstA) / outA;

    dst[0] = static_cast<uint8_t>(std::lerp(static_cast<float>(dst[0]), static_cast<float>(r), std::max(blend, srcA * 0.6F)));
    dst[1] = static_cast<uint8_t>(std::lerp(static_cast<float>(dst[1]), static_cast<float>(g), std::max(blend, srcA * 0.6F)));
    dst[2] = static_cast<uint8_t>(std::lerp(static_cast<float>(dst[2]), static_cast<float>(b), std::max(blend, srcA * 0.6F)));
    dst[3] = static_cast<uint8_t>(outA * 255.0F);
}

void PaintDocument::rebuildComposite() const {
    for (int y = 0; y < height_; ++y) {
        for (int x = 0; x < width_; ++x) {
            const size_t offset = (static_cast<size_t>(y) * static_cast<size_t>(width_) + static_cast<size_t>(x)) * 4U;
            const float paper = smoothNoise(static_cast<float>(x) * 0.08F, static_cast<float>(y) * 0.08F);
            const uint8_t tone = static_cast<uint8_t>(236.0F + (paper * 16.0F));
            compositeBuffer_[offset] = tone;
            compositeBuffer_[offset + 1U] = tone;
            compositeBuffer_[offset + 2U] = static_cast<uint8_t>(tone - 3U);
            compositeBuffer_[offset + 3U] = 255U;
        }
    }

    for (size_t i = 0; i < layers_.size(); ++i) {
        const auto& layer = layers_[i];
        if (!layer.visible) {
            continue;
        }

        for (size_t offset = 0; offset < layer.pixels.size(); offset += 4U) {
            const float srcA = (static_cast<float>(layer.pixels[offset + 3U]) / 255.0F) * layer.opacity;
            if (srcA <= 0.0F) {
                continue;
            }

            const float dstA = static_cast<float>(compositeBuffer_[offset + 3U]) / 255.0F;
            const float outA = srcA + (dstA * (1.0F - srcA));
            const float blend = outA <= 0.0F ? 0.0F : srcA / outA;

            compositeBuffer_[offset] = static_cast<uint8_t>(std::lerp(static_cast<float>(compositeBuffer_[offset]), static_cast<float>(layer.pixels[offset]), blend));
            compositeBuffer_[offset + 1U] = static_cast<uint8_t>(std::lerp(static_cast<float>(compositeBuffer_[offset + 1U]), static_cast<float>(layer.pixels[offset + 1U]), blend));
            compositeBuffer_[offset + 2U] = static_cast<uint8_t>(std::lerp(static_cast<float>(compositeBuffer_[offset + 2U]), static_cast<float>(layer.pixels[offset + 2U]), blend));
            compositeBuffer_[offset + 3U] = static_cast<uint8_t>(outA * 255.0F);
        }
    }
}

}  // namespace atelierprime
