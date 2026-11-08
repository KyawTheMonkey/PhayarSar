#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Arithmetic hashing is fixed to a particle's destination. Neither its seed,
// glyph coverage nor brightness changes with the animation clock.
static float2 particleSeed(float2 cell) {
  float3 p = fract(float3(cell.x, cell.y, cell.x) * float3(0.1031, 0.1030, 0.0973));
  p += dot(p, p.yzx + 33.33);
  return fract((p.xx + p.yz) * p.zy);
}

static float2 unitPosition(float2 p, float4 bounds) {
  return saturate((p - bounds.xy) / max(bounds.zw, float2(1.0)));
}

// Zero velocity and acceleration at both ends keep a settling particle from
// acquiring a visible kink as it joins the final glyph.
static float fluidEase(float t) {
  t = saturate(t);
  return t * t * t * (t * (6.0 * t - 15.0) + 10.0);
}

static float gatheringProgress(float2 p, float progress, float4 bounds) {
  float2 uv = unitPosition(p, bounds);
  // An elliptical wave starts at the text's top-left corner and travels
  // predominantly rightward. The curved front avoids revealing a rectangular
  // block of particles across the whole passage at once.
  float order = length(float2(uv.x, uv.y * 0.45)) / length(float2(1.0, 0.45));
  float delay = 0.58 * order;
  return saturate((progress - delay) / (1.0 - delay));
}

// One continuous field carries neighbouring particles together. The old
// independently translated tiles cut through letters at their boundaries.
// This gently curved path has no tiles, brightness pulses or changing noise.
static float2 gatheringFlow(float2 p, float progress, float4 bounds, float scatter) {
  float2 uv = unitPosition(p, bounds);
  float t = fluidEase(gatheringProgress(p, progress, bounds));
  float remaining = (1.0 - t) * (1.0 - t);
  float2 direction = float2(-1.0 + 0.12 * uv.y, -0.3 * (1.0 - uv.x));
  float2 arc = float2(0.12, -0.1) * (4.0 * t * (1.0 - t));
  return (direction + arc) * scatter * remaining;
}

static half3 revealColor(float2 p, float4 bounds, half3 rose, half3 violet, half3 blue) {
  float2 uv = unitPosition(p, bounds);
  half phase = half(0.65 * uv.x + 0.35 * uv.y);
  return phase < 0.5h
    ? mix(rose, violet, phase * 2.0h)
    : mix(violet, blue, (phase - 0.5h) * 2.0h);
}

[[ stitchable ]] half4 appParticleAssemble(
  float2 position,
  SwiftUI::Layer layer,
  float progress,
  float4 paddedBounds,
  float scatter,
  float particlePitch,
  float particleRadius,
  float feather,
  float haloStrength,
  half4 rose,
  half4 violet,
  half4 blue
) {
  half4 ink = layer.sample(position);
  if (progress >= 0.999) { return ink; }
  if (progress <= 0.001) { return half4(0); }

  // Anchor the wave to the text, not the transparent sampling margin. Include
  // the particle footprint in that margin so the leading dust is not cut off
  // by the layer's rectangular edge.
  float inset = scatter + particlePitch;
  float4 bounds = float4(paddedBounds.xy + inset, max(paddedBounds.zw - 2.0 * inset, float2(1.0)));

  // Invert the smooth field to find nearby destinations. Each destination is
  // sampled at a fixed glyph coordinate; only its drawing position moves.
  // Nine candidate cells suffice, with texture reads skipped outside a small,
  // feathered footprint. Per-pixel search stays bounded for long passages.
  float2 guess = position - gatheringFlow(position, progress, bounds, scatter);
  guess = position - gatheringFlow(guess, progress, bounds, scatter);
  guess = position - gatheringFlow(guess, progress, bounds, scatter);
  float2 cell = floor(guess / particlePitch);
  half4 dust = half4(0);

  for (int y = -1; y <= 1; ++y) {
    for (int x = -1; x <= 1; ++x) {
      // Stagger rows before jittering them, so the particle field has no
      // visible square lattice even while the wave pauses over a short word.
      float row = cell.y + float(y);
      float stagger = fract(row * 0.5);
      float column = floor(guess.x / particlePitch - stagger) + float(x);
      float2 destination = float2(column, row);
      float2 seed = particleSeed(destination);
      // Stable jitter breaks up the visible dot-matrix pattern without adding
      // temporal noise or changing a particle's destination between frames.
      float2 anchor = (destination + float2(0.5 + stagger, 0.5) + (seed - 0.5) * 0.6) * particlePitch;
      float t = gatheringProgress(anchor, progress, bounds);
      float fade = 1.0 - smoothstep(0.18, 0.72, t);
      if (t <= 0.0 || fade <= 0.0) { continue; }
      float birth = smoothstep(0.0, 0.12, t);

      float2 center = anchor + gatheringFlow(anchor, progress, bounds, scatter);
      float distanceToCenter = distance(position, center);
      float radius = particleRadius * mix(0.9, 1.1, seed.x);
      float support = radius * 2.6;
      if (distanceToCenter >= support) { continue; }

      // Two fixed samples keep thin Burmese strokes represented without
      // re-sampling a moving grid, which made the earlier effect glitter.
      half coverage = max(layer.sample(anchor).a,
        layer.sample(anchor + float2(particlePitch * 0.16, 0.0)).a);
      float core = 1.0 - smoothstep(radius - feather, radius + feather, distanceToCenter);
      float halo = pow(max(0.0, 1.0 - distanceToCenter / support), 3.0) * haloStrength;
      half alpha = coverage * half(min(core + halo, 1.0) * birth * fade * mix(0.75, 1.0, seed.y));
      half3 tint = revealColor(anchor, bounds, rose.rgb, violet.rgb, blue.rgb);
      half4 particle = half4(tint * alpha, alpha);
      dust = particle + dust * (1.0h - particle.a);
    }
  }

  // Whole glyph outlines emerge continuously behind the dust. The temporary
  // colour bloom then settles into the original theme-aware ink, preserving
  // the exact rasterized Burmese text at rest.
  float localProgress = gatheringProgress(position, progress, bounds);
  half glyphOpacity = half(smoothstep(0.16, 0.74, localProgress));
  half tintStrength = half(1.0 - smoothstep(0.55, 0.98, localProgress));
  half3 tint = revealColor(position, bounds, rose.rgb, violet.rgb, blue.rgb);
  half3 glyphRGB = mix(ink.rgb, tint * ink.a, tintStrength);
  half4 glyph = half4(glyphRGB * glyphOpacity, ink.a * glyphOpacity);
  return glyph + dust * (1.0h - glyph.a);
}
