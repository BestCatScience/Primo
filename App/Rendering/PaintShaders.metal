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
