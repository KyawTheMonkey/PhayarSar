import DesignKit
import LocalisationKit
import PrayersKit
import SwiftUI

// MARK: - Metrics

/// Layout constants for `PrayerThemePreview`.
private enum PrayerThemePreviewMetrics {
  /// How long the page takes to settle after a control moves.
  ///
  /// Short. The point of the preview is that it answers the slider immediately,
  /// and anything long enough to be watched would put the answer behind the
  /// question. A drag crosses many detents, so this is also what keeps a scrub
  /// from reading as a stutter.
  static let reflowDuration: TimeInterval = 0.2
}

// MARK: - Preview pane

/// A page of the prayer, drawn exactly as the reading settings say it should
/// be — the thing the theme editor is editing.
///
/// Plain SwiftUI rather than the UIKit reader (``PrayerViewController``): this
/// is a fixed sample that never scrolls and never recycles a cell, and standing
/// a table up behind it would buy nothing. What it *does* borrow is every
/// number the reader lays out with — ``PrayerReaderMetrics`` and
/// ``PrayerVerseGloss`` are used directly rather than re-derived, so the preview
/// cannot quietly drift into showing something the reader wouldn't.
///
/// Fills whatever frame it is given, top-aligned. The caller decides how much
/// page to show.
struct PrayerThemePreview: View {
  let settings: PrayerSettings

  /// The specimen, repeated to fill the pane.
  ///
  /// A fixed sentence rather than the prayer being read: this is a type
  /// specimen, and the pangram below exercises far more of a Burmese face —
  /// stacked medials, a kinzi, subscripted consonants — than any one verse
  /// happens to. Repeated rather than shown once because ``verseSpacing`` is
  /// invisible with nothing to space against.
  private var verses: [Prayer.Verse] {
    [
      Prayer.Verse(index: 0, content: Self.specimen)
    ]
  }

  /// The standard Burmese pangram.
  static let specimen = "သီဟိုဠ်မှ ဉာဏ်ကြီးရှင်သည် အာယုဝဍ္ဎနဆေးညွှန်းစာကို ဇလွန်ဈေးဘေး ဗာဒံပင်ထက် အဓိဋ္ဌာန်လျက် ဂဃနဏဖတ်ခဲ့သည်။"

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // MARK: Resolved style
  //
  // Computed once per body rather than per verse, mirroring what
  // `PrayerReadingStyle` does for the reader and for the same reason.

  private var recitedFont: Font {
    settings.font.font(size: CGFloat(settings.textSize))
  }

  /// The Pali beneath a respelling. A reading aid — at parity with the line it
  /// glosses it would compete with it.
  private var glossedFont: Font {
    settings.font.font(
      size: max(
        CGFloat(settings.textSize) * PrayerReaderMetrics.pronunciationScale,
        PrayerReaderMetrics.minimumPronunciationSize
      )
    )
  }

  /// The page's own ink, which follows the paper rather than the app's theme.
  private var ink: Color {
    settings.background.foreground
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: AppCardMetrics.cornerRadius, style: .continuous)
  }

  var body: some View {
    ZStack(alignment: .top) {
      settings.background.color

      page
    }
    // The specimen runs past the bottom of the card and is cut off there, the
    // way a page is cut off by the edge of a window onto it.
    //
    // It used to dissolve instead, over the bottom 28% of the pane. That cost
    // this view a third of its height to show nothing, and one sentence of the
    // pangram at the default 28pt already needs more room than the whole card —
    // so the fade was eating the only text there was space for, and the page
    // read as a vignette that had run out rather than as a page continuing.
    .clipShape(shape)
    .overlay(shape.strokeBorder(AppColor.border, lineWidth: 0.5))
    .animation(
      reduceMotion ? nil : .easeOut(duration: PrayerThemePreviewMetrics.reflowDuration),
      value: settings
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(L10n.preview)
  }

  // MARK: - Page

  private var page: some View {
    VStack(alignment: settings.alignment.horizontal, spacing: settings.verseSpacing) {
      ForEach(verses) { verse in
        Verse(verse)
      }
    }
    .padding(.horizontal, PrayerReaderMetrics.horizontalInset)
    .padding(.top, PrayerReaderMetrics.topInset)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: settings.alignment.frameTop)
  }

  @ViewBuilder
  private func Verse(_ verse: Prayer.Verse) -> some View {
    let gloss = PrayerVerseGloss(
      content: verse.content,
      pronunciation: verse.pronunciation
    )

    VStack(alignment: settings.alignment.horizontal, spacing: PrayerReaderMetrics.nameSpacing) {
      // Set only where the source names each unit — currently just the 24
      // paccayas in ပဋ္ဌာန်းအကျယ်.
      if let name = verse.name, !name.isEmpty {
        Text(name)
          .font(AppFont.sectionLabel)
          .textCase(.uppercase)
          .kerning(0.6)
          .foregroundStyle(ink.opacity(0.6))
      }

      if settings.showsPronunciation, !verse.pronunciation.isEmpty, !gloss.isEmpty {
        Glossed(gloss)
      } else {
        Recited(verse.content)
      }
    }
    .frame(maxWidth: .infinity, alignment: settings.alignment.frame)
  }

  /// A verse with no respelling to show: the recited text on its own, closed by
  /// the same rule the reader draws under every line.
  private func Recited(_ text: String) -> some View {
    VStack(alignment: settings.alignment.horizontal, spacing: 0) {
      Text(text)
        .font(recitedFont)
        .tracking(settings.letterSpacing)
        .lineSpacing(settings.lineSpacing)
        .foregroundStyle(ink)
        .multilineTextAlignment(settings.alignment.textAlignment)
        .frame(maxWidth: .infinity, alignment: settings.alignment.frame)

      Rule()
        .padding(.top, PrayerReaderMetrics.glossSeparatorSpacing)
    }
    .frame(maxWidth: .infinity, alignment: settings.alignment.frame)
  }

  /// The rule that closes a line, in both of the shapes a line can take.
  private func Rule() -> some View {
    Rectangle()
      .fill(ink.opacity(0.15))
      .frame(height: PrayerReaderMetrics.glossSeparatorThickness)
  }

  /// A verse as an interlinear gloss.
  ///
  /// The respelling takes the recited size and ink and the Pali becomes the
  /// reference beneath it — the way round it is actually read, and the way
  /// ``PrayerReadingStyle/attributedGloss(_:)`` sets it for the reader.
  private func Glossed(_ gloss: PrayerVerseGloss) -> some View {
    VStack(
      alignment: settings.alignment.horizontal,
      // The reader's base gap between pairs, plus whatever leading the reader
      // has asked for on top of it.
      spacing: PrayerReaderMetrics.glossLineSpacing + settings.lineSpacing
    ) {
      ForEach(Array(gloss.lines.enumerated()), id: \.offset) { _, line in
        VStack(
          alignment: settings.alignment.horizontal,
          spacing: PrayerReaderMetrics.glossPairSpacing
        ) {
          Text(line.pronunciation)
            .font(recitedFont)
            .tracking(settings.letterSpacing)
            .lineSpacing(settings.lineSpacing)
            .foregroundStyle(ink)

          Text(line.content)
            // No tracking: the letter-spacing setting is about the recited
            // line, and the Pali is set small enough that the same tracking
            // would pull it apart.
            .font(glossedFont)
            .lineSpacing(settings.lineSpacing / 2)
            .foregroundStyle(ink.opacity(0.6))

          Rule()
            // The stack's own spacing already contributes `glossPairSpacing`,
            // so only the remainder is added here — otherwise the rule would
            // sit further from the pair than the reader puts it.
            .padding(
              .top,
              PrayerReaderMetrics.glossSeparatorSpacing - PrayerReaderMetrics.glossPairSpacing
            )
        }
        .multilineTextAlignment(settings.alignment.textAlignment)
        .frame(maxWidth: .infinity, alignment: settings.alignment.frame)
      }
    }
  }

}

// MARK: - SwiftUI alignment bridges

extension PrayerSettings.Alignment {
  /// The stack counterpart of ``textAlignment``.
  ///
  /// Both are needed: `multilineTextAlignment` only moves the lines *within* a
  /// `Text` that has wrapped, so on its own a short line stays wherever the
  /// stack put it. Named apart rather than overloaded on return type, following
  /// ``nsTextAlignment``.
  fileprivate var horizontal: HorizontalAlignment {
    switch self {
    case .left:
      return .leading
    case .center:
      return .center
    case .right:
      return .trailing
    }
  }

  /// The `frame(alignment:)` counterpart, for the same reason as ``horizontal``.
  fileprivate var frame: Alignment {
    switch self {
    case .left:
      return .leading
    case .center:
      return .center
    case .right:
      return .trailing
    }
  }

  /// ``frame`` pinned to the top, for the page as a whole — a short prayer
  /// should sit at the top of the pane, not float in the middle of it.
  fileprivate var frameTop: Alignment {
    switch self {
    case .left:
      return .topLeading
    case .center:
      return .top
    case .right:
      return .topTrailing
    }
  }
}

// MARK: - Previews

#Preview("Paper colours") {
  PrayerThemePreviewPreview()
}

private struct PrayerThemePreviewPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        ForEach(PrayerSettings.Background.allCases, id: \.self) { background in
          PrayerThemePreview(
            settings: PrayerSettings(textSize: 22, background: background)
          )
          .frame(height: 200)
        }
      }
      .padding()
    }
    .background(AppColor.background.ignoresSafeArea())
  }
}
