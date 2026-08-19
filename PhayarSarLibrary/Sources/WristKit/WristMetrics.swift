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

  /// The reading glance — how many lines of the current verse are shown before
  /// it truncates. Three fits the 41mm screen with the controls still on it.
  static let verseLineLimit = 3

  static let controlSpacing: CGFloat = 6
  static let sectionSpacing: CGFloat = 10

  /// The tap targets. Apple's floor is 44pt square on the phone; on the watch
  /// the useful floor is lower but the buttons here are the whole point of the
  /// screen, so they take the room.
  static let primaryControlHeight: CGFloat = 46
  static let secondaryControlHeight: CGFloat = 32

  static let cornerRadius: CGFloat = 10

  // MARK: - Type

  static let titleSize: CGFloat = 15
  static let verseSize: CGFloat = 16
  static let captionSize: CGFloat = 12
}
#endif
