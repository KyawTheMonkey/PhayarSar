#if os(watchOS)
import Foundation
import SwiftUI

/// The numbers the watch remote is laid out and timed by.
///
/// Gathered here for the same reason `PrayerReaderMetrics` exists on the phone:
/// a screen this small is mostly spacing decisions, and they are only coherent
/// if they can be read next to one another.
enum WristMetrics {

  // MARK: - The crown

  /// How much of a page one unit of crown value is worth.
  ///
  /// The Digital Crown reports in units that depend on the sensitivity it was
  /// configured with and on nothing the app can measure, so this is a feel
  /// constant rather than a derived one — tuned so a comfortable turn of the
  /// wrist moves the phone about a screenful. It is the first thing to change
  /// if scrolling comes out too eager or too slow.
  static let crownPagesPerUnit: Double = 0.9

  /// How often accumulated crown movement is sent, at most.
  ///
  /// About fifteen a second: fast enough that the page tracks the crown rather
  /// than stepping after it, slow enough to stay well inside what `WCSession`
  /// will carry without dropping messages.
  static let scrollInterval: TimeInterval = 1.0 / 15.0

  /// How much page has to go by between haptic ticks. Roughly a tick per line
  /// of text at the default size.
  static let hapticPageInterval: Double = 0.08

  /// What the page-scroll buttons move, as a fraction of a page.
  ///
  /// Less than a whole screen on purpose: a full page turn leaves nothing of
  /// what was being read on screen, and a reader who has lost their place has
  /// to scroll back to find it. This keeps a couple of lines of overlap.
  static let buttonScroll: Double = 0.8

  // MARK: - Layout

  /// A ceiling on the glance, so one long verse cannot take an Ultra's whole
  /// screen. How many lines actually show is decided by the room left after the
  /// fixed rows — see `WristReaderView.body`.
  static let verseLineLimit = 4

  /// How far the verse may shrink to fit the width before it truncates instead.
  static let verseMinimumScale: CGFloat = 0.8

  /// How thick the bar under the title is. A hairline: it says how far through
  /// the prayer the page is and nothing else, and anything heavier competes
  /// with the verse it sits above.
  static let progressHeight: CGFloat = 2

  // MARK: - Text size

  /// What the size stepper offers, mirroring the phone's own compact range.
  ///
  /// Advisory rather than authoritative. `PrayerScreen` clamps whatever arrives
  /// from the wrist against `PrayerThemeMetrics` before applying it, because
  /// only the phone knows whether it is laid out compact or regular. These
  /// bounds exist so the stepper stops where the phone would have stopped it,
  /// rather than letting the reader press a button that does nothing.
  static let textSizeRange = 14...32

  /// Two points a step, matching the phone's slider — one point is a change
  /// nobody can see.
  static let textSizeStep = 2

  static let controlSpacing: CGFloat = 6

  /// Between the four rows of the remote. Tight, because on a 41mm watch every
  /// point spent here is a point the verse does not get.
  static let sectionSpacing: CGFloat = 8

  /// The tap targets. Apple's floor is 44pt square on the phone; on the watch
  /// the useful floor is lower but the buttons here are the whole point of the
  /// screen, so they take the room.
  static let primaryControlHeight: CGFloat = 46
  static let secondaryControlHeight: CGFloat = 32

  static let cornerRadius: CGFloat = 10

  // MARK: - Type

  static let titleSize: CGFloat = 15
  static let verseSize: CGFloat = 16

  /// The verse's name, where it has one. Smaller than the verse it titles and
  /// set in the accent, so it reads as a label rather than as a first line.
  static let verseNameSize: CGFloat = 12
}
#endif
