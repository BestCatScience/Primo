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
    pushHistorySnapshot();
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
    pushHistorySnapshot();
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
    pushHistorySnapshot();
    layers_[index].opacity = clamped;
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
    pushHistorySnapshot();
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
    pushHistorySnapshot();
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

    pushHistorySnapshot();

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
    current.layers = layers_;
    redoStack_.push_back(std::move(current));

    HistorySnapshot snapshot = std::move(undoStack_.back());
    undoStack_.pop_back();
    layers_ = std::move(snapshot.layers);
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
    current.layers = layers_;
    undoStack_.push_back(std::move(current));
    if (undoStack_.size() > kMaxHistoryDepth) {
        undoStack_.erase(undoStack_.begin());
    }

    HistorySnapshot snapshot = std::move(redoStack_.back());
    redoStack_.pop_back();
    layers_ = std::move(snapshot.layers);
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
    snapshot.activeLayerIndex = activeLayerIndex_;
    snapshot.layers = layers_;
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
    const float effectiveOpacity = clamp01(activeBrush_.opacity);
    const int minX = std::max(0, static_cast<int>(std::floor(point.x - radius - 1.0F)));
    const int maxX = std::min(width_ - 1, static_cast<int>(std::ceil(point.x + radius + 1.0F)));
    const int minY = std::max(0, static_cast<int>(std::floor(point.y - radius - 1.0F)));
    const int maxY = std::min(height_ - 1, static_cast<int>(std::ceil(point.y + radius + 1.0F)));
    dirtyRect_.expand(minX, minY, maxX, maxY);

    for (int y = minY; y <= maxY; ++y) {
        for (int x = minX; x <= maxX; ++x) {
            const float dx = (static_cast<float>(x) + 0.5F) - point.x;
            const float dy = (static_cast<float>(y) + 0.5F) - point.y;
            const float distance = std::sqrt((dx * dx) + (dy * dy)) / radius;
            if (distance >= 1.0F) {
                continue;
            }

            const float clampedHardness = clamp01(activeBrush_.hardness);
            float falloff = 1.0F;
            if (clampedHardness < 0.995F) {
                const float effectiveHardness = std::pow(clampedHardness, 3.2F);
                if (distance <= effectiveHardness) {
                    falloff = 1.0F;
                } else {
                    const float span = std::max(0.001F, 1.0F - effectiveHardness);
                    const float normalized = clamp01((distance - effectiveHardness) / span);
                    falloff = 1.0F - normalized;
                }
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
    for (int y = 0; y < height_; ++y) {
        for (int x = 0; x < width_; ++x) {
            const size_t offset = (static_cast<size_t>(y) * static_cast<size_t>(width_) + static_cast<size_t>(x)) * 4U;
            const uint8_t tone = 239U;
            compositeBuffer_[offset] = tone;
            compositeBuffer_[offset + 1U] = tone;
            compositeBuffer_[offset + 2U] = 236U;
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
