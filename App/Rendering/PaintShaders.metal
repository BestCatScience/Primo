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
    float paperSeed;
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

float noise(float2 st) {
    return fract(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453123);
}

fragment float4 paperFragment(VertexOut in [[stage_in]],
                              constant MetalQuadUniforms& uniforms [[buffer(0)]]) {
    float coarse = noise((in.paperUV * 180.0) + uniforms.paperSeed);
    float fine = noise((in.paperUV * 600.0) + 1.7);
    float warm = 0.93 + (coarse * 0.05) + (fine * 0.015);
    return float4(warm, warm * 0.992, warm * 0.972, 1.0);
}

fragment float4 layerFragment(VertexOut in [[stage_in]],
                              texture2d<float> layerTexture [[texture(0)]],
                              constant MetalQuadUniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);
    float4 color = layerTexture.sample(textureSampler, in.uv);
    color.a *= uniforms.opacity;
    color.rgb *= uniforms.opacity;
    return color;
}
