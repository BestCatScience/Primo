#include "PaintEngine.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <queue>
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

float computeBaseFalloff(float distance, float hardness) {
    const float clampedHardness = clamp01(hardness);
    if (clampedHardness >= 0.995F) {
        return 1.0F;
    }
    const float effectiveHardness = std::pow(clampedHardness, 3.2F);
    if (distance <= effectiveHardness) {
        return 1.0F;
    }
    const float span = std::max(0.001F, 1.0F - effectiveHardness);
    const float normalized = clamp01((distance - effectiveHardness) / span);
    return 1.0F - normalized;
}

float rotatedX(float dx, float dy, float cosine, float sine) {
    return (dx * cosine) + (dy * sine);
}

float rotatedY(float dx, float dy, float cosine, float sine) {
    return (-dx * sine) + (dy * cosine);
}

float blendChannel(float backdrop, float source, Layer::BlendMode mode) {
    switch (mode) {
        case Layer::BlendMode::Normal:
            return source;
        case Layer::BlendMode::Darken:
            return std::min(backdrop, source);
        case Layer::BlendMode::Multiply:
            return backdrop * source;
        case Layer::BlendMode::ColorBurn:
            return source <= 0.0F ? 0.0F : clamp01(1.0F - ((1.0F - backdrop) / std::max(0.001F, source)));
        case Layer::BlendMode::LinearBurn:
            return clamp01(backdrop + source - 1.0F);
        case Layer::BlendMode::Subtract:
            return clamp01(backdrop - source);
        case Layer::BlendMode::Lighten:
            return std::max(backdrop, source);
        case Layer::BlendMode::Screen:
            return 1.0F - ((1.0F - backdrop) * (1.0F - source));
        case Layer::BlendMode::Add:
            return clamp01(backdrop + source);
        case Layer::BlendMode::ColorDodge:
            return source >= 1.0F ? 1.0F : clamp01(backdrop / std::max(0.001F, 1.0F - source));
        case Layer::BlendMode::GlowDodge:
            return source >= 1.0F ? 1.0F : clamp01(backdrop / std::max(0.0005F, 1.0F - (source * 0.92F)));
        case Layer::BlendMode::Overlay:
            return backdrop <= 0.5F
                ? (2.0F * backdrop * source)
                : (1.0F - (2.0F * (1.0F - backdrop) * (1.0F - source)));
        case Layer::BlendMode::SoftLight:
            return source <= 0.5F
                ? (backdrop - ((1.0F - (2.0F * source)) * backdrop * (1.0F - backdrop)))
                : (backdrop + ((2.0F * source - 1.0F) * ((backdrop <= 0.25F)
                    ? ((((16.0F * backdrop - 12.0F) * backdrop) + 4.0F) * backdrop)
                    : std::sqrt(backdrop)) - backdrop));
        case Layer::BlendMode::HardLight:
            return source <= 0.5F
                ? (2.0F * backdrop * source)
                : (1.0F - (2.0F * (1.0F - backdrop) * (1.0F - source)));
        case Layer::BlendMode::Difference:
            return std::fabs(backdrop - source);
        case Layer::BlendMode::VividLight:
            return source <= 0.5F
                ? blendChannel(backdrop, 2.0F * source, Layer::BlendMode::ColorBurn)
                : blendChannel(backdrop, 2.0F * (source - 0.5F), Layer::BlendMode::ColorDodge);
        case Layer::BlendMode::LinearLight:
            return clamp01(backdrop + (2.0F * source) - 1.0F);
        case Layer::BlendMode::PinLight:
            return source <= 0.5F
                ? std::min(backdrop, 2.0F * source)
                : std::max(backdrop, 2.0F * (source - 0.5F));
        case Layer::BlendMode::HardMix:
            return blendChannel(backdrop, source, Layer::BlendMode::VividLight) < 0.5F ? 0.0F : 1.0F;
        case Layer::BlendMode::Exclusion:
            return backdrop + source - (2.0F * backdrop * source);
        case Layer::BlendMode::DarkerColor:
            return source;
        case Layer::BlendMode::LighterColor:
            return source;
        case Layer::BlendMode::Divide:
            return clamp01(backdrop / std::max(0.001F, source));
        case Layer::BlendMode::Hue:
            return source;
        case Layer::BlendMode::Saturation:
            return source;
        case Layer::BlendMode::Color:
            return source;
        case Layer::BlendMode::AddGlow:
            return clamp01(backdrop + (source * 1.35F));
        case Layer::BlendMode::Luminosity:
            return source;
    }
}

float colorLum(float r, float g, float b) {
    return (0.3F * r) + (0.59F * g) + (0.11F * b);
}

float colorSat(float r, float g, float b) {
    return std::max({r, g, b}) - std::min({r, g, b});
}

void clipColor(float& r, float& g, float& b) {
    const float lum = colorLum(r, g, b);
    const float minimum = std::min({r, g, b});
    const float maximum = std::max({r, g, b});

    if (minimum < 0.0F) {
        const float scale = lum / std::max(0.001F, lum - minimum);
        r = lum + ((r - lum) * scale);
        g = lum + ((g - lum) * scale);
        b = lum + ((b - lum) * scale);
    }

    if (maximum > 1.0F) {
        const float scale = (1.0F - lum) / std::max(0.001F, maximum - lum);
        r = lum + ((r - lum) * scale);
        g = lum + ((g - lum) * scale);
        b = lum + ((b - lum) * scale);
    }
}

void setLum(float& r, float& g, float& b, float lum) {
    const float delta = lum - colorLum(r, g, b);
    r += delta;
    g += delta;
    b += delta;
    clipColor(r, g, b);
}

void setSat(float& r, float& g, float& b, float sat) {
    float components[3] = { r, g, b };
    int minIndex = 0;
    int midIndex = 1;
    int maxIndex = 2;

    if (components[minIndex] > components[midIndex]) std::swap(minIndex, midIndex);
    if (components[midIndex] > components[maxIndex]) std::swap(midIndex, maxIndex);
    if (components[minIndex] > components[midIndex]) std::swap(minIndex, midIndex);

    if (components[maxIndex] > components[minIndex]) {
        components[midIndex] = ((components[midIndex] - components[minIndex]) * sat) / (components[maxIndex] - components[minIndex]);
        components[maxIndex] = sat;
    } else {
        components[midIndex] = 0.0F;
        components[maxIndex] = 0.0F;
    }
    components[minIndex] = 0.0F;

    r = components[0];
    g = components[1];
    b = components[2];
}

std::array<float, 3> blendColorRGB(float dstR, float dstG, float dstB, float srcR, float srcG, float srcB, Layer::BlendMode mode) {
    if (mode == Layer::BlendMode::DarkerColor) {
        return colorLum(srcR, srcG, srcB) < colorLum(dstR, dstG, dstB)
            ? std::array<float, 3>{ srcR, srcG, srcB }
            : std::array<float, 3>{ dstR, dstG, dstB };
    }

    if (mode == Layer::BlendMode::LighterColor) {
        return colorLum(srcR, srcG, srcB) > colorLum(dstR, dstG, dstB)
            ? std::array<float, 3>{ srcR, srcG, srcB }
            : std::array<float, 3>{ dstR, dstG, dstB };
    }

    if (mode == Layer::BlendMode::Hue) {
        float outR = srcR;
        float outG = srcG;
        float outB = srcB;
        setSat(outR, outG, outB, colorSat(dstR, dstG, dstB));
        setLum(outR, outG, outB, colorLum(dstR, dstG, dstB));
        return { clamp01(outR), clamp01(outG), clamp01(outB) };
    }

    if (mode == Layer::BlendMode::Saturation) {
        float outR = dstR;
        float outG = dstG;
        float outB = dstB;
        setSat(outR, outG, outB, colorSat(srcR, srcG, srcB));
        setLum(outR, outG, outB, colorLum(dstR, dstG, dstB));
        return { clamp01(outR), clamp01(outG), clamp01(outB) };
    }

    if (mode == Layer::BlendMode::Color) {
        float outR = srcR;
        float outG = srcG;
        float outB = srcB;
        setSat(outR, outG, outB, colorSat(srcR, srcG, srcB));
        setLum(outR, outG, outB, colorLum(dstR, dstG, dstB));
        return { clamp01(outR), clamp01(outG), clamp01(outB) };
    }

    if (mode == Layer::BlendMode::Luminosity) {
        float outR = dstR;
        float outG = dstG;
        float outB = dstB;
        setLum(outR, outG, outB, colorLum(srcR, srcG, srcB));
        return { clamp01(outR), clamp01(outG), clamp01(outB) };
    }

    return {
        clamp01(blendChannel(dstR, srcR, mode)),
        clamp01(blendChannel(dstG, srcG, mode)),
        clamp01(blendChannel(dstB, srcB, mode))
    };
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
    pushHistorySnapshot();
    Layer layer;
    layer.name = name;
    layer.pixels.assign(static_cast<size_t>(width_) * static_cast<size_t>(height_) * 4U, 0U);
    layers_.push_back(std::move(layer));
    activeLayerIndex_ = layerCount() - 1;
    markEntireDocumentDirty();
    compositeDirty_ = true;
    return activeLayerIndex_;
}

void PaintDocument::clearLayer(int index) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    pushLayerHistorySnapshot(index);
    std::fill(layers_[index].pixels.begin(), layers_[index].pixels.end(), 0U);
    markEntireDocumentDirty();
    compositeDirty_ = true;
}

void PaintDocument::setLayerVisibility(int index, bool visible) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    if (layers_[index].visible == visible) {
        return;
    }
    pushLayerHistorySnapshot(index);
    layers_[index].visible = visible;
    markEntireDocumentDirty();
    compositeDirty_ = true;
}

void PaintDocument::setLayerOpacity(int index, float opacity) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    const float clamped = clamp01(opacity);
    if (layers_[index].opacity == clamped) {
        return;
    }
    pushLayerHistorySnapshot(index);
    layers_[index].opacity = clamped;
    markEntireDocumentDirty();
    compositeDirty_ = true;
}

void PaintDocument::setLayerBlendMode(int index, Layer::BlendMode blendMode) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    if (layers_[index].blendMode == blendMode) {
        return;
    }
    pushLayerHistorySnapshot(index);
    layers_[index].blendMode = blendMode;
    markEntireDocumentDirty();
    compositeDirty_ = true;
}

void PaintDocument::replaceLayerPixels(int index, std::span<const uint8_t> pixels) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    auto& layer = layers_[index];
    if (pixels.size() != layer.pixels.size()) {
        return;
    }
    pushLayerHistorySnapshot(index);
    std::copy(pixels.begin(), pixels.end(), layer.pixels.begin());
    markEntireDocumentDirty();
    compositeDirty_ = true;
}

const Layer& PaintDocument::layer(int index) const {
    return layers_.at(static_cast<size_t>(index));
}

void PaintDocument::beginStroke(const BrushSettings& brush, StrokePoint point) {
    if (strokeInFlight_) {
        return;
    }
    if (point.x < 0.0F || point.x >= static_cast<float>(width_) || point.y < 0.0F || point.y >= static_cast<float>(height_)) {
        return;
    }
    pushLayerHistorySnapshot(activeLayerIndex_);
    activeBrush_ = brush;
    previousPoint_ = point;
    strokeInFlight_ = true;
    dirtyRect_.reset();
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

void PaintDocument::fill(int x, int y, const BrushSettings& brush) {
    if (strokeInFlight_ || x < 0 || x >= width_ || y < 0 || y >= height_) {
        return;
    }

    activeBrush_ = brush;
    auto& layer = layers_[static_cast<size_t>(activeLayerIndex_)];
    const size_t startOffset = (static_cast<size_t>(y) * static_cast<size_t>(width_) + static_cast<size_t>(x)) * 4U;

    const std::array<uint8_t, 4> target = {
        layer.pixels[startOffset],
        layer.pixels[startOffset + 1U],
        layer.pixels[startOffset + 2U],
        layer.pixels[startOffset + 3U]
    };

    const std::array<uint8_t, 4> replacement = brush.eraser
        ? std::array<uint8_t, 4>{0U, 0U, 0U, 0U}
        : std::array<uint8_t, 4>{brush.red, brush.green, brush.blue, static_cast<uint8_t>(clamp01(brush.opacity) * 255.0F)};

    if (target == replacement) {
        return;
    }

    pushLayerHistorySnapshot(activeLayerIndex_);

    std::queue<std::pair<int, int>> queue;
    queue.push({x, y});
    DirtyRect filledRect;
    std::vector<uint8_t> filledMask(static_cast<size_t>(width_) * static_cast<size_t>(height_), 0U);

    const auto alphaWithinTolerance = [&](uint8_t sampleAlpha) -> bool {
        const float targetAlpha = static_cast<float>(target[3]) / 255.0F;
        const float candidateAlpha = static_cast<float>(sampleAlpha) / 255.0F;
        return std::abs(candidateAlpha - targetAlpha) <= clamp01(brush.fillOpacityTolerance);
    };

    const auto colorWithinTolerance = [&](uint8_t sampleR, uint8_t sampleG, uint8_t sampleB) -> bool {
        const float dr = (static_cast<float>(sampleR) - static_cast<float>(target[0])) / 255.0F;
        const float dg = (static_cast<float>(sampleG) - static_cast<float>(target[1])) / 255.0F;
        const float db = (static_cast<float>(sampleB) - static_cast<float>(target[2])) / 255.0F;
        const float distance = std::sqrt((dr * dr) + (dg * dg) + (db * db)) / std::sqrt(3.0F);
        return distance <= clamp01(brush.fillColorTolerance);
    };

    auto matchesTarget = [&](int px, int py) -> bool {
        const size_t offset = (static_cast<size_t>(py) * static_cast<size_t>(width_) + static_cast<size_t>(px)) * 4U;
        if (brush.fillThresholdMode == 1) {
            return colorWithinTolerance(
                layer.pixels[offset],
                layer.pixels[offset + 1U],
                layer.pixels[offset + 2U]
            );
        }
        const bool sameColor =
            layer.pixels[offset] == target[0] &&
            layer.pixels[offset + 1U] == target[1] &&
            layer.pixels[offset + 2U] == target[2];
        return sameColor && alphaWithinTolerance(layer.pixels[offset + 3U]);
    };

    auto applyReplacement = [&](int px, int py) {
        const size_t offset = (static_cast<size_t>(py) * static_cast<size_t>(width_) + static_cast<size_t>(px)) * 4U;
        layer.pixels[offset] = replacement[0];
        layer.pixels[offset + 1U] = replacement[1];
        layer.pixels[offset + 2U] = replacement[2];
        layer.pixels[offset + 3U] = replacement[3];
        filledMask[static_cast<size_t>(py) * static_cast<size_t>(width_) + static_cast<size_t>(px)] = 1U;
        filledRect.expand(px, py, px, py);
    };

    while (!queue.empty()) {
        const auto [px, py] = queue.front();
        queue.pop();
        if (px < 0 || px >= width_ || py < 0 || py >= height_) {
            continue;
        }
        if (!matchesTarget(px, py)) {
            continue;
        }

        applyReplacement(px, py);

        queue.push({px - 1, py});
        queue.push({px + 1, py});
        queue.push({px, py - 1});
        queue.push({px, py + 1});
    }

    const int expansion = std::max(0, brush.fillExpansion);
    if (expansion > 0 && !filledRect.empty()) {
        std::vector<std::pair<int, int>> seeds;
        seeds.reserve(static_cast<size_t>(filledRect.width()) * static_cast<size_t>(filledRect.height()));
        for (int py = filledRect.minY; py <= filledRect.maxY; ++py) {
            for (int px = filledRect.minX; px <= filledRect.maxX; ++px) {
                if (filledMask[static_cast<size_t>(py) * static_cast<size_t>(width_) + static_cast<size_t>(px)] != 0U) {
                    seeds.push_back({px, py});
                }
            }
        }

        for (const auto& [seedX, seedY] : seeds) {
            for (int dy = -expansion; dy <= expansion; ++dy) {
                for (int dx = -expansion; dx <= expansion; ++dx) {
                    if (std::abs(dx) + std::abs(dy) > expansion) {
                        continue;
                    }
                    const int px = seedX + dx;
                    const int py = seedY + dy;
                    if (px < 0 || px >= width_ || py < 0 || py >= height_) {
                        continue;
                    }
                    const size_t offset = (static_cast<size_t>(py) * static_cast<size_t>(width_) + static_cast<size_t>(px)) * 4U;
                    layer.pixels[offset] = replacement[0];
                    layer.pixels[offset + 1U] = replacement[1];
                    layer.pixels[offset + 2U] = replacement[2];
                    layer.pixels[offset + 3U] = replacement[3];
                    filledRect.expand(px, py, px, py);
                }
            }
        }
    }

    if (!filledRect.empty()) {
        dirtyRect_.expand(filledRect.minX, filledRect.minY, filledRect.maxX, filledRect.maxY);
        compositeDirty_ = true;
    }
}

bool PaintDocument::canUndo() const noexcept {
    return !undoStack_.empty() && !strokeInFlight_;
}

bool PaintDocument::canRedo() const noexcept {
    return !redoStack_.empty() && !strokeInFlight_;
}

bool PaintDocument::undo() {
    if (!canUndo()) {
        return false;
    }

    HistorySnapshot current;
    current.activeLayerIndex = activeLayerIndex_;
    if (undoStack_.back().capturesEntireDocument) {
        current.capturesEntireDocument = true;
        current.layers = layers_;
    } else {
        current.layerIndex = undoStack_.back().layerIndex;
        if (current.layerIndex >= 0 && current.layerIndex < layerCount()) {
            current.layer = layers_[current.layerIndex];
        }
    }
    redoStack_.push_back(std::move(current));

    HistorySnapshot snapshot = std::move(undoStack_.back());
    undoStack_.pop_back();
    if (snapshot.capturesEntireDocument) {
        layers_ = std::move(snapshot.layers);
    } else if (snapshot.layerIndex >= 0 && snapshot.layerIndex < layerCount()) {
        layers_[snapshot.layerIndex] = std::move(snapshot.layer);
    }
    activeLayerIndex_ = std::clamp(snapshot.activeLayerIndex, 0, layerCount() - 1);
    strokeInFlight_ = false;
    markEntireDocumentDirty();
    compositeDirty_ = true;
    return true;
}

bool PaintDocument::redo() {
    if (!canRedo()) {
        return false;
    }

    HistorySnapshot current;
    current.activeLayerIndex = activeLayerIndex_;
    if (redoStack_.back().capturesEntireDocument) {
        current.capturesEntireDocument = true;
        current.layers = layers_;
    } else {
        current.layerIndex = redoStack_.back().layerIndex;
        if (current.layerIndex >= 0 && current.layerIndex < layerCount()) {
            current.layer = layers_[current.layerIndex];
        }
    }
    undoStack_.push_back(std::move(current));
    if (undoStack_.size() > kMaxHistoryDepth) {
        undoStack_.erase(undoStack_.begin());
    }

    HistorySnapshot snapshot = std::move(redoStack_.back());
    redoStack_.pop_back();
    if (snapshot.capturesEntireDocument) {
        layers_ = std::move(snapshot.layers);
    } else if (snapshot.layerIndex >= 0 && snapshot.layerIndex < layerCount()) {
        layers_[snapshot.layerIndex] = std::move(snapshot.layer);
    }
    activeLayerIndex_ = std::clamp(snapshot.activeLayerIndex, 0, layerCount() - 1);
    strokeInFlight_ = false;
    markEntireDocumentDirty();
    compositeDirty_ = true;
    return true;
}

DirtyRect PaintDocument::consumeDirtyRect() noexcept {
    DirtyRect result = dirtyRect_;
    dirtyRect_.reset();
    return result;
}

std::vector<uint8_t> PaintDocument::pixelDataForRect(int layerIndex, const DirtyRect& rect) const {
    if (layerIndex < 0 || layerIndex >= layerCount() || rect.empty()) {
        return {};
    }
    const auto& layer = layers_[static_cast<size_t>(layerIndex)];
    const int rectWidth = rect.width();
    const int rectHeight = rect.height();
    std::vector<uint8_t> result(static_cast<size_t>(rectWidth) * static_cast<size_t>(rectHeight) * 4U);
    for (int row = 0; row < rectHeight; ++row) {
        const int srcY = rect.minY + row;
        const size_t srcOffset = (static_cast<size_t>(srcY) * static_cast<size_t>(width_) + static_cast<size_t>(rect.minX)) * 4U;
        const size_t dstOffset = static_cast<size_t>(row) * static_cast<size_t>(rectWidth) * 4U;
        std::copy_n(layer.pixels.data() + srcOffset, static_cast<size_t>(rectWidth) * 4U, result.data() + dstOffset);
    }
    return result;
}

std::vector<uint8_t> PaintDocument::compositePixelDataForRect(const DirtyRect& rect) const {
    if (rect.empty()) {
        return {};
    }
    const auto currentComposite = composite();
    const int rectWidth = rect.width();
    const int rectHeight = rect.height();
    std::vector<uint8_t> result(static_cast<size_t>(rectWidth) * static_cast<size_t>(rectHeight) * 4U);
    for (int row = 0; row < rectHeight; ++row) {
        const int srcY = rect.minY + row;
        const size_t srcOffset = (static_cast<size_t>(srcY) * static_cast<size_t>(width_) + static_cast<size_t>(rect.minX)) * 4U;
        const size_t dstOffset = static_cast<size_t>(row) * static_cast<size_t>(rectWidth) * 4U;
        std::copy_n(currentComposite.data() + srcOffset, static_cast<size_t>(rectWidth) * 4U, result.data() + dstOffset);
    }
    return result;
}

std::span<const uint8_t> PaintDocument::composite() const noexcept {
    if (compositeDirty_) {
        rebuildComposite();
        compositeDirty_ = false;
    }
    return compositeBuffer_;
}

void PaintDocument::pushHistorySnapshot() {
    if (strokeInFlight_) {
        return;
    }

    HistorySnapshot snapshot;
    snapshot.capturesEntireDocument = true;
    snapshot.activeLayerIndex = activeLayerIndex_;
    snapshot.layers = layers_;
    undoStack_.push_back(std::move(snapshot));
    if (undoStack_.size() > kMaxHistoryDepth) {
        undoStack_.erase(undoStack_.begin());
    }
    redoStack_.clear();
}

void PaintDocument::pushLayerHistorySnapshot(int layerIndex) {
    if (strokeInFlight_ || layerIndex < 0 || layerIndex >= layerCount()) {
        return;
    }

    HistorySnapshot snapshot;
    snapshot.activeLayerIndex = activeLayerIndex_;
    snapshot.layerIndex = layerIndex;
    snapshot.layer = layers_[layerIndex];
    undoStack_.push_back(std::move(snapshot));
    if (undoStack_.size() > kMaxHistoryDepth) {
        undoStack_.erase(undoStack_.begin());
    }
    redoStack_.clear();
}

void PaintDocument::markEntireDocumentDirty() noexcept {
    dirtyRect_.expand(0, 0, width_ - 1, height_ - 1);
}

void PaintDocument::stampDab(Layer& layer, const StrokePoint& point) {
    if (point.pressure <= 0.001F) {
        return;
    }

    const float clampedPressure = std::clamp(point.pressure, 0.08F, 1.0F);
    const float clampedSensitivity = clamp01(activeBrush_.pressureSensitivity);
    const float pressureScale = (1.0F - clampedSensitivity) + (clampedPressure * clampedSensitivity);
    const float radius = std::max(0.4F, activeBrush_.radius * pressureScale);
    if (point.x < 0.0F || point.x >= static_cast<float>(width_) || point.y < 0.0F || point.y >= static_cast<float>(height_)) {
        return;
    }
    const float effectiveOpacity = clamp01(activeBrush_.opacity);
    const bool isPencil = activeBrush_.tipKind == "pencil";
    const bool isInk = activeBrush_.tipKind == "ink";
    const bool isOil = activeBrush_.tipKind == "oil";
    const bool isAirbrush = activeBrush_.tipKind == "airbrush";
    const float azimuthCos = std::cos(point.azimuth);
    const float azimuthSin = std::sin(point.azimuth);
    const float altitudeFactor = clamp01((1.5707963F - point.altitude) / 1.5707963F);
    const int minX = std::max(0, static_cast<int>(std::floor(point.x - radius - 1.0F)));
    const int maxX = std::min(width_ - 1, static_cast<int>(std::ceil(point.x + radius + 1.0F)));
    const int minY = std::max(0, static_cast<int>(std::floor(point.y - radius - 1.0F)));
    const int maxY = std::min(height_ - 1, static_cast<int>(std::ceil(point.y + radius + 1.0F)));
    dirtyRect_.expand(minX, minY, maxX, maxY);

    for (int y = minY; y <= maxY; ++y) {
        for (int x = minX; x <= maxX; ++x) {
            const float dx = (static_cast<float>(x) + 0.5F) - point.x;
            const float dy = (static_cast<float>(y) + 0.5F) - point.y;
            const float along = rotatedX(dx, dy, azimuthCos, azimuthSin);
            const float across = rotatedY(dx, dy, azimuthCos, azimuthSin);
            float shapeDistance = std::sqrt((dx * dx) + (dy * dy)) / radius;

            if (isPencil) {
                const float majorRadius = radius * lerp(1.05F, 1.42F, altitudeFactor * 0.65F);
                const float minorRadius = radius * lerp(0.95F, 0.72F, altitudeFactor * 0.55F);
                shapeDistance = std::sqrt(
                    std::pow(along / std::max(majorRadius, 0.001F), 2.0F) +
                    std::pow(across / std::max(minorRadius, 0.001F), 2.0F)
                );
            } else if (isInk) {
                const float majorRadius = radius * lerp(1.0F, 1.8F, altitudeFactor * 0.9F);
                const float minorRadius = radius * lerp(0.92F, 0.44F, altitudeFactor);
                shapeDistance = std::sqrt(
                    std::pow(along / std::max(majorRadius, 0.001F), 2.0F) +
                    std::pow(across / std::max(minorRadius, 0.001F), 2.0F)
                );
            } else if (isOil) {
                const float majorRadius = radius * lerp(1.1F, 1.95F, 0.45F + (altitudeFactor * 0.55F));
                const float minorRadius = radius * lerp(0.78F, 0.52F, altitudeFactor * 0.7F);
                const float superellipse =
                    std::pow(std::abs(along) / std::max(majorRadius, 0.001F), 4.0F) +
                    std::pow(std::abs(across) / std::max(minorRadius, 0.001F), 4.0F);
                shapeDistance = std::pow(superellipse, 0.25F);
            }

            if (shapeDistance >= 1.0F) {
                continue;
            }

            float falloff = computeBaseFalloff(shapeDistance, activeBrush_.hardness);
            if (isPencil) {
                const float tooth = 0.42F + (0.58F * hash2D((static_cast<float>(x) + 13.0F) * 1.7F, (static_cast<float>(y) - 5.0F) * 1.7F));
                const float grain = 0.72F + (0.28F * hash2D((static_cast<float>(x) * 4.5F) + point.x, (static_cast<float>(y) * 4.5F) + point.y));
                const float graphite = lerp(tooth, 1.0F, clampedPressure * 0.55F);
                falloff *= graphite * grain * std::pow(1.0F - (shapeDistance * 0.12F), 1.35F);
            } else if (isInk) {
                falloff = std::pow(falloff, 0.55F);
                falloff *= 0.96F + (0.04F * hash2D((static_cast<float>(x) * 0.9F) + point.timestamp, (static_cast<float>(y) * 0.9F) - point.timestamp));
            } else if (isOil) {
                const float alongNorm = along / std::max(radius, 0.001F);
                const float acrossNorm = across / std::max(radius, 0.001F);
                const float bristle = 0.48F + (0.52F * std::abs(std::sin((acrossNorm * 11.0F) + (alongNorm * 2.2F) + (point.timestamp * 0.6F))));
                const float pigment = 0.82F + (0.18F * hash2D((static_cast<float>(x) * 1.1F) + point.x, (static_cast<float>(y) * 1.1F) + point.y));
                const float edgeLoad = lerp(0.92F, 1.08F, clamp01(std::abs(acrossNorm) * 0.7F));
                falloff *= bristle * pigment * edgeLoad;
                falloff = std::pow(falloff, 0.82F);
            } else if (isAirbrush) {
                const float mist = std::exp(-(shapeDistance * shapeDistance) * 2.6F);
                const float cloud = 0.74F + (0.26F * hash2D((static_cast<float>(x) + point.x) * 0.8F, (static_cast<float>(y) + point.y) * 0.8F));
                falloff = mist * cloud;
            }
            const float alpha = clamp01(effectiveOpacity * falloff);
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

    const float dstR = static_cast<float>(dst[0]) / 255.0F;
    const float dstG = static_cast<float>(dst[1]) / 255.0F;
    const float dstB = static_cast<float>(dst[2]) / 255.0F;
    const float srcR = static_cast<float>(r) / 255.0F;
    const float srcG = static_cast<float>(g) / 255.0F;
    const float srcB = static_cast<float>(b) / 255.0F;

    const float outA = dstA + (srcA * (1.0F - dstA));
    if (outA <= 0.001F) {
        dst[0] = 0U;
        dst[1] = 0U;
        dst[2] = 0U;
        dst[3] = 0U;
        return;
    }

    const float outRPremul = (srcR * srcA) + (dstR * dstA * (1.0F - srcA));
    const float outGPremul = (srcG * srcA) + (dstG * dstA * (1.0F - srcA));
    const float outBPremul = (srcB * srcA) + (dstB * dstA * (1.0F - srcA));
    const float outR = clamp01(outRPremul / outA);
    const float outG = clamp01(outGPremul / outA);
    const float outB = clamp01(outBPremul / outA);

    dst[0] = static_cast<uint8_t>(outR * 255.0F);
    dst[1] = static_cast<uint8_t>(outG * 255.0F);
    dst[2] = static_cast<uint8_t>(outB * 255.0F);
    dst[3] = static_cast<uint8_t>(clamp01(outA) * 255.0F);
}

void PaintDocument::rebuildComposite() const {
    std::fill(compositeBuffer_.begin(), compositeBuffer_.end(), 0U);

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
            if (outA <= 0.0F) {
                compositeBuffer_[offset] = 0U;
                compositeBuffer_[offset + 1U] = 0U;
                compositeBuffer_[offset + 2U] = 0U;
                compositeBuffer_[offset + 3U] = 0U;
                continue;
            }

            const float srcR = static_cast<float>(layer.pixels[offset]) / 255.0F;
            const float srcG = static_cast<float>(layer.pixels[offset + 1U]) / 255.0F;
            const float srcB = static_cast<float>(layer.pixels[offset + 2U]) / 255.0F;
            const float dstR = static_cast<float>(compositeBuffer_[offset]) / 255.0F;
            const float dstG = static_cast<float>(compositeBuffer_[offset + 1U]) / 255.0F;
            const float dstB = static_cast<float>(compositeBuffer_[offset + 2U]) / 255.0F;

            const auto blended = blendColorRGB(dstR, dstG, dstB, srcR, srcG, srcB, layer.blendMode);
            const float outR = clamp01(
                (
                    srcA * ((1.0F - dstA) * srcR + (dstA * blended[0])) +
                    (dstA * (1.0F - srcA) * dstR)
                ) / outA
            );
            const float outG = clamp01(
                (
                    srcA * ((1.0F - dstA) * srcG + (dstA * blended[1])) +
                    (dstA * (1.0F - srcA) * dstG)
                ) / outA
            );
            const float outB = clamp01(
                (
                    srcA * ((1.0F - dstA) * srcB + (dstA * blended[2])) +
                    (dstA * (1.0F - srcA) * dstB)
                ) / outA
            );

            compositeBuffer_[offset] = static_cast<uint8_t>(outR * 255.0F);
            compositeBuffer_[offset + 1U] = static_cast<uint8_t>(outG * 255.0F);
            compositeBuffer_[offset + 2U] = static_cast<uint8_t>(outB * 255.0F);
            compositeBuffer_[offset + 3U] = static_cast<uint8_t>(clamp01(outA) * 255.0F);
        }
    }
}

}  // namespace atelierprime
