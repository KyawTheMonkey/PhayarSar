import CoreGraphics
import Foundation

/// Layout constants for the reading screen.
///
/// Outside the UIKit guard below, unlike everything else in this file: these are
/// plain numbers with nothing UIKit about them, and the SwiftUI chrome floating
/// over the reader — see ``PrayerPageSwitcher`` — has to be laid out against the
/// same ones the table is.
enum PrayerReaderMetrics {
  /// Side margins for the recited text. Wider than the 16pt the cards on the
  /// detail screen use — a full-bleed page of text needs more gutter than a
  /// card that already has its own edge.
  static let horizontalInset: CGFloat = 20

  static let topInset: CGFloat = 16

  /// The strip at the foot of the page the switcher rests in, above the home
  /// indicator. Taken from the switcher's own numbers so the two cannot drift.
  static var chromeClearance: CGFloat {
    PrayerPageSwitcherMetrics.bottomPadding + PrayerPageSwitcherMetrics.shutHeight
  }

  /// Air between the last line and the switcher resting under it, so the end of
  /// a prayer stops short of the pill rather than against it.
  ///
  /// Roughly a line of recited text at the default size.
  static let chromeGap: CGFloat = 28

  /// Clearance under the last verse, so the reader can scroll it clear of the
  /// home indicator and of the floating page switcher.
  ///
  /// This is the only thing keeping the two apart. Nothing is laid over the
  /// foot of the page, so a line *passing* the switcher mid-scroll does go
  /// under it — the inset decides where the last line comes to rest, not what
  /// happens on the way there.
  static var bottomInset: CGFloat { chromeClearance + chromeGap }

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

  /// Base gap between the rule under one line and the line after it, before the
  /// reader's own line-spacing setting is added to it. There is a floor under it
  /// because the rule has to stay nearer the line it closes than the one it
  /// opens, which it would not at a line-spacing setting of zero.
  static let glossLineSpacing: CGFloat = 8

  /// Gap between a line and the rule under it. Nearer to the line it closes than
  /// to the one it opens, so the rule reads as ending a line rather than as
  /// floating between two.
  static let glossSeparatorSpacing: CGFloat = 8

  /// A hairline at the densest screen the app runs on. Fixed rather than
  /// `1 / displayScale`: this is a rule drawn across a page of text, and it
  /// should look the same weight wherever it is read.
  static let glossSeparatorThickness: CGFloat = 0.5

  /// What the rest of the page fades to while a tapped line is being followed.
  /// Far enough down to put the page behind glass, not so far that the reader
  /// loses the passage the line sits in.
  static let recededAlpha: CGFloat = 0.28

  /// How long the page takes to carry a tapped line to the middle. The page
  /// recedes over exactly this, on the same curve and from the same instant, so
  /// that the move and the tint are one movement rather than two.
  ///
  /// Slower than `scrollToRow`'s own animation, which this replaces: the whole
  /// point of the move is to be followed, and UIKit's is quick enough to be
  /// missed.
  static let focusScroll: TimeInterval = 0.4

  /// How long the tinted line is held after the page has settled — the "and
  /// there it is" beat, before the page comes back up around it.
  static let focusLinger: TimeInterval = 0.35

  /// How long a scroll asked for from the watch takes.
  ///
  /// Shorter than ``focusScroll``: that one is a move the reader is meant to
  /// *follow*, from a line they tapped to the middle of the page, while this is
  /// the page simply going where it was pushed. Long enough not to be a cut,
  /// short enough that a second press does not queue up behind it.
  static let remoteScroll: TimeInterval = 0.28

  /// The smallest scroll that is worth animating, as a fraction of a page.
  ///
  /// Below this the request came from the Digital Crown, which sends a stream
  /// of small nudges as it turns; animating each one would have every nudge
  /// interrupting the last and the page moving in a stutter rather than under
  /// the finger. Above it the request was a button press, which wants to be
  /// seen as a movement.
  static let remoteScrollAnimationThreshold: Double = 0.08

  /// How long the page takes to come back up. Slow enough to be seen as a
  /// movement rather than a cut.
  static let focusFade: TimeInterval = 0.28

  /// How long the sheet takes to grow out of the verse, and to fold back into
  /// it. Spring-driven — see ``nissayaSheet`` — so this is the settling time
  /// rather than a hard duration.
  static let sheetTravel: TimeInterval = 0.5

    /// How long UIKit takes to slide a swipe tray shut.
  ///
  /// Theirs, not ours — measured, because there is no constant to read it from.
  /// The turn waits this long so that it does not start under a tray still on
  /// its way out, which would be two animations over one row.
  static let trayClose: TimeInterval = 0.25

  /// How long the page takes to soften before one prayer is exchanged for
  /// another, and how long it takes to come back.
  ///
  /// The turn is a cross-dissolve and nothing else — no travel, no zoom. Those
  /// are the two things that make a transition unpleasant for a reader prone to
  /// motion sickness, and neither of them was earning its place here: a page
  /// sliding sideways says "you have moved", which is a lie, because the reader
  /// has not gone anywhere. They asked for a different prayer and got one.
  ///
  /// The leaving half is timed rather than sprung because the exchange has to be
  /// placed at the exact instant the page is least legible, and a spring
  /// approaches its rest position without ever arriving at it. The returning
  /// half is the slower of the two so that the new page settles rather than
  /// snaps.
  static let pageDissolve: TimeInterval = 0.22
  static let pageResolve: TimeInterval = 0.32

  /// How much of its ink the page gives up at the deepest point of the turn.
  ///
  /// All of it, which is what makes this a true cross-dissolve: the old page
  /// goes to nothing, the exchange happens on an empty page, and the new one
  /// comes up out of the same nothing. Anything short of that leaves a ghost of
  /// the old text for the new to cut through, which is the one artefact a
  /// dissolve exists to avoid.
  ///
  /// Nothing else happens. No travel, no zoom, no blur — a fade is the calmest
  /// transition there is, it carries no vestibular load at all, and it is what
  /// Reduce Motion would have asked for anyway, so both paths are the same
  /// path.
  static let pageFade: Double = 1

  /// Inset of the tint behind a focused line from the text it sits behind.
  static let focusOutset = (horizontal: CGFloat(10), vertical: CGFloat(6))

  static let focusCornerRadius: CGFloat = 10

  /// How much of the readable page counts as "near enough to the middle" when a
  /// line is tapped: a line already inside this much of it, centred on the
  /// middle, does not move the page. Two thirds leaves the outer sixth at each
  /// end — where a line is genuinely awkward to read — as the part worth
  /// scrolling for.
  static let centredBandFraction: CGFloat = 2.0 / 3.0

  /// Only a starting guess for the scroll indicator — every row measures
  /// itself. A row is one line of the prayer: a respelling, the Pali under it,
  /// and the rule closing them.
  static let estimatedRowHeight: CGFloat = 72
}

#if canImport(UIKit)
import DesignKit
import PrayersKit
// For the `UIColor(_: Color)` bridge — the design tokens are SwiftUI `Color`s.
import SwiftUI
import UIKit

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

  /// The rule under each line. Far fainter than either text: it is there to
  /// close a line, not to be read as part of it.
  let separatorColor: UIColor

  /// The tint behind a line the reader has tapped. Fainter still than the rule
  /// — the line is picked out by the rest of the page receding from it, and
  /// this only has to say which line it was.
  let focusColor: UIColor

  let alignment: NSTextAlignment
  let kern: CGFloat
  let lineSpacing: CGFloat
  let verseSpacing: CGFloat

  /// Whether the pronunciation is wanted at all. A verse may still have none —
  /// see ``Prayer/Verse/pronunciation``.
  let showsPronunciation: Bool

  init(settings: PrayerSettings) {
    let size = CGFloat(settings.textSize)

    verseFont = settings.font.uiFont(size: size, relativeTo: .body)
    pronunciationFont = settings.font.uiFont(
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
    focusColor = textColor.withAlphaComponent(0.07)

    alignment = settings.alignment.nsTextAlignment
    kern = settings.letterSpacing
    lineSpacing = settings.lineSpacing
    verseSpacing = settings.verseSpacing
    showsPronunciation = settings.showsPronunciation
  }

  /// A verse's name, and the small labels the sheet uses in the same slot.
  ///
  /// On ``PrayerReadingStyle`` rather than on the cell so that the sheet, which
  /// is not a cell, cannot end up labelling things a little differently from
  /// the page it grew out of.
  func attributedName(_ text: String) -> NSAttributedString {
    NSAttributedString(
      string: text.uppercased(),
      attributes: [
        .font: nameFont,
        .foregroundColor: secondaryTextColor,
        .paragraphStyle: paragraphStyle(lineSpacing: 0)
      ]
    )
  }

  /// The gap under a line.
  ///
  /// - Parameter next: What follows it. The last line of a verse block drops the
  ///   gap entirely — on the page the table's bottom inset provides the
  ///   clearance, and in the sheet the panel's own padding does; either way both
  ///   together would read as a hole.
  func gap(before next: PrayerVerseLine.Next) -> CGFloat {
    switch next {
    case .line:
      // Every line is closed by a rule, so every line needs more air under it
      // than the reader's leading alone would give — enough that the rule stays
      // nearer the line it closes than the one it opens.
      return PrayerReaderMetrics.glossLineSpacing + lineSpacing
    case .verse:
      return verseSpacing
    case .end:
      return 0
    }
  }

  /// The paper the inline nissaya sheet is cut from.
  ///
  /// The page's own colour with a little of its ink laid over it: a panel that
  /// is of the page rather than a slab of some other material dropped onto it,
  /// but still separable from it — which matters most on the true-black paper,
  /// where a panel in the page's exact colour and a shadow that black cannot
  /// carry would leave the sheet with no edge at all.
  var sheetColor: UIColor {
    textColor.withAlphaComponent(0.07).blended(over: pageColor)
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

  /// A verse's nissaya, for the face a row turns over to.
  ///
  /// The recited size and the page's full ink, because on that face this *is*
  /// the row's text rather than a note under it — but none of the tracking:
  /// letter-spacing is a setting about chanting a line of Pali, and a paragraph
  /// of Burmese prose set with it comes apart.
  func attributedMeaning(_ text: String) -> NSAttributedString {
    NSAttributedString(
      string: text,
      attributes: [
        .font: verseFont,
        .foregroundColor: textColor,
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

// MARK: - Colour

extension UIColor {
  /// This colour laid over an opaque one, resolved to a single opaque colour.
  ///
  /// Flattened rather than left translucent because it backs a sheet: anything
  /// behind the panel has to be hidden by it, and a 7% ink wash that let the
  /// page through would show the verse it is sitting on.
  fileprivate func blended(over base: UIColor) -> UIColor {
    UIColor { traits in
      var top = (red: CGFloat(0), green: CGFloat(0), blue: CGFloat(0), alpha: CGFloat(0))
      var bottom = (red: CGFloat(0), green: CGFloat(0), blue: CGFloat(0), alpha: CGFloat(0))

      guard
        self.resolvedColor(with: traits)
          .getRed(&top.red, green: &top.green, blue: &top.blue, alpha: &top.alpha),
        base.resolvedColor(with: traits)
          .getRed(&bottom.red, green: &bottom.green, blue: &bottom.blue, alpha: &bottom.alpha)
      else {
        return base
      }

      return UIColor(
        red: bottom.red + (top.red - bottom.red) * top.alpha,
        green: bottom.green + (top.green - bottom.green) * top.alpha,
        blue: bottom.blue + (top.blue - bottom.blue) * top.alpha,
        alpha: 1
      )
    }
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
