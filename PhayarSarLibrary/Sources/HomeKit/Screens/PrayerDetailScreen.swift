import DesignKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI
import UtilKit

/// Layout constants for `PrayerDetailScreen`.
private enum PrayerDetailMetrics {
  /// Cover art. Square and roughly half the width of a phone, so the hero reads
  /// as artwork rather than as an oversized list thumbnail.
  static let coverSize: CGFloat = 176
  static let coverCornerRadius: CGFloat = 28

  /// Gap between the cover and the title block beneath it.
  static let heroSpacing: CGFloat = 20

  /// Width reserved for a quick action's leading icon. The glyphs vary in width
  /// — a calendar is far wider than a chevron — so they get a fixed column and
  /// the labels beside them stay aligned down the card.
  static let rowIconColumnWidth: CGFloat = 24

  /// Space above and below a quick action's content. The rows own their own
  /// vertical rhythm — the section is handed zero vertical content insets — so
  /// between two rows this reads as 14 above and 14 below the divider, and at
  /// the card's edges as a single 14.
  static let rowVerticalPadding: CGFloat = 14

  /// Diameter of the page-colour swatch on the background spec. Sized to the
  /// cap height of `AppFont.statValue` beside it, so the two read as one line
  /// rather than as a dot next to some text.
  static let swatchDiameter: CGFloat = 18

  /// Gutter between spec columns.
  static let specColumnSpacing: CGFloat = 12

  /// Gap between spec rows. Wider than the gutter so the grid reads down in
  /// columns rather than across in a block.
  static let specRowSpacing: CGFloat = 20

  /// The width a spec column wants to be. The count is chosen by rounding to
  /// whatever lands nearest this, not by fitting as many as clear some floor —
  /// a floor lets the last column that fits stretch to nearly twice the minimum
  /// before another one earns its place, which is how a 442pt card ends up
  /// showing two 215pt columns instead of three 139pt ones.
  static let idealSpecColumnWidth: CGFloat = 165

  /// Two columns even on the narrowest phone — a single column would just be
  /// the list layout again.
  static let minSpecColumns = 2

  /// Past four the specs stop reading as pairs of related settings and start
  /// reading as a strip of loose numbers.
  static let maxSpecColumns = 4

  /// Fixed box around a spec's glyph. The glyphs differ in width by nearly 2×,
  /// so without a shared box the labels beside them would start at a different
  /// x in every cell.
  static let specIconBoxWidth: CGFloat = 16

  static let ctaCornerRadius: CGFloat = 16

  /// How much of the about text shows before the "Show more" toggle takes over.
  static let aboutCollapsedLineLimit = 5

  /// Above this many characters the about text is assumed not to fit in
  /// ``aboutCollapsedLineLimit`` lines, and the toggle is offered.
  ///
  /// A count rather than a real truncation measurement: `ViewThatFits` can't
  /// decide this inside a `ScrollView`, which proposes unbounded height, so
  /// every candidate would "fit". The threshold sits well above the ~200
  /// characters five lines actually hold, which biases towards not showing a
  /// toggle that would reveal nothing.
  static let aboutExpandThreshold = 240
}

public struct PrayerDetailScreen: View {
  @ObserveInjection private var injectionObserver

  /// Resolved from the id the route carried rather than passed in whole — see
  /// `RouterDestination`, whose payloads are ids so that routes stay `Codable`.
  private let prayer: Prayer?

  public init(prayerID: String) {
    self.prayer = PrayerCatalog.shared.prayer(id: prayerID)
  }

  public var body: some View {
    Group {
      if let prayer {
        PrayerContent(prayer)
      } else {
        PrayerNotFoundView()
      }
    }
    .navigationTitle(prayer?.title ?? L10n.prayerNotFound)
    // No navigation bar on macOS, so no display mode to set either.
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    // The reading CTA owns the bottom of this screen; the tab bar under it
    // would compete for the same thumb. Restored on pop by the modifier itself.
    .hideTabBar()
    .appBackground()
    .enableInjection()
  }

  // MARK: - Content

  @ViewBuilder
  private func PrayerContent(_ prayer: Prayer) -> some View {
    ScrollView {
      VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        Hero(prayer)

        if !prayer.about.isEmpty {
          PrayerAboutSection(about: prayer.about)
        }

        QuickActions()
        ReadingSettings(prayer)
      }
      .padding(.top, 8)
      .padding(.bottom, AppListSectionMetrics.recommendedSectionSpacing)
    }
    .safeAreaInset(edge: .bottom) {
      StartBar()
    }
  }

  // MARK: - Hero

  @ViewBuilder
  private func Hero(_ prayer: Prayer) -> some View {
    VStack(spacing: PrayerDetailMetrics.heroSpacing) {
      RoundedRectangle(
        cornerRadius: PrayerDetailMetrics.coverCornerRadius,
        style: .continuous
      )
      .fill(AppColor.grey300)
      .frame(
        width: PrayerDetailMetrics.coverSize,
        height: PrayerDetailMetrics.coverSize
      )
      .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
      .accessibilityHidden(true)

      VStack(spacing: 12) {
        Text(prayer.title)
          .font(AppFont.title)
          .foregroundStyle(AppColor.textPrimary)
          .multilineTextAlignment(.center)

        HStack(spacing: 8) {
          MetaChip(
            icon: "clock",
            text: "\(prayer.estimatedMinutes) \(L10n.minutesUnit)",
            accessibilityLabel: "\(L10n.duration), \(prayer.estimatedMinutes) \(L10n.minutesUnit)"
          )

          MetaChip(
            icon: "list.bullet",
            text: "\(prayer.body.count) \(L10n.verses)",
            accessibilityLabel: "\(prayer.body.count) \(L10n.verses)"
          )
        }
      }
    }
    .frame(maxWidth: .infinity)
    .appHorizontalInset()
  }

  // MARK: - Quick actions

  /// The quick actions, in tap order. Nissaya sits with Add to plan because
  /// both act on the prayer itself; the two below it are about the app's
  /// handling of it.
  ///
  /// No destinations yet: `RouterDestination` and `SheetDestination` don't
  /// carry these screens, so the rows are wired but land nowhere until they do.
  private var quickActions: [(icon: String, title: String)] {
    [
      ("calendar.badge.plus", L10n.addToPlan),
      ("character.book.closed", L10n.nissaya),
      ("paintpalette", L10n.themeAndSettings),
      ("exclamationmark.bubble", L10n.reportError)
    ]
  }

  @ViewBuilder
  private func QuickActions() -> some View {
    // Zero vertical insets: `QuickActionRow` pads its own rows, so the section
    // adding more would double the gap at the first and last row.
    AppListSection(
      L10n.quickActions,
      contentInsets: EdgeInsets(
        top: 0,
        leading: AppListSectionMetrics.contentInsets.leading,
        bottom: 0,
        trailing: AppListSectionMetrics.contentInsets.trailing
      )
    ) {
      ForEach(Array(quickActions.enumerated()), id: \.offset) { index, action in
        if index > 0 {
          Divider()
        }

        QuickActionRow(icon: action.icon, title: action.title) {}
      }
    }
  }

  // MARK: - Reading settings

  /// What this prayer is currently set to be read with.
  ///
  /// A two-column grid of specs rather than the labelled rows the sections
  /// above use — this is a spec sheet, not a menu. Nothing here is tappable
  /// ("Theme & settings" above is where these get changed), so rows that looked
  /// like the tappable ones would be promising something they don't do.
  ///
  /// The numbers are unitless on purpose: they are the reader's own scale, and
  /// labelling them "pt" would imply a precision the sliders don't have.
  @ViewBuilder
  private func ReadingSettings(_ prayer: Prayer) -> some View {
    AppListSection(L10n.prayerSettings) {
      PrayerSpecGrid(settings: PrayerSettings.settings(for: prayer.id))
    }
  }

  // MARK: - Start CTA

  @ViewBuilder
  private func StartBar() -> some View {
    Button {
      // The reading screen doesn't exist yet.
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "play.fill")
        Text(L10n.startReading)
      }
      .font(AppFont.headline)
      .foregroundStyle(AppColor.buttonPrimaryText)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background(
        AppColor.buttonPrimaryBackground,
        in: RoundedRectangle(
          cornerRadius: PrayerDetailMetrics.ctaCornerRadius,
          style: .continuous
        )
      )
    }
    .buttonStyle(PressableButtonStyle())
    .appHorizontalInset()
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background {
      // `AppFadeBlurBackground` is built for a top bar — strongest at its top
      // edge, fading downward. Turning it over puts the solid end against the
      // screen's bottom and the fade against the content, which is what a
      // bottom bar needs.
      AppFadeBlurBackground()
        .rotationEffect(.degrees(180))
        .ignoresSafeArea(edges: .bottom)
    }
  }
}

// MARK: - Pieces

/// The prayer's background text, clamped to a few lines with a toggle when it
/// runs long.
///
/// A view of its own rather than a method on the screen so that it owns the
/// expansion state. Held on the screen, a tap would re-evaluate the whole
/// screen's `body` — the hero's shadowed cover art and the CTA's masked
/// material blur included — none of which has anything to do with this toggle.
private struct PrayerAboutSection: View {
  private let about: String

  /// Settled at init rather than read from `body`. `String.count` walks the
  /// whole string with Unicode segmentation (0.15ms for the longest `about` on
  /// a Mac), and `body` runs far more often than this text changes, which is
  /// never.
  private let canExpand: Bool

  @State private var isExpanded = false

  init(about: String) {
    self.about = about
    self.canExpand = about.count > PrayerDetailMetrics.aboutExpandThreshold
  }

  var body: some View {
    AppListSection(L10n.prayerAbout) {
      VStack(alignment: .leading, spacing: 12) {
        Text(about)
          .font(AppFont.body)
          .foregroundStyle(AppColor.textSecondary)
          // Burmese script stacks diacritics above and below the baseline, so
          // the default leading crowds consecutive lines.
          .lineSpacing(6)
          .lineLimit(isExpanded ? nil : PrayerDetailMetrics.aboutCollapsedLineLimit)
          .frame(maxWidth: .infinity, alignment: .leading)

        if canExpand {
          // Bare toggle, no `withAnimation`. Animating a line-limit change
          // animates the paragraph's height, and SwiftUI re-runs the text
          // layout at every intermediate height it passes through — thousands
          // of characters of Burmese, reshaped once a frame for the whole
          // transition. That was the hitch. Snapping the reflow lays the text
          // out once; the chevron below carries the motion instead.
          Button {
            withAnimation(.smooth) {
              isExpanded.toggle()
            }
          } label: {
            HStack(spacing: 4) {
              Text(isExpanded ? L10n.showLess : L10n.showMore)
              Image(systemName: "chevron.down")
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .font(AppFont.button)
            .foregroundStyle(AppColor.primary)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

/// A capsule of one fact about the prayer — its length, its size.
private struct MetaChip: View {
  let icon: String
  let text: String
  /// The icon carries meaning the label doesn't spell out, so VoiceOver is
  /// given the full phrase rather than the bare number.
  let accessibilityLabel: String

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: icon)
        .font(AppFont.caption)
      Text(text)
        .font(AppFont.caption)
    }
    .foregroundStyle(AppColor.textSecondary)
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    .background(AppColor.surface, in: Capsule(style: .continuous))
    .overlay(Capsule(style: .continuous).strokeBorder(AppColor.border, lineWidth: 0.5))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }
}

/// Width available to the spec grid, for deciding how many columns fit.
private struct SpecGridWidthKey: PreferenceKey {
  static var defaultValue: CGFloat { 0 }

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// The reading settings laid out as a spec grid, in as many columns as the
/// card is wide enough for.
private struct PrayerSpecGrid: View {
  let settings: PrayerSettings

  /// Measured rather than taken from `horizontalSizeClass`. On iPad this screen
  /// sits in a split view's detail column, so the window being regular width
  /// says nothing about how much room this card actually got — and on macOS the
  /// size class is regular at every window size, including tiny ones.
  @State private var width: CGFloat = 0

  private var columnCount: Int {
    guard width > 0 else { return PrayerDetailMetrics.minSpecColumns }

    // n columns occupy n * ideal + (n - 1) * spacing, so this is that solved
    // for n and rounded to the nearest whole column rather than floored.
    let spacing = PrayerDetailMetrics.specColumnSpacing
    let ideal = (width + spacing) / (PrayerDetailMetrics.idealSpecColumnWidth + spacing)

    return min(
      max(Int(ideal.rounded()), PrayerDetailMetrics.minSpecColumns),
      PrayerDetailMetrics.maxSpecColumns
    )
  }

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(
        .flexible(),
        spacing: PrayerDetailMetrics.specColumnSpacing,
        alignment: .topLeading
      ),
      count: columnCount
    )
  }

  var body: some View {
    LazyVGrid(
      columns: columns,
      alignment: .leading,
      spacing: PrayerDetailMetrics.specRowSpacing
    ) {
      SpecCell(
        icon: .textSize,
        label: L10n.textSize,
        value: "\(settings.textSize)"
      )

      // The glyph tracks the value rather than naming the spec, so this one can
      // be read without reading.
      SpecCell(
        icon: .alignment(settings.alignment.systemImage),
        label: L10n.textAlignment,
        value: settings.alignment.displayText
      )

      SpecCell(
        icon: .background,
        label: L10n.backgroundColor,
        value: settings.background.displayText,
        swatch: settings.background.color
      )

      SpecCell(
        icon: .letterSpacing,
        label: L10n.letterSpacing,
        value: settings.letterSpacing.settingValueText
      )

      SpecCell(
        icon: .lineSpacing,
        label: L10n.lineSpacing,
        value: settings.lineSpacing.settingValueText
      )

      SpecCell(
        icon: .verseSpacing,
        label: L10n.verseSpacing,
        value: settings.verseSpacing.settingValueText
      )

      SpecCell(
        icon: .pronunciation,
        label: L10n.pronunciation,
        value: settings.showsPronunciation ? L10n.shown : L10n.hidden
      )
    }
    // Safe from feeding back into itself: the grid's width comes from the card
    // around it, not from its contents, so changing the column count can't
    // change the number being measured.
    .background {
      GeometryReader { proxy in
        Color.clear.preference(key: SpecGridWidthKey.self, value: proxy.size.width)
      }
    }
    .onPreferenceChange(SpecGridWidthKey.self) { width = $0 }
  }
}

/// A spec's glyph, with the point size it needs in order to carry the same
/// visual weight as the others.
///
/// SF Symbols are optically matched to *text* at a given point size, not to each
/// other. Rendered at a common size and measured by ink coverage,
/// `circle.lefthalf.filled` — a solid disc — carries 1.34× the ink of the median
/// glyph in this set, while the two spacing arrows are hairlines at 0.88×. Left
/// at one size the disc reads as a bullet and the arrows nearly disappear, so
/// each glyph gets the size that normalises it against the rest.
private struct SpecIcon {
  let systemName: String
  let size: CGFloat

  private init(_ systemName: String, _ size: CGFloat) {
    self.systemName = systemName
    self.size = size
  }

  static let textSize = SpecIcon("textformat.size", 13)
  static let background = SpecIcon("circle.lefthalf.filled", 11)
  static let letterSpacing = SpecIcon("arrow.left.and.right", 15)
  static let lineSpacing = SpecIcon("arrow.up.and.down", 15)
  static let verseSpacing = SpecIcon("text.quote", 12)
  static let pronunciation = SpecIcon("waveform", 13)

  /// The three alignment glyphs measure identically, so which one the setting
  /// resolves to makes no difference to the size.
  static func alignment(_ systemName: String) -> SpecIcon {
    SpecIcon(systemName, 13)
  }
}

/// One reading setting, as a spec: the value it is set to, and the name of the
/// thing it sets.
///
/// Caption first — the glyph and the name of the setting, in one quiet line —
/// then the value beneath it in the cell's only strong weight.
///
/// The value is pushed to the *bottom* of the cell rather than sitting a fixed
/// gap under the caption. Grid rows take the height of their tallest cell, so
/// with the caption on top a label that wraps to two lines in Burmese would
/// otherwise leave its own value sitting lower than its neighbour's. Bottom-
/// aligning puts every value in a row on one line, whatever happened above it.
private struct SpecCell: View {
  let icon: SpecIcon
  let value: String
  let label: String
  /// Shown before the value on the background spec. The page colours are the
  /// one setting whose name ("Grey", "Classic") is worth less than seeing it.
  var swatch: Color?

  init(icon: SpecIcon, label: String, value: String, swatch: Color? = nil) {
    self.icon = icon
    self.label = label
    self.value = value
    self.swatch = swatch
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: 5) {
        Image(systemName: icon.systemName)
          .font(.system(size: icon.size, weight: .medium))
          // Centred in a shared box so the labels all start at the same x,
          // whatever the glyph's own width.
          .frame(width: PrayerDetailMetrics.specIconBoxWidth)

        Text(label)
          .font(AppFont.caption)
          // Burmese labels run longer than the English ones and a column is
          // narrow; without this they'd truncate rather than wrap.
          .fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(AppColor.textTertiary)

      // Carries the minimum gap as well as doing the bottom-aligning, so a
      // one-line caption still clears its value.
      Spacer(minLength: 4)

      HStack(spacing: 6) {
        if let swatch {
          Circle()
            .fill(swatch)
            .frame(
              width: PrayerDetailMetrics.swatchDiameter,
              height: PrayerDetailMetrics.swatchDiameter
            )
            // Both the classic page and the black one would otherwise vanish
            // into the card behind them, depending on the appearance.
            .overlay(Circle().strokeBorder(AppColor.border, lineWidth: 1))
        }

        Text(value)
          .font(AppFont.statValue)
          .foregroundStyle(AppColor.textPrimary)
          .lineLimit(1)
          // Rather than truncate: "Classic" nearly fills a narrow column at this
          // size already, and the Burmese values are longer still — a clipped
          // value defeats the point of the cell.
          .minimumScaleFactor(0.7)
      }
    }
    // `maxHeight` is what lets the `Spacer` above do anything: without it the
    // cell shrinks to its content and never fills the row it was given.
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    // Read as "Text size, 28" rather than as separate stops.
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label), \(value)")
  }
}

extension Double {
  /// A reader setting as it appears in the summary: `15`, not `15.0`, but
  /// `2.5` kept intact if a slider ever lands between two whole numbers.
  fileprivate var settingValueText: String {
    self == rounded() ? String(Int(self)) : String(format: "%.1f", self)
  }
}

/// One quick action: an icon, its label, and a disclosure chevron.
private struct QuickActionRow: View {
  let icon: String
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(AppColor.primary)
          // Fixed width, so the labels still line up down the card even though
          // the glyphs behind them differ in width.
          .frame(width: PrayerDetailMetrics.rowIconColumnWidth, alignment: .leading)

        Text(title)
          .font(AppFont.body)
          .foregroundStyle(AppColor.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textTertiary)
      }
      .padding(.vertical, PrayerDetailMetrics.rowVerticalPadding)
      // After the padding, so the tap target covers the row's full height —
      // and without it the label would only cover the icon and text, leaving
      // the gap before the chevron dead.
      .contentShape(Rectangle())
    }
    // Rows highlight rather than shrink: scaling something this wide reads as
    // the card itself flexing.
    .buttonStyle(PressableButtonStyle(pressedScale: 1))
  }
}

/// `.plain` with the press feedback put back — plain leaves a filled control
/// looking dead under the finger.
private struct PressableButtonStyle: ButtonStyle {
  /// `1` for full-width rows, where only the dimming should show.
  var pressedScale: CGFloat = 0.97

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.7 : 1)
      .scaleEffect(configuration.isPressed ? pressedScale : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

/// Shown when the route's id matches no bundled prayer.
///
/// Reachable state rather than a programmer error: with id-carrying routes, a
/// notification payload or a restored stack can name a prayer that a later
/// build no longer ships.
private struct PrayerNotFoundView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "questionmark.circle")
        .font(.largeTitle)
      Text(L10n.prayerNotFound)
        .multilineTextAlignment(.center)
    }
    .foregroundStyle(.secondary)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Previews

#Preview {
  NavigationStack {
    PrayerDetailScreen(prayerID: "Khandha")
  }
}

#Preview("Long about") {
  NavigationStack {
    PrayerDetailScreen(prayerID: "သရဏဂုံ")
  }
}

#Preview("No about") {
  NavigationStack {
    PrayerDetailScreen(prayerID: "အမျှဝေ")
  }
}

#Preview("Not found") {
  NavigationStack {
    PrayerDetailScreen(prayerID: "no-such-prayer")
  }
}
