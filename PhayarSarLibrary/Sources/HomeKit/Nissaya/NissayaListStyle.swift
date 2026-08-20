#if canImport(UIKit)
import DesignKit
// For the `UIColor(_: Color)` bridge — the design tokens are SwiftUI `Color`s.
import SwiftUI
import UIKit

// MARK: - Metrics

/// Layout, type and motion constants for the nissaya list.
enum NissayaListMetrics {

  // MARK: - The page

  /// Side margins. The same size-class-aware inset `appHorizontalInset()`
  /// applies in SwiftUI, so the text lines up with every other screen's — 16pt
  /// in compact width, 20pt in regular.
  static func horizontalInset(for traits: UITraitCollection) -> CGFloat {
    traits.horizontalSizeClass == .regular ? 20 : 16
  }

  /// Widest the text column is allowed to get, however much room the window
  /// has.
  ///
  /// Past this the measure stops being comfortable: on a landscape iPad an
  /// uncapped column puts some 500pt of Burmese on a line, and finding the
  /// start of the next one becomes work. The *paper* still runs edge to edge —
  /// it is the text that is centred in it.
  static let maxTextWidth: CGFloat = 640

  /// Nothing above the first verse: the sheet starts at the top of the page,
  /// under the navigation bar, the way a page of a book does.
  static let topInset: CGFloat = 0

  /// Clearance under the last verse, so the end of the sheet can be scrolled
  /// clear of the home indicator rather than stopping against it.
  static let bottomInset: CGFloat = 32

  /// A verse at the default type size, near enough. Only ever used before a row
  /// has been measured.
  static let estimatedRowHeight: CGFloat = 120

  // MARK: - The page
  //
  // No cards, no gutters, no corners: one continuous sheet, ruled into verses.
  // Rows sit directly against one another and are told apart by the rule
  // between them and by the setting of their text — which is what lets a
  // meaning *unfold* out of the page rather than appear in a gap between two
  // floating panels.

  /// The rule between one row and the next. A hairline in points rather than in
  /// pixels, matching every other separator in the app.
  static let hairline: CGFloat = 0.5

  /// Air above and below a row's text.
  static let verticalPadding: CGFloat = 15

  /// Padding around a row's text, given the width it is being read at.
  static func contentInsets(for traits: UITraitCollection) -> NSDirectionalEdgeInsets {
    NSDirectionalEdgeInsets(
      top: verticalPadding,
      leading: horizontalInset(for: traits),
      bottom: verticalPadding,
      trailing: horizontalInset(for: traits)
    )
  }

  /// Gap between a verse's number line and the Pali under it.
  static let headerSpacing: CGFloat = 8

  /// Gap between the text and the chevron at the trailing edge.
  static let chevronGap: CGFloat = 14

  static let chevronSize: CGFloat = 13

  // MARK: - Type
  //
  // The meaning is what this screen exists to show, so it carries the larger,
  // darker setting and the Pali sits above it as the reference — the opposite
  // of `PrayerScreen`, where the recited line is the point and everything else
  // is an aid to it.

  static let paliTextSize: CGFloat = 16
  static let meaningTextSize: CGFloat = 20
  static let nameTextSize: CGFloat = 14

  /// Burmese stacks diacritics above and below the baseline, so the default
  /// leading crowds consecutive lines. Opened up further for the meaning, whose
  /// taller glyphs would otherwise close the gap again.
  static let paliLineSpacing: CGFloat = 6
  static let meaningLineSpacing: CGFloat = 9

  // MARK: - Motion

  /// How long the paper takes to unfold, and to fold back.
  ///
  /// Slower than a disclosure normally is. The fold is the answer arriving —
  /// four panels of paper opening out — and at the 0.3s a row insert usually
  /// takes there is nothing to see.
  static let foldDuration: TimeInterval = 0.62

  /// How much spring is left in the paper: how far under 1 the fold's damping
  /// ratio is. Just under critical, so the sheet arrives with a single small
  /// overshoot and no second bounce — a stiff sheet settling, not a flapping
  /// one. See `NissayaListViewController.ease(_:)`.
  static let foldDamping: Double = 0.78

  /// How long the page waits before opening its first verse.
  ///
  /// Long enough that the push has settled and the reader is looking at the
  /// page rather than at the transition — and short enough that it is still
  /// obviously part of arriving. See `NissayaListViewController.introduce()`.
  static let introDelay: TimeInterval = 0.25

  /// How long the page takes to change when the menu opens or shuts every verse
  /// at once.
  ///
  /// A dissolve rather than a fold — see `NissayaListViewController.setAllOpen`.
  /// Short, because nothing is being explained by it: it is there so the page
  /// changes rather than cuts.
  static let bulkDissolve: TimeInterval = 0.28
}

// MARK: - Text

/// The two blocks of Burmese this screen sets, and the one rule they share.
enum NissayaText {
  /// Text in a face, an ink and a leading of the caller's choosing.
  ///
  /// Attributed rather than plain because of the leading: `UILabel` has no
  /// line-spacing of its own, and Burmese set at the font's default leading
  /// collides with itself.
  static func attributed(
    _ text: String,
    font: UIFont,
    lineSpacing: CGFloat,
    color: UIColor
  ) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = lineSpacing

    return NSAttributedString(
      string: text,
      attributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
      ]
    )
  }
}
#endif
