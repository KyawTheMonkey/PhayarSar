/// Everything kept about how one prayer is read.
///
/// The unit of persistence: one of these per prayer, stored against ``Prayer/id``
/// by ``PrayerConfigurationStore``. A plan — a collection of prayers — will later
/// hold one of these of its own and lend it to every prayer read inside it.
///
/// A wrapper around ``PrayerSettings`` rather than two more fields on it. The
/// reader compares settings to decide whether its page needs rebuilding
/// (`PrayerViewController.update(prayer:settings:)`), and the slot is not
/// something the page can show — folding it in would rebuild the page for a
/// change nobody can see.
public struct PrayerConfiguration: Hashable, Sendable {
  /// Everything the reader tuned.
  ///
  /// ``PrayerSettings/background`` is the one exception: it is *derived*, not
  /// stored. See ``themeSlot``.
  public var settings: PrayerSettings

  /// The theme the page is built from.
  ///
  /// The paper is resolved through this rather than kept alongside it, which is
  /// what makes a theme survive the lights going out: the same slot answers with
  /// a light paper by day and a dark one after dark. Storing the paper instead
  /// would pin a page to the appearance it happened to be chosen in.
  ///
  /// Not optional. A page is always on one of the three — there is no way in the
  /// app to arrive at a paper that belongs to none of them.
  public var themeSlot: PrayerThemeSlot

  public init(settings: PrayerSettings = .standard, themeSlot: PrayerThemeSlot = .one) {
    self.settings = settings
    self.themeSlot = themeSlot
  }

  /// What a prayer opens with before the reader has changed anything.
  ///
  /// ``PrayerThemeSlot/one`` because ``PrayerSettings/standard`` is already
  /// jasmine on classic, which is the first theme — a reader who has changed
  /// nothing is on a theme rather than off all of them.
  public static let standard = PrayerConfiguration()
}
