#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// Subtle biome-wide luminance pulse used to avoid flat static color output.
[[ stitchable ]] half4 terrariumColorPulse(
    float2 position,
    half4 color,
    float time,
    float intensity
) {
    float wave = sin((position.x + position.y) * 0.008 + time * 1.2) * 0.5 + 0.5;
    float gain = 1.0 + wave * intensity;

    return half4(
        half(color.r * gain),
        half(color.g * (gain * 0.98 + 0.02)),
        half(color.b * (gain * 1.02)),
        color.a
    );
}

// Refraction-like layer distortion with optional RGB channel split.
[[ stitchable ]] half4 terrariumDistortion(
    float2 position,
    SwiftUI::Layer layer,
    float time,
    float refractionStrength,
    float chromaticOffset
) {
    float2 wave;
    wave.x = sin(position.y * 0.014 + time * 1.8);
    wave.y = cos(position.x * 0.012 - time * 1.5);

    float2 baseOffset = wave * (refractionStrength * 0.35);
    float2 offsetR = baseOffset + float2(chromaticOffset, 0.0);
    float2 offsetB = baseOffset - float2(chromaticOffset, 0.0);

    half4 center = layer.sample(position + baseOffset);

    if (chromaticOffset <= 0.001) {
        return center;
    }

    half4 sampleR = layer.sample(position + offsetR);
    half4 sampleB = layer.sample(position + offsetB);

    return half4(sampleR.r, center.g, sampleB.b, center.a);
}
