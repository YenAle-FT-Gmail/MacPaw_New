#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// Full-screen quad vertex shader
vertex VertexOut coreOrbVertex(uint vertexID [[vertex_id]]) {
    float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1), float2(1, -1), float2(1, 1)
    };
    
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = (positions[vertexID] + 1.0) * 0.5;
    return out;
}

// Orb fragment shader — glowing sphere with state-driven color
fragment float4 coreOrbFragment(VertexOut in [[stage_in]],
                                 constant float &time [[buffer(0)]],
                                 constant float3 &baseColor [[buffer(1)]],
                                 constant float &pulseRate [[buffer(2)]]) {
    float2 uv = in.uv * 2.0 - 1.0;
    float dist = length(uv);
    
    // Sphere SDF
    float sphere = 1.0 - smoothstep(0.35, 0.42, dist);
    
    // Animated glow pulse
    float pulse = sin(time * pulseRate) * 0.5 + 0.5;
    float irregularPulse = sin(time * pulseRate * 1.3 + 0.7) * 0.3 + 0.7;
    float combinedPulse = mix(pulse, irregularPulse, 0.4);
    
    // Inner glow (brighter at center)
    float innerGlow = exp(-dist * 3.5) * (0.7 + 0.3 * combinedPulse);
    
    // Outer glow (ambient halo)
    float outerGlow = exp(-dist * 1.8) * 0.35 * (0.8 + 0.2 * pulse);
    
    // Surface detail — fresnel-like rim lighting
    float rim = smoothstep(0.15, 0.4, dist) * sphere;
    
    // Noise-like surface variation  
    float surfaceDetail = sin(uv.x * 12.0 + time * 0.5) * sin(uv.y * 12.0 - time * 0.3) * 0.05;
    
    // Composite color
    float3 core = baseColor * (innerGlow + surfaceDetail) * sphere;
    float3 rimColor = baseColor * 1.3 * rim * 0.5;
    float3 halo = baseColor * outerGlow;
    
    float3 finalColor = core + rimColor + halo;
    float alpha = max(sphere, outerGlow * 0.6);
    
    return float4(finalColor, alpha);
}
