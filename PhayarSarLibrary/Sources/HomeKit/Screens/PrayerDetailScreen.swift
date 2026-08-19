import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI
import UtilKit

/// Layout constants for `PrayerDetailScreen`.
private enum PrayerDetailMetrics {
  /// Gap between the carousel and the title block beneath it. Tighter than it
  /// looks — `PrayerCoverMetrics.verticalInset` already sits inside the
  /// carousel's own height.
  static let heroSpacing: CGFloat = 8

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

  /// How far above the CTA the scrolling content starts to dissolve.
  ///
  /// Added to the bar's own measured height, so the ramp always begins clear of
  /// the button rather than part way down it. `AppFadeBlurBackground` behind the
  /// CTA fades too, but only across the bar itself — at `solidStop` 0.55 of a
  /// ~70pt bar that is barely 30pt of ramp, short enough that content arriving
  /// at it reads as meeting an edge. This is the long half of the transition;
  /// the blur is the short, legibility-holding half.
  static let ctaContentFadeHeight: CGFloat = 64

  /// Clearance under the last section.
  ///
  /// `safeAreaInset` already stops the content at the CTA's top edge, but the
  /// fade above begins higher than that — so scrolled to the very bottom, the
  /// last card came to rest *inside* the ramp and never reached full strength.
  /// Padding by the whole fade height lifts it clear whatever the device's
  /// bottom safe area happens to be: about 58pt of daylight on a phone, and on
  /// an iPad — which has no bottom inset to help — still the full 24.
  static var contentBottomClearance: CGFloat {
    AppListSectionMetrics.recommendedSectionSpacing + (ctaContentFadeHeight * 0.5)
  }

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
  @EnvironmentObject private var navigator: AppNavigatorModel

  /// The catalog in order, so the carousel can page through it.
  ///
  /// Cheap to hold whole: `PrayerCatalog` has decoded and cached every prayer
  /// by the time this screen can open, and the array is a reference to that
  /// storage. The neighbours either side of the current prayer are therefore
  /// already in memory — there is nothing to prefetch.
  private let prayers: [Prayer]

  /// Whether the id the route carried names a prayer this build ships. Only the
  /// *opening* id can fail this; every id after it comes from the carousel.
  private let isKnownPrayer: Bool

  /// The prayer the route asked for, kept as a `let` so it survives whatever
  /// the carousel writes to ``selectedID`` while it is finding its place.
  private let openingID: Prayer.ID

  /// Which prayer the screen is currently showing. The carousel writes to it,
  /// and everything else on the screen reads from it.
  @State private var selectedID: Prayer.ID

  /// How this prayer is set to be read.
  ///
  /// Held as state rather than read fresh on every `body`, because the theme
  /// cards below write to it — a theme picked here has to show up in the spec
  /// grid under it, which is the only confirmation this screen can give that the
  /// tap landed.
  ///
  /// This screen has no Save button, so every change here is written to
  /// ``PrayerConfigurationStore`` as it is made. That is also what carries a
  /// theme chosen here into the reader.
  @State private var configuration: PrayerConfiguration

  /// The drawing half of ``configuration``, which is what the grid and the
  /// sections below read.
  private var settings: PrayerSettings { configuration.settings }

  /// The appearance the app is actually in, whether that came from the system or
  /// from the reader's own override.
  @Environment(\.colorScheme) private var colorScheme

  /// How tall the CTA turned out to be, so the content's fade can be anchored
  /// to it. `0` until the first layout pass.
  ///
  /// Measured rather than assumed: the bar is about 70pt at the default text
  /// size, but the button's label grows with Dynamic Type, and a hard-coded
  /// number would put the ramp across the middle of the button at the largest
  /// sizes.
  @State private var ctaHeight: CGFloat = 0

  /// Resolved from the id the route carried rather than passed in whole — see
  /// `RouterDestination`, whose payloads are ids so that routes stay `Codable`.
  public init(prayerID: String) {
    self.prayers = PrayerCatalog.shared.orderedPrayers()
    self.isKnownPrayer = PrayerCatalog.shared.prayer(id: prayerID) != nil
    self.openingID = prayerID
    _selectedID = State(initialValue: prayerID)
    _configuration = State(initialValue: PrayerConfigurationStore.shared.configuration(for: prayerID))
  }

  private var prayer: Prayer? {
    guard isKnownPrayer else { return nil }
    // A dictionary lookup rather than a scan of `prayers` — this is read on
    // every `body` evaluation.
    return PrayerCatalog.shared.prayer(id: selectedID)
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
    // On appear rather than in `init`, which cannot see the appearance — and the
    // paper is resolved from the appearance, so nothing may draw before this.
    .onAppear(perform: followAppearance)
    // The carousel can land on a prayer with settings of its own, so both the
    // grid and the lit card have to follow it rather than stay on the prayer the
    // screen opened with.
    .onValueChange(selectedID, perform: loadConfiguration)
    .onValueChange(colorScheme, perform: followAppearance)
    // Both controls tick, from one value rather than one modifier each — see
    // `appSelectionFeedback(trigger:)`, which asks to be applied to whatever owns
    // the selection.
    .appSelectionFeedback(trigger: DiscreteChoices(configuration: configuration))
    .enableInjection()
  }

  // MARK: - Content

  @ViewBuilder
  private func PrayerContent(_ prayer: Prayer) -> some View {
    ScrollView {
      VStack(spacing: 0) {
        // Outside the animated stack below. The carousel is what *drives* the
        // change, and its covers already scale under the finger — letting the
        // content swap's curve reach them too would fight that.
        PrayerCoverCarousel(
          prayers: prayers,
          openingID: openingID,
          selectedID: $selectedID,
          // The cover at the front is the prayer this screen is about, so
          // tapping it is the CTA — see `StartBar`, which routes identically.
          onOpen: { navigator.navigate(to: .prayer(prayerID: prayer.id)) }
        )

        VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
          TitleBlock(prayer)
            .prayerContentTransition(id: prayer.id)

          if !prayer.about.isEmpty {
            PrayerAboutSection(about: prayer.about)
              // The identity here does double duty: it runs the transition, and
              // it stops the section being reused across a swipe and carrying
              // its expanded state over — which would open the next prayer
              // already unfolded, reading "Show less" over text nobody expanded.
              .prayerContentTransition(id: prayer.id)
          }

          // No transition: the four rows are the same whichever prayer is
          // showing, so replacing them would be motion with nothing behind it.
          // The prayer is still passed in — the rows look identical, but the
          // routes behind them have to follow the carousel.
          QuickActions(prayer)

          // Above the themes rather than below them: this decides how much text
          // is on the page, and a theme only decides what that text looks like.
          Pronunciation()

          // No transition either, and for a sharper reason than the rows above:
          // the three cards are the same three whichever prayer is showing, and
          // blur-swapping them would animate nine identical elements to say
          // nothing. What does change across a swipe — which card is lit — is
          // the one thing a replacement would restart rather than carry.
          Themes()

          ReadingSettings()
            .prayerContentTransition(id: prayer.id)
        }
        .padding(.top, PrayerDetailMetrics.heroSpacing)
        // Drives the transitions above, and carries the sections that aren't
        // transitioning as the ones that are change height around them.
        .animation(.prayerContentSwap, value: prayer.id)
      }
      .padding(.top, 8)
      .padding(.bottom, PrayerDetailMetrics.contentBottomClearance)
    }
    // Applied to the scroll view *before* the CTA is inset below, so the bar
    // itself is outside the mask. Masking after would fade out the button along
    // with the content it is supposed to be sitting above.
    .mask(alignment: .top) {
      VStack(spacing: 0) {
        // Takes everything the ramp doesn't: the content is untouched until it
        // reaches the CTA's neighbourhood.
        Rectangle()

        LinearGradient(
          colors: [.black, .clear],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: ctaHeight + PrayerDetailMetrics.ctaContentFadeHeight)
      }
    }
    .safeAreaInset(edge: .bottom) {
      StartBar(prayer)
        .background {
          GeometryReader { geometry in
            Color.clear.preference(key: CTAHeightKey.self, value: geometry.size.height)
          }
        }
    }
    // Safe from feeding back into itself: the mask above changes what the
    // content looks like, never how tall the bar is.
    .onPreferenceChange(CTAHeightKey.self) { ctaHeight = $0 }
  }

  // MARK: - Title block

  @ViewBuilder
  private func TitleBlock(_ prayer: Prayer) -> some View {
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
    .frame(maxWidth: .infinity)
    .appHorizontalInset()
  }

  // MARK: - Quick actions

  /// The quick actions, in tap order. Nissaya sits with Add to plan because
  /// both act on the prayer itself; the two below it are about the app's
  /// handling of it.
  ///
  /// A `nil` destination is a row that is drawn and tappable but lands nowhere
  /// — `RouterDestination` doesn't carry those screens yet. They stay in the
  /// list rather than being hidden so the section keeps its shape as each one
  /// is built.
  ///
  /// Takes the prayer rather than reading ``selectedID``, so a row can only
  /// ever route to the prayer whose card is actually on screen.
  private func quickActions(
    for prayer: Prayer
  ) -> [(icon: String, title: String, destination: RouterDestination?)] {
    [
      ("calendar.badge.plus", L10n.addToPlan, nil),
      ("character.book.closed", L10n.nissaya, .nissaya(prayerID: prayer.id)),
      ("exclamationmark.bubble", L10n.reportError, nil)
    ]
  }

  @ViewBuilder
  private func QuickActions(_ prayer: Prayer) -> some View {
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
      ForEach(Array(quickActions(for: prayer).enumerated()), id: \.offset) { index, action in
        if index > 0 {
          Divider()
        }

        QuickActionRow(icon: action.icon, title: action.title) {
          guard let destination = action.destination else { return }
          navigator.navigate(to: destination)
        }
      }
    }
  }

  // MARK: - Pronunciation

  /// The respelling switch, the same one the reader's editor carries.
  ///
  /// The one reading setting worth deciding before opening a prayer: everything
  /// else in the spec grid below is judged against the page it applies to, but
  /// whether the respelling is there at all is a question about how the reader
  /// reads, which they can answer without seeing it.
  ///
  /// Writes to the same ``configuration`` the grid reads, so the Pronunciation
  /// cell under it follows the switch — and straight on to the store, since this
  /// screen has no Save button to defer to.
  @ViewBuilder
  private func Pronunciation() -> some View {
    PrayerPronunciationSection(
      isOn: Binding(
        get: { settings.showsPronunciation },
        set: {
          configuration.settings.showsPronunciation = $0
          persist()
        }
      )
    )
  }

  // MARK: - Themes

  /// Setting the page before opening it.
  ///
  /// The same cards the reader's own editor shows (``PrayerThemeSection``), so
  /// that choosing a theme here and changing it mid-prayer are visibly the same
  /// act. Only the theme, though — the six controls behind it belong with the
  /// page they are judged against, which is why the grid below this is a spec
  /// sheet rather than a second editor.
  @ViewBuilder
  private func Themes() -> some View {
    PrayerThemeSection(selection: configuration.themeSlot, onSelect: select)
  }

  // MARK: - Reading settings

  /// What this prayer is currently set to be read with.
  ///
  /// A two-column grid of specs rather than the labelled rows the sections
  /// above use — this is a spec sheet, not a menu. Nothing here is tappable:
  /// these are changed from inside the reader, where the page they describe is
  /// on screen to judge them against, so rows that looked like the tappable ones
  /// would be promising something they don't do.
  ///
  /// The numbers are unitless on purpose: they are the reader's own scale, and
  /// labelling them "pt" would imply a precision the sliders don't have.
  @ViewBuilder
  private func ReadingSettings() -> some View {
    AppListSection(L10n.prayerSettings) {
      PrayerSpecGrid(settings: settings)
    }
  }

  // MARK: - Editing

  /// Applies a theme: its face and its paper, and nothing else.
  ///
  /// The same rule the editor follows — see ``PrayerThemeScreen`` — so that a
  /// size or a spacing the reader has tuned survives trying all three.
  private func select(_ theme: PrayerTheme) {
    configuration.themeSlot = theme.slot
    configuration.settings.font = theme.font
    // Through the resolver rather than `theme.page(for:)` directly, so the paper
    // is decided in one place for every screen that shows a prayer.
    configuration = configuration.resolvingBackground(for: colorScheme)
    persist()
  }

  /// Reads back the prayer the carousel has landed on.
  private func loadConfiguration() {
    configuration = PrayerConfigurationStore.shared
      .configuration(for: selectedID)
      .resolvingBackground(for: colorScheme)
  }

  /// Keeps what the reader just changed.
  ///
  /// Immediately, unlike ``PrayerThemeScreen``, because there is no Save button
  /// here to defer to — the cards and the switch are the whole interaction, and
  /// leaving this screen is not an act of confirmation.
  private func persist() {
    PrayerConfigurationStore.shared.save(configuration, for: selectedID)
  }

  /// What a tap on this screen can change.
  ///
  /// Grouped into one value so the tick fires from a single place. The paper is
  /// deliberately absent: it moves on its own when the appearance changes, and a
  /// haptic for something the reader did not just do would read as the app
  /// twitching. Same shape, and the same reasoning, as ``PrayerThemeScreen``'s.
  private struct DiscreteChoices: Equatable {
    let slot: PrayerThemeSlot
    let showsPronunciation: Bool

    init(configuration: PrayerConfiguration) {
      slot = configuration.themeSlot
      showsPronunciation = configuration.settings.showsPronunciation
    }
  }

  /// Puts the page on the right half of its theme.
  ///
  /// Runs on appear as well as on a change, because the paper is derived rather
  /// than stored — a prayer opened cold in the dark has to resolve its dark paper
  /// before it draws, not only once the appearance changes under it.
  ///
  /// Deliberately does **not** persist. It answers the system, not the reader,
  /// and the paper is a pure function of the stored theme and the appearance —
  /// writing here would stamp the record and push a CloudKit export every time
  /// the lights go out.
  private func followAppearance() {
    configuration = configuration.resolvingBackground(for: colorScheme)
  }

  // MARK: - Start CTA

  @ViewBuilder
  private func StartBar(_ prayer: Prayer) -> some View {
    AppButton(L10n.startReading, systemImage: "play.fill") {
      // Whichever prayer the carousel has landed on, not the one the route
      // opened with.
      navigator.navigate(to: .prayer(prayerID: prayer.id))
    }
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

/// The CTA's measured height, so the content's fade can be anchored to the bar
/// rather than to a guess about how tall it is.
private struct CTAHeightKey: PreferenceKey {
  static var defaultValue: CGFloat { 0 }

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

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

// MARK: - Previews

// The navigator is what "Start" pushes through, so every preview needs one —
// without it the screen traps the moment SwiftUI resolves the environment.
#Preview {
  NavigationStack {
    PrayerDetailScreen(prayerID: "Khandha")
  }
  .environmentObject(AppNavigatorModel())
}

#Preview("Long about") {
  NavigationStack {
    PrayerDetailScreen(prayerID: "သရဏဂုံ")
  }
  .environmentObject(AppNavigatorModel())
}

#Preview("No about") {
  NavigationStack {
    PrayerDetailScreen(prayerID: "အမျှဝေ")
  }
  .environmentObject(AppNavigatorModel())
}

#Preview("Not found") {
  NavigationStack {
    PrayerDetailScreen(prayerID: "no-such-prayer")
  }
  .environmentObject(AppNavigatorModel())
}
