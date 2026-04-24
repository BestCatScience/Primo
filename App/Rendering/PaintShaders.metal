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

fragment float4 nearestLayerFragment(VertexOut in [[stage_in]],
                                     texture2d<float> layerTexture [[texture(0)]],
                                     constant MetalQuadUniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::nearest);
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

struct MetalLayerMaskApplyDescriptor {
    uint width;
    uint height;
};

struct MetalLayerProcessingDescriptor {
    uint width;
    uint height;
    uint requestKind;
    uint gradientStopCount;
    float param0;
    float param1;
    float param2;
    float param3;
    float param4;
    float param5;
    float param6;
    float param7;
    uint selectionWidth;
    uint selectionHeight;
    uint hasSelection;
    uint _padding0;
};

struct MetalGradientStopDescriptor {
    float position;
    float red;
    float green;
    float blue;
};

struct MetalFillDescriptor {
    uint width;
    uint height;
    uint seedX;
    uint seedY;
    uint thresholdMode;
    uint expansion;
    float tolerance;
    float seedRed;
    float seedGreen;
    float seedBlue;
    float seedAlpha;
    float targetRed;
    float targetGreen;
    float targetBlue;
    float targetAlpha;
};

struct MetalBlurDescriptor {
    uint width;
    uint height;
    uint radius;
    uint sampleCount;
    float flow;
    float hardness;
    float influenceRadius;
    float _padding0;
};

struct MetalTextComposeDescriptor {
    uint width;
    uint height;
    float red;
    float green;
    float blue;
    float alpha;
};

struct MetalScaleDescriptor {
    uint sourceWidth;
    uint sourceHeight;
    uint targetWidth;
    uint targetHeight;
};

struct MetalTranslateDescriptor {
    uint sourceWidth;
    uint sourceHeight;
    uint targetWidth;
    uint targetHeight;
    int offsetX;
    int offsetY;
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
    float loadPressureSensitivity;
    float smudgeLength;
    float colorRate;
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
    uint smudgeMode;
};

struct MetalColorSmudgeDabDescriptor {
    uint canvasWidth;
    uint canvasHeight;
    uint rectOriginX;
    uint rectOriginY;
    uint rectWidth;
    uint rectHeight;
    float centerX;
    float centerY;
    float previousCenterX;
    float previousCenterY;
    float pressure;
    float progress;
    float radius;
};

struct MetalStrokeRasterRequestDescriptor {
    uint canvasWidth;
    uint canvasHeight;
    uint originX;
    uint originY;
    uint rectWidth;
    uint rectHeight;
    uint sampleCount;
    uint tileSize;
    uint tileColumns;
};

struct MetalStrokePrimitiveDescriptor {
    float startX;
    float startY;
    float endX;
    float endY;
    float startPressure;
    float endPressure;
    float startProgress;
    float endProgress;
    float maxRadius;
    uint isSegment;
    uint _padding0;
    uint _padding1;
};

struct MetalStrokeTileRangeDescriptor {
    uint startIndex;
    uint primitiveCount;
};

struct MetalStrokeRectCopyDescriptor {
    uint canvasWidth;
    uint canvasHeight;
    uint originX;
    uint originY;
    uint rectWidth;
    uint rectHeight;
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

inline float3 rgbToHSV(float3 color) {
    float cMax = max(color.r, max(color.g, color.b));
    float cMin = min(color.r, min(color.g, color.b));
    float delta = cMax - cMin;
    float hue = 0.0;
    if (delta > 0.0001) {
        if (cMax == color.r) {
            hue = fmod(((color.g - color.b) / delta), 6.0);
        } else if (cMax == color.g) {
            hue = ((color.b - color.r) / delta) + 2.0;
        } else {
            hue = ((color.r - color.g) / delta) + 4.0;
        }
        hue /= 6.0;
        if (hue < 0.0) {
            hue += 1.0;
        }
    }
    float saturation = cMax <= 0.0001 ? 0.0 : delta / cMax;
    return float3(hue, saturation, cMax);
}

inline float3 hsvToRGB(float3 hsv) {
    float hue = hsv.x * 6.0;
    float saturation = hsv.y;
    float value = hsv.z;
    float c = value * saturation;
    float x = c * (1.0 - fabs(fmod(hue, 2.0) - 1.0));
    float m = value - c;
    float3 rgb;
    if (hue < 1.0) rgb = float3(c, x, 0.0);
    else if (hue < 2.0) rgb = float3(x, c, 0.0);
    else if (hue < 3.0) rgb = float3(0.0, c, x);
    else if (hue < 4.0) rgb = float3(0.0, x, c);
    else if (hue < 5.0) rgb = float3(x, 0.0, c);
    else rgb = float3(c, 0.0, x);
    return previewClamped(rgb + float3(m));
}

inline float layerLuminance(float3 color) {
    return (0.2126 * color.r) + (0.7152 * color.g) + (0.0722 * color.b);
}

inline float4 sourcePixelRGBA(
    const device uchar *pixels,
    uint width,
    uint height,
    uint2 gid
) {
    if (gid.x >= width || gid.y >= height) {
        return float4(0.0);
    }
    uint offset = ((gid.y * width) + gid.x) * 4u;
    return float4(
        float(pixels[offset]) / 255.0,
        float(pixels[offset + 1u]) / 255.0,
        float(pixels[offset + 2u]) / 255.0,
        float(pixels[offset + 3u]) / 255.0
    );
}

inline void writePixelRGBA(device uchar *outputPixels, uint width, uint2 gid, float4 color) {
    uint offset = ((gid.y * width) + gid.x) * 4u;
    outputPixels[offset] = uchar(clamp(int(round(color.r * 255.0)), 0, 255));
    outputPixels[offset + 1u] = uchar(clamp(int(round(color.g * 255.0)), 0, 255));
    outputPixels[offset + 2u] = uchar(clamp(int(round(color.b * 255.0)), 0, 255));
    outputPixels[offset + 3u] = uchar(clamp(int(round(color.a * 255.0)), 0, 255));
}

inline float gradientChannel(
    const device MetalGradientStopDescriptor *stops,
    uint stopCount,
    float value,
    uint channel
) {
    if (stopCount == 0u) { return value; }
    if (stopCount == 1u) {
        return channel == 0u ? stops[0].red : (channel == 1u ? stops[0].green : stops[0].blue);
    }
    float clampedValue = clamp(value, 0.0, 1.0);
    uint upperIndex = stopCount - 1u;
    for (uint index = 0u; index < stopCount; ++index) {
        if (clampedValue <= stops[index].position) {
            upperIndex = index;
            break;
        }
    }
    if (upperIndex == 0u) {
        return channel == 0u ? stops[0].red : (channel == 1u ? stops[0].green : stops[0].blue);
    }
    MetalGradientStopDescriptor lower = stops[upperIndex - 1u];
    MetalGradientStopDescriptor upper = stops[upperIndex];
    float span = max(upper.position - lower.position, 0.0001);
    float t = clamp((clampedValue - lower.position) / span, 0.0, 1.0);
    float lowerValue = channel == 0u ? lower.red : (channel == 1u ? lower.green : lower.blue);
    float upperValue = channel == 0u ? upper.red : (channel == 1u ? upper.green : upper.blue);
    return mix(lowerValue, upperValue, t);
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

inline float4 smudgeSourcePixel(
    const device uchar *pixels,
    constant MetalColorSmudgeDabDescriptor& dab,
    int x,
    int y
) {
    int clampedX = clamp(x, 0, int(dab.canvasWidth) - 1);
    int clampedY = clamp(y, 0, int(dab.canvasHeight) - 1);
    uint offset = (uint(clampedY) * dab.canvasWidth + uint(clampedX)) * 4u;
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
    bool usesFastOilPath = brush.isOil != 0u && brush.radius >= 96.0f;
    float spread = max(1.0f, radius * (0.24f + (brush.smudgeRadius * 1.45f) + (brush.wetness * 0.35f) + (brush.isOil != 0u ? 0.18f : 0.0f)));
    if (usesFastOilPath) {
        spread = min(spread, radius * 0.85f);
    }
    float4 accumulated = float4(0.0f);
    float totalWeight = 0.0f;

    const int2 offsets[9] = {
        int2(0, 0), int2(-1, 0), int2(1, 0),
        int2(0, -1), int2(0, 1), int2(-1, -1),
        int2(1, -1), int2(-1, 1), int2(1, 1)
    };
    const float weights[9] = { 0.24f, 0.12f, 0.12f, 0.12f, 0.12f, 0.07f, 0.07f, 0.07f, 0.07f };
    uint sampleCount = usesFastOilPath ? 5u : 9u;

    for (uint index = 0; index < sampleCount; ++index) {
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

inline float4 smudgeRepresentativeColor(
    const device uchar *pixels,
    constant MetalColorSmudgeDabDescriptor& dab,
    constant MetalStrokeBrushDescriptor& brush,
    const device uchar *customTipPixels
) {
    float radiusFactor = 0.18f + (strokeClampUnit(brush.smudgeRadius) * 0.82f);
    float sampleRadius = max(1.0f, dab.radius * radiusFactor);
    const float2 offsets[9] = {
        float2(0.0f, 0.0f),
        float2(-0.6f, 0.0f),
        float2(0.6f, 0.0f),
        float2(0.0f, -0.6f),
        float2(0.0f, 0.6f),
        float2(-0.42f, -0.42f),
        float2(0.42f, -0.42f),
        float2(-0.42f, 0.42f),
        float2(0.42f, 0.42f)
    };

    float4 accumulated = float4(0.0f);
    float totalWeight = 0.0f;
    for (uint index = 0; index < 9u; ++index) {
        float2 point = float2(
            dab.centerX + (offsets[index].x * sampleRadius),
            dab.centerY + (offsets[index].y * sampleRadius)
        );
        float4 sample = smudgeSourcePixel(pixels, dab, int(round(point.x)), int(round(point.y)));
        float weight = max(
            0.05f,
            rasterizedSourceAlpha(
                brush,
                customTipPixels,
                float2(dab.centerX, dab.centerY),
                dab.pressure,
                dab.progress,
                max(sampleRadius, dab.radius),
                point
            )
        );
        accumulated += sample * weight;
        totalWeight += weight;
    }

    if (totalWeight <= 0.0001f) {
        return smudgeSourcePixel(pixels, dab, int(round(dab.centerX)), int(round(dab.centerY)));
    }
    return accumulated / totalWeight;
}

inline float4 sampleSmearingColor(
    const device uchar *pixels,
    constant MetalColorSmudgeDabDescriptor& dab,
    constant MetalStrokeBrushDescriptor& brush,
    const device uchar *customTipPixels,
    float2 point,
    float4 representative
) {
    float softness = 1.0f - strokeClampUnit(brush.hardness);
    float sampleRadius = max(0.2f, dab.radius * (0.025f + (softness * 0.05f)));
    const float2 taps[7] = {
        float2(0.0f, 0.0f),
        float2(-0.55f, 0.0f),
        float2(0.55f, 0.0f),
        float2(0.0f, -0.55f),
        float2(0.0f, 0.55f),
        float2(-0.4f, -0.4f),
        float2(0.4f, 0.4f)
    };
    const float weights[7] = { 0.58f, 0.10f, 0.10f, 0.10f, 0.10f, 0.06f, 0.06f };

    float4 accumulated = float4(0.0f);
    float totalWeight = 0.0f;
    for (uint index = 0; index < 7u; ++index) {
        float2 tapPoint = point + (taps[index] * sampleRadius);
        accumulated += smudgeSourcePixel(pixels, dab, int(round(tapPoint.x)), int(round(tapPoint.y))) * weights[index];
        totalWeight += weights[index];
    }
    float4 sampled = totalWeight > 0.0001f ? accumulated / totalWeight : representative;
    float mixRatio = 0.12f + (0.18f * (1.0f - strokeClampUnit(brush.hardness)));
    sampled.rgb = mix(sampled.rgb, representative.rgb, mixRatio);
    sampled.a = max(sampled.a, representative.a * 0.12f);
    return sampled;
}

inline float strokeSegmentEndpointFalloff(float t) {
    float endpointBlend = smoothstep(0.92f, 1.0f, strokeClampUnit(t));
    return 1.0f - (0.14f * endpointBlend);
}

inline float strokePrimitiveSourceAlpha(
    constant MetalStrokePrimitiveDescriptor& primitive,
    constant MetalStrokeBrushDescriptor& brush,
    const device uchar *customTipPixels,
    float2 pixelCenter,
    thread float2 &candidatePoint,
    thread float &candidatePressure,
    thread float &candidateProgress,
    thread float &candidateRadius
) {
    candidatePressure = primitive.startPressure;
    candidateProgress = primitive.startProgress;
    candidateRadius = resolvedStrokeRadius(brush, candidatePressure, candidateProgress);
    candidatePoint = float2(primitive.startX, primitive.startY);

    if (primitive.isSegment == 0u) {
        return rasterizedSourceAlpha(
            brush,
            customTipPixels,
            candidatePoint,
            candidatePressure,
            candidateProgress,
            candidateRadius,
            pixelCenter
        );
    }

    float2 start = float2(primitive.startX, primitive.startY);
    float2 end = float2(primitive.endX, primitive.endY);
    float2 segment = end - start;
    float lengthSquared = max(dot(segment, segment), 0.0001f);
    float projection = dot(pixelCenter - start, segment) / lengthSquared;
    float t = strokeClampUnit(projection);
    candidatePoint = start + (segment * t);
    candidatePressure = primitive.startPressure + ((primitive.endPressure - primitive.startPressure) * t);
    candidateProgress = primitive.startProgress + ((primitive.endProgress - primitive.startProgress) * t);
    candidateRadius = resolvedStrokeRadius(brush, candidatePressure, candidateProgress);
    float sourceAlpha = rasterizedSourceAlpha(
        brush,
        customTipPixels,
        candidatePoint,
        candidatePressure,
        candidateProgress,
        candidateRadius,
        pixelCenter
    );
    return sourceAlpha * strokeSegmentEndpointFalloff(t);
}

kernel void copyStrokeRectKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalStrokeRectCopyDescriptor& request [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= request.rectWidth || gid.y >= request.rectHeight) {
        return;
    }

    uint x = request.originX + gid.x;
    uint y = request.originY + gid.y;
    if (x >= request.canvasWidth || y >= request.canvasHeight) {
        return;
    }

    uint offset = ((y * request.canvasWidth) + x) * 4u;
    outputPixels[offset] = sourcePixels[offset];
    outputPixels[offset + 1u] = sourcePixels[offset + 1u];
    outputPixels[offset + 2u] = sourcePixels[offset + 2u];
    outputPixels[offset + 3u] = sourcePixels[offset + 3u];
}

kernel void strokeRasterKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalStrokePrimitiveDescriptor *primitives [[buffer(2)]],
    constant MetalStrokeBrushDescriptor& brush [[buffer(3)]],
    constant MetalStrokeRasterRequestDescriptor& request [[buffer(4)]],
    const device uchar *customTipPixels [[buffer(5)]],
    constant MetalStrokeTileRangeDescriptor *tileRanges [[buffer(6)]],
    const device uint *primitiveIndices [[buffer(7)]],
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

    uint tileSize = max(request.tileSize, 1u);
    uint tileX = gid.x / tileSize;
    uint tileY = gid.y / tileSize;
    uint tileIndex = tileY * max(request.tileColumns, 1u) + tileX;
    MetalStrokeTileRangeDescriptor tileRange = tileRanges[tileIndex];

    float accumulatedSourceAlpha = 0.0f;
    float strongestSourceAlpha = 0.0f;
    float bestPressure = primitives[0].startPressure;
    float bestProgress = primitives[0].startProgress;
    float bestRadius = resolvedStrokeRadius(brush, bestPressure, bestProgress);
    for (uint rangeIndex = 0; rangeIndex < tileRange.primitiveCount; ++rangeIndex) {
        uint primitiveIndex = primitiveIndices[tileRange.startIndex + rangeIndex];
        constant MetalStrokePrimitiveDescriptor& primitive = primitives[primitiveIndex];
        float2 candidatePoint;
        float candidatePressure;
        float candidateProgress;
        float candidateRadius;
        float sourceAlpha = strokePrimitiveSourceAlpha(
            primitive,
            brush,
            customTipPixels,
            pixelCenter,
            candidatePoint,
            candidatePressure,
            candidateProgress,
            candidateRadius
        );
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
        accumulatedSourceAlpha += sourceAlpha * (1.0f - accumulatedSourceAlpha);
        accumulatedSourceAlpha = strokeClampUnit(accumulatedSourceAlpha);
        if (sourceAlpha > strongestSourceAlpha) {
            strongestSourceAlpha = sourceAlpha;
            bestPressure = candidatePressure;
            bestProgress = candidateProgress;
            bestRadius = candidateRadius;
        }
    }

    if (accumulatedSourceAlpha <= 0.001f) {
        return;
    }

    if (brush.isEraser != 0u) {
        float outAlpha = destinationAlpha * (1.0f - accumulatedSourceAlpha);
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
        accumulatedSourceAlpha *= mix(
            1.0f,
            max(neighborhood.a, destinationAlpha),
            strokeClampUnit((1.0f - pigmentLoad) * 0.42f + mixStrength * 0.26f)
        );
        accumulatedSourceAlpha = strokeClampUnit(accumulatedSourceAlpha);
    }

    float outAlpha = destinationAlpha + (accumulatedSourceAlpha * (1.0f - destinationAlpha));
    if (outAlpha <= 0.001f) {
        return;
    }

    float outRed = ((sourceColor.r * accumulatedSourceAlpha) + (destinationRed * destinationAlpha * (1.0f - accumulatedSourceAlpha))) / outAlpha;
    float outGreen = ((sourceColor.g * accumulatedSourceAlpha) + (destinationGreen * destinationAlpha * (1.0f - accumulatedSourceAlpha))) / outAlpha;
    float outBlue = ((sourceColor.b * accumulatedSourceAlpha) + (destinationBlue * destinationAlpha * (1.0f - accumulatedSourceAlpha))) / outAlpha;

    outputPixels[offset] = uchar(clamp(int(round(outRed * 255.0f)), 0, 255));
    outputPixels[offset + 1u] = uchar(clamp(int(round(outGreen * 255.0f)), 0, 255));
    outputPixels[offset + 2u] = uchar(clamp(int(round(outBlue * 255.0f)), 0, 255));
    outputPixels[offset + 3u] = uchar(clamp(int(round(outAlpha * 255.0f)), 0, 255));
}

kernel void strokeColorSmudgeKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalColorSmudgeDabDescriptor& dab [[buffer(2)]],
    constant MetalStrokeBrushDescriptor& brush [[buffer(3)]],
    const device uchar *customTipPixels [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= dab.rectWidth || gid.y >= dab.rectHeight) {
        return;
    }

    uint x = dab.rectOriginX + gid.x;
    uint y = dab.rectOriginY + gid.y;
    if (x >= dab.canvasWidth || y >= dab.canvasHeight) {
        return;
    }

    uint offset = ((y * dab.canvasWidth) + x) * 4u;
    float2 pixelCenter = float2(float(x) + 0.5f, float(y) + 0.5f);
    float maskAlpha = rasterizedSourceAlpha(
        brush,
        customTipPixels,
        float2(dab.centerX, dab.centerY),
        dab.pressure,
        dab.progress,
        dab.radius,
        pixelCenter
    );
    if (maskAlpha <= 0.001f) {
        return;
    }

    float4 destination = smudgeSourcePixel(sourcePixels, dab, int(x), int(y));
    float4 representative = smudgeRepresentativeColor(
        sourcePixels,
        dab,
        brush,
        customTipPixels
    );

    float4 sourceColor;
    if (brush.smudgeMode == 0u) {
        float2 sourcePoint = float2(
            pixelCenter.x + (dab.previousCenterX - dab.centerX),
            pixelCenter.y + (dab.previousCenterY - dab.centerY)
        );
        float4 sampled = sampleSmearingColor(
            sourcePixels,
            dab,
            brush,
            customTipPixels,
            sourcePoint,
            representative
        );
        sourceColor = sampled.a > 0.001f ? sampled : representative;
    } else {
        sourceColor = representative;
    }

    float baseOpacity = strokeClampUnit(brush.opacity * brush.flow);
    float spacingInfluence = 0.2f;
    float pressureMixScale = max(
        0.12f,
        1.0f - brush.loadPressureSensitivity + (brush.loadPressureSensitivity * strokeClampUnit(dab.pressure))
    );
    float smudgeBlend = strokeClampUnit(brush.smudgeLength * pressureMixScale);
    float colorBlend = strokeClampUnit(brush.colorRate * pressureMixScale);
    float colorContribution = min(colorBlend * colorBlend * baseOpacity * (1.0f - (smudgeBlend * 0.55f)), 0.85f);
    float smudgeContribution = strokeClampUnit(smudgeBlend * (0.35f + (baseOpacity * 0.65f)) * (1.08f - min(spacingInfluence, 0.9f) * 0.35f));

    float4 smudged = sourceColor;
    smudged.a *= maskAlpha * smudgeContribution;
    smudged.rgb *= smudged.a;

    float pigmentAlpha = maskAlpha * colorContribution;
    float3 pigmentRGB = float3(brush.red, brush.green, brush.blue) * pigmentAlpha;

    float combinedAlpha;
    float3 combinedRGB;
    if (colorContribution > 0.001f) {
        combinedAlpha = pigmentAlpha + (smudged.a * (1.0f - pigmentAlpha));
        combinedRGB = pigmentRGB + (smudged.rgb * (1.0f - pigmentAlpha));
    } else {
        combinedAlpha = smudged.a;
        combinedRGB = smudged.rgb;
    }
    if (combinedAlpha <= 0.001f) {
        return;
    }

    float outAlpha = combinedAlpha + (destination.a * (1.0f - combinedAlpha));
    float3 outRGB = combinedRGB + (destination.rgb * destination.a * (1.0f - combinedAlpha));
    float3 resolved = outAlpha > 0.0001f ? outRGB / outAlpha : float3(0.0f);

    outputPixels[offset] = uchar(clamp(int(round(resolved.r * 255.0f)), 0, 255));
    outputPixels[offset + 1u] = uchar(clamp(int(round(resolved.g * 255.0f)), 0, 255));
    outputPixels[offset + 2u] = uchar(clamp(int(round(resolved.b * 255.0f)), 0, 255));
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

kernel void applyLayerMaskKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    const device uchar *maskPixels [[buffer(1)]],
    device uchar *outputPixels [[buffer(2)]],
    constant MetalLayerMaskApplyDescriptor& descriptor [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }

    uint pixelIndex = (gid.y * descriptor.width) + gid.x;
    uint rgbaOffset = pixelIndex * 4u;
    uint sourceAlpha = uint(sourcePixels[rgbaOffset + 3u]);
    uint maskAlpha = uint(maskPixels[pixelIndex]);
    uint outputAlpha = (sourceAlpha * maskAlpha) / 255u;

    outputPixels[rgbaOffset] = sourcePixels[rgbaOffset];
    outputPixels[rgbaOffset + 1u] = sourcePixels[rgbaOffset + 1u];
    outputPixels[rgbaOffset + 2u] = sourcePixels[rgbaOffset + 2u];
    outputPixels[rgbaOffset + 3u] = uchar(outputAlpha);
}

kernel void layerProcessingKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalLayerProcessingDescriptor& descriptor [[buffer(2)]],
    const device MetalGradientStopDescriptor *gradientStops [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }

    float4 source = sourcePixelRGBA(sourcePixels, descriptor.width, descriptor.height, gid);
    if (source.a <= 0.0001) {
        writePixelRGBA(outputPixels, descriptor.width, gid, source);
        return;
    }

    float3 color = source.rgb;
    switch (descriptor.requestKind) {
        case 0u: {
            float luminance = layerLuminance(color);
            color = float3(
                gradientChannel(gradientStops, descriptor.gradientStopCount, luminance, 0u),
                gradientChannel(gradientStops, descriptor.gradientStopCount, luminance, 1u),
                gradientChannel(gradientStops, descriptor.gradientStopCount, luminance, 2u)
            );
            break;
        }
        case 1u: {
            float3 hsv = rgbToHSV(color);
            hsv.x = fmod(hsv.x + descriptor.param0 + 1.0, 1.0);
            hsv.y = clamp(hsv.y * descriptor.param1, 0.0, 1.0);
            hsv.z = clamp(hsv.z + descriptor.param2, 0.0, 1.0);
            color = hsvToRGB(hsv);
            break;
        }
        case 2u:
            color = previewClamped((((color - 0.5) * descriptor.param1) + 0.5) + descriptor.param0);
            break;
        case 3u: {
            float inputBlack = descriptor.param0;
            float inputWhite = max(descriptor.param1, inputBlack + 0.001);
            float gamma = max(descriptor.param2, 0.01);
            float outputBlack = descriptor.param3;
            float outputWhite = max(descriptor.param4, outputBlack);
            float3 normalized = clamp((color - inputBlack) / max(inputWhite - inputBlack, 0.001), 0.0, 1.0);
            float3 gammaCorrected = pow(normalized, float3(1.0 / gamma));
            color = previewClamped(outputBlack + ((outputWhite - outputBlack) * gammaCorrected));
            break;
        }
        case 4u: {
            float shadows = descriptor.param0;
            float midtones = descriptor.param1;
            float highlights = descriptor.param2;
            float3 shadowWeight = pow(1.0 - color, 2.0);
            float3 highlightWeight = pow(color, 2.0);
            float3 midtoneWeight = max(float3(0.0), 1.0 - abs((color * 2.0) - 1.0));
            float3 offset = (shadows * shadowWeight) + (midtones * midtoneWeight) + (highlights * highlightWeight);
            color = previewClamped(color + (offset * 0.35));
            break;
        }
        case 5u:
            color = previewClamped(color + float3(descriptor.param0, descriptor.param1, descriptor.param2));
            break;
        case 6u: {
            float mapped = layerLuminance(color) >= descriptor.param0 ? 1.0 : 0.0;
            color = float3(mapped);
            break;
        }
        case 7u: {
            float levels = max(round(descriptor.param0), 2.0);
            float denominator = max(levels - 1.0, 1.0);
            color = round(color * denominator) / denominator;
            break;
        }
        default:
            break;
    }

    writePixelRGBA(outputPixels, descriptor.width, gid, float4(previewClamped(color), source.a));
}

kernel void layerTransformKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    const device uchar *selectionMask [[buffer(1)]],
    device uchar *outputPixels [[buffer(2)]],
    constant MetalLayerProcessingDescriptor& descriptor [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }

    float2 pivot = float2(descriptor.param3, descriptor.param4);
    float2 translation = float2(descriptor.param0, descriptor.param1);
    float scale = max(descriptor.param2, 0.001);
    float rotationRadians = descriptor.param5;

    float4 base = descriptor.hasSelection != 0u
        ? sourcePixelRGBA(sourcePixels, descriptor.width, descriptor.height, gid)
        : float4(0.0);
    if (descriptor.hasSelection != 0u && selectionMask[(gid.y * descriptor.selectionWidth) + gid.x] > 0u) {
        base = float4(0.0);
    }

    float2 position = float2(gid) - (pivot + translation);
    float inverseCos = cos(-rotationRadians);
    float inverseSin = sin(-rotationRadians);
    float2 rotated = float2(
        (position.x * inverseCos) - (position.y * inverseSin),
        (position.x * inverseSin) + (position.y * inverseCos)
    ) / scale;
    float2 sourcePoint = rotated + pivot;

    if (sourcePoint.x >= 0.0 && sourcePoint.y >= 0.0 &&
        sourcePoint.x < float(descriptor.width) && sourcePoint.y < float(descriptor.height)) {
        uint2 sample = uint2(uint(sourcePoint.x), uint(sourcePoint.y));
        if (descriptor.hasSelection == 0u || selectionMask[(sample.y * descriptor.selectionWidth) + sample.x] > 0u) {
            base = sourcePixelRGBA(sourcePixels, descriptor.width, descriptor.height, sample);
        }
    }

    writePixelRGBA(outputPixels, descriptor.width, gid, base);
}

kernel void fillEligibilityKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device uchar *eligiblePixels [[buffer(1)]],
    constant MetalFillDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }
    float4 source = sourcePixelRGBA(sourcePixels, descriptor.width, descriptor.height, gid);
    float matches = 0.0;
    if (descriptor.thresholdMode == 0u) {
        matches = fabs(source.a - descriptor.seedAlpha) <= descriptor.tolerance ? 1.0 : 0.0;
    } else {
        float distance = length(source.rgb - float3(descriptor.seedRed, descriptor.seedGreen, descriptor.seedBlue)) / 1.7320508;
        matches = distance <= descriptor.tolerance ? 1.0 : 0.0;
    }
    eligiblePixels[(gid.y * descriptor.width) + gid.x] = matches > 0.5 ? uchar(255) : uchar(0);
}

kernel void fillPropagationKernel(
    const device uchar *eligiblePixels [[buffer(0)]],
    const device uchar *filledPixels [[buffer(1)]],
    device uchar *nextFilledPixels [[buffer(2)]],
    device atomic_uint *didChange [[buffer(3)]],
    constant MetalFillDescriptor& descriptor [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }
    uint index = (gid.y * descriptor.width) + gid.x;
    uchar current = filledPixels[index];
    if (current > 0u) {
        nextFilledPixels[index] = current;
        return;
    }
    if (eligiblePixels[index] == 0u) {
        nextFilledPixels[index] = 0u;
        return;
    }

    bool propagate = false;
    if (gid.x > 0 && filledPixels[index - 1u] > 0u) propagate = true;
    if (!propagate && gid.x + 1u < descriptor.width && filledPixels[index + 1u] > 0u) propagate = true;
    if (!propagate && gid.y > 0 && filledPixels[index - descriptor.width] > 0u) propagate = true;
    if (!propagate && gid.y + 1u < descriptor.height && filledPixels[index + descriptor.width] > 0u) propagate = true;

    nextFilledPixels[index] = propagate ? uchar(255) : uchar(0);
    if (propagate) {
        atomic_store_explicit(didChange, 1u, memory_order_relaxed);
    }
}

kernel void fillExpansionKernel(
    const device uchar *filledPixels [[buffer(0)]],
    device uchar *expandedPixels [[buffer(1)]],
    constant MetalFillDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }
    uint index = (gid.y * descriptor.width) + gid.x;
    if (filledPixels[index] > 0u) {
        expandedPixels[index] = uchar(255);
        return;
    }
    bool hasNeighbor = false;
    if (gid.x > 0 && filledPixels[index - 1u] > 0u) hasNeighbor = true;
    if (!hasNeighbor && gid.x + 1u < descriptor.width && filledPixels[index + 1u] > 0u) hasNeighbor = true;
    if (!hasNeighbor && gid.y > 0 && filledPixels[index - descriptor.width] > 0u) hasNeighbor = true;
    if (!hasNeighbor && gid.y + 1u < descriptor.height && filledPixels[index + descriptor.width] > 0u) hasNeighbor = true;
    expandedPixels[index] = hasNeighbor ? uchar(255) : uchar(0);
}

kernel void fillComposeKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    const device uchar *filledPixels [[buffer(1)]],
    device uchar *outputPixels [[buffer(2)]],
    constant MetalFillDescriptor& descriptor [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }
    uint index = (gid.y * descriptor.width) + gid.x;
    if (filledPixels[index] > 0u) {
        writePixelRGBA(
            outputPixels,
            descriptor.width,
            gid,
            float4(descriptor.targetRed, descriptor.targetGreen, descriptor.targetBlue, descriptor.targetAlpha)
        );
        return;
    }
    writePixelRGBA(outputPixels, descriptor.width, gid, sourcePixelRGBA(sourcePixels, descriptor.width, descriptor.height, gid));
}

kernel void blurHorizontalKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device float4 *temporaryPixels [[buffer(1)]],
    constant MetalBlurDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }
    float4 sum = float4(0.0);
    float total = 0.0;
    for (int dx = -int(descriptor.radius); dx <= int(descriptor.radius); ++dx) {
        int sampleX = clamp(int(gid.x) + dx, 0, int(descriptor.width) - 1);
        sum += sourcePixelRGBA(sourcePixels, descriptor.width, descriptor.height, uint2(uint(sampleX), gid.y));
        total += 1.0;
    }
    temporaryPixels[(gid.y * descriptor.width) + gid.x] = sum / max(total, 1.0);
}

kernel void blurVerticalKernel(
    const device float4 *temporaryPixels [[buffer(0)]],
    device uchar *blurredPixels [[buffer(1)]],
    constant MetalBlurDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }
    float4 sum = float4(0.0);
    float total = 0.0;
    for (int dy = -int(descriptor.radius); dy <= int(descriptor.radius); ++dy) {
        int sampleY = clamp(int(gid.y) + dy, 0, int(descriptor.height) - 1);
        sum += temporaryPixels[(uint(sampleY) * descriptor.width) + gid.x];
        total += 1.0;
    }
    writePixelRGBA(blurredPixels, descriptor.width, gid, sum / max(total, 1.0));
}

kernel void blurBlendKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    const device uchar *blurredPixels [[buffer(1)]],
    const device MetalStrokeSampleDescriptor *samples [[buffer(2)]],
    device uchar *outputPixels [[buffer(3)]],
    constant MetalBlurDescriptor& descriptor [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }
    float2 pixelCenter = float2(gid) + 0.5;
    float softness = max(0.12, 1.0 - descriptor.hardness);
    float influence = 0.0;
    for (uint sampleIndex = 0u; sampleIndex < descriptor.sampleCount; ++sampleIndex) {
        float2 samplePoint = float2(samples[sampleIndex].x, samples[sampleIndex].y);
        float sampleRadius = descriptor.influenceRadius * max(0.35, float(samples[sampleIndex].pressure));
        float distance = length(pixelCenter - samplePoint);
        if (distance > sampleRadius) {
            continue;
        }
        float normalized = max(0.0, 1.0 - (distance / max(sampleRadius, 0.001)));
        float feathered = pow(normalized, max(0.75, 2.4 - (softness * 1.6)));
        influence = max(influence, feathered * descriptor.flow);
    }
    float4 source = sourcePixelRGBA(sourcePixels, descriptor.width, descriptor.height, gid);
    float4 blurred = sourcePixelRGBA(blurredPixels, descriptor.width, descriptor.height, gid);
    writePixelRGBA(outputPixels, descriptor.width, gid, mix(source, blurred, clamp(influence, 0.0, 1.0)));
}

kernel void textMaskComposeKernel(
    const device uchar *maskPixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalTextComposeDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.width || gid.y >= descriptor.height) {
        return;
    }
    uint index = (gid.y * descriptor.width) + gid.x;
    float alpha = (float(maskPixels[index]) / 255.0) * descriptor.alpha;
    writePixelRGBA(
        outputPixels,
        descriptor.width,
        gid,
        float4(descriptor.red, descriptor.green, descriptor.blue, alpha)
    );
}

kernel void scaleRGBAKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalScaleDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.targetWidth || gid.y >= descriptor.targetHeight) {
        return;
    }
    float sourceX = ((float(gid.x) + 0.5) / max(float(descriptor.targetWidth), 1.0)) * float(descriptor.sourceWidth) - 0.5;
    float sourceY = ((float(gid.y) + 0.5) / max(float(descriptor.targetHeight), 1.0)) * float(descriptor.sourceHeight) - 0.5;
    int x0 = clamp(int(floor(sourceX)), 0, int(descriptor.sourceWidth) - 1);
    int y0 = clamp(int(floor(sourceY)), 0, int(descriptor.sourceHeight) - 1);
    int x1 = clamp(x0 + 1, 0, int(descriptor.sourceWidth) - 1);
    int y1 = clamp(y0 + 1, 0, int(descriptor.sourceHeight) - 1);
    float tx = clamp(sourceX - float(x0), 0.0, 1.0);
    float ty = clamp(sourceY - float(y0), 0.0, 1.0);
    float4 c00 = sourcePixelRGBA(sourcePixels, descriptor.sourceWidth, descriptor.sourceHeight, uint2(uint(x0), uint(y0)));
    float4 c10 = sourcePixelRGBA(sourcePixels, descriptor.sourceWidth, descriptor.sourceHeight, uint2(uint(x1), uint(y0)));
    float4 c01 = sourcePixelRGBA(sourcePixels, descriptor.sourceWidth, descriptor.sourceHeight, uint2(uint(x0), uint(y1)));
    float4 c11 = sourcePixelRGBA(sourcePixels, descriptor.sourceWidth, descriptor.sourceHeight, uint2(uint(x1), uint(y1)));
    float4 top = mix(c00, c10, tx);
    float4 bottom = mix(c01, c11, tx);
    writePixelRGBA(outputPixels, descriptor.targetWidth, gid, mix(top, bottom, ty));
}

kernel void scaleMaskKernel(
    const device uchar *sourceMask [[buffer(0)]],
    device uchar *outputMask [[buffer(1)]],
    constant MetalScaleDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.targetWidth || gid.y >= descriptor.targetHeight) {
        return;
    }
    float sourceX = ((float(gid.x) + 0.5) / max(float(descriptor.targetWidth), 1.0)) * float(descriptor.sourceWidth) - 0.5;
    float sourceY = ((float(gid.y) + 0.5) / max(float(descriptor.targetHeight), 1.0)) * float(descriptor.sourceHeight) - 0.5;
    int x0 = clamp(int(floor(sourceX)), 0, int(descriptor.sourceWidth) - 1);
    int y0 = clamp(int(floor(sourceY)), 0, int(descriptor.sourceHeight) - 1);
    int x1 = clamp(x0 + 1, 0, int(descriptor.sourceWidth) - 1);
    int y1 = clamp(y0 + 1, 0, int(descriptor.sourceHeight) - 1);
    float tx = clamp(sourceX - float(x0), 0.0, 1.0);
    float ty = clamp(sourceY - float(y0), 0.0, 1.0);
    float c00 = float(sourceMask[(uint(y0) * descriptor.sourceWidth) + uint(x0)]);
    float c10 = float(sourceMask[(uint(y0) * descriptor.sourceWidth) + uint(x1)]);
    float c01 = float(sourceMask[(uint(y1) * descriptor.sourceWidth) + uint(x0)]);
    float c11 = float(sourceMask[(uint(y1) * descriptor.sourceWidth) + uint(x1)]);
    float top = mix(c00, c10, tx);
    float bottom = mix(c01, c11, tx);
    outputMask[(gid.y * descriptor.targetWidth) + gid.x] = uchar(clamp(round(mix(top, bottom, ty)), 0.0, 255.0));
}

kernel void translateRGBAKernel(
    const device uchar *sourcePixels [[buffer(0)]],
    device uchar *outputPixels [[buffer(1)]],
    constant MetalTranslateDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.targetWidth || gid.y >= descriptor.targetHeight) {
        return;
    }
    int sourceX = int(gid.x) - descriptor.offsetX;
    int sourceY = int(gid.y) - descriptor.offsetY;
    if (sourceX < 0 || sourceY < 0 || sourceX >= int(descriptor.sourceWidth) || sourceY >= int(descriptor.sourceHeight)) {
        writePixelRGBA(outputPixels, descriptor.targetWidth, gid, float4(0.0));
        return;
    }
    writePixelRGBA(
        outputPixels,
        descriptor.targetWidth,
        gid,
        sourcePixelRGBA(sourcePixels, descriptor.sourceWidth, descriptor.sourceHeight, uint2(uint(sourceX), uint(sourceY)))
    );
}

kernel void translateMaskKernel(
    const device uchar *sourceMask [[buffer(0)]],
    device uchar *outputMask [[buffer(1)]],
    constant MetalTranslateDescriptor& descriptor [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= descriptor.targetWidth || gid.y >= descriptor.targetHeight) {
        return;
    }
    int sourceX = int(gid.x) - descriptor.offsetX;
    int sourceY = int(gid.y) - descriptor.offsetY;
    uchar value = 0;
    if (sourceX >= 0 && sourceY >= 0 && sourceX < int(descriptor.sourceWidth) && sourceY < int(descriptor.sourceHeight)) {
        value = sourceMask[(uint(sourceY) * descriptor.sourceWidth) + uint(sourceX)];
    }
    outputMask[(gid.y * descriptor.targetWidth) + gid.x] = value;
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
