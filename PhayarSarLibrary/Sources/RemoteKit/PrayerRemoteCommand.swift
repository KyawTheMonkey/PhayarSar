import Foundation

/// What the watch can ask the phone to do.
///
/// Every case is *semantic* rather than positional — "the next verse", not
/// "scroll to y=1840". No public API lets one device drive another's touch
/// input, so the watch never sends gestures; it sends intentions, and the phone
/// decides what they mean against the page it is actually showing. That is also
/// what keeps the two in step when the reader has moved the phone by hand in
/// between.
///
/// `Codable` because it crosses to the other device as JSON inside a
/// `WCSession` message — see ``RemoteLink``.
public enum PrayerRemoteCommand: Codable, Hashable, Sendable {
  /// Move the page by a fraction of its own height: `1` is a screenful down,
  /// `-0.25` a quarter screen up.
  ///
  /// A fraction rather than a distance in points because the two devices
  /// disagree about how big a page is and the watch has no way to find out —
  /// the phone may be an SE or a Pro Max, at any type size.
  case scroll(fraction: Double)

  /// Bring the next (`+1`) or previous (`-1`) verse to the middle of the page.
  ///
  /// Larger steps are legal, and are what the Digital Crown sends when it is
  /// turned fast enough to cross several detents inside one throttle window.
  case stepVerse(Int)

  /// Turn to the next (`+1`) or previous (`-1`) prayer in catalog order.
  case stepPrayer(Int)

  /// Open a particular prayer, whether or not the reader is already up.
  case openPrayer(id: String)

  /// Leave the reader, back to wherever it was opened from.
  case closeReader

  /// Set the recited text's point size, in the same units as
  /// `PrayerSettings.textSize`.
  case setTextSize(Int)

  /// "Tell me where you are." Sent when the watch app opens and each time the
  /// link comes back, so a watch that missed the last few updates catches up
  /// rather than showing a stale page.
  case requestState
}
