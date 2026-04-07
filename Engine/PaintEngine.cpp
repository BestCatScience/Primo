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
    layerFolderIDs_.push_back(-1);
    activeLayerIndex_ = layerCount() - 1;
    markEntireDocumentDirty();
    compositeDirty_ = true;
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
    compositeDirty_ = true;
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
    compositeDirty_ = true;
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
    compositeDirty_ = true;
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
    compositeDirty_ = true;
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
    compositeDirty_ = true;
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
    if (index < 0 || index >= layerCount()) {
        return;
    }
    pushLayerHistorySnapshot(index);
    std::fill(layers_[index].pixels.begin(), layers_[index].pixels.end(), 0U);
    markEntireDocumentDirty();
    compositeDirty_ = true;
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
    lastDabPoint_ = point;
    strokeOriginPoint_ = point;
    distanceUntilNextDab_ = nextBrushSpacingDistance(activeBrush_, point);
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
    if (distance <= 0.0001F) {
        previousPoint_ = point;
        return;
    }

    float traveledAlongSegment = 0.0F;
    float remainingToNextDab = std::max(0.0001F, distanceUntilNextDab_);
    while (remainingToNextDab <= (distance - traveledAlongSegment)) {
        traveledAlongSegment += remainingToNextDab;
        const float t = traveledAlongSegment / distance;
        StrokePoint interpolated;
        interpolated.x = previousPoint_.x + (dx * t);
        interpolated.y = previousPoint_.y + (dy * t);
        interpolated.pressure = previousPoint_.pressure + ((point.pressure - previousPoint_.pressure) * t);
        interpolated.altitude = previousPoint_.altitude + ((point.altitude - previousPoint_.altitude) * t);
        interpolated.azimuth = previousPoint_.azimuth + ((point.azimuth - previousPoint_.azimuth) * t);
        interpolated.timestamp = previousPoint_.timestamp + ((point.timestamp - previousPoint_.timestamp) * t);

        const float timeDelta = std::max(0.001F, interpolated.timestamp - lastDabPoint_.timestamp);
        const float traveled = std::sqrt(((interpolated.x - lastDabPoint_.x) * (interpolated.x - lastDabPoint_.x)) +
                                         ((interpolated.y - lastDabPoint_.y) * (interpolated.y - lastDabPoint_.y)));
        interpolated.speed = traveled / timeDelta;
        stampDab(layer, interpolated);
        lastDabPoint_ = interpolated;
        remainingToNextDab = nextBrushSpacingDistance(activeBrush_, interpolated);
    }

    distanceUntilNextDab_ = remainingToNextDab - (distance - traveledAlongSegment);
    previousPoint_ = point;
    compositeDirty_ = true;
}

void PaintDocument::endStroke() {
    strokeInFlight_ = false;
    distanceUntilNextDab_ = 0.0F;
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
        current.folders = folders_;
        current.layerFolderIDs = layerFolderIDs_;
        current.nextFolderID = nextFolderID_;
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
        current.folders = folders_;
        current.layerFolderIDs = layerFolderIDs_;
        current.nextFolderID = nextFolderID_;
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
    undoStack_.push_back(std::move(snapshot));
    if (undoStack_.size() > kMaxHistoryDepth) {
        undoStack_.erase(undoStack_.begin());
    }
    redoStack_.clear();
}

void PaintDocument::markEntireDocumentDirty() noexcept {
    dirtyRect_.expand(0, 0, width_ - 1, height_ - 1);
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

    const float clampedPressure = std::clamp(point.pressure, 0.08F, 1.0F);
    const float clampedSensitivity = clamp01(activeBrush_.pressureSensitivity);
    const float pressureScale = (1.0F - clampedSensitivity) + (clampedPressure * clampedSensitivity);
    const float speedFactor = clamp01(point.speed / std::max(12.0F, activeBrush_.radius * 18.0F));
    const float speedScale = lerp(1.0F, remap(speedFactor, 0.0F, 1.0F, 1.0F, 0.58F), clamp01(activeBrush_.sizeSpeedSensitivity));
    const float radius = std::max(0.4F, activeBrush_.radius * pressureScale * speedScale);
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
    const float effectiveOpacity = clamp01(activeBrush_.opacity * std::max(0.05F, resolvedFlow) * opacityPressure);
    const bool isPencil = activeBrush_.tipKind == "pencil";
    const bool isInk = activeBrush_.tipKind == "ink";
    const bool isOil = activeBrush_.tipKind == "oil";
    const bool isAirbrush = activeBrush_.tipKind == "airbrush";
    const float altitudeFactor = clamp01((1.5707963F - point.altitude) / 1.5707963F);
    const float strokeDX = point.x - lastDabPoint_.x;
    const float strokeDY = point.y - lastDabPoint_.y;
    const float strokeDistance = std::sqrt((strokeDX * strokeDX) + (strokeDY * strokeDY));
    const float tangentX = strokeDistance > 0.001F ? (strokeDX / strokeDistance) : std::cos(point.azimuth);
    const float tangentY = strokeDistance > 0.001F ? (strokeDY / strokeDistance) : std::sin(point.azimuth);
    const float normalX = -tangentY;
    const float normalY = tangentX;
    const int resolvedCount = std::max(1, activeBrush_.count + static_cast<int>(std::round(jitterValue(point.x + 3.7F, point.y - 1.9F, activeBrush_.countJitter * static_cast<float>(std::max(activeBrush_.count, 1))))));
    const float maxRoundnessJitter = activeBrush_.roundnessJitter;
    const float maxAngleJitter = activeBrush_.angleJitter;
    float baseRoundness = effectiveRoundness(activeBrush_, activeBrush_.tipKind, altitudeFactor);
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
    dirtyRect_.expand(minX, minY, maxX, maxY);

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
            auto* pixel = &layer.pixels[(static_cast<size_t>(y) * static_cast<size_t>(width_) + static_cast<size_t>(x)) * 4U];
            blendPixel(pixel, activeBrush_.red, activeBrush_.green, activeBrush_.blue, alpha, clampedPressure);
        }
    }
}

void PaintDocument::blendPixel(uint8_t* dst, uint8_t r, uint8_t g, uint8_t b, float alpha, float pressure) {
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
        if (!isLayerVisibleEffective(static_cast<int>(i))) {
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
