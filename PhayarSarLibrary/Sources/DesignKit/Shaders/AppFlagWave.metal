#include <TargetConditionals.h>

// DesignKit is also linked by WristKit, but watchOS has no SwiftUI::Layer.
// Match the Swift view's static watch fallback at shader compile time too.
#if TARGET_OS_IOS || TARGET_OS_OSX
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Inverse-sample the emoji rather than moving the whole icon. The envelope
/// fixes the left edge and lets the free edge flutter. A smaller harmonic
/// breaks up the main sine wave, while lighting follows the folds so the
/// result reads as cloth rather than a bouncing sticker. Multiplying RGB
/// preserves the sampled layer's premultiplied alpha at the glyph edges.
/// A persistent downward slope keeps the free edge draped even as the ripple
/// passes through zero; a sine wave alone alternates between leaning up and down.
/// The horizontal curl must also vary down the cloth's height. Displacing only
/// by horizontal position moves each column rigidly and leaves the fly edge
/// straight, regardless of how much the top and bottom edges wave.
[[ stitchable ]] half4 appFlagWave(
  float2 position,
  SwiftUI::Layer layer,
  float4 bounds,
  float progress,
  float padding,
  float horizontalDisplacement,
  float edgeCurvature,
  float verticalDisplacement,
  float downwardDrape,
  float waveCount,
  float foldShading
) {
  float2 origin = bounds.xy + padding;
  float2 size = max(bounds.zw - 2.0f * padding, float2(1.0f));
  float u = clamp((position.x - origin.x) / size.x, 0.0f, 1.0f);
  float envelope = u * u;
  float phase = 2.0f * M_PI_F * (waveCount * u - progress);
  float ripple = 0.8f * sin(phase) + 0.2f * sin(2.0f * phase + 0.6f);
  float2 displacement = envelope * float2(
    horizontalDisplacement * sin(phase + 0.8f),
    verticalDisplacement * ripple
  );
  displacement.y += downwardDrape * u;

  // Measure height after undoing the vertical wave, so the curl follows the
  // fabric rather than sliding over it as the free edge rises and falls.
  float v = clamp((position.y - displacement.y - origin.y) / size.y, 0.0f, 1.0f);
  float curlProfile = 0.8f * sin(M_PI_F * v) + 0.2f * sin(2.0f * M_PI_F * v + phase);
  float curlStrength = edgeCurvature * (0.85f + 0.15f * cos(phase));
  displacement.x -= envelope * u * curlStrength * curlProfile;

  half4 color = layer.sample(position - displacement);
  float lighting = 1.0f + foldShading * envelope * cos(phase);
  color.rgb = min(color.rgb * half(lighting), half3(color.a));
  return color;
}
#endif
