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
