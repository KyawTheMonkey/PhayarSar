import LocalisationKit
import PrayersKit
import SwiftUI

/// One theme, in both appearances.
///
/// **A theme is a paper and a face, and nothing else.** Everything else about
/// the page — the size, the alignment, the three spacings — is the reader's, is
/// the same whichever theme is chosen, and survives switching between them.
/// That is why this type carries a ``font`` and two papers rather than a whole
/// ``PrayerSettings``: there is no third thing for a theme to say.
///
/// The face is a **starting point, not a rule**. Choosing a theme sets it, and
/// the reader can pick a different one straight afterwards without coming off
/// the theme — the chip stays lit, because the theme is still what the page was
/// built from.
///
/// The paper is the half the reader does not set directly. It comes from
/// ``light`` or ``dark`` according to the appearance, which is what makes the
/// pairing work: everything the reader has tuned survives the lights going out,
/// and only the page underneath it changes.
///
/// **These are placeholders.** The real set is still to be decided — what they
/// are called, and what each one carries. They are deliberately all in this one
/// file so that replacing them later is a single-file change with no call sites
/// to chase.
struct PrayerTheme: Identifiable, Hashable {
  let slot: PrayerThemeSlot

  /// The face choosing this theme sets.
  let font: PrayerSettings.Face

  /// The paper for each appearance. Naming lives on the paper itself — see
  /// ``PrayerSettings/Background/displayText`` — because the six papers and the
  /// six theme names are the same six things, and holding a second copy here
  /// only created something to keep in step.
  let light: PrayerSettings.Background
  let dark: PrayerSettings.Background

  var id: PrayerThemeSlot { slot }

  func page(for colorScheme: ColorScheme) -> PrayerSettings.Background {
    colorScheme == .dark ? dark : light
  }
}

extension PrayerTheme {
  /// The three themes, in the order they appear in the row.
  ///
  /// Not `CaseIterable` off an enum, because the real set will almost certainly
  /// come from somewhere else — a JSON file beside the prayers, or the reader's
  /// own saved themes — and an enum would have to be torn out to get there.
  ///
  /// There is one paper per theme per appearance, and no two themes share one.
  /// The three in each set are separated by hue rather than by brightness —
  /// warm white, amber cream and cool grey-green in the light; blue-black, warm
  /// charcoal and true black in the dark — because three warm off-whites a few
  /// percent apart are three papers nobody can tell apart on a phone.
  static let all: [PrayerTheme] = [
    PrayerTheme(
      slot: .one,
      // The face `PrayerSettings.standard` already uses: the first theme is what
      // a prayer opens with, so a reader who has changed nothing finds it
      // selected rather than finding no theme at all.
      font: .jasmine,
      light: .classic,
      dark: .midnight
    ),

    PrayerTheme(
      slot: .two,
      font: .panglong,
      light: .parchment,
      dark: .charcoal
    ),

    PrayerTheme(
      slot: .three,
      font: .square,
      light: .paper,
      dark: .ink
    )
  ]

  /// The theme in a given slot, falling back to ``first``.
  ///
  /// This used to trap on a slot with no theme behind it, which was fair while
  /// the enum and the table above were written together in this file. The enum
  /// is in PrayersKit now because it is persisted, so a slot can also arrive out
  /// of a stored record — including one synced from a build that had a fourth
  /// preset this one does not. Opening a prayer on the first theme is a far
  /// better answer to that than crashing on a CloudKit import.
  static func theme(_ slot: PrayerThemeSlot) -> PrayerTheme {
    all.first { $0.slot == slot } ?? first
  }

  /// The theme a prayer opens on.
  static var first: PrayerTheme { all[0] }
}

// MARK: - Resolving the paper

extension PrayerConfiguration {
  /// The same configuration, wearing the paper its theme calls for in this
  /// appearance.
  ///
  /// **The one place an appearance becomes a paper.** ``PrayerSettings/background``
  /// is derived rather than stored — see ``PrayerConfiguration/themeSlot`` — so
  /// this has to run on every load and on every appearance change, before
  /// anything draws with it.
  ///
  /// It lives in HomeKit, on a PrayersKit type, because the light/dark pairing is
  /// ``PrayerTheme``'s and nothing in PrayersKit knows it: a slot is an identity
  /// there, and only the table above says what it looks like.
  func resolvingBackground(for colorScheme: ColorScheme) -> PrayerConfiguration {
    var resolved = self
    resolved.settings.background = PrayerTheme.theme(themeSlot).page(for: colorScheme)
    return resolved
  }
}
