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

float remap(float value, float inMin, float inMax, float outMin, float outMax) {
    if (std::abs(inMax - inMin) <= 0.0001F) {
        return outMin;
    }
    const float t = clamp01((value - inMin) / (inMax - inMin));
    return lerp(outMin, outMax, t);
}

float brushSpacingDistance(const BrushSettings& brush) {
    return std::max(0.35F, brush.radius * std::clamp(brush.stampSpacing, 0.08F, 2.0F));
}

float effectiveRoundness(const BrushSettings& brush, std::string_view tipKind, float altitudeFactor) {
    float roundness = std::clamp(brush.roundness, 0.18F, 1.0F);
    if (tipKind == "ink") {
        roundness *= lerp(0.74F, 0.38F, altitudeFactor);
    } else if (tipKind == "oil") {
        roundness *= 0.58F;
    } else if (tipKind == "pencil") {
        roundness *= lerp(0.92F, 0.62F, altitudeFactor * 0.75F);
    }
    return std::clamp(roundness, 0.12F, 1.0F);
}

float resolvedBrushAngle(
    const BrushSettings& brush,
    const StrokePoint& point,
    const StrokePoint& previousPoint,
    float altitudeFactor
) {
    float baseAngle = brush.angle;
    switch (brush.angleMode) {
        case 2:
            baseAngle += point.azimuth * clamp01(brush.tiltInfluence);
            break;
        case 1: {
            const float dx = point.x - previousPoint.x;
            const float dy = point.y - previousPoint.y;
            if (std::abs(dx) > 0.0001F || std::abs(dy) > 0.0001F) {
                baseAngle += std::atan2(dy, dx);
            } else {
                baseAngle += point.azimuth * altitudeFactor * 0.35F;
            }
            break;
        }
        case 0:
        default:
            baseAngle += point.azimuth * clamp01(brush.tiltInfluence) * altitudeFactor * 0.12F;
            break;
    }
    return baseAngle;
}

float textureMaskForTip(
    std::string_view tipKind,
    float alongNorm,
    float acrossNorm,
    float pointX,
    float pointY,
    float anchorX,
    float anchorY,
    float textureStrength,
    int textureMode,
    float grainScale,
    float paperScale,
    float timestamp
) {
    const float clampedTexture = clamp01(textureStrength);
    if (clampedTexture <= 0.001F) {
        return 1.0F;
    }

    const float grainFrequency = std::max(0.2F, grainScale * 2.8F);
    const float paperFrequency = std::max(0.15F, paperScale * 24.0F);
    float sampleX = pointX;
    float sampleY = pointY;
    switch (textureMode) {
        case 1:
            sampleX = anchorX + (alongNorm * 12.0F);
            sampleY = anchorY + (acrossNorm * 12.0F);
            break;
        case 2:
            sampleX = anchorX + (alongNorm * 17.0F);
            sampleY = anchorY + (acrossNorm * 17.0F);
            break;
        case 3:
            sampleX = (pointX - anchorX) + (alongNorm * 12.0F) + (timestamp * 0.8F);
            sampleY = (pointY - anchorY) + (acrossNorm * 12.0F) + (timestamp * 0.3F);
            break;
        case 0:
        default:
            return 1.0F;
    }

    const float primaryNoise = hash2D(sampleX * grainFrequency, sampleY * grainFrequency);
    const float paperNoise = hash2D((sampleX - 19.0F) * paperFrequency, (sampleY + 7.0F) * paperFrequency);

    float mask = 1.0F;
    if (tipKind == "pencil") {
        const float tooth = remap(primaryNoise, 0.0F, 1.0F, 0.42F, 1.0F);
        const float streak = 0.84F + (0.16F * std::abs(std::sin((alongNorm * 8.0F) + (acrossNorm * 4.0F))));
        mask = tooth * streak * remap(paperNoise, 0.0F, 1.0F, 0.75F, 1.0F);
    } else if (tipKind == "ink") {
        const float edgeBreak = 0.90F + (0.10F * hash2D((pointX * 0.9F) + timestamp, (pointY * 0.9F) - timestamp));
        const float fiber = 0.92F + (0.08F * std::abs(std::sin((acrossNorm * 13.0F) + (alongNorm * 1.8F))));
        mask = edgeBreak * fiber;
    } else if (tipKind == "oil") {
        const float bristleBands = 0.46F + (0.54F * std::abs(std::sin((acrossNorm * 15.0F) + (alongNorm * 2.4F) + (timestamp * 0.4F))));
        const float pigment = remap(primaryNoise, 0.0F, 1.0F, 0.78F, 1.0F);
        mask = bristleBands * pigment;
    } else if (tipKind == "airbrush") {
        const float cloud = remap(primaryNoise, 0.0F, 1.0F, 0.72F, 1.0F);
        const float dust = remap(paperNoise, 0.0F, 1.0F, 0.86F, 1.0F);
        mask = cloud * dust;
    } else {
        mask = remap(primaryNoise, 0.0F, 1.0F, 0.8F, 1.0F);
    }

    return lerp(1.0F, std::clamp(mask, 0.0F, 1.0F), clampedTexture);
}

float pencilClusterMask(
    float normalizedAlong,
    float normalizedAcross,
    float pointX,
    float pointY,
    float timestamp,
    float pressure
) {
    const float radial = std::sqrt((normalizedAlong * normalizedAlong) + (normalizedAcross * normalizedAcross));
    if (radial >= 1.0F) {
        return 0.0F;
    }

    const float coarseNoise = hash2D((pointX * 0.33F) + (normalizedAlong * 9.0F), (pointY * 0.33F) + (normalizedAcross * 9.0F));
    const float grainNoise = hash2D((pointX * 2.8F) + (normalizedAlong * 19.0F), (pointY * 2.8F) + (normalizedAcross * 19.0F));
    const float speckleNoise = hash2D((pointX * 7.4F) + (timestamp * 0.5F), (pointY * 7.4F) - (timestamp * 0.3F));

    const float lobeA = std::sqrt(std::pow((normalizedAlong + 0.18F) / 0.46F, 2.0F) + std::pow((normalizedAcross + 0.06F) / 0.34F, 2.0F));
    const float lobeB = std::sqrt(std::pow((normalizedAlong - 0.22F) / 0.34F, 2.0F) + std::pow((normalizedAcross - 0.24F) / 0.26F, 2.0F));
    const float lobeC = std::sqrt(std::pow((normalizedAlong - 0.06F) / 0.30F, 2.0F) + std::pow((normalizedAcross + 0.28F) / 0.22F, 2.0F));
    const float body = std::max({1.0F - (radial * 1.08F), 1.0F - lobeA, 1.0F - lobeB, 1.0F - lobeC});

    const float hollowA = std::sqrt(std::pow((normalizedAlong + 0.08F) / 0.18F, 2.0F) + std::pow((normalizedAcross + 0.30F) / 0.15F, 2.0F));
    const float hollowB = std::sqrt(std::pow((normalizedAlong - 0.02F) / 0.16F, 2.0F) + std::pow((normalizedAcross - 0.02F) / 0.14F, 2.0F));
    const float hollowC = std::sqrt(std::pow((normalizedAlong + 0.34F) / 0.15F, 2.0F) + std::pow((normalizedAcross - 0.10F) / 0.12F, 2.0F));
    const float hollowD = std::sqrt(std::pow((normalizedAlong - 0.28F) / 0.18F, 2.0F) + std::pow((normalizedAcross + 0.18F) / 0.10F, 2.0F));

    float mask = std::clamp(body, 0.0F, 1.0F);
    if (hollowA < 1.0F) mask *= 0.10F + (0.90F * hollowA);
    if (hollowB < 1.0F) mask *= 0.06F + (0.94F * hollowB);
    if (hollowC < 1.0F) mask *= 0.18F + (0.82F * hollowC);
    if (hollowD < 1.0F) mask *= 0.24F + (0.76F * hollowD);

    const float density = remap(coarseNoise, 0.0F, 1.0F, 0.45F, 1.0F);
    const float pepper = grainNoise > remap(pressure, 0.08F, 1.0F, 0.62F, 0.36F) ? 0.0F : 1.0F;
    const float fringe = std::pow(std::max(0.0F, 1.0F - radial), 1.9F);
    const float dust = remap(speckleNoise, 0.0F, 1.0F, 0.68F, 1.0F);

    mask *= density * pepper;
    mask = std::max(mask, fringe * dust * 0.42F);
    return std::clamp(mask, 0.0F, 1.0F);
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
    strokeOriginPoint_ = point;
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
    const float spacing = brushSpacingDistance(activeBrush_);
    const int steps = std::max(1, static_cast<int>(std::ceil(distance / spacing)));
    const float tangentX = distance > 0.001F ? (dx / distance) : std::cos(point.azimuth);
    const float tangentY = distance > 0.001F ? (dy / distance) : std::sin(point.azimuth);
    const float normalX = -tangentY;
    const float normalY = tangentX;
    const float scatterLateral = activeBrush_.scatterLateral * activeBrush_.radius;
    const float scatterLinear = activeBrush_.scatterLinear * activeBrush_.radius;

    for (int step = 1; step <= steps; ++step) {
        const float t = static_cast<float>(step) / static_cast<float>(steps);
        StrokePoint interpolated;
        interpolated.x = previousPoint_.x + (dx * t);
        interpolated.y = previousPoint_.y + (dy * t);
        interpolated.pressure = previousPoint_.pressure + ((point.pressure - previousPoint_.pressure) * t);
        interpolated.altitude = previousPoint_.altitude + ((point.altitude - previousPoint_.altitude) * t);
        interpolated.azimuth = previousPoint_.azimuth + ((point.azimuth - previousPoint_.azimuth) * t);
        interpolated.timestamp = previousPoint_.timestamp + ((point.timestamp - previousPoint_.timestamp) * t);

        if (scatterLateral > 0.001F || scatterLinear > 0.001F) {
            const float spreadAcross = (hash2D(interpolated.x + (t * 37.0F), interpolated.y - (t * 11.0F)) - 0.5F) * 2.0F * scatterLateral;
            const float spreadAlong = (hash2D(interpolated.y + (t * 23.0F), interpolated.x + (t * 17.0F)) - 0.5F) * 2.0F * scatterLinear;
            interpolated.x += (normalX * spreadAcross) + (tangentX * spreadAlong);
            interpolated.y += (normalY * spreadAcross) + (tangentY * spreadAlong);
        }

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
    const float altitudeFactor = clamp01((1.5707963F - point.altitude) / 1.5707963F);
    const float baseAngle = resolvedBrushAngle(activeBrush_, point, previousPoint_, altitudeFactor);
    const float angleCos = std::cos(baseAngle);
    const float angleSin = std::sin(baseAngle);
    const float roundness = effectiveRoundness(activeBrush_, activeBrush_.tipKind, altitudeFactor);
    const float majorRadius = radius;
    const float minorRadius = std::max(0.18F, radius * roundness);
    const float boundRadius = std::max(majorRadius, minorRadius) + 1.5F;
    const int minX = std::max(0, static_cast<int>(std::floor(point.x - boundRadius)));
    const int maxX = std::min(width_ - 1, static_cast<int>(std::ceil(point.x + boundRadius)));
    const int minY = std::max(0, static_cast<int>(std::floor(point.y - boundRadius)));
    const int maxY = std::min(height_ - 1, static_cast<int>(std::ceil(point.y + boundRadius)));
    dirtyRect_.expand(minX, minY, maxX, maxY);

    for (int y = minY; y <= maxY; ++y) {
        for (int x = minX; x <= maxX; ++x) {
            const float dx = (static_cast<float>(x) + 0.5F) - point.x;
            const float dy = (static_cast<float>(y) + 0.5F) - point.y;
            const float along = rotatedX(dx, dy, angleCos, angleSin);
            const float across = rotatedY(dx, dy, angleCos, angleSin);
            const float normalizedAlong = along / std::max(majorRadius, 0.001F);
            const float normalizedAcross = across / std::max(minorRadius, 0.001F);

            float exponent = 2.0F;
            if (isInk) {
                exponent = 5.5F;
            } else if (isOil) {
                exponent = 3.8F;
            } else if (isPencil) {
                exponent = 2.6F;
            }

            const float superellipse =
                std::pow(std::abs(normalizedAlong), exponent) +
                std::pow(std::abs(normalizedAcross), exponent);
            float shapeDistance = std::pow(superellipse, 1.0F / exponent);

            if (shapeDistance >= 1.0F) {
                continue;
            }

            float falloff = computeBaseFalloff(shapeDistance, activeBrush_.hardness);
            if (isPencil) {
                const float clusterMask = pencilClusterMask(
                    normalizedAlong,
                    normalizedAcross,
                    static_cast<float>(x),
                    static_cast<float>(y),
                    point.timestamp,
                    clampedPressure
                );
                if (clusterMask <= 0.001F) {
                    continue;
                }
                const float core = 1.0F - (shapeDistance * 0.04F);
                const float edgeDust = 0.78F + (0.22F * hash2D((static_cast<float>(x) * 5.1F) + point.x, (static_cast<float>(y) * 5.1F) + point.y));
                falloff *= std::pow(core, 1.08F) * clusterMask * edgeDust;
            } else if (isInk) {
                falloff = std::pow(falloff, 0.55F);
            } else if (isOil) {
                falloff = std::pow(falloff, 0.82F);
            } else if (isAirbrush) {
                const float mist = std::exp(-(shapeDistance * shapeDistance) * 2.6F);
                falloff = mist;
            }
            const float textureMask = textureMaskForTip(
                activeBrush_.tipKind,
                normalizedAlong,
                normalizedAcross,
                static_cast<float>(x),
                static_cast<float>(y),
                activeBrush_.textureMode == 1 ? strokeOriginPoint_.x : point.x,
                activeBrush_.textureMode == 1 ? strokeOriginPoint_.y : point.y,
                activeBrush_.textureStrength,
                activeBrush_.textureMode,
                activeBrush_.grainScale,
                activeBrush_.paperScale,
                point.timestamp
            );
            const float alpha = clamp01(effectiveOpacity * falloff * textureMask);
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
