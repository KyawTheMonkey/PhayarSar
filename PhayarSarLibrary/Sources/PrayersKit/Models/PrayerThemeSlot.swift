/// Which of the three themes a prayer is read on, independent of appearance.
///
/// The slot is what a reader's choice is stored against — not the variant they
/// happened to pick it in. Choosing the second theme in daylight and then turning
/// the lights off lands on the second theme again, in its dark form, rather than
/// dropping the choice or carrying a light page into the dark.
///
/// What each slot actually *is* — its face, and its paper in either appearance —
/// is `PrayerTheme`'s business, in HomeKit. Only the identity lives here, because
/// this is the half that gets persisted: see ``PrayerConfiguration/themeSlot``.
public enum PrayerThemeSlot: String, CaseIterable, Hashable, Sendable, Codable {
  case one
  case two
  case three
}
