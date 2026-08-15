import CoreGraphics

/// Tuning for the scroll-driven nav bar collapse.
///
/// Shared between `HomeScreen` (which owns the large title and computes
/// `progress`) and `HomeNavView` (which owns the bar), so every constant that
/// shapes the collapse lives in one place.
enum HomeNavMetrics {
  /// Scroll distance, in points, over which the collapse completes. Roughly one
  /// line of `AppFont.largeTitle`, so the bar is fully collapsed by the time the
  /// large title has travelled its own height.
  static let collapseDistance: CGFloat = 44

  /// Fixed height of the bar. Deliberately constant: animating the height of a
  /// `safeAreaInset` changes the scroll view's content inset, which changes the
  /// offset, which changes the height — a feedback loop that shows up as jitter.
  static let barHeight: CGFloat = 52

  /// Large title shrinks to exactly this fraction. `AppFont.largeTitle` is 34pt
  /// and `AppFont.listItemTitle` — the inline size — is 17pt, so 0.5 lands the
  /// two at matching sizes for the hand-off.
  static let titleScaleFloor: CGFloat = 0.5

  /// The 38pt buttons scale to ~28pt across the collapse.
  static let buttonScaleFloor: CGFloat = 0.74

  /// Divides the overscroll distance before it is added to the title scale.
  /// Larger is subtler.
  static let overscrollGain: CGFloat = 400

  /// Ceiling on the overscroll bounce, so a hard pull can't balloon the title.
  static let maxOverscrollScale: CGFloat = 0.10

  /// The blur reaches full strength this far into the collapse — early, so
  /// contrast arrives before content reaches the title.
  static let blurRampEnd: CGFloat = 0.35

  /// How far past its pinned resting position the picker starts joining onto
  /// the bar, so the two backgrounds merge over a few points rather than
  /// snapping together.
  static let dockDistance: CGFloat = 20

  /// How far the docked picker's background reaches up behind the nav bar.
  /// Only needs to exceed the pinned resting gap; the excess is covered by the
  /// bar itself.
  static let dockOverlap: CGFloat = 40

  /// Where the docked picker's background starts fading. High, because
  /// `dockOverlap` inflates that pane's height — the fade has to be pushed past
  /// the control itself rather than running through it.
  static let dockedSolidStop: CGFloat = 0.85

  /// Height of the soft gradient hanging below the nav bar, which carries the
  /// blur out into the content instead of ending it on a hard line. Only
  /// visible while the picker has not docked.
  static let barFadeTail: CGFloat = 28

  /// Space above the segment picker while it scrolls with the content.
  static let segmentTopPadding: CGFloat = 8

  /// Space above the picker once docked. Negative: a pinned header settles a
  /// little below the safe-area inset, and pulling back through that is what
  /// closes the gap so the picker sits tight under the bar.
  ///
  /// Safe to drive from `docked` because `docked` is computed from the scroll
  /// offset, not from the picker's measured position — so moving the picker
  /// cannot feed back into the value that moved it. The one place the position
  /// *is* measured, `calibratePinDistance()`, runs only at rest where this is 0.
  static let segmentDockedTopPadding: CGFloat = -4

  /// Clearance above the large title. Small on purpose — the title reads as
  /// part of the bar, not as the first row of the list.
  static let largeTitleTopPadding: CGFloat = 0

  /// Progress window over which the large title fades out.
  static let largeTitleFade: ClosedRange<CGFloat> = 0.55...1.0

  /// Progress window over which the inline title fades in. Overlaps the large
  /// title's window so there is never a moment with no title on screen.
  static let inlineTitleFade: ClosedRange<CGFloat> = 0.6...1.0
}

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
