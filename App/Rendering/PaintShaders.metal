#include <metal_stdlib>
using namespace metal;

struct MetalQuadVertex {
    float2 position;
    float2 uv;
};

struct MetalQuadUniforms {
    float2 origin;
    float2 size;
    float2 viewport;
    float opacity;
    float4 paperColor;
    float checkerboard;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float2 paperUV;
};

vertex VertexOut canvasVertex(
    const device MetalQuadVertex *vertices [[buffer(0)]],
    constant MetalQuadUniforms& uniforms [[buffer(1)]],
    uint vertexID [[vertex_id]]
) {
    VertexOut out;
    float2 pixelPosition = uniforms.origin + (vertices[vertexID].position * uniforms.size);
    float2 ndc = float2(
        (pixelPosition.x / uniforms.viewport.x) * 2.0 - 1.0,
        1.0 - ((pixelPosition.y / uniforms.viewport.y) * 2.0)
    );
    out.position = float4(ndc, 0.0, 1.0);
    out.uv = vertices[vertexID].uv;
    out.paperUV = pixelPosition / max(uniforms.viewport, float2(1.0));
    return out;
}

fragment float4 paperFragment(VertexOut in [[stage_in]],
                              constant MetalQuadUniforms& uniforms [[buffer(0)]]) {
    if (uniforms.checkerboard > 0.5) {
        float2 grid = floor(in.paperUV * uniforms.viewport / 12.0);
        float checker = fmod(grid.x + grid.y, 2.0);
        float3 light = float3(0.94, 0.94, 0.94);
        float3 dark = float3(0.82, 0.82, 0.82);
        float3 color = mix(light, dark, checker);
        return float4(color, 1.0);
    }
    return uniforms.paperColor;
}

fragment float4 layerFragment(VertexOut in [[stage_in]],
                              texture2d<float> layerTexture [[texture(0)]],
                              constant MetalQuadUniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);
    float4 color = layerTexture.sample(textureSampler, in.uv);
    color.a *= uniforms.opacity;
    color.rgb *= color.a;
    return color;
}

struct MetalCompositeLayerDescriptor {
    int documentIndex;
    float opacity;
    uint visible;
    uint isClipped;
    int blendMode;
};

struct MetalCompositeRequestDescriptor {
    uint canvasWidth;
    uint canvasHeight;
    uint originX;
    uint originY;
    uint outputWidth;
    uint outputHeight;
    uint layerCount;
    int activeLayerIndex;
    uint hasActiveLayerOverride;
    uint includeActiveLayerWhenHidden;
};

struct MetalMaskKernelDescriptor {
    uint width;
    uint height;
    uint radius;
};

struct MetalColorRangeSelectionDescriptor {
    uint width;
    uint height;
    uint red;
    uint green;
    uint blue;
    float tolerance;
    float minimumAlpha;
};

struct MetalSelectionOverlayDescriptor {
    uint width;
    uint height;
    uint red;
    uint green;
    uint blue;
    float maximumAlpha;
};

struct MetalEyedropperLoupeDescriptor {
    uint sourceWidth;
    uint sourceHeight;
    int centerX;
    int centerY;
    uint gridSize;
    uint blendWithPaper;
    float paperRed;
    float paperGreen;
    float paperBlue;
};

struct MetalPaperCompositeDescriptor {
    uint width;
    uint height;
    float paperRed;
    float paperGreen;
    float paperBlue;
    float paperAlpha;
    uint checkerboard;
};

struct MetalStrokeSampleDescriptor {
    float x;
    float y;
    float pressure;
    float progress;
};

struct MetalStrokeBrushDescriptor {
    float radius;
    float pressureSensitivity;
    float taperIn;
    float taperOut;
    float opacity;
    float flow;
    float hardness;
    float opacityPressureSensitivity;
    float flowPressureSensitivity;
    float grainScale;
    float grainContrast;
    float paperScale;
    float paperStrength;
    float paperThreshold;
    float textureStrength;
    float wetness;
    float colorMixStrength;
    float smudgeBleed;
    float smudgeRadius;
    float paintLoad;
    float red;
    float green;
    float blue;
    float scatterLateral;
    float scatterLinear;
    float dualScale;
    float dualSpacing;
    float dualScatter;
    uint customTipWidth;
    uint customTipHeight;
    uint isEraser;
    uint isPencil;
    uint isOil;
    uint isAirbrush;
    uint dualBrushEnabled;
    uint customTipEnabled;
    uint scatterMode;
    uint textureMode;
    uint dualBlendMode;
    uint colorMixingMode;
};

struct MetalStrokeRasterRequestDescriptor {
    uint canvasWidth;
    uint canvasHeight;
    uint originX;
    uint originY;
    uint rectWidth;
    uint rectHeight;
    uint sampleCount;
};

constant int BlendModeNormal = 0;
constant int BlendModeDarken = 1;
constant int BlendModeMultiply = 2;
constant int BlendModeColorBurn = 3;
constant int BlendModeLinearBurn = 4;
constant int BlendModeSubtract = 5;
constant int BlendModeLighten = 6;
constant int BlendModeScreen = 7;
constant int BlendModeColorDodge = 8;
constant int BlendModeGlowDodge = 9;
constant int BlendModeOverlay = 10;
constant int BlendModeSoftLight = 11;
constant int BlendModeHardLight = 12;
constant int BlendModeDifference = 13;
constant int BlendModeVividLight = 14;
constant int BlendModeLinearLight = 15;
constant int BlendModePinLight = 16;
constant int BlendModeHardMix = 17;
constant int BlendModeExclusion = 18;
constant int BlendModeDarkerColor = 19;
constant int BlendModeLighterColor = 20;
constant int BlendModeDivide = 21;
constant int BlendModeHue = 22;
constant int BlendModeSaturation = 23;
constant int BlendModeColor = 24;
constant int BlendModeAdd = 25;
constant int BlendModeAddGlow = 26;
constant int BlendModeLuminosity = 27;

inline float previewLuminosity(float3 color) {
    return (0.3 * color.r) + (0.59 * color.g) + (0.11 * color.b);
}

inline float previewSaturation(float3 color) {
    return max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
}

inline float3 previewClamped(float3 color) {
    return clamp(color, float3(0.0), float3(1.0));
}

inline float3 previewClipColor(float3 color) {
    const float luminosity = previewLuminosity(color);
    const float minValue = min(color.r, min(color.g, color.b));
    const float maxValue = max(color.r, max(color.g, color.b));
    float3 result = color;

    if (minValue < 0.0) {
        result.r = luminosity + (((result.r - luminosity) * luminosity) / max(0.0001, luminosity - minValue));
        result.g = luminosity + (((result.g - luminosity) * luminosity) / max(0.0001, luminosity - minValue));
        result.b = luminosity + (((result.b - luminosity) * luminosity) / max(0.0001, luminosity - minValue));
    }
    if (maxValue > 1.0) {
        result.r = luminosity + (((result.r - luminosity) * (1.0 - luminosity)) / max(0.0001, maxValue - luminosity));
        result.g = luminosity + (((result.g - luminosity) * (1.0 - luminosity)) / max(0.0001, maxValue - luminosity));
        result.b = luminosity + (((result.b - luminosity) * (1.0 - luminosity)) / max(0.0001, maxValue - luminosity));
    }
    return previewClamped(result);
}

inline float3 previewSetLuminosity(float3 color, float luminosity) {
    const float delta = luminosity - previewLuminosity(color);
    return previewClipColor(float3(color.r + delta, color.g + delta, color.b + delta));
}

inline float3 previewSetSaturation(float3 color, float saturation) {
    float components[3] = { color.r, color.g, color.b };
    float minValue = min(components[0], min(components[1], components[2]));
    float maxValue = max(components[0], max(components[1], components[2]));
    if (maxValue <= minValue) {
        return float3(0.0);
    }

    for (uint index = 0; index < 3; ++index) {
        components[index] = ((components[index] - minValue) * saturation) / (maxValue - minValue);
    }

    const float updatedMin = min(components[0], min(components[1], components[2]));
    const float updatedMax = max(components[0], max(components[1], components[2]));
    if (updatedMax <= updatedMin) {
        return float3(0.0);
    }

    for (uint index = 0; index < 3; ++index) {
        components[index] = ((components[index] - updatedMin) / (updatedMax - updatedMin)) * saturation;
    }

    return previewClipColor(float3(components[0], components[1], components[2]));
}

inline float previewBlendChannel(float backdrop, float source, int blendMode) {
    switch (blendMode) {
        case BlendModeNormal:
            return source;
        case BlendModeDarken:
            return min(backdrop, source);
        case BlendModeMultiply:
            return backdrop * source;
        case BlendModeColorBurn:
            return source <= 0.0 ? 0.0 : max(0.0, 1.0 - ((1.0 - backdrop) / max(0.001, source)));
        case BlendModeLinearBurn:
            return max(0.0, backdrop + source - 1.0);
        case BlendModeSubtract:
            return max(0.0, backdrop - source);
        case BlendModeLighten:
            return max(backdrop, source);
        case BlendModeScreen:
            return 1.0 - ((1.0 - backdrop) * (1.0 - source));
        case BlendModeAdd:
            return min(1.0, backdrop + source);
        case BlendModeColorDodge:
            return source >= 1.0 ? 1.0 : min(1.0, backdrop / max(0.001, 1.0 - source));
        case BlendModeGlowDodge:
            return source >= 1.0 ? 1.0 : min(1.0, backdrop / max(0.0005, 1.0 - (source * 0.92)));
        case BlendModeOverlay:
            return backdrop <= 0.5 ? (2.0 * backdrop * source) : (1.0 - 2.0 * (1.0 - backdrop) * (1.0 - source));
        case BlendModeSoftLight:
            return source <= 0.5
                ? (backdrop - ((1.0 - 2.0 * source) * backdrop * (1.0 - backdrop)))
                : (backdrop + ((2.0 * source - 1.0) * ((backdrop <= 0.25)
                    ? ((((16.0 * backdrop - 12.0) * backdrop) + 4.0) * backdrop)
                    : sqrt(backdrop)) - backdrop));
        case BlendModeHardLight:
            return source <= 0.5 ? (2.0 * backdrop * source) : (1.0 - 2.0 * (1.0 - backdrop) * (1.0 - source));
        case BlendModeDifference:
            return fabs(backdrop - source);
        case BlendModeVividLight:
            return source <= 0.5
                ? (1.0 - ((1.0 - backdrop) / max(0.001, 2.0 * source)))
                : (backdrop / max(0.001, 2.0 * (1.0 - source)));
        case BlendModeLinearLight:
            return clamp(backdrop + (2.0 * source) - 1.0, 0.0, 1.0);
        case BlendModePinLight:
            return source > 0.5 ? max(backdrop, 2.0 * (source - 0.5)) : min(backdrop, 2.0 * source);
        case BlendModeHardMix:
            return previewBlendChannel(backdrop, source, BlendModeVividLight) < 0.5 ? 0.0 : 1.0;
        case BlendModeExclusion:
            return backdrop + source - (2.0 * backdrop * source);
        case BlendModeDivide:
            return source <= 0.001 ? 1.0 : min(1.0, backdrop / source);
        case BlendModeAddGlow:
            return min(1.0, backdrop + (source * 1.15));
        case BlendModeDarkerColor:
        case BlendModeLighterColor:
        case BlendModeHue:
        case BlendModeSaturation:
        case BlendModeColor:
        case BlendModeLuminosity:
            return source;
        default:
            return source;
    }
}

inline float3 blendedPreviewColor(float3 backdrop, float3 source, int blendMode) {
    if (blendMode == BlendModeDarkerColor) {
        return previewLuminosity(source) < previewLuminosity(backdrop) ? source : backdrop;
    }
    if (blendMode == BlendModeLighterColor) {
        return previewLuminosity(source) > previewLuminosity(backdrop) ? source : backdrop;
    }
    if (blendMode == BlendModeHue) {
        float3 output = source;
        output = previewSetSaturation(output, previewSaturation(backdrop));
        output = previewSetLuminosity(output, previewLuminosity(backdrop));
        return previewClamped(output);
    }
    if (blendMode == BlendModeSaturation) {
        float3 output = backdrop;
        output = previewSetSaturation(output, previewSaturation(source));
        output = previewSetLuminosity(output, previewLuminosity(backdrop));
        return previewClamped(output);
    }
    if (blendMode == BlendModeColor) {
        float3 output = source;
        output = previewSetSaturation(output, previewSaturation(source));
        output = previewSetLuminosity(output, previewLuminosity(backdrop));
        return previewClamped(output);
    }
    if (blendMode == BlendModeLuminosity) {
        float3 output = backdrop;
        output = previewSetLuminosity(output, previewLuminosity(source));
        return previewClamped(output);
    }

    return clamp(float3(
        previewBlendChannel(backdrop.r, source.r, blendMode),
        previewBlendChannel(backdrop.g, source.g, blendMode),
        previewBlendChannel(backdrop.b, source.b, blendMode)
    ), float3(0.0), float3(1.0));
}

inline float strokeClampUnit(float value) {
    return clamp(value, 0.0f, 1.0f);
}

inline float strokeNoise(float x, float y) {
    float value = sin((x * 12.9898f) + (y * 78.233f)) * 43758.5453f;
    return value - floor(value);
}

inline float strokeTaperScale(float progress, float taperIn, float taperOut) {
    auto easedRamp = [](float localProgress, float length) -> float {
        if (length <= 0.001f) {
            return 1.0f;
        }
        float t = strokeClampUnit(localProgress / length);
        float eased = t * t * (3.0f - (2.0f * t));
        return 0.08f + (0.92f * eased);
    };

    float entry = easedRamp(progress, taperIn);
    float exit = easedRamp(1.0f - progress, taperOut);
    return min(entry, exit);
}

inline float resolvedStrokeRadius(
    constant MetalStrokeBrushDescriptor& brush,
    float pressure,
    float progress
) {
    float clampedPressure = max(0.08f, min(pressure, 1.0f));
    float pressureFactor = max(0.1f, 1.0f + ((clampedPressure - 1.0f) * brush.pressureSensitivity));
    float taperScale = strokeTaperScale(progress, brush.taperIn, brush.taperOut);
    return max(brush.radius * pressureFactor * taperScale, 1.5f);
}

inline float rasterizedSourceAlpha(
    constant MetalStrokeBrushDescriptor& brush,
    const device uchar *customTipPixels,
    float2 samplePoint,
    float pressure,
    float progress,
    float radius,
    float2 pixelCenter
) {
    if (brush.scatterLateral > 0.001f || brush.scatterLinear > 0.001f) {
        float directionalNoise = (strokeNoise((samplePoint.x * 0.13f) + progress * 17.0f, (samplePoint.y * 0.11f) + pressure * 13.0f) * 2.0f) - 1.0f;
        float perpendicularNoise = (strokeNoise((samplePoint.y * 0.17f) + progress * 29.0f, (samplePoint.x * 0.07f) + pressure * 19.0f) * 2.0f) - 1.0f;
        if (brush.scatterMode == 1u) {
            samplePoint += float2(directionalNoise * brush.scatterLinear, perpendicularNoise * brush.scatterLateral);
        } else {
            samplePoint += float2(perpendicularNoise * brush.scatterLateral, directionalNoise * brush.scatterLinear * 0.45f);
        }
    }

    float pressureOpacity = max(0.05f, 1.0f + ((pressure - 1.0f) * brush.opacityPressureSensitivity));
    float flowOpacity = max(0.05f, 1.0f + ((pressure - 1.0f) * brush.flowPressureSensitivity));
    float clampedOpacity = strokeClampUnit(brush.opacity);
    float clampedFlow = strokeClampUnit(brush.flow);
    float baseAlpha = strokeClampUnit(clampedOpacity * clampedFlow * pressureOpacity * flowOpacity);
    if (baseAlpha <= 0.001f) {
        return 0.0f;
    }

    float2 delta = pixelCenter - samplePoint;
    float normalizedDistance = length(delta) / max(radius, 0.001f);
    if (normalizedDistance > 1.0f) {
        return 0.0f;
    }

    float customTipAlpha = 1.0f;
    if (brush.customTipEnabled != 0u && brush.customTipWidth > 0u && brush.customTipHeight > 0u) {
        float2 normalized = clamp((delta / max(radius, 0.001f)) * 0.5f + 0.5f, float2(0.0f), float2(1.0f));
        uint tipX = min(uint(normalized.x * float(max(int(brush.customTipWidth) - 1, 0))), brush.customTipWidth - 1u);
        uint tipY = min(uint(normalized.y * float(max(int(brush.customTipHeight) - 1, 0))), brush.customTipHeight - 1u);
        uint tipOffset = (tipY * brush.customTipWidth) + tipX;
        customTipAlpha = float(customTipPixels[tipOffset]) / 255.0f;
        if (customTipAlpha <= 0.001f) {
            return 0.0f;
        }
    }

    float hardness = strokeClampUnit(brush.hardness);
    if (brush.isAirbrush != 0u) {
        hardness *= 0.28f;
    }
    float hardCore = brush.isPencil != 0
        ? min(0.78f, pow(hardness, 4.8f) * 0.72f)
        : (hardness >= 0.995f ? 1.0f : pow(hardness, brush.isAirbrush != 0u ? 1.35f : 3.2f));
    float falloff = 1.0f;
    if (hardCore < 0.999f && normalizedDistance > hardCore) {
        float span = max(0.001f, 1.0f - hardCore);
        float softened = strokeClampUnit((normalizedDistance - hardCore) / span);
        if (brush.isPencil != 0) {
            falloff = pow(1.0f - softened, 1.6f);
        } else if (brush.isAirbrush != 0u) {
            falloff = pow(1.0f - softened, 2.3f);
        } else {
            falloff = 1.0f - softened;
        }
    }

    float textureAlpha = 1.0f;
    if (brush.isPencil != 0) {
        float grainNoise = strokeNoise(
            pixelCenter.x * max(brush.grainScale, 0.6f),
            pixelCenter.y * max(brush.grainScale, 0.6f)
        );
        float paperNoise = strokeNoise(
            pixelCenter.x * max(brush.paperScale * 24.0f, 1.0f),
            pixelCenter.y * max(brush.paperScale * 24.0f, 1.0f)
        );
        float grainContrast = max(0.35f, brush.grainContrast);
        float contrastedGrain = strokeClampUnit(((grainNoise - 0.5f) * grainContrast) + 0.5f);
        float grainStrength = strokeClampUnit(brush.textureStrength) * 0.55f;
        float paperStrength = strokeClampUnit(brush.paperStrength) * 0.45f;
        float grainMask = max(0.14f, 1.0f - grainStrength + (contrastedGrain * grainStrength));
        float paperThreshold = strokeClampUnit(brush.paperThreshold);
        float paperMask = max(
            0.18f,
            1.0f - paperStrength + (strokeClampUnit((paperNoise - paperThreshold + 1.0f) * 0.75f) * paperStrength)
        );
        textureAlpha = grainMask * paperMask;
    } else if (brush.textureStrength > 0.001f && brush.textureMode != 0u) {
        float2 texturePoint = pixelCenter;
        if (brush.textureMode == 2u) {
            texturePoint -= samplePoint * 0.65f;
        } else if (brush.textureMode == 3u) {
            texturePoint += float2(progress * radius * 3.2f, progress * radius * 2.4f);
        }
        float primaryNoise = strokeNoise(
            texturePoint.x * max(brush.grainScale * 0.75f, 0.35f),
            texturePoint.y * max(brush.grainScale * 0.75f, 0.35f)
        );
        float secondaryNoise = strokeNoise(
            (texturePoint.x + samplePoint.x * 0.21f) * max(brush.paperScale * 18.0f, 0.8f),
            (texturePoint.y + samplePoint.y * 0.21f) * max(brush.paperScale * 18.0f, 0.8f)
        );
        float textureStrength = strokeClampUnit(brush.textureStrength);
        float contrastedNoise = strokeClampUnit(((primaryNoise - 0.5f) * max(brush.grainContrast, 0.5f)) + 0.5f);
        float paperMask = strokeClampUnit((secondaryNoise - (brush.paperThreshold * 0.85f)) + 0.75f);
        float textureMask = mix(1.0f, max(0.15f, contrastedNoise * max(0.18f, paperMask)), textureStrength * 0.65f);
        textureAlpha *= textureMask;
    }

    return baseAlpha * falloff * textureAlpha * customTipAlpha;
}

inline float dualBrushMask(
    constant MetalStrokeBrushDescriptor& brush,
    float2 samplePoint,
    float progress,
    float radius,
    float2 pixelCenter
) {
    if (brush.dualBrushEnabled == 0u) {
        return 1.0f;
    }

    float scaledRadius = max(1.0f, radius * max(brush.dualScale, 0.12f));
    float phase = progress * (6.2831853f * (1.0f + brush.dualSpacing));
    float offsetDistance = scaledRadius * min(brush.dualScatter, 1.8f) * 0.55f;
    float2 offset = float2(cos(phase), sin(phase)) * offsetDistance;
    float2 dualCenter = samplePoint + offset;
    float normalizedDistance = length(pixelCenter - dualCenter) / scaledRadius;
    if (normalizedDistance >= 1.0f) {
        return brush.dualBlendMode == 2u ? 0.35f : 0.18f;
    }

    float mask = 1.0f - normalizedDistance;
    mask = brush.isAirbrush != 0u ? pow(mask, 1.8f) : pow(mask, 1.2f);
    float stripeNoise = strokeNoise(
        (pixelCenter.x + samplePoint.x * 0.31f) * (0.7f + brush.dualSpacing * 1.3f),
        (pixelCenter.y + samplePoint.y * 0.27f) * (0.7f + brush.dualSpacing * 1.1f)
    );
    mask *= 0.65f + (stripeNoise * 0.35f);

    switch (brush.dualBlendMode) {
    case 0u:
        return max(0.14f, mask);
    case 1u:
        return max(0.08f, min(mask, 0.82f));
    case 2u:
        return max(0.04f, 1.0f - ((1.0f - mask) * 0.72f));
    default:
        return max(0.12f, mask);
    }
}

inline float4 strokeSourcePixel(
    const device uchar *pixels,
    constant MetalStrokeRasterRequestDescriptor& request,
    int x,
    int y
) {
    int clampedX = clamp(x, 0, int(request.canvasWidth) - 1);
    int clampedY = clamp(y, 0, int(request.canvasHeight) - 1);
    uint offset = (uint(clampedY) * request.canvasWidth + uint(clampedX)) * 4u;
    return float4(
        float(pixels[offset]) / 255.0f,
        float(pixels[offset + 1u]) / 255.0f,
        float(pixels[offset + 2u]) / 255.0f,
        float(pixels[offset + 3u]) / 255.0f
    );
}

inline float4 strokeNeighborhoodSample(
    const device uchar *pixels,
    constant MetalStrokeRasterRequestDescriptor& request,
    int centerX,
    int centerY,
    float radius,
    constant MetalStrokeBrushDescriptor& brush
) {
    float spread = max(1.0f, radius * (0.24f + (brush.smudgeRadius * 1.45f) + (brush.wetness * 0.35f) + (brush.isOil != 0u ? 0.18f : 0.0f)));
    float4 accumulated = float4(0.0f);
    float totalWeight = 0.0f;

    const int2 offsets[9] = {
        int2(0, 0), int2(-1, 0), int2(1, 0),
        int2(0, -1), int2(0, 1), int2(-1, -1),
        int2(1, -1), int2(-1, 1), int2(1, 1)
    };
    const float weights[9] = { 0.24f, 0.12f, 0.12f, 0.12f, 0.12f, 0.07f, 0.07f, 0.07f, 0.07f };

    for (uint index = 0; index < 9; ++index) {
        int sampleX = centerX + int(round(float(offsets[index].x) * spread));
        int sampleY = centerY + int(round(float(offsets[index].y) * spread));
        float4 sample = strokeSourcePixel(pixels, request, sampleX, sampleY);
        accumulated += sample * weights[index];
        totalWeight += weights[index];
    }

    if (totalWeight <= 0.0001f) {
        return strokeSourcePixel(pixels, request, centerX, centerY);
    }
    return accumulated / totalWeight;
}

kernel void strokeRasterKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalStrokeSampleDescriptor *samples [[buffer(2)]],
    constant MetalStrokeBrushDescriptor& brush [[buffer(3)]],
    constant MetalStrokeRasterRequestDescriptor& request [[buffer(4)]],
    const device uchar *customTipPixels [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= request.rectWidth || gid.y >= request.rectHeight || request.sampleCount == 0) {
        return;
    }

    uint x = request.originX + gid.x;
    uint y = request.originY + gid.y;
    if (x >= request.canvasWidth || y >= request.canvasHeight) {
        return;
    }

    float2 pixelCenter = float2(float(x) + 0.5f, float(y) + 0.5f);
    uint offset = ((y * request.canvasWidth) + x) * 4u;

    float4 destination = strokeSourcePixel(sourcePixels, request, int(x), int(y));
    float destinationAlpha = destination.a;
    float destinationRed = destination.r;
    float destinationGreen = destination.g;
    float destinationBlue = destination.b;

    float maxSourceAlpha = 0.0f;
    float bestPressure = samples[0].pressure;
    float bestProgress = samples[0].progress;
    float bestRadius = resolvedStrokeRadius(brush, bestPressure, bestProgress);
    for (uint index = 0; index < request.sampleCount; ++index) {
        float sourceAlpha = 0.0f;
        float candidatePressure = samples[index].pressure;
        float candidateProgress = samples[index].progress;
        float candidateRadius = resolvedStrokeRadius(brush, candidatePressure, candidateProgress);
        float2 candidatePoint = float2(samples[index].x, samples[index].y);
        if (request.sampleCount == 1 || index == request.sampleCount - 1u) {
            sourceAlpha = rasterizedSourceAlpha(
                brush,
                customTipPixels,
                candidatePoint,
                candidatePressure,
                candidateProgress,
                candidateRadius,
                pixelCenter
            );
        } else {
            MetalStrokeSampleDescriptor start = samples[index];
            MetalStrokeSampleDescriptor end = samples[index + 1u];
            float2 segment = float2(end.x - start.x, end.y - start.y);
            float lengthSquared = max(dot(segment, segment), 0.0001f);
            float projection = dot(pixelCenter - float2(start.x, start.y), segment) / lengthSquared;
            float t = strokeClampUnit(projection);
            float2 samplePoint = float2(start.x, start.y) + (segment * t);
            float pressure = start.pressure + ((end.pressure - start.pressure) * t);
            float progress = start.progress + ((end.progress - start.progress) * t);
            float radius = resolvedStrokeRadius(brush, pressure, progress);
            candidatePoint = samplePoint;
            candidatePressure = pressure;
            candidateProgress = progress;
            candidateRadius = radius;
            sourceAlpha = rasterizedSourceAlpha(
                brush,
                customTipPixels,
                samplePoint,
                pressure,
                progress,
                radius,
                pixelCenter
            );
        }
        if (sourceAlpha > 0.0f) {
            float appliedMask = dualBrushMask(
                brush,
                candidatePoint,
                candidateProgress,
                candidateRadius,
                pixelCenter
            );
            sourceAlpha *= appliedMask;
        }
        if (sourceAlpha > maxSourceAlpha) {
            maxSourceAlpha = sourceAlpha;
            bestPressure = candidatePressure;
            bestProgress = candidateProgress;
            bestRadius = candidateRadius;
        }
    }

    if (maxSourceAlpha <= 0.001f) {
        return;
    }

    if (brush.isEraser != 0u) {
        float outAlpha = destinationAlpha * (1.0f - maxSourceAlpha);
        outputPixels[offset] = sourcePixels[offset];
        outputPixels[offset + 1u] = sourcePixels[offset + 1u];
        outputPixels[offset + 2u] = sourcePixels[offset + 2u];
        outputPixels[offset + 3u] = uchar(clamp(int(round(outAlpha * 255.0f)), 0, 255));
        return;
    }

    float3 sourceColor = float3(brush.red, brush.green, brush.blue);
    if (brush.colorMixingMode != 0u || brush.isOil != 0u) {
        float4 neighborhood = strokeNeighborhoodSample(
            sourcePixels,
            request,
            int(x),
            int(y),
            bestRadius,
            brush
        );
        float mixStrength = strokeClampUnit(
            max(brush.colorMixStrength, brush.wetness * 0.72f) +
            (brush.isOil != 0u ? 0.16f : 0.0f) +
            (brush.colorMixingMode == 2u ? brush.smudgeBleed * 0.22f : 0.0f)
        );
        float smearStrength = strokeClampUnit(
            (brush.colorMixingMode == 3u ? 0.72f : 0.0f) +
            (brush.colorMixingMode == 2u ? 0.34f : 0.0f) +
            brush.smudgeRadius * 0.18f
        );
        float pigmentLoad = strokeClampUnit(brush.paintLoad);
        float3 neighborhoodColor = mix(
            destination.rgb,
            neighborhood.rgb,
            strokeClampUnit(smearStrength + mixStrength * 0.35f)
        );
        sourceColor = mix(neighborhoodColor, sourceColor, strokeClampUnit((pigmentLoad * 0.88f) + 0.12f));
        maxSourceAlpha *= mix(
            1.0f,
            max(neighborhood.a, destinationAlpha),
            strokeClampUnit((1.0f - pigmentLoad) * 0.42f + mixStrength * 0.26f)
        );
        maxSourceAlpha = strokeClampUnit(maxSourceAlpha);
    }

    float outAlpha = destinationAlpha + (maxSourceAlpha * (1.0f - destinationAlpha));
    if (outAlpha <= 0.001f) {
        return;
    }

    float outRed = ((sourceColor.r * maxSourceAlpha) + (destinationRed * destinationAlpha * (1.0f - maxSourceAlpha))) / outAlpha;
    float outGreen = ((sourceColor.g * maxSourceAlpha) + (destinationGreen * destinationAlpha * (1.0f - maxSourceAlpha))) / outAlpha;
    float outBlue = ((sourceColor.b * maxSourceAlpha) + (destinationBlue * destinationAlpha * (1.0f - maxSourceAlpha))) / outAlpha;

    outputPixels[offset] = uchar(clamp(int(round(outRed * 255.0f)), 0, 255));
    outputPixels[offset + 1u] = uchar(clamp(int(round(outGreen * 255.0f)), 0, 255));
    outputPixels[offset + 2u] = uchar(clamp(int(round(outBlue * 255.0f)), 0, 255));
    outputPixels[offset + 3u] = uchar(clamp(int(round(outAlpha * 255.0f)), 0, 255));
}

kernel void selectionOverlayKernel(
    const device uchar *maskPixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalSelectionOverlayDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }

    uint index = (gid.y * descriptor.width) + gid.x;
    uint inputOffset = index;
    uint outputOffset = index * 4u;
    float alpha = (float(maskPixels[inputOffset]) / 255.0f) * descriptor.maximumAlpha;

    outputPixels[outputOffset] = uchar(min(descriptor.red, 255u));
    outputPixels[outputOffset + 1u] = uchar(min(descriptor.green, 255u));
    outputPixels[outputOffset + 2u] = uchar(min(descriptor.blue, 255u));
    outputPixels[outputOffset + 3u] = uchar(clamp(int(round(alpha * 255.0f)), 0, 255));
}

kernel void eyedropperLoupeKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalEyedropperLoupeDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.gridSize || gid.y >= descriptor.gridSize) {
        return;
    }

    int halfGrid = int(descriptor.gridSize / 2u);
    int sampleX = clamp(descriptor.centerX + int(gid.x) - halfGrid, 0, max(int(descriptor.sourceWidth) - 1, 0));
    int sampleY = clamp(descriptor.centerY + int(gid.y) - halfGrid, 0, max(int(descriptor.sourceHeight) - 1, 0));
    uint sourceOffset = (uint(sampleY) * descriptor.sourceWidth + uint(sampleX)) * 4u;
    uint outputOffset = ((gid.y * descriptor.gridSize) + gid.x) * 4u;

    float red = float(sourcePixels[sourceOffset]) / 255.0f;
    float green = float(sourcePixels[sourceOffset + 1u]) / 255.0f;
    float blue = float(sourcePixels[sourceOffset + 2u]) / 255.0f;
    float alpha = float(sourcePixels[sourceOffset + 3u]) / 255.0f;

    if (descriptor.blendWithPaper != 0u) {
        red = red * alpha + descriptor.paperRed * (1.0f - alpha);
        green = green * alpha + descriptor.paperGreen * (1.0f - alpha);
        blue = blue * alpha + descriptor.paperBlue * (1.0f - alpha);
    }

    outputPixels[outputOffset] = uchar(clamp(int(round(red * 255.0f)), 0, 255));
    outputPixels[outputOffset + 1u] = uchar(clamp(int(round(green * 255.0f)), 0, 255));
    outputPixels[outputOffset + 2u] = uchar(clamp(int(round(blue * 255.0f)), 0, 255));
    outputPixels[outputOffset + 3u] = 255;
}

kernel void paperCompositeKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalPaperCompositeDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }

    uint offset = ((gid.y * descriptor.width) + gid.x) * 4u;
    float sourceRed = float(sourcePixels[offset]) / 255.0f;
    float sourceGreen = float(sourcePixels[offset + 1u]) / 255.0f;
    float sourceBlue = float(sourcePixels[offset + 2u]) / 255.0f;
    float sourceAlpha = float(sourcePixels[offset + 3u]) / 255.0f;

    float3 background = float3(descriptor.paperRed, descriptor.paperGreen, descriptor.paperBlue);
    if (descriptor.checkerboard != 0u) {
        uint tileX = gid.x / 12u;
        uint tileY = gid.y / 12u;
        bool isDark = ((tileX + tileY) & 1u) == 0u;
        background = isDark ? float3(0.82f, 0.82f, 0.82f) : float3(0.94f, 0.94f, 0.94f);
    }

    float outRed = sourceRed * sourceAlpha + background.r * (1.0f - sourceAlpha);
    float outGreen = sourceGreen * sourceAlpha + background.g * (1.0f - sourceAlpha);
    float outBlue = sourceBlue * sourceAlpha + background.b * (1.0f - sourceAlpha);
    float outAlpha = descriptor.checkerboard != 0u ? 1.0f : max(descriptor.paperAlpha, sourceAlpha);

    outputPixels[offset] = uchar(clamp(int(round(outRed * 255.0f)), 0, 255));
    outputPixels[offset + 1u] = uchar(clamp(int(round(outGreen * 255.0f)), 0, 255));
    outputPixels[offset + 2u] = uchar(clamp(int(round(outBlue * 255.0f)), 0, 255));
    outputPixels[offset + 3u] = uchar(clamp(int(round(outAlpha * 255.0f)), 0, 255));
}

inline float4 readLayerColor(
    texture2d_array<float, access::read> layerTexture,
    const device uchar4 *overridePixels,
    constant MetalCompositeRequestDescriptor& request,
    uint layerIndex,
    int layerDocumentIndex,
    uint2 canvasPosition
) {
    if (request.hasActiveLayerOverride != 0 && layerDocumentIndex == request.activeLayerIndex) {
        const uint offset = (canvasPosition.y * request.canvasWidth) + canvasPosition.x;
        const uchar4 pixel = overridePixels[offset];
        return float4(float(pixel.r), float(pixel.g), float(pixel.b), float(pixel.a)) / 255.0;
    }
    return layerTexture.read(canvasPosition, layerIndex);
}

kernel void compositePreviewKernel(
    texture2d_array<float, access::read> layerTexture [[texture(0)]],
    constant MetalCompositeLayerDescriptor *layers [[buffer(0)]],
    const device uchar4 *overridePixels [[buffer(1)]],
    device uchar4 *outputPixels [[buffer(2)]],
    constant MetalCompositeRequestDescriptor& request [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= request.outputWidth || gid.y >= request.outputHeight) {
        return;
    }

    const uint2 canvasPosition = uint2(request.originX + gid.x, request.originY + gid.y);
    if (canvasPosition.x >= request.canvasWidth || canvasPosition.y >= request.canvasHeight) {
        return;
    }

    float4 destination = float4(0.0);
    float clipMask = 0.0;

    for (uint layerIndex = 0; layerIndex < request.layerCount; ++layerIndex) {
        const MetalCompositeLayerDescriptor layer = layers[layerIndex];
        const bool isActiveLayer = layer.documentIndex == request.activeLayerIndex;
        if (layer.visible == 0 && !(request.includeActiveLayerWhenHidden != 0 && request.hasActiveLayerOverride != 0 && isActiveLayer)) {
            continue;
        }

        const float4 source = readLayerColor(layerTexture, overridePixels, request, layerIndex, layer.documentIndex, canvasPosition);
        const float baseAlpha = source.a * layer.opacity;
        const float effectiveOpacity = layer.isClipped != 0 ? (layer.opacity * clipMask) : layer.opacity;
        if (layer.isClipped == 0) {
            clipMask = baseAlpha;
        }

        const float srcAlpha = source.a * effectiveOpacity;
        if (srcAlpha <= 0.001) {
            continue;
        }

        const float dstAlpha = destination.a;
        const float outAlpha = srcAlpha + (dstAlpha * (1.0 - srcAlpha));
        if (outAlpha <= 0.001) {
            continue;
        }

        const float3 blended = blendedPreviewColor(destination.rgb, source.rgb, layer.blendMode);
        const float3 outputColor = (
            srcAlpha * (((1.0 - dstAlpha) * source.rgb) + (dstAlpha * blended)) +
            (dstAlpha * (1.0 - srcAlpha) * destination.rgb)
        ) / outAlpha;

        destination = float4(clamp(outputColor, float3(0.0), float3(1.0)), clamp(outAlpha, 0.0, 1.0));
    }

    outputPixels[(gid.y * request.outputWidth) + gid.x] = uchar4(
        uchar(clamp(round(destination.r * 255.0), 0.0, 255.0)),
        uchar(clamp(round(destination.g * 255.0), 0.0, 255.0)),
        uchar(clamp(round(destination.b * 255.0), 0.0, 255.0)),
        uchar(clamp(round(destination.a * 255.0), 0.0, 255.0))
    );
}

kernel void invertMaskKernel(
    const device uchar *sourceMask [[buffer(0)]],
    device uchar *outputMask [[buffer(1)]],
    constant MetalMaskKernelDescriptor& request [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    const uint count = request.width * request.height;
    if (gid >= count) {
        return;
    }
    outputMask[gid] = sourceMask[gid] == 0 ? uchar(255) : uchar(0);
}

kernel void dilateMaskKernel(
    const device uchar *sourceMask [[buffer(0)]],
    device uchar *outputMask [[buffer(1)]],
    constant MetalMaskKernelDescriptor& request [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= request.width || gid.y >= request.height) {
        return;
    }

    uchar result = 0;
    for (int dy = -1; dy <= 1 && result == 0; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
            if (abs(dx) + abs(dy) > 1) {
                continue;
            }
            const int sampleX = int(gid.x) + dx;
            const int sampleY = int(gid.y) + dy;
            if (sampleX < 0 || sampleY < 0 || sampleX >= int(request.width) || sampleY >= int(request.height)) {
                continue;
            }
            result = max(result, sourceMask[(uint(sampleY) * request.width) + uint(sampleX)]);
        }
    }
    outputMask[(gid.y * request.width) + gid.x] = result;
}

kernel void erodeMaskKernel(
    const device uchar *sourceMask [[buffer(0)]],
    device uchar *outputMask [[buffer(1)]],
    constant MetalMaskKernelDescriptor& request [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= request.width || gid.y >= request.height) {
        return;
    }

    const uint index = (gid.y * request.width) + gid.x;
    if (sourceMask[index] == 0) {
        outputMask[index] = 0;
        return;
    }

    const bool hasOutsideNeighbor =
        gid.x == 0 ||
        gid.y == 0 ||
        gid.x + 1 >= request.width ||
        gid.y + 1 >= request.height ||
        sourceMask[index - 1] == 0 ||
        sourceMask[index + 1] == 0 ||
        sourceMask[index - request.width] == 0 ||
        sourceMask[index + request.width] == 0;

    outputMask[index] = hasOutsideNeighbor ? uchar(0) : sourceMask[index];
}

kernel void featherHorizontalKernel(
    const device uchar *sourceMask [[buffer(0)]],
    device float *temporaryMask [[buffer(1)]],
    constant MetalMaskKernelDescriptor& request [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= request.width || gid.y >= request.height) {
        return;
    }

    const int radius = int(request.radius);
    const float normalization = float((radius * 2) + 1);
    float sum = 0.0;
    for (int dx = -radius; dx <= radius; ++dx) {
        const int sampleX = clamp(int(gid.x) + dx, 0, int(request.width) - 1);
        sum += float(sourceMask[(gid.y * request.width) + uint(sampleX)]);
    }
    temporaryMask[(gid.y * request.width) + gid.x] = sum / normalization;
}

kernel void featherVerticalKernel(
    const device float *temporaryMask [[buffer(0)]],
    device uchar *outputMask [[buffer(1)]],
    constant MetalMaskKernelDescriptor& request [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= request.width || gid.y >= request.height) {
        return;
    }

    const int radius = int(request.radius);
    const float normalization = float((radius * 2) + 1);
    float sum = 0.0;
    for (int dy = -radius; dy <= radius; ++dy) {
        const int sampleY = clamp(int(gid.y) + dy, 0, int(request.height) - 1);
        sum += temporaryMask[(uint(sampleY) * request.width) + gid.x];
    }
    const float blurred = sum / normalization;
    outputMask[(gid.y * request.width) + gid.x] = blurred < 2.0 ? uchar(0) : uchar(clamp(round(blurred), 0.0, 255.0));
}

kernel void colorRangeSelectionKernel(
    const device uchar4 *sourcePixels [[buffer(0)]],
    device uchar *outputMask [[buffer(1)]],
    constant MetalColorRangeSelectionDescriptor& request [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= request.width || gid.y >= request.height) {
        return;
    }

    const uint index = (gid.y * request.width) + gid.x;
    const uchar4 pixel = sourcePixels[index];
    const float alpha = float(pixel.a) / 255.0;
    if (alpha < request.minimumAlpha) {
        outputMask[index] = 0;
        return;
    }

    const float dr = (float(pixel.r) - float(request.red)) / 255.0;
    const float dg = (float(pixel.g) - float(request.green)) / 255.0;
    const float db = (float(pixel.b) - float(request.blue)) / 255.0;
    const float distance = sqrt((dr * dr) + (dg * dg) + (db * db)) / sqrt(3.0);
    outputMask[index] = distance <= request.tolerance ? uchar(255) : uchar(0);
}
