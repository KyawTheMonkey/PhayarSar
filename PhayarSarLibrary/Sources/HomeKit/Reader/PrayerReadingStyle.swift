#if canImport(UIKit)
import DesignKit
import PrayersKit
// For the `UIColor(_: Color)` bridge — the design tokens are SwiftUI `Color`s.
import SwiftUI
import UIKit

/// Layout constants for the reading screen.
enum PrayerReaderMetrics {
  /// Side margins for the recited text. Wider than the 16pt the cards on the
  /// detail screen use — a full-bleed page of text needs more gutter than a
  /// card that already has its own edge.
  static let horizontalInset: CGFloat = 20

  static let topInset: CGFloat = 16

  /// Clearance under the last verse, so the reader can scroll it clear of the
  /// home indicator and of whatever playback controls land here later.
  static let bottomInset: CGFloat = 48

  /// Pronunciation size as a fraction of the recited size. The respelling is a
  /// reading aid; at parity it competes with the text it is glossing.
  static let pronunciationScale: CGFloat = 0.62

  /// Floor for the above, so the aid stays readable when the recited text is
  /// set small.
  static let minimumPronunciationSize: CGFloat = 13

  /// Gap between a named verse's name and its text.
  static let nameSpacing: CGFloat = 4

  /// Gap between a glossed line's respelling and the Pali beneath it. Nearly
  /// nothing — the two are one unit, and any air here starts to read as the gap
  /// to the next pair instead.
  static let glossPairSpacing: CGFloat = 2

  /// Base gap between the rule under one pair of a gloss and the next pair,
  /// before the reader's own line-spacing setting is added to it. There is a
  /// floor under it because a pair is two lines of text tall, and at a setting
  /// of zero the pairs would run into each other where plain lines would only
  /// sit close.
  static let glossLineSpacing: CGFloat = 8

  /// Gap between a glossed pair and the rule under it. Nearer to the pair it
  /// closes than to the one it opens, so the rule reads as ending a line rather
  /// than as floating between two.
  static let glossSeparatorSpacing: CGFloat = 8

  /// A hairline at the densest screen the app runs on. Fixed rather than
  /// `1 / displayScale`: this is a rule drawn across a page of text, and it
  /// should look the same weight wherever it is read.
  static let glossSeparatorThickness: CGFloat = 0.5

  /// Only a starting guess for the scroll indicator — every row measures itself.
  static let estimatedRowHeight: CGFloat = 140
}

/// Everything the cells need to draw a verse, resolved once from
/// ``PrayerSettings``.
///
/// Resolved up front rather than read per-cell: the fonts go through
/// `UIFontMetrics` and the colours through a SwiftUI `Color` bridge, and a
/// scrolling table would redo both for every cell that comes into view.
struct PrayerReadingStyle {
  let verseFont: UIFont
  let pronunciationFont: UIFont
  let nameFont: UIFont

  let pageColor: UIColor
  let textColor: UIColor
  /// For the pronunciation and the verse name — the page's own ink, stepped
  /// back so the recited line stays the loudest thing on the page.
  let secondaryTextColor: UIColor

  /// The rule under each line of a gloss. Far fainter than either text: it is
  /// there to close a line, not to be read as part of it.
  let separatorColor: UIColor

  let alignment: NSTextAlignment
  let kern: CGFloat
  let lineSpacing: CGFloat
  let verseSpacing: CGFloat

  /// Whether the pronunciation is wanted at all. A verse may still have none —
  /// see ``Prayer/Verse/pronunciation``.
  let showsPronunciation: Bool

  init(settings: PrayerSettings) {
    let size = CGFloat(settings.textSize)

    // Jasmine for the recited text: the settings model has no font picker yet,
    // so this is the reader's one face until it does.
    verseFont = AppUIFont.jasmine(size: size, relativeTo: .body)
    pronunciationFont = AppUIFont.jasmine(
      size: max(
        size * PrayerReaderMetrics.pronunciationScale,
        PrayerReaderMetrics.minimumPronunciationSize
      ),
      relativeTo: .footnote
    )
    nameFont = AppUIFont.sectionLabel

    pageColor = UIColor(settings.background.color)
    textColor = UIColor(settings.background.foreground)
    secondaryTextColor = textColor.withAlphaComponent(0.6)
    separatorColor = textColor.withAlphaComponent(0.15)

    alignment = settings.alignment.nsTextAlignment
    kern = settings.letterSpacing
    lineSpacing = settings.lineSpacing
    verseSpacing = settings.verseSpacing
    showsPronunciation = settings.showsPronunciation
  }

  /// The paragraph style shared by every line the reader draws.
  ///
  /// - Parameter lineSpacing: The verse's own leading, or a fraction of it for
  ///   the smaller text beneath.
  func paragraphStyle(lineSpacing: CGFloat) -> NSParagraphStyle {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = lineSpacing
    paragraph.alignment = alignment
    return paragraph
  }

  /// Recited text, with the reader's tracking and leading applied.
  func attributedVerse(_ text: String) -> NSAttributedString {
    NSAttributedString(
      string: text,
      attributes: [
        .font: verseFont,
        .foregroundColor: textColor,
        .kern: kern,
        .paragraphStyle: paragraphStyle(lineSpacing: lineSpacing)
      ]
    )
  }

  /// A verse as an interlinear gloss: each line's respelling with the Pali it
  /// stands for set smaller beneath it.
  ///
  /// The respelling takes the recited size and ink and the Pali becomes the
  /// reference beneath it, which is the way round it is actually read: someone
  /// reciting is reading the respelling, and the Pali under it is what they are
  /// reciting *from*.
  ///
  /// The two halves are one attributed string rather than two labels: they are
  /// paragraphs of the same text, and a paragraph is the smallest run that can
  /// carry its own spacing.
  func attributedGloss(_ line: PrayerVerseGloss.Line) -> NSAttributedString {
    let composed = NSMutableAttributedString()

    composed.append(glossHalf(
      line.pronunciation,
      attributes: [.font: verseFont, .foregroundColor: textColor, .kern: kern],
      leading: lineSpacing,
      // Tight, so the Pali reads as belonging to the line above it.
      spacingAfter: PrayerReaderMetrics.glossPairSpacing,
      terminated: true
    ))

    composed.append(glossHalf(
      line.content,
      // No tracking: the letter-spacing setting is about the recited line, and
      // the Pali is set small enough that the same tracking would pull it
      // apart.
      attributes: [.font: pronunciationFont, .foregroundColor: secondaryTextColor],
      leading: lineSpacing / 2,
      spacingAfter: 0,
      terminated: false
    ))

    return composed
  }

  /// One half of a glossed line, as a paragraph of its own.
  ///
  /// - Parameters:
  ///   - leading: Spacing between this half's own rows, for a line long enough
  ///     to wrap.
  ///   - spacingAfter: Gap to the half below.
  ///   - terminated: Whether to end the paragraph. The lower half is left open
  ///     — a trailing newline would draw an empty line under it and push the
  ///     rule that much further from the text it closes.
  private func glossHalf(
    _ text: String,
    attributes: [NSAttributedString.Key: Any],
    leading: CGFloat,
    spacingAfter: CGFloat,
    terminated: Bool
  ) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = leading
    paragraph.alignment = alignment
    paragraph.paragraphSpacing = spacingAfter

    var attributes = attributes
    attributes[.paragraphStyle] = paragraph

    return NSAttributedString(
      string: (text.isEmpty ? Self.blank : text) + (terminated ? "\n" : ""),
      attributes: attributes
    )
  }

  /// Stands in for a line the other half of the verse has no counterpart for.
  ///
  /// A space rather than the empty string: an empty paragraph has no character
  /// to carry the font, so it would collapse and let the pairs below it ride up
  /// out of step — see ``PrayerVerseGloss`` for why a verse can come up a line
  /// short.
  private static let blank = " "
}

// MARK: - SwiftUI alignment bridge

extension PrayerSettings.Alignment {
  /// The UIKit counterpart of ``textAlignment``, which is SwiftUI's.
  ///
  /// Named apart from it rather than overloaded on return type: two properties
  /// called `textAlignment` on one type is ambiguity waiting to be resolved by
  /// whatever the call site happens to expect.
  fileprivate var nsTextAlignment: NSTextAlignment {
    switch self {
    case .left:
      return .left
    case .center:
      return .center
    case .right:
      return .right
    }
  }
}
#endif
