import Foundation

/// How fast a prayer reads itself, as a multiple of its ordinary pace.
///
/// A multiplier rather than a set of intervals, so there is exactly one number
/// in the app that says how long a line is held for and this says how much of it
/// to take. The interval itself belongs to the reader — see
/// `PrayerReaderMetrics.playbackInterval` — which is why only the multiple is
/// here: this module knows what the reader was asked for, not how long it takes
/// to do it.
///
/// Five, and no dial. A reader wants the pace of the recitation they know, and
/// picking it off a short list is one tap where a slider is an adjustment to
/// make and then to keep making.
///
/// Stored per prayer as part of ``PrayerConfiguration``, which is why the raw
/// values matter: they are what is written to the synced store, and changing one
/// would change what an existing row means.
public enum PrayerPlaybackSpeed: Double, CaseIterable, Hashable, Sendable {
  /// For a line being learned rather than recited — four times as long on each,
  /// which is long enough to look at every syllable.
  case quarter = 0.25
  case half = 0.5
  /// The pace everything else is measured against.
  case normal = 1
  case fast = 1.5
  case double = 2

  /// Deliberately digits and a sign rather than words, in both languages. This
  /// is the one label in the reader that says a quantity, and `2×` is `2×` to
  /// anybody who has ever used a player.
  public var label: String {
    switch self {
    case .quarter:
      return "0.25×"
    case .half:
      return "0.5×"
    case .normal:
      return "1×"
    case .fast:
      return "1.5×"
    case .double:
      return "2×"
    }
  }
}
