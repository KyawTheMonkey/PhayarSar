#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

/// The pill being drawn into the Dynamic Island, and let back out of it.
///
/// A `distortionEffect` shader, which means it runs backwards from the way the
/// animation is described: for every pixel of the *output* it is asked which
/// pixel of the input belongs there. So to make content appear to move up, this
/// samples further down; to make it appear to narrow, it samples further out.
/// Everything below reads inverted for that reason.
///
/// Sampling outside the view returns nothing, which is the whole reason the
/// squeeze works — the further out it reaches, the less of the pill there is
/// left to find.
///
/// Adapted from Alex Widua's genie shader (MIT), which sucks a window *down*
/// into a Dock at the foot of the screen. Ours goes the other way, into a cutout
/// at the top, so the slot is at `y = 0` and the pill hangs below it — which
/// inverts both the taper and the direction of the slide.
///
/// - Parameters:
///   - position: The output pixel, in the view's own space.
///   - bounds: The view's rectangle. The slot is the middle of its top edge and
///     the pill sits along its bottom.
///   - centreX: Where the neck pinches to, normalised across the width.
///   - squeeze: How much narrower the pill is drawn nearest the slot. 0 leaves
///     it alone.
///   - stretch: How much the body lengthens on its way in, which is what stops
///     the pill from simply sliding away. 1 leaves it alone.
///   - slide: How far the pill is drawn up towards the slot, as a fraction of
///     the view's height. Past 1 it has gone entirely.
[[ stitchable ]] float2 prayerGenie(
  float2 position,
  float4 bounds,
  float centreX,
  float squeeze,
  float stretch,
  float slide
) {
  float2 size = bounds.zw;
  float2 uv = (position - bounds.xy) / size;

  // 1 at the slot, 0 at the pill's resting place, eased between. This is what
  // makes a neck rather than a uniform narrowing: the closer to the cutout, the
  // harder the pinch.
  float taper = smoothstep(0.0, 1.0, 1.0 - uv.y);

  // Lengthen the body away from the bottom edge, so the pill is drawn *out* on
  // its way in rather than just travelling.
  float y = 1.0 + (uv.y - 1.0) / max(stretch, 0.0001);

  // And pull it towards the slot. Sampling further down is what moves it up.
  y += slide;

  // The pinch. A factor above one reaches outside the pill, and what is outside
  // the pill is nothing at all — so the pill narrows.
  float pinch = 1.0 + squeeze * taper;
  float x = centreX + (uv.x - centreX) * pinch;

  return bounds.xy + float2(x, y) * size;
}
