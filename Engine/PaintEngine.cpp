#include "PaintEngine.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <deque>
#include <functional>
#include <queue>
#include <stdexcept>
#include <variant>

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

float signedNoise(float x, float y) {
    return (hash2D(x, y) * 2.0F) - 1.0F;
}

float softScatterNoise(float x, float y) {
    const float a = signedNoise(x + 17.31F, y - 9.17F);
    const float b = signedNoise(x - 23.77F, y + 14.61F);
    const float c = signedNoise(x + 6.13F, y + 27.49F);
    return (a + b + c) / 3.0F;
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

constexpr size_t kPixelStride = 4U;
constexpr size_t kTileByteCount =
    static_cast<size_t>(Layer::kTileSize) *
    static_cast<size_t>(Layer::kTileSize) *
    kPixelStride;

int tileCountForExtent(int extent) {
    return std::max(1, (extent + Layer::kTileSize - 1) / Layer::kTileSize);
}

size_t expectedLayerPixelCount(int width, int height) {
    return static_cast<size_t>(width) * static_cast<size_t>(height) * kPixelStride;
}

float brushSpacingDistance(const BrushSettings& brush) {
    return std::max(0.35F, brush.radius * std::clamp(brush.stampSpacing, 0.08F, 2.0F));
}

void constrainPixelsToAlphaLock(std::span<uint8_t> pixels, std::span<const uint8_t> source) {
    if (pixels.size() != source.size()) {
        return;
    }

    for (size_t offset = 0; offset + 3U < pixels.size(); offset += kPixelStride) {
        const uint8_t sourceAlpha = source[offset + 3U];
        if (sourceAlpha == 0U) {
            pixels[offset] = 0U;
            pixels[offset + 1U] = 0U;
            pixels[offset + 2U] = 0U;
            pixels[offset + 3U] = 0U;
            continue;
        }
        pixels[offset + 3U] = sourceAlpha;
    }
}

float pressureScaleForBrush(const BrushSettings& brush, float pressure) {
    const float clampedPressure = std::clamp(pressure, 0.08F, 1.0F);
    const float clampedSensitivity = clamp01(brush.pressureSensitivity);
    return (1.0F - clampedSensitivity) + (clampedPressure * clampedSensitivity);
}

float normalizedSpeedFactor(const BrushSettings& brush, float speed) {
    return clamp01(speed / std::max(12.0F, brush.radius * 18.0F));
}

float speedScaleForBrush(const BrushSettings& brush, float speed) {
    const float speedFactor = normalizedSpeedFactor(brush, speed);
    const float clampedSensitivity = std::clamp(brush.sizeSpeedSensitivity, -1.0F, 1.0F);
    return std::max(0.3F, 1.0F + (clampedSensitivity * speedFactor * 0.42F));
}

float speedOpacityScaleForBrush(const BrushSettings& brush, float speed) {
    const float speedFactor = normalizedSpeedFactor(brush, speed);
    const float clampedSensitivity = std::clamp(brush.velocityInfluence, -1.0F, 1.0F);
    return std::max(0.2F, 1.0F + (clampedSensitivity * speedFactor * 0.6F));
}

float resolvedStrokeRadius(const BrushSettings& brush, float pressure, float speed) {
    return std::max(0.4F, brush.radius * pressureScaleForBrush(brush, pressure) * speedScaleForBrush(brush, speed));
}

bool shouldPreserveCircularInkTip(const BrushSettings& brush) {
    if (brush.tipKind != "ink") {
        return false;
    }
    if (brush.tipMaskWidth > 0 && brush.tipMaskHeight > 0 && !brush.tipMaskAlpha.empty()) {
        return false;
    }
    return brush.roundness >= 0.98F &&
        std::abs(brush.roundnessPressureSensitivity) <= 0.001F &&
        std::abs(brush.roundnessTiltSensitivity) <= 0.001F &&
        std::abs(brush.anglePressureSensitivity) <= 0.001F &&
        std::abs(brush.angleTiltSensitivity) <= 0.001F &&
        std::abs(brush.angleJitter) <= 0.001F &&
        std::abs(brush.roundnessJitter) <= 0.001F;
}

float effectiveRoundness(const BrushSettings& brush, std::string_view tipKind, float altitudeFactor) {
    float roundness = std::clamp(brush.roundness, 0.18F, 1.0F);
    if (tipKind == "ink" && shouldPreserveCircularInkTip(brush)) {
        return roundness;
    }
    if (tipKind == "ink") {
        roundness *= lerp(0.74F, 0.38F, altitudeFactor);
    } else if (tipKind == "oil") {
        roundness *= 0.58F;
    } else if (tipKind == "pencil") {
        roundness *= lerp(0.92F, 0.62F, altitudeFactor * 0.75F);
    }
    return std::clamp(roundness, 0.12F, 1.0F);
}

float shapeExponentForTip(std::string_view tipKind) {
    if (tipKind == "ink") {
        return 5.5F;
    }
    if (tipKind == "oil") {
        return 3.8F;
    }
    if (tipKind == "pencil") {
        return 2.6F;
    }
    return 2.0F;
}

float shapeDistanceForTip(std::string_view tipKind, float normalizedAlong, float normalizedAcross) {
    const float exponent = shapeExponentForTip(tipKind);
    const float superellipse =
        std::pow(std::abs(normalizedAlong), exponent) +
        std::pow(std::abs(normalizedAcross), exponent);
    return std::pow(superellipse, 1.0F / exponent);
}

float resolvedBrushAngle(
    const BrushSettings& brush,
    const StrokePoint& point,
    const StrokePoint& previousPoint,
    float altitudeFactor
) {
    float baseAngle = brush.angle;
    if (shouldPreserveCircularInkTip(brush)) {
        return baseAngle;
    }
    switch (brush.angleMode) {
        case 2:
            baseAngle += point.azimuth * clamp01(brush.tiltInfluence);
            break;
        case 1: {
            const float dx = point.x - previousPoint.x;
            const float dy = point.y - previousPoint.y;
            if (std::abs(dx) > 0.0001F || std::abs(dy) > 0.0001F) {
                baseAngle += std::atan2(dy, dx);
            }
            break;
        }
        case 0:
        default:
            baseAngle += point.azimuth * clamp01(brush.tiltInfluence) * altitudeFactor * 0.12F;
            break;
    }
    baseAngle += brush.anglePressureSensitivity * remap(point.pressure, 0.08F, 1.0F, -0.35F, 0.35F);
    baseAngle += brush.angleTiltSensitivity * point.azimuth * altitudeFactor * clamp01(brush.tiltInfluence);
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
    float grainContrast,
    float paperScale,
    float paperThreshold,
    float paperStrength,
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
    const float grainResponse = std::pow(
        std::clamp(primaryNoise, 0.001F, 1.0F),
        std::max(0.35F, grainContrast)
    );
    const float paperCut = clamp01(remap(
        paperNoise,
        std::clamp(paperThreshold - 0.34F, 0.0F, 1.0F),
        std::clamp(paperThreshold + 0.22F, 0.0F, 1.0F),
        0.0F,
        1.0F
    ));

    float mask = 1.0F;
    if (tipKind == "pencil") {
        const float tooth = remap(grainResponse, 0.0F, 1.0F, 0.36F, 1.0F);
        const float streak = 0.84F + (0.16F * std::abs(std::sin((alongNorm * 8.0F) + (acrossNorm * 4.0F))));
        mask = tooth * streak * lerp(1.0F, remap(paperCut, 0.0F, 1.0F, 0.68F, 1.0F), clamp01(paperStrength));
    } else if (tipKind == "ink") {
        const float edgeBreak = 0.90F + (0.10F * hash2D((pointX * 0.9F) + timestamp, (pointY * 0.9F) - timestamp));
        const float fiber = 0.92F + (0.08F * std::abs(std::sin((acrossNorm * 13.0F) + (alongNorm * 1.8F))));
        mask = edgeBreak * fiber * lerp(1.0F, remap(paperCut, 0.0F, 1.0F, 0.82F, 1.0F), clamp01(paperStrength * 0.55F));
    } else if (tipKind == "oil") {
        const float bristleBands = 0.46F + (0.54F * std::abs(std::sin((acrossNorm * 15.0F) + (alongNorm * 2.4F) + (timestamp * 0.4F))));
        const float pigment = remap(grainResponse, 0.0F, 1.0F, 0.72F, 1.0F);
        mask = bristleBands * pigment * lerp(1.0F, remap(paperCut, 0.0F, 1.0F, 0.86F, 1.0F), clamp01(paperStrength * 0.4F));
    } else if (tipKind == "airbrush") {
        const float cloud = remap(grainResponse, 0.0F, 1.0F, 0.70F, 1.0F);
        const float dust = lerp(1.0F, remap(paperCut, 0.0F, 1.0F, 0.82F, 1.0F), clamp01(paperStrength * 0.65F));
        mask = cloud * dust;
    } else {
        mask = remap(grainResponse, 0.0F, 1.0F, 0.8F, 1.0F);
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

float sampleBrushTipAlpha(const BrushSettings& brush, float normalizedAlong, float normalizedAcross) {
    if (brush.tipMaskWidth <= 0 || brush.tipMaskHeight <= 0 || brush.tipMaskAlpha.empty()) {
        return 1.0F;
    }

    const float u = ((normalizedAlong + 1.0F) * 0.5F);
    const float v = ((normalizedAcross + 1.0F) * 0.5F);
    if (u < 0.0F || u > 1.0F || v < 0.0F || v > 1.0F) {
        return 0.0F;
    }

    const float sampleX = u * static_cast<float>(brush.tipMaskWidth - 1);
    const float sampleY = v * static_cast<float>(brush.tipMaskHeight - 1);
    const int x0 = std::clamp(static_cast<int>(std::floor(sampleX)), 0, brush.tipMaskWidth - 1);
    const int y0 = std::clamp(static_cast<int>(std::floor(sampleY)), 0, brush.tipMaskHeight - 1);
    const int x1 = std::clamp(x0 + 1, 0, brush.tipMaskWidth - 1);
    const int y1 = std::clamp(y0 + 1, 0, brush.tipMaskHeight - 1);
    const float tx = sampleX - static_cast<float>(x0);
    const float ty = sampleY - static_cast<float>(y0);

    const auto alphaAt = [&](int x, int y) -> float {
        const size_t index = static_cast<size_t>(y * brush.tipMaskWidth + x);
        if (index >= brush.tipMaskAlpha.size()) {
            return 0.0F;
        }
        return static_cast<float>(brush.tipMaskAlpha[index]) / 255.0F;
    };

    const float top = lerp(alphaAt(x0, y0), alphaAt(x1, y0), tx);
    const float bottom = lerp(alphaAt(x0, y1), alphaAt(x1, y1), tx);
    return lerp(top, bottom, ty);
}

float jitterValue(float seedA, float seedB, float amount) {
    if (amount <= 0.001F) {
        return 0.0F;
    }
    return ((hash2D(seedA, seedB) - 0.5F) * 2.0F) * amount;
}

float nextBrushSpacingDistance(const BrushSettings& brush, const StrokePoint& point) {
    const float baseSpacing = brushSpacingDistance(brush);
    const float jitteredSpacing = baseSpacing * (
        1.0F + jitterValue(
            point.x + (point.timestamp * 0.37F),
            point.y - (point.timestamp * 0.21F),
            brush.spacingJitter
        )
    );
    return std::max(0.2F, jitteredSpacing);
}

float dualBrushMask(
    const BrushSettings& brush,
    float pointX,
    float pointY,
    float sampleX,
    float sampleY,
    float radius,
    float dabAngle,
    float baseRoundness,
    float dabSeed,
    float timestamp
) {
    if (!brush.dualBrushEnabled) {
        return 1.0F;
    }

    const float dualScale = std::clamp(brush.dualScale, 0.2F, 2.2F);
    const float dualRoundness = effectiveRoundness(brush, brush.dualTipKind, 0.0F);
    const float dualMajorRadius = std::max(0.12F, radius * dualScale);
    const float dualMinorRadius = std::max(0.12F, radius * dualScale * std::clamp(dualRoundness * lerp(0.9F, 1.15F, baseRoundness), 0.12F, 1.0F));
    const float dualAngle = dabAngle + brush.dualAngle;
    const float dualCos = std::cos(dualAngle);
    const float dualSin = std::sin(dualAngle);
    const float dualSpacingOffset = (hash2D(pointX + (dabSeed * 0.41F), pointY - (dabSeed * 0.23F)) - 0.5F) * 2.0F * brush.dualSpacing * radius;
    const float dualScatterOffset = jitterValue(pointY + (dabSeed * 0.77F), pointX - (dabSeed * 0.59F), brush.dualScatter * radius);
    const float dualCenterX = pointX + (std::cos(dualAngle) * dualSpacingOffset) - (std::sin(dualAngle) * dualScatterOffset);
    const float dualCenterY = pointY + (std::sin(dualAngle) * dualSpacingOffset) + (std::cos(dualAngle) * dualScatterOffset);
    const float dx = sampleX - dualCenterX;
    const float dy = sampleY - dualCenterY;
    const float along = rotatedX(dx, dy, dualCos, dualSin);
    const float across = rotatedY(dx, dy, dualCos, dualSin);
    const float normalizedAlong = along / std::max(dualMajorRadius, 0.001F);
    const float normalizedAcross = across / std::max(dualMinorRadius, 0.001F);

    const float dualShapeDistance = shapeDistanceForTip(brush.dualTipKind, normalizedAlong, normalizedAcross);
    float mask = computeBaseFalloff(dualShapeDistance, std::clamp(brush.hardness * 0.94F, 0.16F, 0.99F));
    if (brush.tipMaskWidth > 0 && brush.tipMaskHeight > 0 && !brush.tipMaskAlpha.empty()) {
        mask *= sampleBrushTipAlpha(brush, normalizedAlong, normalizedAcross);
    }

    const float breakup = 0.78F + (0.22F * hash2D((sampleX * 1.9F) + timestamp + dabSeed, (sampleY * 1.9F) - timestamp - dabSeed));
    mask = std::clamp(mask * breakup, 0.0F, 1.0F);

    switch (brush.dualBlendMode) {
        case 1:
            return std::min(1.0F, mask);
        case 2:
            return clamp01(1.0F - (mask * 0.88F));
        case 0:
        default:
            return std::clamp(mask, 0.0F, 1.0F);
    }
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

struct GradientMapStop {
    double position = 0.0;
    uint8_t red = 0U;
    uint8_t green = 0U;
    uint8_t blue = 0U;
};

struct LayerProcessingContext {
    int layerIndex = -1;
    int width = 0;
    int height = 0;
};

struct TransformBounds {
    int minX = 0;
    int minY = 0;
    int maxX = -1;
    int maxY = -1;

    bool empty() const noexcept {
        return maxX < minX || maxY < minY;
    }

    double midX() const noexcept {
        return static_cast<double>(minX) + (static_cast<double>((maxX - minX) + 1) / 2.0);
    }

    double midY() const noexcept {
        return static_cast<double>(minY) + (static_cast<double>((maxY - minY) + 1) / 2.0);
    }
};

std::vector<GradientMapStop> gradientMapStopsForPreset(int preset) {
    switch (preset) {
        case 0:
            return {
                {0.0, 17U, 21U, 27U},
                {0.38, 84U, 93U, 108U},
                {1.0, 243U, 244U, 246U},
            };
        case 1:
            return {
                {0.0, 28U, 17U, 12U},
                {0.42, 123U, 74U, 40U},
                {1.0, 241U, 220U, 184U},
            };
        case 2:
            return {
                {0.0, 8U, 19U, 44U},
                {0.45, 27U, 110U, 171U},
                {1.0, 192U, 241U, 255U},
            };
        case 3:
            return {
                {0.0, 36U, 11U, 54U},
                {0.4, 173U, 58U, 91U},
                {0.72, 244U, 142U, 68U},
                {1.0, 255U, 223U, 128U},
            };
        case 4:
            return {
                {0.0, 4U, 23U, 18U},
                {0.44, 35U, 172U, 106U},
                {1.0, 227U, 255U, 111U},
            };
        default:
            return {};
    }
}

std::array<uint8_t, 3> mappedGradientColor(double value, const std::vector<GradientMapStop>& stops) {
    const double clampedValue = std::clamp(value, 0.0, 1.0);
    const auto upper = std::find_if(stops.begin(), stops.end(), [clampedValue](const GradientMapStop& stop) {
        return clampedValue <= stop.position;
    });

    if (upper == stops.end()) {
        const GradientMapStop& last = stops.back();
        return {last.red, last.green, last.blue};
    }
    if (upper == stops.begin()) {
        return {upper->red, upper->green, upper->blue};
    }

    const GradientMapStop& lower = *std::prev(upper);
    const double span = std::max(upper->position - lower.position, 0.0001);
    const double t = (clampedValue - lower.position) / span;
    const auto mix = [t](uint8_t a, uint8_t b) -> uint8_t {
        return static_cast<uint8_t>(std::clamp(std::lround(static_cast<double>(a) + ((static_cast<double>(b) - static_cast<double>(a)) * t)), 0L, 255L));
    };

    return {
        mix(lower.red, upper->red),
        mix(lower.green, upper->green),
        mix(lower.blue, upper->blue),
    };
}

struct HSVColor {
    double hue = 0.0;
    double saturation = 0.0;
    double value = 0.0;
};

HSVColor rgbToHSV(double red, double green, double blue) {
    const double maxValue = std::max({red, green, blue});
    const double minValue = std::min({red, green, blue});
    const double delta = maxValue - minValue;

    double hue = 0.0;
    if (delta >= 0.000001) {
        if (maxValue == red) {
            hue = std::fmod((green - blue) / delta, 6.0) / 6.0;
        } else if (maxValue == green) {
            hue = (((blue - red) / delta) + 2.0) / 6.0;
        } else {
            hue = (((red - green) / delta) + 4.0) / 6.0;
        }
    }
    if (hue < 0.0) {
        hue += 1.0;
    }

    return HSVColor{
        .hue = hue,
        .saturation = maxValue <= 0.0 ? 0.0 : delta / maxValue,
        .value = maxValue,
    };
}

std::array<double, 3> hsvToRGB(double hue, double saturation, double value) {
    if (saturation <= 0.000001) {
        return {value, value, value};
    }

    const double scaledHue = std::fmod(hue - std::floor(hue), 1.0) * 6.0;
    const int sector = static_cast<int>(std::floor(scaledHue));
    const double fraction = scaledHue - static_cast<double>(sector);
    const double p = value * (1.0 - saturation);
    const double q = value * (1.0 - (saturation * fraction));
    const double t = value * (1.0 - (saturation * (1.0 - fraction)));

    switch (sector) {
        case 0:
            return {value, t, p};
        case 1:
            return {q, value, p};
        case 2:
            return {p, value, t};
        case 3:
            return {p, q, value};
        case 4:
            return {t, p, value};
        default:
            return {value, p, q};
    }
}

std::optional<std::vector<uint8_t>> expandedSelectionMask(
    const LayerProcessing& processing,
    int canvasWidth,
    int canvasHeight
) {
    if (processing.selectionWidth <= 0 ||
        processing.selectionHeight <= 0 ||
        processing.selectionMask.empty() ||
        processing.selectionMask.size() != static_cast<size_t>(processing.selectionWidth) * static_cast<size_t>(processing.selectionHeight)) {
        return std::nullopt;
    }

    const int originX = std::max(processing.selectionOriginX, 0);
    const int originY = std::max(processing.selectionOriginY, 0);
    const int copyWidth = std::min(processing.selectionWidth, canvasWidth - originX);
    const int copyHeight = std::min(processing.selectionHeight, canvasHeight - originY);
    if (copyWidth <= 0 || copyHeight <= 0) {
        return std::nullopt;
    }

    std::vector<uint8_t> result(static_cast<size_t>(canvasWidth) * static_cast<size_t>(canvasHeight), 0U);
    for (int y = 0; y < copyHeight; ++y) {
        for (int x = 0; x < copyWidth; ++x) {
            const size_t sourceIndex = static_cast<size_t>(y * processing.selectionWidth + x);
            const size_t destinationIndex = static_cast<size_t>((originY + y) * canvasWidth + (originX + x));
            result[destinationIndex] = processing.selectionMask[sourceIndex];
        }
    }
    return result;
}

std::vector<uint8_t> alphaMask(std::span<const uint8_t> source, int canvasWidth, int canvasHeight) {
    std::vector<uint8_t> result(static_cast<size_t>(canvasWidth) * static_cast<size_t>(canvasHeight), 0U);
    for (int index = 0; index < canvasWidth * canvasHeight; ++index) {
        if (source[static_cast<size_t>(index) * kPixelStride + 3U] != 0U) {
            result[static_cast<size_t>(index)] = 255U;
        }
    }
    return result;
}

std::optional<TransformBounds> transformationBounds(
    const LayerProcessing& processing,
    const std::optional<std::vector<uint8_t>>& selectionMask,
    std::span<const uint8_t> source,
    int canvasWidth,
    int canvasHeight
) {
    if (selectionMask.has_value()) {
        const int minX = std::clamp(processing.selectionOriginX, 0, std::max(canvasWidth - 1, 0));
        const int minY = std::clamp(processing.selectionOriginY, 0, std::max(canvasHeight - 1, 0));
        const int maxX = std::clamp(processing.selectionOriginX + processing.selectionWidth - 1, 0, std::max(canvasWidth - 1, 0));
        const int maxY = std::clamp(processing.selectionOriginY + processing.selectionHeight - 1, 0, std::max(canvasHeight - 1, 0));
        if (maxX >= minX && maxY >= minY) {
            return TransformBounds{
                .minX = minX,
                .minY = minY,
                .maxX = maxX,
                .maxY = maxY,
            };
        }
        return std::nullopt;
    }

    TransformBounds bounds{
        .minX = canvasWidth,
        .minY = canvasHeight,
        .maxX = -1,
        .maxY = -1,
    };
    for (int y = 0; y < canvasHeight; ++y) {
        for (int x = 0; x < canvasWidth; ++x) {
            if (source[(static_cast<size_t>(y * canvasWidth + x) * kPixelStride) + 3U] == 0U) {
                continue;
            }
            bounds.minX = std::min(bounds.minX, x);
            bounds.minY = std::min(bounds.minY, y);
            bounds.maxX = std::max(bounds.maxX, x);
            bounds.maxY = std::max(bounds.maxY, y);
        }
    }

    if (bounds.empty()) {
        return std::nullopt;
    }
    return bounds;
}

std::optional<std::vector<uint8_t>> transformedPixels(
    const LayerProcessing& processing,
    std::span<const uint8_t> source,
    int canvasWidth,
    int canvasHeight
) {
    const int dx = processing.transformTranslateX;
    const int dy = processing.transformTranslateY;
    const double clampedScale = std::clamp(processing.transformScale, 0.2, 6.0);
    if ((dx == 0 && dy == 0) && std::abs(clampedScale - 1.0) <= 0.001) {
        return std::nullopt;
    }

    if (source.size() != expectedLayerPixelCount(canvasWidth, canvasHeight)) {
        return std::nullopt;
    }

    const auto selectionMask = expandedSelectionMask(processing, canvasWidth, canvasHeight);
    const std::vector<uint8_t> mask = selectionMask.value_or(alphaMask(source, canvasWidth, canvasHeight));
    const auto bounds = transformationBounds(processing, selectionMask, source, canvasWidth, canvasHeight);
    if (!bounds.has_value()) {
        return std::nullopt;
    }

    std::vector<uint8_t> destination(source.begin(), source.end());
    for (int index = 0; index < canvasWidth * canvasHeight; ++index) {
        if (mask[static_cast<size_t>(index)] == 0U) {
            continue;
        }
        const size_t pixelOffset = static_cast<size_t>(index) * kPixelStride;
        destination[pixelOffset] = 0U;
        destination[pixelOffset + 1U] = 0U;
        destination[pixelOffset + 2U] = 0U;
        destination[pixelOffset + 3U] = 0U;
    }

    const double anchorX = bounds->midX();
    const double anchorY = bounds->midY();
    for (int y = 0; y < canvasHeight; ++y) {
        for (int x = 0; x < canvasWidth; ++x) {
            const double destinationPointX = static_cast<double>(x - dx);
            const double destinationPointY = static_cast<double>(y - dy);
            const double sourceX = ((destinationPointX - anchorX) / clampedScale) + anchorX;
            const double sourceY = ((destinationPointY - anchorY) / clampedScale) + anchorY;
            const int sourcePixelX = static_cast<int>(std::lround(sourceX));
            const int sourcePixelY = static_cast<int>(std::lround(sourceY));
            if (sourcePixelX < 0 || sourcePixelX >= canvasWidth || sourcePixelY < 0 || sourcePixelY >= canvasHeight) {
                continue;
            }

            const size_t sourceIndex = static_cast<size_t>(sourcePixelY * canvasWidth + sourcePixelX);
            if (mask[sourceIndex] == 0U) {
                continue;
            }

            const size_t sourceOffset = sourceIndex * kPixelStride;
            if (source[sourceOffset + 3U] == 0U) {
                continue;
            }

            const size_t destinationOffset = static_cast<size_t>(y * canvasWidth + x) * kPixelStride;
            destination[destinationOffset] = source[sourceOffset];
            destination[destinationOffset + 1U] = source[sourceOffset + 1U];
            destination[destinationOffset + 2U] = source[sourceOffset + 2U];
            destination[destinationOffset + 3U] = source[sourceOffset + 3U];
        }
    }

    return destination;
}

}  // namespace

namespace {

enum class StrokeJobType {
    Concurrent,
    Sequential,
    Barrier,
};

enum class StrokeJobKind {
    Initialization,
    Dab,
    Finish,
    Cancel,
};

enum class StrokeCommand {
    BeginFreehand,
    AppendFreehand,
    EndFreehand,
    CancelFreehand,
    Fill,
};

struct FillPoint {
    int x = 0;
    int y = 0;
};

using StrokeJobPayload = std::variant<std::monostate, StrokePoint, FillPoint>;

struct StrokeJobData {
    StrokeJobPayload payload;
};

struct StrokeJob {
    StrokeJobKind kind = StrokeJobKind::Dab;
    StrokeJobType type = StrokeJobType::Sequential;
    StrokeCommand command = StrokeCommand::AppendFreehand;
    BrushSettings brush;
    StrokeJobPayload payload;
    bool exclusive = false;
};

class StrokeStrategy {
public:
    virtual ~StrokeStrategy() = default;

    virtual std::string name() const = 0;
    virtual bool isExclusive() const noexcept { return false; }
    virtual StrokeJob createInitJob(const StrokeJobData& data) const = 0;
    virtual StrokeJob createDabJob(const StrokeJobData& data) const = 0;
    virtual std::optional<StrokeJob> createFinishJob() const { return std::nullopt; }
    virtual std::optional<StrokeJob> createCancelJob() const { return std::nullopt; }
};

class FreehandStrokeStrategy final : public StrokeStrategy {
public:
    explicit FreehandStrokeStrategy(BrushSettings brush)
        : brush_(std::move(brush)) {}

    std::string name() const override {
        return "Freehand Stroke";
    }

    StrokeJob createInitJob(const StrokeJobData& data) const override {
        return StrokeJob{
            .kind = StrokeJobKind::Initialization,
            .type = StrokeJobType::Sequential,
            .command = StrokeCommand::BeginFreehand,
            .brush = brush_,
            .payload = data.payload,
            .exclusive = false,
        };
    }

    StrokeJob createDabJob(const StrokeJobData& data) const override {
        return StrokeJob{
            .kind = StrokeJobKind::Dab,
            .type = StrokeJobType::Sequential,
            .command = StrokeCommand::AppendFreehand,
            .payload = data.payload,
            .exclusive = false,
        };
    }

    std::optional<StrokeJob> createFinishJob() const override {
        return StrokeJob{
            .kind = StrokeJobKind::Finish,
            .type = StrokeJobType::Barrier,
            .command = StrokeCommand::EndFreehand,
            .exclusive = false,
        };
    }

    std::optional<StrokeJob> createCancelJob() const override {
        return StrokeJob{
            .kind = StrokeJobKind::Cancel,
            .type = StrokeJobType::Barrier,
            .command = StrokeCommand::CancelFreehand,
            .exclusive = false,
        };
    }

private:
    BrushSettings brush_;
};

class FillStrokeStrategy final : public StrokeStrategy {
public:
    explicit FillStrokeStrategy(BrushSettings brush)
        : brush_(std::move(brush)) {}

    std::string name() const override {
        return "Fill Stroke";
    }

    StrokeJob createInitJob(const StrokeJobData& data) const override {
        return createDabJob(data);
    }

    StrokeJob createDabJob(const StrokeJobData& data) const override {
        return StrokeJob{
            .kind = StrokeJobKind::Dab,
            .type = StrokeJobType::Sequential,
            .command = StrokeCommand::Fill,
            .brush = brush_,
            .payload = data.payload,
            .exclusive = false,
        };
    }

private:
    BrushSettings brush_;
};

struct Stroke {
    uint64_t id = 0;
    std::unique_ptr<StrokeStrategy> strategy;
    std::deque<StrokeJob> jobs;
    bool isEnded = false;
    bool isCanceled = false;

    [[nodiscard]] bool isOpen() const noexcept {
        return !isEnded && !isCanceled;
    }
};

}  // namespace

namespace {

class PaintDocumentLayerProcessingVisitor {
public:
    virtual ~PaintDocumentLayerProcessingVisitor() = default;

    virtual std::optional<std::vector<uint8_t>> process(
        const LayerProcessingContext& context,
        std::span<const uint8_t> source
    ) const = 0;
};

class DescriptorLayerProcessingVisitor final : public PaintDocumentLayerProcessingVisitor {
public:
    explicit DescriptorLayerProcessingVisitor(LayerProcessing processing)
        : processing_(std::move(processing)) {}

    std::optional<std::vector<uint8_t>> process(
        const LayerProcessingContext& context,
        std::span<const uint8_t> source
    ) const override {
        if (source.size() != expectedLayerPixelCount(context.width, context.height)) {
            return std::nullopt;
        }

        switch (processing_.kind) {
            case LayerProcessingKind::ReplacePixels:
                if (processing_.pixelData.size() != source.size()) {
                    return std::nullopt;
                }
                return processing_.pixelData;

            case LayerProcessingKind::Clear:
                return std::vector<uint8_t>(source.size(), 0U);

            case LayerProcessingKind::GradientMap: {
                const std::vector<GradientMapStop> stops = gradientMapStopsForPreset(processing_.gradientMapPreset);
                if (stops.size() < 2) {
                    return std::nullopt;
                }

                std::vector<uint8_t> output(source.begin(), source.end());
                for (size_t offset = 0; offset < output.size(); offset += kPixelStride) {
                    if (output[offset + 3U] == 0U) {
                        continue;
                    }

                    const double red = static_cast<double>(output[offset]) / 255.0;
                    const double green = static_cast<double>(output[offset + 1U]) / 255.0;
                    const double blue = static_cast<double>(output[offset + 2U]) / 255.0;
                    const double luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
                    const auto mapped = mappedGradientColor(luminance, stops);
                    output[offset] = mapped[0];
                    output[offset + 1U] = mapped[1];
                    output[offset + 2U] = mapped[2];
                }
                return output;
            }

            case LayerProcessingKind::HueSaturationBrightness: {
                std::vector<uint8_t> output(source.begin(), source.end());
                const double hueShift = processing_.hueDegrees / 360.0;
                const double saturationScale = std::max(processing_.saturation, 0.0);
                const double brightnessOffset = processing_.brightness;

                for (size_t offset = 0; offset < output.size(); offset += kPixelStride) {
                    if (output[offset + 3U] == 0U) {
                        continue;
                    }

                    const double red = static_cast<double>(output[offset]) / 255.0;
                    const double green = static_cast<double>(output[offset + 1U]) / 255.0;
                    const double blue = static_cast<double>(output[offset + 2U]) / 255.0;
                    HSVColor hsv = rgbToHSV(red, green, blue);
                    hsv.hue += hueShift;
                    if (hsv.hue < 0.0) {
                        hsv.hue += 1.0;
                    } else if (hsv.hue > 1.0) {
                        hsv.hue -= std::floor(hsv.hue);
                    }
                    hsv.saturation = std::clamp(hsv.saturation * saturationScale, 0.0, 1.0);
                    hsv.value = std::clamp(hsv.value + brightnessOffset, 0.0, 1.0);

                    const auto rgb = hsvToRGB(hsv.hue, hsv.saturation, hsv.value);
                    output[offset] = static_cast<uint8_t>(std::clamp(std::lround(std::clamp(rgb[0], 0.0, 1.0) * 255.0), 0L, 255L));
                    output[offset + 1U] = static_cast<uint8_t>(std::clamp(std::lround(std::clamp(rgb[1], 0.0, 1.0) * 255.0), 0L, 255L));
                    output[offset + 2U] = static_cast<uint8_t>(std::clamp(std::lround(std::clamp(rgb[2], 0.0, 1.0) * 255.0), 0L, 255L));
                }
                return output;
            }

            case LayerProcessingKind::BrightnessContrast: {
                std::vector<uint8_t> output(source.begin(), source.end());
                const double contrast = std::max(processing_.contrast, 0.0);
                const double brightnessOffset = processing_.brightness;

                for (size_t offset = 0; offset < output.size(); offset += kPixelStride) {
                    if (output[offset + 3U] == 0U) {
                        continue;
                    }

                    double red = static_cast<double>(output[offset]) / 255.0;
                    double green = static_cast<double>(output[offset + 1U]) / 255.0;
                    double blue = static_cast<double>(output[offset + 2U]) / 255.0;

                    red = (((red - 0.5) * contrast) + 0.5) + brightnessOffset;
                    green = (((green - 0.5) * contrast) + 0.5) + brightnessOffset;
                    blue = (((blue - 0.5) * contrast) + 0.5) + brightnessOffset;

                    output[offset] = static_cast<uint8_t>(std::clamp(std::lround(std::clamp(red, 0.0, 1.0) * 255.0), 0L, 255L));
                    output[offset + 1U] = static_cast<uint8_t>(std::clamp(std::lround(std::clamp(green, 0.0, 1.0) * 255.0), 0L, 255L));
                    output[offset + 2U] = static_cast<uint8_t>(std::clamp(std::lround(std::clamp(blue, 0.0, 1.0) * 255.0), 0L, 255L));
                }
                return output;
            }

            case LayerProcessingKind::Levels: {
                const double inputBlack = std::clamp(processing_.inputBlack, 0.0, 1.0);
                const double inputWhite = std::max(std::clamp(processing_.inputWhite, 0.0, 1.0), inputBlack + 0.001);
                const double gamma = std::max(processing_.gamma, 0.01);
                const double outputBlack = std::clamp(processing_.outputBlack, 0.0, 1.0);
                const double outputWhite = std::max(std::clamp(processing_.outputWhite, 0.0, 1.0), outputBlack);
                auto map = [inputBlack, inputWhite, gamma, outputBlack, outputWhite](uint8_t value) -> uint8_t {
                    const double normalized = std::clamp((static_cast<double>(value) / 255.0 - inputBlack) / (inputWhite - inputBlack), 0.0, 1.0);
                    const double gammaCorrected = std::pow(normalized, 1.0 / gamma);
                    const double remapped = outputBlack + ((outputWhite - outputBlack) * gammaCorrected);
                    return static_cast<uint8_t>(std::clamp(std::lround(remapped * 255.0), 0L, 255L));
                };

                std::vector<uint8_t> output(source.begin(), source.end());
                for (size_t offset = 0; offset < output.size(); offset += kPixelStride) {
                    if (output[offset + 3U] == 0U) {
                        continue;
                    }
                    output[offset] = map(output[offset]);
                    output[offset + 1U] = map(output[offset + 1U]);
                    output[offset + 2U] = map(output[offset + 2U]);
                }
                return output;
            }

            case LayerProcessingKind::ToneCurve: {
                auto map = [this](uint8_t value) -> uint8_t {
                    const double normalized = static_cast<double>(value) / 255.0;
                    const double shadowWeight = std::pow(1.0 - normalized, 2.0);
                    const double highlightWeight = std::pow(normalized, 2.0);
                    const double midtoneWeight = std::max(0.0, 1.0 - std::abs((normalized * 2.0) - 1.0));
                    const double offset = (processing_.shadows * shadowWeight) +
                        (processing_.midtones * midtoneWeight) +
                        (processing_.highlights * highlightWeight);
                    const double adjusted = std::clamp(normalized + (offset * 0.35), 0.0, 1.0);
                    return static_cast<uint8_t>(std::clamp(std::lround(adjusted * 255.0), 0L, 255L));
                };

                std::vector<uint8_t> output(source.begin(), source.end());
                for (size_t offset = 0; offset < output.size(); offset += kPixelStride) {
                    if (output[offset + 3U] == 0U) {
                        continue;
                    }
                    output[offset] = map(output[offset]);
                    output[offset + 1U] = map(output[offset + 1U]);
                    output[offset + 2U] = map(output[offset + 2U]);
                }
                return output;
            }

            case LayerProcessingKind::ColorBalance: {
                std::vector<uint8_t> output(source.begin(), source.end());
                const double redOffset = processing_.redCyan * 0.4;
                const double greenOffset = processing_.greenMagenta * 0.4;
                const double blueOffset = processing_.blueYellow * 0.4;

                for (size_t offset = 0; offset < output.size(); offset += kPixelStride) {
                    if (output[offset + 3U] == 0U) {
                        continue;
                    }

                    const double red = std::clamp((static_cast<double>(output[offset]) / 255.0) + redOffset, 0.0, 1.0);
                    const double green = std::clamp((static_cast<double>(output[offset + 1U]) / 255.0) + greenOffset, 0.0, 1.0);
                    const double blue = std::clamp((static_cast<double>(output[offset + 2U]) / 255.0) + blueOffset, 0.0, 1.0);

                    output[offset] = static_cast<uint8_t>(std::lround(red * 255.0));
                    output[offset + 1U] = static_cast<uint8_t>(std::lround(green * 255.0));
                    output[offset + 2U] = static_cast<uint8_t>(std::lround(blue * 255.0));
                }
                return output;
            }

            case LayerProcessingKind::Threshold: {
                std::vector<uint8_t> output(source.begin(), source.end());
                const double threshold = std::clamp(processing_.threshold, 0.0, 1.0);
                for (size_t offset = 0; offset < output.size(); offset += kPixelStride) {
                    if (output[offset + 3U] == 0U) {
                        continue;
                    }
                    const double red = static_cast<double>(output[offset]) / 255.0;
                    const double green = static_cast<double>(output[offset + 1U]) / 255.0;
                    const double blue = static_cast<double>(output[offset + 2U]) / 255.0;
                    const double luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
                    const uint8_t mapped = luminance >= threshold ? 255U : 0U;
                    output[offset] = mapped;
                    output[offset + 1U] = mapped;
                    output[offset + 2U] = mapped;
                }
                return output;
            }

            case LayerProcessingKind::Posterize: {
                const int steps = std::max(static_cast<int>(std::lround(processing_.posterizeLevels)), 2);
                const double denominator = static_cast<double>(steps - 1);
                auto map = [denominator](uint8_t value) -> uint8_t {
                    const double normalized = static_cast<double>(value) / 255.0;
                    const double quantized = std::round(normalized * denominator) / denominator;
                    return static_cast<uint8_t>(std::clamp(std::lround(quantized * 255.0), 0L, 255L));
                };

                std::vector<uint8_t> output(source.begin(), source.end());
                for (size_t offset = 0; offset < output.size(); offset += kPixelStride) {
                    if (output[offset + 3U] == 0U) {
                        continue;
                    }
                    output[offset] = map(output[offset]);
                    output[offset + 1U] = map(output[offset + 1U]);
                    output[offset + 2U] = map(output[offset + 2U]);
                }
                return output;
            }

            case LayerProcessingKind::Transform:
                return transformedPixels(processing_, source, context.width, context.height);
        }

        return std::nullopt;
    }

private:
    LayerProcessing processing_;
};

}  // namespace

class PaintDocumentProcessingApplicator {
public:
    PaintDocumentProcessingApplicator(PaintDocument& document, std::vector<int> targetLayerIndices)
        : document_(document),
          targetLayerIndices_(std::move(targetLayerIndices)),
          useDocumentSnapshot_(targetLayerIndices_.size() != 1U) {}

    bool applyVisitor(const PaintDocumentLayerProcessingVisitor& visitor) {
        bool appliedAny = false;
        for (int layerIndex : targetLayerIndices_) {
            if (layerIndex < 0 || layerIndex >= document_.layerCount()) {
                continue;
            }

            const Layer& sourceLayer = document_.layer(layerIndex);
            const LayerProcessingContext context{
                .layerIndex = layerIndex,
                .width = document_.width_,
                .height = document_.height_,
            };

            auto processed = visitor.process(context, sourceLayer.pixels);
            if (!processed.has_value() || processed->size() != sourceLayer.pixels.size()) {
                continue;
            }
            if (document_.layers_[static_cast<size_t>(layerIndex)].alphaLocked) {
                constrainPixelsToAlphaLock(*processed, sourceLayer.pixels);
            }
            if (std::equal(processed->begin(), processed->end(), sourceLayer.pixels.begin())) {
                continue;
            }

            ensureSnapshot();
            document_.loadLayerPixels(document_.layers_[static_cast<size_t>(layerIndex)], *processed);
            appliedAny = true;
        }

        changed_ = changed_ || appliedAny;
        return appliedAny;
    }

    bool applyCommand(const std::function<bool(PaintDocument&)>& command) {
        ensureSnapshot();
        const bool changed = command(document_);
        changed_ = changed_ || changed;
        return changed;
    }

    bool end() {
        if (!changed_) {
            return false;
        }

        document_.markEntireDocumentDirty();
        (void)document_.composite();
        return true;
    }

private:
    void ensureSnapshot() {
        if (snapshotTaken_) {
            return;
        }

        if (!useDocumentSnapshot_ && !targetLayerIndices_.empty()) {
            document_.pushLayerHistorySnapshot(targetLayerIndices_.front());
        } else {
            document_.pushHistorySnapshot();
        }
        snapshotTaken_ = true;
    }

    PaintDocument& document_;
    std::vector<int> targetLayerIndices_;
    bool useDocumentSnapshot_ = false;
    bool snapshotTaken_ = false;
    bool changed_ = false;
};

class PaintDocument::StrokesQueue {
public:
    uint64_t startStroke(std::unique_ptr<StrokeStrategy> strategy) {
        Stroke stroke;
        stroke.id = nextStrokeID_++;
        stroke.strategy = std::move(strategy);
        strokes_.push_back(std::move(stroke));
        return strokes_.back().id;
    }

    bool addInitJob(uint64_t strokeID, const StrokeJobData& data) {
        Stroke* stroke = strokeByID(strokeID);
        if (stroke == nullptr || !stroke->isOpen()) {
            return false;
        }
        stroke->jobs.push_back(stroke->strategy->createInitJob(data));
        return true;
    }

    bool addDabJob(uint64_t strokeID, const StrokeJobData& data) {
        Stroke* stroke = strokeByID(strokeID);
        if (stroke == nullptr || !stroke->isOpen()) {
            return false;
        }
        stroke->jobs.push_back(stroke->strategy->createDabJob(data));
        return true;
    }

    bool endStroke(uint64_t strokeID) {
        Stroke* stroke = strokeByID(strokeID);
        if (stroke == nullptr || !stroke->isOpen()) {
            return false;
        }
        if (auto finishJob = stroke->strategy->createFinishJob()) {
            stroke->jobs.push_back(std::move(*finishJob));
        }
        stroke->isEnded = true;
        return true;
    }

    bool cancelStroke(uint64_t strokeID) {
        Stroke* stroke = strokeByID(strokeID);
        if (stroke == nullptr || !stroke->isOpen()) {
            return false;
        }
        stroke->jobs.clear();
        if (auto cancelJob = stroke->strategy->createCancelJob()) {
            stroke->jobs.push_back(std::move(*cancelJob));
        }
        stroke->isCanceled = true;
        stroke->isEnded = true;
        return true;
    }

    void process(PaintDocument& document) {
        while (!strokes_.empty()) {
            Stroke& stroke = strokes_.front();

            if (stroke.jobs.empty()) {
                if (stroke.isOpen()) {
                    break;
                }
                strokes_.pop_front();
                continue;
            }

            const StrokeJobType nextType = stroke.jobs.front().type;
            if (nextType == StrokeJobType::Barrier) {
                (void)document.composite();
            }

            if (nextType == StrokeJobType::Concurrent) {
                std::vector<StrokeJob> batch;
                while (!stroke.jobs.empty() && stroke.jobs.front().type == StrokeJobType::Concurrent) {
                    batch.push_back(std::move(stroke.jobs.front()));
                    stroke.jobs.pop_front();
                }
                for (const StrokeJob& job : batch) {
                    executeJob(document, job);
                }
            } else {
                StrokeJob job = std::move(stroke.jobs.front());
                stroke.jobs.pop_front();
                executeJob(document, job);
            }

            if (!stroke.isOpen() && stroke.jobs.empty()) {
                strokes_.pop_front();
            }
        }
    }

private:
    Stroke* strokeByID(uint64_t strokeID) {
        for (Stroke& stroke : strokes_) {
            if (stroke.id == strokeID) {
                return &stroke;
            }
        }
        return nullptr;
    }

    static void executeJob(PaintDocument& document, const StrokeJob& job) {
        switch (job.command) {
            case StrokeCommand::BeginFreehand:
                document.beginStrokeImmediate(job.brush, std::get<StrokePoint>(job.payload));
                break;
            case StrokeCommand::AppendFreehand:
                document.appendStrokeImmediate(std::get<StrokePoint>(job.payload));
                break;
            case StrokeCommand::EndFreehand:
                document.endStrokeImmediate();
                break;
            case StrokeCommand::CancelFreehand:
                document.cancelStrokeImmediate();
                break;
            case StrokeCommand::Fill: {
                const FillPoint point = std::get<FillPoint>(job.payload);
                document.fillImmediate(point.x, point.y, job.brush);
                break;
            }
        }
    }

    uint64_t nextStrokeID_ = 1;
    std::deque<Stroke> strokes_;
};

PaintDocument::PaintDocument(int width, int height) {
    if (width <= 0 || height <= 0) {
        throw std::invalid_argument("Document dimensions must be positive");
    }

    width_ = width;
    height_ = height;
    tileColumns_ = tileCountForExtent(width_);
    tileRows_ = tileCountForExtent(height_);
    strokesQueue_ = std::make_unique<StrokesQueue>();
    dirtyTileFlags_.assign(static_cast<size_t>(tileColumns_) * static_cast<size_t>(tileRows_), 1U);
    compositeBuffer_.assign(expectedLayerPixelCount(width_, height_), 0U);

    addLayer("Layer 1");
}

PaintDocument::~PaintDocument() = default;

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
    initializeLayerStorage(layer);
    layers_.push_back(std::move(layer));
    layerFolderIDs_.push_back(-1);
    activeLayerIndex_ = layerCount() - 1;
    markEntireDocumentDirty();
    return activeLayerIndex_;
}

bool PaintDocument::deleteLayer(int index) {
    if (index < 0 || index >= layerCount() || layerCount() <= 1) {
        return false;
    }
    pushHistorySnapshot();
    layers_.erase(layers_.begin() + index);
    layerFolderIDs_.erase(layerFolderIDs_.begin() + index);
    for (LayerFolder& folder : folders_) {
        if (folder.anchorLayerIndex == index) {
            folder.anchorLayerIndex = index > 0 ? index - 1 : -1;
        } else if (folder.anchorLayerIndex > index) {
            folder.anchorLayerIndex -= 1;
        }
    }
    if (activeLayerIndex_ > index) {
        activeLayerIndex_ -= 1;
    } else if (activeLayerIndex_ >= layerCount()) {
        activeLayerIndex_ = layerCount() - 1;
    }
    markEntireDocumentDirty();
    return true;
}

bool PaintDocument::moveLayer(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= layerCount() || toIndex < 0 || toIndex >= layerCount() || fromIndex == toIndex) {
        return false;
    }
    pushHistorySnapshot();
    Layer movedLayer = std::move(layers_[static_cast<size_t>(fromIndex)]);
    const int movedLayerFolderID = layerFolderIDs_[static_cast<size_t>(fromIndex)];
    layers_.erase(layers_.begin() + fromIndex);
    layerFolderIDs_.erase(layerFolderIDs_.begin() + fromIndex);
    layers_.insert(layers_.begin() + toIndex, std::move(movedLayer));
    layerFolderIDs_.insert(layerFolderIDs_.begin() + toIndex, movedLayerFolderID);
    for (LayerFolder& folder : folders_) {
        const int anchor = folder.anchorLayerIndex;
        if (anchor < 0) {
            continue;
        }
        if (anchor == fromIndex) {
            folder.anchorLayerIndex = toIndex;
        } else if (fromIndex < toIndex && anchor > fromIndex && anchor <= toIndex) {
            folder.anchorLayerIndex -= 1;
        } else if (fromIndex > toIndex && anchor >= toIndex && anchor < fromIndex) {
            folder.anchorLayerIndex += 1;
        }
    }

    if (activeLayerIndex_ == fromIndex) {
        activeLayerIndex_ = toIndex;
    } else if (fromIndex < activeLayerIndex_ && toIndex >= activeLayerIndex_) {
        activeLayerIndex_ -= 1;
    } else if (fromIndex > activeLayerIndex_ && toIndex <= activeLayerIndex_) {
        activeLayerIndex_ += 1;
    }

    markEntireDocumentDirty();
    return true;
}

int PaintDocument::createFolder(const std::string& name, int layerIndex) {
    pushHistorySnapshot();
    LayerFolder folder;
    folder.id = nextFolderID_++;
    folder.name = name;
    folder.anchorLayerIndex = layerIndex >= 0 && layerIndex < layerCount() ? layerIndex : -1;
    folders_.push_back(folder);
    return folder.id;
}

bool PaintDocument::deleteFolder(int folderID) {
    auto it = std::find_if(folders_.begin(), folders_.end(), [folderID](const LayerFolder& folder) {
        return folder.id == folderID;
    });
    if (it == folders_.end()) {
        return false;
    }
    pushHistorySnapshot();
    for (int& assignedFolderID : layerFolderIDs_) {
        if (assignedFolderID == folderID) {
            assignedFolderID = -1;
        }
    }
    folders_.erase(it);
    markEntireDocumentDirty();
    return true;
}

void PaintDocument::setFolderName(int folderID, std::string name) {
    if (name.empty()) {
        return;
    }
    auto it = std::find_if(folders_.begin(), folders_.end(), [folderID](const LayerFolder& folder) {
        return folder.id == folderID;
    });
    if (it == folders_.end() || it->name == name) {
        return;
    }
    pushHistorySnapshot();
    it->name = std::move(name);
}

void PaintDocument::setFolderVisibility(int folderID, bool visible) {
    auto it = std::find_if(folders_.begin(), folders_.end(), [folderID](const LayerFolder& folder) {
        return folder.id == folderID;
    });
    if (it == folders_.end() || it->visible == visible) {
        return;
    }
    pushHistorySnapshot();
    it->visible = visible;
    markEntireDocumentDirty();
}

void PaintDocument::setFolderExpanded(int folderID, bool expanded) {
    auto it = std::find_if(folders_.begin(), folders_.end(), [folderID](const LayerFolder& folder) {
        return folder.id == folderID;
    });
    if (it == folders_.end() || it->expanded == expanded) {
        return;
    }
    pushHistorySnapshot();
    it->expanded = expanded;
}

bool PaintDocument::setLayerFolder(int layerIndex, int folderID) {
    if (layerIndex < 0 || layerIndex >= layerCount()) {
        return false;
    }
    if (folderID >= 0 && folderByID(folderID) == nullptr) {
        return false;
    }
    if (layerFolderIDs_[static_cast<size_t>(layerIndex)] == folderID) {
        return true;
    }
    pushHistorySnapshot();
    layerFolderIDs_[static_cast<size_t>(layerIndex)] = folderID;
    markEntireDocumentDirty();
    return true;
}

int PaintDocument::layerFolderID(int layerIndex) const noexcept {
    if (layerIndex < 0 || layerIndex >= layerCount()) {
        return -1;
    }
    return layerFolderIDs_[static_cast<size_t>(layerIndex)];
}

bool PaintDocument::isLayerVisibleEffective(int layerIndex) const noexcept {
    if (layerIndex < 0 || layerIndex >= layerCount()) {
        return false;
    }
    const Layer& layer = layers_[static_cast<size_t>(layerIndex)];
    if (!layer.visible) {
        return false;
    }
    const int folderID = layerFolderIDs_[static_cast<size_t>(layerIndex)];
    if (folderID < 0) {
        return true;
    }
    const LayerFolder* folder = folderByID(folderID);
    return folder == nullptr ? true : folder->visible;
}

int PaintDocument::folderCount() const noexcept {
    return static_cast<int>(folders_.size());
}

const LayerFolder& PaintDocument::folderAt(int position) const {
    return folders_.at(static_cast<size_t>(position));
}

void PaintDocument::clearLayer(int index) {
    LayerProcessing processing;
    processing.kind = LayerProcessingKind::Clear;
    (void)applyLayerProcessing(index, processing);
}

void PaintDocument::setLayerName(int index, std::string name) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    if (name.empty() || layers_[index].name == name) {
        return;
    }
    pushLayerHistorySnapshot(index);
    layers_[index].name = std::move(name);
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
}

void PaintDocument::setLayerLocked(int index, bool locked) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    if (layers_[index].locked == locked) {
        return;
    }
    pushLayerHistorySnapshot(index);
    layers_[index].locked = locked;
    markEntireDocumentDirty();
}

void PaintDocument::setLayerAlphaLocked(int index, bool alphaLocked) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    if (layers_[index].alphaLocked == alphaLocked) {
        return;
    }
    pushLayerHistorySnapshot(index);
    layers_[index].alphaLocked = alphaLocked;
    markEntireDocumentDirty();
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
}

bool PaintDocument::applyLayerProcessing(int index, const LayerProcessing& processing) {
    if (index < 0 || index >= layerCount() || strokeInFlight_ || activeQueuedStrokeID_.has_value()) {
        return false;
    }
    if (layers_[static_cast<size_t>(index)].locked) {
        return false;
    }

    PaintDocumentProcessingApplicator applicator(*this, {index});
    const DescriptorLayerProcessingVisitor visitor(processing);
    if (!applicator.applyVisitor(visitor)) {
        return false;
    }
    return applicator.end();
}

void PaintDocument::replaceLayerPixels(int index, std::span<const uint8_t> pixels) {
    LayerProcessing processing;
    processing.kind = LayerProcessingKind::ReplacePixels;
    processing.pixelData.assign(pixels.begin(), pixels.end());
    (void)applyLayerProcessing(index, processing);
}

void PaintDocument::replaceLayerPixelsTransient(int index, std::span<const uint8_t> pixels) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    if (pixels.size() != expectedLayerPixelCount(width_, height_)) {
        return;
    }
    loadLayerPixels(layers_[index], pixels);
    markEntireDocumentDirty();
}

bool PaintDocument::hasLayerMask(int index) const noexcept {
    if (index < 0 || index >= layerCount()) {
        return false;
    }
    return !layers_[static_cast<size_t>(index)].mask.empty();
}

std::vector<uint8_t> PaintDocument::layerMaskData(int index) const {
    if (index < 0 || index >= layerCount()) {
        return {};
    }
    return layers_[static_cast<size_t>(index)].mask;
}

void PaintDocument::replaceLayerMask(int index, std::span<const uint8_t> mask) {
    if (index < 0 || index >= layerCount()) {
        return;
    }
    if (layers_[static_cast<size_t>(index)].locked) {
        return;
    }
    if (mask.size() != static_cast<size_t>(width_) * static_cast<size_t>(height_)) {
        return;
    }

    Layer& layer = layers_[static_cast<size_t>(index)];
    if (std::equal(mask.begin(), mask.end(), layer.mask.begin(), layer.mask.end())) {
        return;
    }

    pushLayerHistorySnapshot(index);
    layer.mask.assign(mask.begin(), mask.end());
    markEntireDocumentDirty();
}

void PaintDocument::clearLayerMask(int index) {
    if (index < 0 || index >= layerCount()) {
        return;
    }

    Layer& layer = layers_[static_cast<size_t>(index)];
    if (layer.mask.empty()) {
        return;
    }

    pushLayerHistorySnapshot(index);
    layer.mask.clear();
    markEntireDocumentDirty();
}

bool PaintDocument::applyLayerMask(int index) {
    if (index < 0 || index >= layerCount() || strokeInFlight_ || activeQueuedStrokeID_.has_value()) {
        return false;
    }

    Layer& layer = layers_[static_cast<size_t>(index)];
    if (layer.mask.size() != static_cast<size_t>(width_) * static_cast<size_t>(height_)) {
        return false;
    }

    pushLayerHistorySnapshot(index);
    for (int y = 0; y < height_; ++y) {
        for (int x = 0; x < width_; ++x) {
            const size_t maskOffset = static_cast<size_t>(y) * static_cast<size_t>(width_) + static_cast<size_t>(x);
            const float maskAlpha = static_cast<float>(layer.mask[maskOffset]) / 255.0F;
            uint8_t* pixel = tilePixelPointer(layer, x, y);
            pixel[3] = static_cast<uint8_t>(std::clamp(
                std::lround((static_cast<float>(pixel[3]) / 255.0F) * maskAlpha * 255.0F),
                0L,
                255L
            ));
        }
    }
    layer.mask.clear();
    invalidateLayerPixelCache(layer);
    markEntireDocumentDirty();
    return true;
}

const Layer& PaintDocument::layer(int index) const {
    const Layer& layer = layers_.at(static_cast<size_t>(index));
    ensureLayerPixelCache(layer);
    return layer;
}

void PaintDocument::beginStroke(const BrushSettings& brush, StrokePoint point) {
    if (strokeInFlight_ || activeQueuedStrokeID_.has_value()) {
        return;
    }
    if (point.x < 0.0F || point.x >= static_cast<float>(width_) || point.y < 0.0F || point.y >= static_cast<float>(height_)) {
        return;
    }
    if (layers_[static_cast<size_t>(activeLayerIndex_)].locked) {
        return;
    }
    beginStrokeImmediate(brush, point);
}

void PaintDocument::appendStroke(StrokePoint point) {
    if (!strokeInFlight_) {
        return;
    }
    appendStrokeImmediate(point);
}

void PaintDocument::endStroke() {
    if (!strokeInFlight_) {
        return;
    }
    endStrokeImmediate();
}

void PaintDocument::cancelStroke() {
    if (!strokeInFlight_) {
        return;
    }
    cancelStrokeImmediate();
}

void PaintDocument::fill(int x, int y, const BrushSettings& brush) {
    if (strokeInFlight_ || activeQueuedStrokeID_.has_value() || strokesQueue_ == nullptr) {
        return;
    }
    if (x < 0 || x >= width_ || y < 0 || y >= height_) {
        return;
    }
    if (layers_[static_cast<size_t>(activeLayerIndex_)].locked) {
        return;
    }

    const uint64_t strokeID = strokesQueue_->startStroke(std::make_unique<FillStrokeStrategy>(brush));
    const StrokeJobData jobData{ .payload = FillPoint{ .x = x, .y = y } };
    if (!strokesQueue_->addDabJob(strokeID, jobData)) {
        return;
    }
    (void)strokesQueue_->endStroke(strokeID);
    strokesQueue_->process(*this);
}

void PaintDocument::beginStrokeImmediate(const BrushSettings& brush, StrokePoint point) {
    if (strokeInFlight_) {
        return;
    }
    if (point.x < 0.0F || point.x >= static_cast<float>(width_) || point.y < 0.0F || point.y >= static_cast<float>(height_)) {
        return;
    }
    pushLayerHistorySnapshot(activeLayerIndex_);
    activeBrush_ = brush;
    invalidateLayerPixelCache(layers_[static_cast<size_t>(activeLayerIndex_)]);
    previousPoint_ = point;
    lastDabPoint_ = point;
    strokeOriginPoint_ = point;
    strokeAccumulatedDistance_ = 0.0F;
    distanceUntilNextDab_ = 0.0F;
    strokeHasStampedDab_ = true;
    strokeInFlight_ = true;
    dirtyRect_.reset();
    point.speed = 0.0F;
    stampDab(layers_[static_cast<size_t>(activeLayerIndex_)], point);
}

void PaintDocument::appendStrokeImmediate(StrokePoint point) {
    if (!strokeInFlight_) {
        return;
    }

    auto& layer = layers_[static_cast<size_t>(activeLayerIndex_)];
    const float dx = point.x - previousPoint_.x;
    const float dy = point.y - previousPoint_.y;
    const float distance = std::sqrt((dx * dx) + (dy * dy));
    if (distance <= 0.0001F) {
        previousPoint_ = point;
        return;
    }
    strokeAccumulatedDistance_ += distance;
    renderStrokeSegment(layer, previousPoint_, point);
    previousPoint_ = point;
}

void PaintDocument::endStrokeImmediate() {
    strokeInFlight_ = false;
    strokeAccumulatedDistance_ = 0.0F;
    distanceUntilNextDab_ = 0.0F;
    strokeHasStampedDab_ = false;
}

void PaintDocument::cancelStrokeImmediate() {
    if (!strokeInFlight_ || undoStack_.empty()) {
        return;
    }

    HistorySnapshot snapshot = std::move(undoStack_.back());
    undoStack_.pop_back();
    redoStack_.clear();

    if (snapshot.capturesEntireDocument) {
        layers_ = std::move(snapshot.layers);
        folders_ = std::move(snapshot.folders);
        layerFolderIDs_ = std::move(snapshot.layerFolderIDs);
        nextFolderID_ = snapshot.nextFolderID;
    } else if (snapshot.layerIndex >= 0 && snapshot.layerIndex < layerCount()) {
        layers_[snapshot.layerIndex] = std::move(snapshot.layer);
    }

    activeLayerIndex_ = std::clamp(snapshot.activeLayerIndex, 0, layerCount() - 1);
    strokeInFlight_ = false;
    strokeAccumulatedDistance_ = 0.0F;
    distanceUntilNextDab_ = 0.0F;
    strokeHasStampedDab_ = false;
    markEntireDocumentDirty();
}

void PaintDocument::fillImmediate(int x, int y, const BrushSettings& brush) {
    if (strokeInFlight_ || x < 0 || x >= width_ || y < 0 || y >= height_) {
        return;
    }

    activeBrush_ = brush;
    auto& layer = layers_[static_cast<size_t>(activeLayerIndex_)];
    if (layer.locked) {
        return;
    }
    const uint8_t* startPixel = tilePixelPointer(layer, x, y);

    const std::array<uint8_t, 4> target = {
        startPixel[0],
        startPixel[1],
        startPixel[2],
        startPixel[3]
    };

    std::array<uint8_t, 4> replacement = brush.eraser
        ? std::array<uint8_t, 4>{0U, 0U, 0U, 0U}
        : std::array<uint8_t, 4>{brush.red, brush.green, brush.blue, static_cast<uint8_t>(clamp01(brush.opacity) * 255.0F)};
    if (layer.alphaLocked) {
        replacement[3] = target[3];
        if (replacement[3] == 0U) {
            replacement[0] = 0U;
            replacement[1] = 0U;
            replacement[2] = 0U;
        }
    }

    if (target == replacement) {
        return;
    }

    pushLayerHistorySnapshot(activeLayerIndex_);
    invalidateLayerPixelCache(layer);

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
        const uint8_t* pixel = tilePixelPointer(layer, px, py);
        if (brush.fillThresholdMode == 1) {
            return colorWithinTolerance(
                pixel[0],
                pixel[1],
                pixel[2]
            );
        }
        const bool sameColor =
            pixel[0] == target[0] &&
            pixel[1] == target[1] &&
            pixel[2] == target[2];
        return sameColor && alphaWithinTolerance(pixel[3]);
    };

    auto applyReplacement = [&](int px, int py) {
        uint8_t* pixel = tilePixelPointer(layer, px, py);
        pixel[0] = replacement[0];
        pixel[1] = replacement[1];
        pixel[2] = replacement[2];
        pixel[3] = replacement[3];
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
                    uint8_t* pixel = tilePixelPointer(layer, px, py);
                    pixel[0] = replacement[0];
                    pixel[1] = replacement[1];
                    pixel[2] = replacement[2];
                    pixel[3] = replacement[3];
                    filledRect.expand(px, py, px, py);
                }
            }
        }
    }

    if (!filledRect.empty()) {
        markDirtyRect(filledRect.minX, filledRect.minY, filledRect.maxX, filledRect.maxY);
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
        for (Layer& layer : current.layers) {
            layer.pixels.clear();
            layer.pixelsDirty = true;
        }
        current.folders = folders_;
        current.layerFolderIDs = layerFolderIDs_;
        current.nextFolderID = nextFolderID_;
    } else {
        current.layerIndex = undoStack_.back().layerIndex;
        if (current.layerIndex >= 0 && current.layerIndex < layerCount()) {
            current.layer = layers_[current.layerIndex];
            current.layer.pixels.clear();
            current.layer.pixelsDirty = true;
        }
    }
    redoStack_.push_back(std::move(current));

    HistorySnapshot snapshot = std::move(undoStack_.back());
    undoStack_.pop_back();
    if (snapshot.capturesEntireDocument) {
        layers_ = std::move(snapshot.layers);
        folders_ = std::move(snapshot.folders);
        layerFolderIDs_ = std::move(snapshot.layerFolderIDs);
        nextFolderID_ = snapshot.nextFolderID;
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
        for (Layer& layer : current.layers) {
            layer.pixels.clear();
            layer.pixelsDirty = true;
        }
        current.folders = folders_;
        current.layerFolderIDs = layerFolderIDs_;
        current.nextFolderID = nextFolderID_;
    } else {
        current.layerIndex = redoStack_.back().layerIndex;
        if (current.layerIndex >= 0 && current.layerIndex < layerCount()) {
            current.layer = layers_[current.layerIndex];
            current.layer.pixels.clear();
            current.layer.pixelsDirty = true;
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
        folders_ = std::move(snapshot.folders);
        layerFolderIDs_ = std::move(snapshot.layerFolderIDs);
        nextFolderID_ = snapshot.nextFolderID;
    } else if (snapshot.layerIndex >= 0 && snapshot.layerIndex < layerCount()) {
        layers_[snapshot.layerIndex] = std::move(snapshot.layer);
    }
    activeLayerIndex_ = std::clamp(snapshot.activeLayerIndex, 0, layerCount() - 1);
    strokeInFlight_ = false;
    markEntireDocumentDirty();
    compositeDirty_ = true;
    return true;
}

void PaintDocument::clearHistory() noexcept {
    undoStack_.clear();
    redoStack_.clear();
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
    std::vector<uint8_t> result(static_cast<size_t>(rectWidth) * static_cast<size_t>(rectHeight) * kPixelStride);
    for (int row = 0; row < rectHeight; ++row) {
        for (int column = 0; column < rectWidth; ++column) {
            const int srcX = rect.minX + column;
            const int srcY = rect.minY + row;
            const uint8_t* src = tilePixelPointer(layer, srcX, srcY);
            const size_t dstOffset =
                (static_cast<size_t>(row) * static_cast<size_t>(rectWidth) + static_cast<size_t>(column)) * kPixelStride;
            std::copy_n(src, kPixelStride, result.data() + dstOffset);
        }
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
    std::vector<uint8_t> result(static_cast<size_t>(rectWidth) * static_cast<size_t>(rectHeight) * kPixelStride);
    for (int row = 0; row < rectHeight; ++row) {
        const int srcY = rect.minY + row;
        const size_t srcOffset = (static_cast<size_t>(srcY) * static_cast<size_t>(width_) + static_cast<size_t>(rect.minX)) * kPixelStride;
        const size_t dstOffset = static_cast<size_t>(row) * static_cast<size_t>(rectWidth) * kPixelStride;
        std::copy_n(
            currentComposite.data() + srcOffset,
            static_cast<size_t>(rectWidth) * kPixelStride,
            result.data() + dstOffset
        );
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

void PaintDocument::initializeLayerStorage(Layer& layer) {
    layer.tileColumns = tileColumns_;
    layer.tileRows = tileRows_;
    layer.tiles.assign(static_cast<size_t>(tileColumns_) * static_cast<size_t>(tileRows_) * kTileByteCount, 0U);
    invalidateLayerPixelCache(layer);
}

void PaintDocument::invalidateLayerPixelCache(Layer& layer) noexcept {
    layer.pixels.clear();
    layer.pixelsDirty = true;
}

void PaintDocument::ensureLayerPixelCache(const Layer& layer) const {
    if (!layer.pixelsDirty && layer.pixels.size() == expectedLayerPixelCount(width_, height_)) {
        return;
    }

    layer.pixels.assign(expectedLayerPixelCount(width_, height_), 0U);

    for (int tileY = 0; tileY < tileRows_; ++tileY) {
        const int originY = tileY * Layer::kTileSize;
        const int copyHeight = std::min(Layer::kTileSize, height_ - originY);
        for (int tileX = 0; tileX < tileColumns_; ++tileX) {
            const int originX = tileX * Layer::kTileSize;
            const int copyWidth = std::min(Layer::kTileSize, width_ - originX);
            const size_t tileOffset = tileIndex(tileX, tileY) * kTileByteCount;
            for (int localY = 0; localY < copyHeight; ++localY) {
                const size_t srcOffset = tileOffset + (static_cast<size_t>(localY) * static_cast<size_t>(Layer::kTileSize) * kPixelStride);
                const size_t dstOffset =
                    (static_cast<size_t>(originY + localY) * static_cast<size_t>(width_) + static_cast<size_t>(originX)) *
                    kPixelStride;
                std::copy_n(
                    layer.tiles.data() + srcOffset,
                    static_cast<size_t>(copyWidth) * kPixelStride,
                    layer.pixels.data() + dstOffset
                );
            }
        }
    }

    layer.pixelsDirty = false;
}

void PaintDocument::loadLayerPixels(Layer& layer, std::span<const uint8_t> pixels) {
    if (layer.tiles.size() != static_cast<size_t>(tileColumns_) * static_cast<size_t>(tileRows_) * kTileByteCount) {
        initializeLayerStorage(layer);
    } else {
        std::fill(layer.tiles.begin(), layer.tiles.end(), 0U);
        invalidateLayerPixelCache(layer);
    }

    for (int tileY = 0; tileY < tileRows_; ++tileY) {
        const int originY = tileY * Layer::kTileSize;
        const int copyHeight = std::min(Layer::kTileSize, height_ - originY);
        for (int tileX = 0; tileX < tileColumns_; ++tileX) {
            const int originX = tileX * Layer::kTileSize;
            const int copyWidth = std::min(Layer::kTileSize, width_ - originX);
            const size_t tileOffset = tileIndex(tileX, tileY) * kTileByteCount;
            for (int localY = 0; localY < copyHeight; ++localY) {
                const size_t srcOffset =
                    (static_cast<size_t>(originY + localY) * static_cast<size_t>(width_) + static_cast<size_t>(originX)) *
                    kPixelStride;
                const size_t dstOffset = tileOffset + (static_cast<size_t>(localY) * static_cast<size_t>(Layer::kTileSize) * kPixelStride);
                std::copy_n(
                    pixels.data() + srcOffset,
                    static_cast<size_t>(copyWidth) * kPixelStride,
                    layer.tiles.data() + dstOffset
                );
            }
        }
    }
}

size_t PaintDocument::tileIndex(int tileX, int tileY) const noexcept {
    return static_cast<size_t>(tileY * tileColumns_ + tileX);
}

void PaintDocument::markDirtyRect(int minX, int minY, int maxX, int maxY) noexcept {
    if (width_ <= 0 || height_ <= 0) {
        return;
    }

    minX = std::clamp(minX, 0, width_ - 1);
    minY = std::clamp(minY, 0, height_ - 1);
    maxX = std::clamp(maxX, 0, width_ - 1);
    maxY = std::clamp(maxY, 0, height_ - 1);
    if (maxX < minX || maxY < minY) {
        return;
    }

    dirtyRect_.expand(minX, minY, maxX, maxY);
    const int minTileX = minX / Layer::kTileSize;
    const int minTileY = minY / Layer::kTileSize;
    const int maxTileX = maxX / Layer::kTileSize;
    const int maxTileY = maxY / Layer::kTileSize;
    for (int tileY = minTileY; tileY <= maxTileY; ++tileY) {
        for (int tileX = minTileX; tileX <= maxTileX; ++tileX) {
            dirtyTileFlags_[tileIndex(tileX, tileY)] = 1U;
        }
    }
    compositeDirty_ = true;
}

void PaintDocument::pushHistorySnapshot() {
    if (strokeInFlight_) {
        return;
    }

    HistorySnapshot snapshot;
    snapshot.capturesEntireDocument = true;
    snapshot.activeLayerIndex = activeLayerIndex_;
    snapshot.layers = layers_;
    for (Layer& layer : snapshot.layers) {
        layer.pixels.clear();
        layer.pixelsDirty = true;
    }
    snapshot.folders = folders_;
    snapshot.layerFolderIDs = layerFolderIDs_;
    snapshot.nextFolderID = nextFolderID_;
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
    snapshot.layer.pixels.clear();
    snapshot.layer.pixelsDirty = true;
    undoStack_.push_back(std::move(snapshot));
    if (undoStack_.size() > kMaxHistoryDepth) {
        undoStack_.erase(undoStack_.begin());
    }
    redoStack_.clear();
}

void PaintDocument::markEntireDocumentDirty() noexcept {
    markDirtyRect(0, 0, width_ - 1, height_ - 1);
}

uint8_t* PaintDocument::tilePixelPointer(Layer& layer, int x, int y) noexcept {
    const int tileX = x / Layer::kTileSize;
    const int tileY = y / Layer::kTileSize;
    const int localX = x % Layer::kTileSize;
    const int localY = y % Layer::kTileSize;
    const size_t offset =
        (tileIndex(tileX, tileY) * kTileByteCount) +
        (static_cast<size_t>(localY) * static_cast<size_t>(Layer::kTileSize) + static_cast<size_t>(localX)) *
            kPixelStride;
    return layer.tiles.data() + offset;
}

const uint8_t* PaintDocument::tilePixelPointer(const Layer& layer, int x, int y) const noexcept {
    const int tileX = x / Layer::kTileSize;
    const int tileY = y / Layer::kTileSize;
    const int localX = x % Layer::kTileSize;
    const int localY = y % Layer::kTileSize;
    const size_t offset =
        (tileIndex(tileX, tileY) * kTileByteCount) +
        (static_cast<size_t>(localY) * static_cast<size_t>(Layer::kTileSize) + static_cast<size_t>(localX)) *
            kPixelStride;
    return layer.tiles.data() + offset;
}

const LayerFolder* PaintDocument::folderByID(int folderID) const noexcept {
    auto it = std::find_if(folders_.begin(), folders_.end(), [folderID](const LayerFolder& folder) {
        return folder.id == folderID;
    });
    return it == folders_.end() ? nullptr : &(*it);
}

void PaintDocument::stampDab(Layer& layer, const StrokePoint& point) {
    if (point.pressure <= 0.001F) {
        return;
    }
    layer.pixelsDirty = true;

    const float clampedPressure = std::clamp(point.pressure, 0.08F, 1.0F);
    const float radius = resolvedStrokeRadius(activeBrush_, clampedPressure, point.speed);
    if (point.x < 0.0F || point.x >= static_cast<float>(width_) || point.y < 0.0F || point.y >= static_cast<float>(height_)) {
        return;
    }
    const float opacityPressure = lerp(
        1.0F,
        clampedPressure,
        clamp01(activeBrush_.opacityPressureSensitivity)
    );
    const float flowJitter = 1.0F + jitterValue(
        point.x + 41.0F,
        point.y - 13.0F,
        clamp01(activeBrush_.flowJitter)
    );
    const float flowPressure = lerp(
        1.0F,
        clampedPressure,
        clamp01(activeBrush_.flowPressureSensitivity)
    );
    const float resolvedFlow = clamp01(activeBrush_.flow * flowPressure * flowJitter);
    const float speedOpacity = speedOpacityScaleForBrush(activeBrush_, point.speed);
    const float effectiveOpacity = clamp01(activeBrush_.opacity * std::max(0.05F, resolvedFlow) * opacityPressure * speedOpacity);
    const bool isPencil = activeBrush_.tipKind == "pencil";
    const bool isInk = activeBrush_.tipKind == "ink";
    const bool isOil = activeBrush_.tipKind == "oil";
    const bool isAirbrush = activeBrush_.tipKind == "airbrush";
    const float altitudeFactor = clamp01((1.5707963F - point.altitude) / 1.5707963F);
    const float strokeDX = point.x - lastDabPoint_.x;
    const float strokeDY = point.y - lastDabPoint_.y;
    const float strokeDistance = std::sqrt((strokeDX * strokeDX) + (strokeDY * strokeDY));
    const float strokeTravelX = point.x - strokeOriginPoint_.x;
    const float strokeTravelY = point.y - strokeOriginPoint_.y;
    const float strokeTravel = std::sqrt((strokeTravelX * strokeTravelX) + (strokeTravelY * strokeTravelY));
    const float tangentX = strokeDistance > 0.001F ? (strokeDX / strokeDistance) : std::cos(point.azimuth);
    const float tangentY = strokeDistance > 0.001F ? (strokeDY / strokeDistance) : std::sin(point.azimuth);
    const float normalX = -tangentY;
    const float normalY = tangentX;
    const int resolvedCount = std::max(1, activeBrush_.count + static_cast<int>(std::round(jitterValue(point.x + 3.7F, point.y - 1.9F, activeBrush_.countJitter * static_cast<float>(std::max(activeBrush_.count, 1))))));
    const float maxRoundnessJitter = activeBrush_.roundnessJitter;
    const float maxAngleJitter = activeBrush_.angleJitter;
    float baseRoundness = effectiveRoundness(activeBrush_, activeBrush_.tipKind, altitudeFactor);
    const float shortStrokeRoundnessDistance = std::max(radius * 1.35F, 2.5F);
    const float shortStrokeRoundnessBlend = std::clamp(
        1.0F - (strokeTravel / std::max(shortStrokeRoundnessDistance, 0.001F)),
        0.0F,
        1.0F
    );
    if (shortStrokeRoundnessBlend > 0.0F) {
        baseRoundness = lerp(baseRoundness, 1.0F, shortStrokeRoundnessBlend * 0.92F);
    }
    baseRoundness = std::clamp(
        baseRoundness +
        (activeBrush_.roundnessPressureSensitivity * remap(clampedPressure, 0.08F, 1.0F, -0.22F, 0.18F)) +
        (activeBrush_.roundnessTiltSensitivity * remap(altitudeFactor, 0.0F, 1.0F, 0.0F, -0.36F)),
        0.12F,
        1.0F
    );
    const float scatterExtent = activeBrush_.scatterEnabled ? std::max(activeBrush_.scatterLateral, activeBrush_.scatterLinear) : 0.0F;
    const float boundRadius = radius + scatterExtent * radius + 2.5F;
    const int minX = std::max(0, static_cast<int>(std::floor(point.x - boundRadius)));
    const int maxX = std::min(width_ - 1, static_cast<int>(std::ceil(point.x + boundRadius)));
    const int minY = std::max(0, static_cast<int>(std::floor(point.y - boundRadius)));
    const int maxY = std::min(height_ - 1, static_cast<int>(std::ceil(point.y + boundRadius)));
    markDirtyRect(minX, minY, maxX, maxY);

    for (int y = minY; y <= maxY; ++y) {
        for (int x = minX; x <= maxX; ++x) {
            float accumulatedAlpha = 0.0F;
            for (int dabIndex = 0; dabIndex < resolvedCount; ++dabIndex) {
                const float dabSeed = point.timestamp + static_cast<float>(dabIndex) * 13.37F;
                const float dabAngle = resolvedBrushAngle(activeBrush_, point, previousPoint_, altitudeFactor) + jitterValue(point.x + dabSeed, point.y + 99.0F, maxAngleJitter);
                const float dabSizeScale = std::max(
                    0.18F,
                    1.0F + jitterValue(
                        point.x - (dabSeed * 0.73F),
                        point.y + (dabSeed * 0.29F),
                        clamp01(activeBrush_.countSizeJitter) * 0.65F
                    )
                );
                const float dabOpacityScale = std::max(
                    0.12F,
                    1.0F + jitterValue(
                        point.x + (dabSeed * 0.19F),
                        point.y - (dabSeed * 0.67F),
                        clamp01(activeBrush_.countOpacityJitter) * 0.72F
                    )
                );
                const float dabCos = std::cos(dabAngle);
                const float dabSin = std::sin(dabAngle);
                const float dabRoundness = std::clamp(baseRoundness + jitterValue(point.x - dabSeed, point.y + dabSeed, maxRoundnessJitter), 0.12F, 1.0F);
                const float majorRadius = radius * dabSizeScale;
                const float minorRadius = std::max(0.18F, radius * dabRoundness * dabSizeScale);
                float dabOffsetAcross = 0.0F;
                float dabOffsetAlong = 0.0F;
                if (!activeBrush_.scatterEnabled) {
                    dabOffsetAcross = 0.0F;
                    dabOffsetAlong = 0.0F;
                } else if (activeBrush_.scatterMode == 1) {
                    const float sprayTheta = hash2D(point.x + (dabSeed * 0.41F), point.y - (dabSeed * 0.23F)) * 6.2831853F;
                    const float sprayRadius = std::sqrt(hash2D(point.y + (dabSeed * 0.59F), point.x + (dabSeed * 0.31F)));
                    dabOffsetAcross =
                        std::cos(sprayTheta) *
                        sprayRadius *
                        activeBrush_.scatterLateral *
                        majorRadius;
                    dabOffsetAlong =
                        std::sin(sprayTheta) *
                        sprayRadius *
                        activeBrush_.scatterLinear *
                        majorRadius;
                } else {
                    const float scatterTheta = hash2D(point.x + (dabSeed * 0.41F), point.y - (dabSeed * 0.23F)) * 6.2831853F;
                    const float scatterRadius = std::sqrt(hash2D(point.y + (dabSeed * 0.59F), point.x + (dabSeed * 0.31F)));
                    dabOffsetAcross =
                        std::cos(scatterTheta) *
                        scatterRadius *
                        activeBrush_.scatterLateral *
                        majorRadius;
                    dabOffsetAlong =
                        (
                            std::sin(scatterTheta) * scatterRadius * 0.65F +
                            softScatterNoise(point.x + dabSeed, point.y - dabSeed) * 0.35F
                        ) *
                        activeBrush_.scatterLinear *
                        majorRadius;
                }
                const float localX = point.x + (tangentX * dabOffsetAlong) + (normalX * dabOffsetAcross);
                const float localY = point.y + (tangentY * dabOffsetAlong) + (normalY * dabOffsetAcross);
                const float dx = (static_cast<float>(x) + 0.5F) - localX;
                const float dy = (static_cast<float>(y) + 0.5F) - localY;
                const float along = rotatedX(dx, dy, dabCos, dabSin);
                const float across = rotatedY(dx, dy, dabCos, dabSin);
                const float normalizedAlong = activeBrush_.flipX ? -(along / std::max(majorRadius, 0.001F)) : (along / std::max(majorRadius, 0.001F));
                const float normalizedAcross = activeBrush_.flipY ? -(across / std::max(minorRadius, 0.001F)) : (across / std::max(minorRadius, 0.001F));

                const float shapeDistance = shapeDistanceForTip(activeBrush_.tipKind, normalizedAlong, normalizedAcross);

                const bool hasCustomTip = activeBrush_.tipMaskWidth > 0 &&
                    activeBrush_.tipMaskHeight > 0 &&
                    !activeBrush_.tipMaskAlpha.empty();
                const float tipAlpha = hasCustomTip
                    ? sampleBrushTipAlpha(activeBrush_, normalizedAlong, normalizedAcross)
                    : 1.0F;

                if ((!hasCustomTip && shapeDistance >= 1.0F) || tipAlpha <= 0.001F) {
                    continue;
                }
                float falloff = computeBaseFalloff(shapeDistance, activeBrush_.hardness);
                if (isPencil) {
                    const float clusterMask = pencilClusterMask(
                        normalizedAlong,
                        normalizedAcross,
                        static_cast<float>(x),
                        static_cast<float>(y),
                        point.timestamp + (dabIndex * 0.11F),
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
                    activeBrush_.grainContrast,
                    activeBrush_.paperScale,
                    activeBrush_.paperThreshold,
                    activeBrush_.paperStrength,
                    point.timestamp
                );
                float combinedMask = textureMask;
                if (activeBrush_.dualBrushEnabled) {
                    const float dualMask = dualBrushMask(
                        activeBrush_,
                        localX,
                        localY,
                        static_cast<float>(x) + 0.5F,
                        static_cast<float>(y) + 0.5F,
                        radius,
                        dabAngle,
                        baseRoundness,
                        dabSeed,
                        point.timestamp
                    );
                    switch (activeBrush_.dualBlendMode) {
                        case 1:
                            combinedMask = std::min(combinedMask, dualMask);
                            break;
                        case 2:
                            combinedMask *= dualMask;
                            break;
                        case 0:
                        default:
                            combinedMask *= dualMask;
                            break;
                    }
                }
                accumulatedAlpha += effectiveOpacity * dabOpacityScale * falloff * combinedMask * tipAlpha / static_cast<float>(resolvedCount);
            }
            const float alpha = clamp01(accumulatedAlpha);
            if (alpha <= 0.001F) {
                continue;
            }
            auto* pixel = tilePixelPointer(layer, x, y);
            blendPixel(pixel, activeBrush_.red, activeBrush_.green, activeBrush_.blue, alpha, clampedPressure);
        }
    }
}

void PaintDocument::renderShortStroke(Layer& layer, const StrokePoint& start, const StrokePoint& end) {
    const float dx = end.x - start.x;
    const float dy = end.y - start.y;
    const float distance = std::sqrt((dx * dx) + (dy * dy));

    BrushSettings savedBrush = activeBrush_;
    BrushSettings shortBrush = activeBrush_;
    shortBrush.roundness = 1.0F;
    shortBrush.roundnessPressureSensitivity = 0.0F;
    shortBrush.roundnessTiltSensitivity = 0.0F;
    shortBrush.angle = 0.0F;
    shortBrush.anglePressureSensitivity = 0.0F;
    shortBrush.angleTiltSensitivity = 0.0F;
    shortBrush.angleJitter = 0.0F;
    shortBrush.roundnessJitter = 0.0F;
    shortBrush.angleMode = 0;
    shortBrush.stampSpacing = 0.02F;
    shortBrush.spacingJitter = 0.0F;
    activeBrush_ = shortBrush;

    if (distance <= 0.0001F) {
        StrokePoint point = start;
        point.speed = 0.0F;
        stampDab(layer, point);
        lastDabPoint_ = point;
        activeBrush_ = savedBrush;
        return;
    }

    const float shortStrokeRadius = std::max(
        0.4F,
        std::min(
            resolvedStrokeRadius(activeBrush_, start.pressure, 0.0F),
            resolvedStrokeRadius(activeBrush_, end.pressure, 0.0F)
        )
    );
    const float stepDistance = std::max(shortStrokeRadius * 0.04F, 0.015F);
    const int steps = std::max(1, static_cast<int>(std::ceil(distance / stepDistance)));
    for (int step = 0; step <= steps; ++step) {
        const float t = static_cast<float>(step) / static_cast<float>(steps);
        StrokePoint point;
        point.x = start.x + (dx * t);
        point.y = start.y + (dy * t);
        point.pressure = start.pressure + ((end.pressure - start.pressure) * t);
        point.altitude = start.altitude + ((end.altitude - start.altitude) * t);
        point.azimuth = start.azimuth + ((end.azimuth - start.azimuth) * t);
        point.timestamp = start.timestamp + ((end.timestamp - start.timestamp) * t);
        point.speed = 0.0F;
        stampDab(layer, point);
        lastDabPoint_ = point;
    }

    activeBrush_ = savedBrush;
}

void PaintDocument::renderStrokeSegment(Layer& layer, const StrokePoint& start, const StrokePoint& end) {
    const float dx = end.x - start.x;
    const float dy = end.y - start.y;
    const float distance = std::sqrt((dx * dx) + (dy * dy));
    if (distance <= 0.0001F) {
        StrokePoint point = end;
        point.speed = 0.0F;
        previousPoint_ = start;
        stampDab(layer, point);
        lastDabPoint_ = point;
        return;
    }

    const float segmentTimeDelta = std::max(0.001F, end.timestamp - start.timestamp);
    const float segmentSpeed = distance / segmentTimeDelta;
    const float startRadius = resolvedStrokeRadius(activeBrush_, start.pressure, segmentSpeed);
    const float endRadius = resolvedStrokeRadius(activeBrush_, end.pressure, segmentSpeed);
    const float minimumRadius = std::max(0.4F, std::min(startRadius, endRadius));
    const float stepDistance = std::max(
        std::min(brushSpacingDistance(activeBrush_) * 0.05F, minimumRadius * 0.04F),
        0.015F
    );
    const int steps = std::max(1, static_cast<int>(std::ceil(distance / stepDistance)));
    StrokePoint priorStamped = start;
    for (int step = 1; step <= steps; ++step) {
        const float t = static_cast<float>(step) / static_cast<float>(steps);
        StrokePoint point;
        point.x = start.x + (dx * t);
        point.y = start.y + (dy * t);
        point.pressure = start.pressure + ((end.pressure - start.pressure) * t);
        point.altitude = start.altitude + ((end.altitude - start.altitude) * t);
        point.azimuth = start.azimuth + ((end.azimuth - start.azimuth) * t);
        point.timestamp = start.timestamp + ((end.timestamp - start.timestamp) * t);
        const float timeDelta = std::max(0.001F, point.timestamp - priorStamped.timestamp);
        point.speed = std::sqrt(
            ((point.x - priorStamped.x) * (point.x - priorStamped.x)) +
            ((point.y - priorStamped.y) * (point.y - priorStamped.y))
        ) / timeDelta;
        previousPoint_ = priorStamped;
        stampDab(layer, point);
        lastDabPoint_ = point;
        priorStamped = point;
    }
}

void PaintDocument::blendPixel(uint8_t* dst, uint8_t r, uint8_t g, uint8_t b, float alpha, float pressure) {
    const float srcA = clamp01(alpha);
    const float dstA = static_cast<float>(dst[3]) / 255.0F;
    const bool alphaLocked = activeLayerIndex_ >= 0 &&
        activeLayerIndex_ < layerCount() &&
        layers_[static_cast<size_t>(activeLayerIndex_)].alphaLocked;

    if (activeBrush_.eraser) {
        if (alphaLocked) {
            return;
        }
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
    const float baseSrcR = static_cast<float>(r) / 255.0F;
    const float baseSrcG = static_cast<float>(g) / 255.0F;
    const float baseSrcB = static_cast<float>(b) / 255.0F;
    const float clampedPressure = std::clamp(pressure, 0.08F, 1.0F);
    const float wetness = clamp01(lerp(
        activeBrush_.wetness,
        activeBrush_.wetness * clampedPressure,
        clamp01(activeBrush_.wetnessPressureSensitivity)
    ));
    const float wetPickup = wetness * dstA;
    const float mixStrength = clamp01(activeBrush_.colorMixStrength) * wetPickup;
    const float loadAmount = clamp01(lerp(
        activeBrush_.paintLoad,
        activeBrush_.paintLoad * clampedPressure,
        clamp01(activeBrush_.loadPressureSensitivity)
    ));
    const float wettedDstR = lerp(baseSrcR, dstR, wetPickup);
    const float wettedDstG = lerp(baseSrcG, dstG, wetPickup);
    const float wettedDstB = lerp(baseSrcB, dstB, wetPickup);
    const float mixedSourceR = lerp(wettedDstR, baseSrcR, loadAmount);
    const float mixedSourceG = lerp(wettedDstG, baseSrcG, loadAmount);
    const float mixedSourceB = lerp(wettedDstB, baseSrcB, loadAmount);
    const float srcR = lerp(baseSrcR, mixedSourceR, mixStrength);
    const float srcG = lerp(baseSrcG, mixedSourceG, mixStrength);
    const float srcB = lerp(baseSrcB, mixedSourceB, mixStrength);

    if (alphaLocked) {
        if (dstA <= 0.001F) {
            return;
        }
        const float colorBlend = srcA;
        const float outR = clamp01(lerp(dstR, srcR, colorBlend));
        const float outG = clamp01(lerp(dstG, srcG, colorBlend));
        const float outB = clamp01(lerp(dstB, srcB, colorBlend));
        dst[0] = static_cast<uint8_t>(outR * 255.0F);
        dst[1] = static_cast<uint8_t>(outG * 255.0F);
        dst[2] = static_cast<uint8_t>(outB * 255.0F);
        dst[3] = static_cast<uint8_t>(dstA * 255.0F);
        return;
    }

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
    if (dirtyTileFlags_.empty()) {
        return;
    }

    for (int tileY = 0; tileY < tileRows_; ++tileY) {
        for (int tileX = 0; tileX < tileColumns_; ++tileX) {
            const size_t dirtyIndex = tileIndex(tileX, tileY);
            if (dirtyTileFlags_[dirtyIndex] == 0U) {
                continue;
            }

            const int originX = tileX * Layer::kTileSize;
            const int originY = tileY * Layer::kTileSize;
            const int copyWidth = std::min(Layer::kTileSize, width_ - originX);
            const int copyHeight = std::min(Layer::kTileSize, height_ - originY);

            for (int localY = 0; localY < copyHeight; ++localY) {
                const size_t rowOffset =
                    (static_cast<size_t>(originY + localY) * static_cast<size_t>(width_) + static_cast<size_t>(originX)) *
                    kPixelStride;
                std::fill_n(
                    compositeBuffer_.begin() + static_cast<std::ptrdiff_t>(rowOffset),
                    static_cast<size_t>(copyWidth) * kPixelStride,
                    0U
                );
            }

            for (size_t layerIndexValue = 0; layerIndexValue < layers_.size(); ++layerIndexValue) {
                const auto& layer = layers_[layerIndexValue];
                if (!isLayerVisibleEffective(static_cast<int>(layerIndexValue)) || layer.opacity <= 0.0F) {
                    continue;
                }

                const size_t tileOffset = dirtyIndex * kTileByteCount;
                for (int localY = 0; localY < copyHeight; ++localY) {
                    const int imageY = originY + localY;
                    for (int localX = 0; localX < copyWidth; ++localX) {
                        const int imageX = originX + localX;
                        const size_t srcOffset =
                            tileOffset +
                            (static_cast<size_t>(localY) * static_cast<size_t>(Layer::kTileSize) + static_cast<size_t>(localX)) *
                                kPixelStride;
                        float srcA = (static_cast<float>(layer.tiles[srcOffset + 3U]) / 255.0F) * layer.opacity;
                        if (!layer.mask.empty()) {
                            const size_t maskOffset =
                                static_cast<size_t>(imageY) * static_cast<size_t>(width_) + static_cast<size_t>(imageX);
                            srcA *= static_cast<float>(layer.mask[maskOffset]) / 255.0F;
                        }
                        if (srcA <= 0.0F) {
                            continue;
                        }

                        const size_t dstOffset =
                            (static_cast<size_t>(imageY) * static_cast<size_t>(width_) + static_cast<size_t>(imageX)) *
                            kPixelStride;
                        const float dstA = static_cast<float>(compositeBuffer_[dstOffset + 3U]) / 255.0F;
                        const float outA = srcA + (dstA * (1.0F - srcA));
                        if (outA <= 0.0F) {
                            compositeBuffer_[dstOffset] = 0U;
                            compositeBuffer_[dstOffset + 1U] = 0U;
                            compositeBuffer_[dstOffset + 2U] = 0U;
                            compositeBuffer_[dstOffset + 3U] = 0U;
                            continue;
                        }

                        const float srcR = static_cast<float>(layer.tiles[srcOffset]) / 255.0F;
                        const float srcG = static_cast<float>(layer.tiles[srcOffset + 1U]) / 255.0F;
                        const float srcB = static_cast<float>(layer.tiles[srcOffset + 2U]) / 255.0F;
                        const float dstR = static_cast<float>(compositeBuffer_[dstOffset]) / 255.0F;
                        const float dstG = static_cast<float>(compositeBuffer_[dstOffset + 1U]) / 255.0F;
                        const float dstB = static_cast<float>(compositeBuffer_[dstOffset + 2U]) / 255.0F;

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

                        compositeBuffer_[dstOffset] = static_cast<uint8_t>(outR * 255.0F);
                        compositeBuffer_[dstOffset + 1U] = static_cast<uint8_t>(outG * 255.0F);
                        compositeBuffer_[dstOffset + 2U] = static_cast<uint8_t>(outB * 255.0F);
                        compositeBuffer_[dstOffset + 3U] = static_cast<uint8_t>(clamp01(outA) * 255.0F);
                    }
                }
            }

            dirtyTileFlags_[dirtyIndex] = 0U;
        }
    }
}

}  // namespace atelierprime
