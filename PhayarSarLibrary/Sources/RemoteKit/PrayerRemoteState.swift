import Foundation

/// Where the phone is, as much of it as the watch needs to draw itself.
///
/// Travels the other way from ``PrayerRemoteCommand`` and is the only thing
/// that does. The watch holds no model of its own: it shows this and sends
/// commands, which is what makes "the reader scrolled the phone by hand" and
/// "the reader turned the crown" end in the same place rather than drifting
/// apart.
///
/// Deliberately small and self-contained — no `Prayer`, no `PrayerSettings`.
/// Carrying domain types would put `PrayersKit` (and through it Core Data and
/// CloudKit) on the watch to render a title and a verse, and would tie the two
/// apps' releases together at the wire.
public struct PrayerRemoteState: Codable, Hashable, Sendable {

  /// Whether the reading screen is up. `false` means the phone is somewhere
  /// else in the app — the watch shows its catalog and little else.
  public var isReaderOpen: Bool

  /// The prayer on screen, if there is one.
  public var prayerID: String?
  public var prayerTitle: String?

  /// Where that prayer sits in the catalog, so the watch can grey out the
  /// prayer steps at either end rather than sending commands that do nothing.
  public var prayerIndex: Int?

  /// How many verses the prayer has, and which one is nearest the middle of the
  /// page. `verseIndex` is 0-based and follows the reader's own scrolling, not
  /// only the watch's stepping.
  public var verseIndex: Int?
  public var verseCount: Int

  /// The centred verse's own text, for the glance — the watch is a remote, but
  /// a remote that cannot tell you where you are is a worse remote.
  public var verseText: String?

  /// The verse's name where it has one; several prayers name only some of them.
  public var verseName: String?

  /// The recited text's point size on the phone, so the watch's size control
  /// starts from the truth rather than from a default.
  public var textSize: Int

  /// Which language the phone is set to, as `Language`'s raw value — `"En"` or
  /// `"Mm"`.
  ///
  /// Sent rather than read locally because the watch cannot read it locally: the
  /// choice lives in the phone's `UserDefaults`, and the watch has its own. A
  /// watch app that asked `LocalisationManager` would answer with whatever its
  /// own defaults happened to hold, which for a fresh install is the fallback
  /// and never the reader's actual choice.
  ///
  /// A `String` rather than the `Language` enum so `RemoteKit` stays free of
  /// `LocalisationKit` — see the note in `WristStrings` about why the watch is
  /// kept off that module entirely.
  public var language: String

  /// Every prayer in reading order, for the watch's jump list.
  ///
  /// Sent whole rather than paged: 35 short titles is a couple of kilobytes
  /// against `WCSession`'s ~256KB ceiling, and a list that arrives in one piece
  /// needs no loading state on a screen this small.
  public var catalog: [Entry]

  public struct Entry: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
      self.id = id
      self.title = title
    }
  }

  public init(
    isReaderOpen: Bool = false,
    prayerID: String? = nil,
    prayerTitle: String? = nil,
    prayerIndex: Int? = nil,
    verseIndex: Int? = nil,
    verseCount: Int = 0,
    verseText: String? = nil,
    verseName: String? = nil,
    textSize: Int = 28,
    language: String = "En",
    catalog: [Entry] = []
  ) {
    self.isReaderOpen = isReaderOpen
    self.prayerID = prayerID
    self.prayerTitle = prayerTitle
    self.prayerIndex = prayerIndex
    self.verseIndex = verseIndex
    self.verseCount = verseCount
    self.verseText = verseText
    self.verseName = verseName
    self.textSize = textSize
    self.language = language
    self.catalog = catalog
  }

  /// What the watch shows before the phone has said anything.
  public static let unknown = PrayerRemoteState()

  // MARK: - Derived

  /// Whether there is a prayer after this one to step to.
  public var canStepPrayerForward: Bool {
    guard let prayerIndex else { return false }
    return prayerIndex + 1 < catalog.count
  }

  public var canStepPrayerBack: Bool {
    guard let prayerIndex else { return false }
    return prayerIndex > 0
  }

  /// How far through the prayer the page is, `0...1`, for the watch's progress
  /// ring. `nil` where there is nothing to be a fraction of.
  public var progress: Double? {
    guard let verseIndex, verseCount > 1 else { return nil }
    return Double(verseIndex) / Double(verseCount - 1)
  }

  /// Merges a fresh state onto this one, keeping the catalog when the new state
  /// arrived without it.
  ///
  /// Live updates leave the catalog out — it is the largest part of the payload
  /// and it does not change between two verses — so the watch folds them onto
  /// the catalog it already has rather than emptying its jump list every time
  /// the page moves.
  public func merging(_ update: PrayerRemoteState) -> PrayerRemoteState {
    var merged = update
    if merged.catalog.isEmpty {
      merged.catalog = catalog
    }
    return merged
  }

  /// A copy with the catalog stripped, for the frequent updates.
  public var withoutCatalog: PrayerRemoteState {
    var copy = self
    copy.catalog = []
    return copy
  }
}
