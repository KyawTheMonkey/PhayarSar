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

  /// Gap between a verse and its pronunciation. Tight on purpose — the two
  /// belong to each other, and `PrayerSettings.verseSpacing` is what separates
  /// one pair from the next.
  static let pronunciationSpacing: CGFloat = 6

  /// Gap between a named verse's name and its text.
  static let nameSpacing: CGFloat = 4

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

  /// The respelling beneath a verse. No tracking: the letter-spacing setting is
  /// about the recited line, and the aid is set small enough that the same
  /// tracking would pull it apart.
  func attributedPronunciation(_ text: String) -> NSAttributedString {
    NSAttributedString(
      string: text,
      attributes: [
        .font: pronunciationFont,
        .foregroundColor: secondaryTextColor,
        .paragraphStyle: paragraphStyle(lineSpacing: lineSpacing / 2)
      ]
    )
  }
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
