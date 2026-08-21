// `os(iOS)` rather than `canImport(ActivityKit)`, which was the first guess and
// was wrong: the module imports perfectly well on macOS and every type in it is
// then marked unavailable there, so the check passes and the build fails a line
// later. The question being asked is which platform this is, so that is what to
// ask.
#if os(iOS)
import ActivityKit
#endif
import Foundation

/// What the Lock Screen and the Dynamic Island are told about a reading in
/// progress, and what they are allowed to change about it.
///
/// Its own module, and a module with no dependencies, for one reason: this type
/// has to be compiled into two binaries that share almost nothing else. The app
/// posts the activity, the widget extension draws it, and the extension has no
/// business linking the prayer catalog, the CloudKit stack or the navigation
/// model in order to put a title and a verse count on a card.
///
/// Which is also why the title travels *in* the attributes rather than being
/// looked up from `PrayerCatalog` on the other side, and why the paces are a
/// list of plain numbers rather than `PrayerPlaybackSpeed`. The card is a
/// message, not a query.
///
/// ## When it is seen
///
/// Never while the app is the app on screen — iOS hides an app's own Live
/// Activity for as long as that app is frontmost. So this is the reading as it
/// looks from *outside*: from the Lock Screen, from another app, from the home
/// screen. Inside the app the same controls are drawn by `PrayerIslandBar`,
/// which hangs from the cutout in the app's own window. The two are deliberately
/// alike and can never be seen at the same time.
///
/// ## What its controls mean
///
/// The reading is a page scrolling itself — see `PrayerViewController` — and a
/// page can only scroll while there is a screen showing it. So a pace chosen
/// here takes effect in full and at once, because pace is stored; and play or
/// pause here settles what the page does the moment the reader is back in front
/// of it, which is the only moment it could have done anything anyway.
#if os(iOS)
public struct PrayerReadingAttributes: ActivityAttributes {

  /// The part that changes while the card is up.
  public struct ContentState: Codable, Hashable, Sendable {
    /// 1-based, as it is shown.
    public var verse: Int

    /// How many the prayer has.
    public var verses: Int

    /// Whether the page is set to be reading.
    ///
    /// The reader's intention rather than a report of pixels moving: away from
    /// the app nothing moves, and this is what the page will be doing when they
    /// come back to it.
    public var isPlaying: Bool

    /// The chosen pace, as its multiple of the ordinary one.
    ///
    /// A number rather than `PrayerPlaybackSpeed`, so that this module — and the
    /// widget extension that links it — stays free of `PrayersKit`. The enum
    /// remains the only place the set of paces is decided; this is the value it
    /// was carrying.
    public var speed: Double

    public init(verse: Int, verses: Int, isPlaying: Bool, speed: Double) {
      self.verse = verse
      self.verses = verses
      self.isPlaying = isPlaying
      self.speed = speed
    }
  }

  /// Which prayer, so an intent arriving from the card can say what it is about.
  public let prayerID: String

  /// The prayer's name, in whichever language the app was showing it in.
  public let title: String

  /// Every pace the app offers, in the order it offers them.
  ///
  /// Sent rather than known, so the widget has no list of its own to fall out of
  /// step with `PrayerPlaybackSpeed.allCases`. In the attributes rather than the
  /// state because the set never changes for the life of a reading.
  public let speeds: [Double]

  public init(prayerID: String, title: String, speeds: [Double]) {
    self.prayerID = prayerID
    self.title = title
    self.speeds = speeds
  }
}

// MARK: - Labels

public extension PrayerReadingAttributes {
  /// A pace as the card writes it: `0.25×`, `1×`, `2×`.
  ///
  /// Derived from the number rather than looked up in a table, which is what
  /// keeps it honest across a module boundary — there is no list here that could
  /// disagree with `PrayerPlaybackSpeed.label`, only arithmetic that produces
  /// the same strings from the same values.
  ///
  /// Digits and a sign in both languages, exactly as the enum's own label is,
  /// and for the reason given there: this is the one label in the reader that
  /// says a quantity.
  static func speedLabel(_ speed: Double) -> String {
    let digits = speed.truncatingRemainder(dividingBy: 1) == 0
      ? String(Int(speed))
      : String(format: "%g", speed)

    return digits + "×"
  }
}
#endif
