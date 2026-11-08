import CoreGraphics

/// Linear interpolation from `a` to `b`. `t` is assumed already clamped to `0...1`.
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
  a + (b - a) * t
}

/// Smooth 0→1 ramp across `range`, flat outside it.
///
/// Used instead of a raw linear ramp so the fades ease in and out rather than
/// starting and stopping abruptly.
func smoothstep(_ range: ClosedRange<CGFloat>, _ x: CGFloat) -> CGFloat {
  let span = range.upperBound - range.lowerBound
  guard span > 0 else { return x < range.lowerBound ? 0 : 1 }

  let t = min(max((x - range.lowerBound) / span, 0), 1)
  return t * t * (3 - 2 * t)
}
