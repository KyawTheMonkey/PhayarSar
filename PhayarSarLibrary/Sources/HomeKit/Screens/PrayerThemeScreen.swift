import DesignKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI
import UtilKit

/// Layout constants for `PrayerThemeScreen`.
private enum PrayerThemeMetrics {
  /// Width at which the specimen moves alongside the controls instead of
  /// sitting above them. Only the combined layout can reach it — the two-pass
  /// sheet is never this wide.
  static let twoColumnMinimumWidth: CGFloat = 700

  /// The share of the width the specimen takes when it is beside the controls.
  static let previewColumnFraction: CGFloat = 0.42

  static let previewColumnMinWidth: CGFloat = 260
  static let previewColumnMaxWidth: CGFloat = 460

  /// How tall the specimen card is when it sits above the controls.
  ///
  /// Sized against the specimen at the *default* text size, where one sentence
  /// of the pangram wraps to about six lines. At 200 it showed four of them and
  /// nothing else, which read as the sentence being the whole page; this shows
  /// enough of the next paragraph for the break between them — and therefore
  /// verse spacing — to be visible at the smaller sizes. At the largest sizes
  /// one sentence still fills the card, which is honest: that is what the real
  /// page looks like there too.
  static let previewHeight: CGFloat = 280

  /// Gap between the second pass's title bar and the specimen pinned under it.
  static let specimenTopPadding: CGFloat = 8

  /// How far the pinned head's fill takes to fall away to nothing.
  ///
  /// The controls scroll *under* the specimen, so something has to happen at the
  /// join. A hard edge would read as the list being sliced off; this dissolves
  /// it over roughly the height of a row's label, which is long enough to be a
  /// transition and short enough not to eat the first control.
  static let stickyFadeHeight: CGFloat = 28

  /// The controls sheet's own fill.
  ///
  /// One stop off `AppColor.background`, so the panel separates from the page
  /// behind it while leaving the `AppColor.surface` cards on it as the brightest
  /// thing in the stack. Computed rather than stored: `Color` is not `Sendable`,
  /// and a `static let` of one trips Swift 6's concurrency checking the way the
  /// `PreferenceKey` defaults elsewhere do.
  static var sheetBackground: Color { AppColor.grey100 }

  /// Clearance above the first control and below the last.
  static let controlsTopPadding: CGFloat = 16
  static let controlsBottomPadding: CGFloat = 24

  /// Air above and below the action bar's button.
  static let actionBarTopPadding: CGFloat = 12
  static let actionBarBottomPadding: CGFloat = 8

  // MARK: - Header

  /// The custom header on the passes that have one, in place of a nav bar.
  static let headerTopPadding: CGFloat = 12
  static let headerBottomPadding: CGFloat = 4
  static let closeButtonDiameter: CGFloat = 32

  // MARK: - Font rows

  /// Size of the `ကခဂ` specimen beside a font's name. Large enough to tell the
  /// four faces apart — at body size Jasmine and PangLong are nearly the same
  /// shape — without turning the row into a banner.
  static let fontSpecimenSize: CGFloat = 22

  /// Vertical padding on a font row, giving it a ~52pt target to match
  /// `AppSettingsRow`.
  static let fontRowVerticalPadding: CGFloat = 10

  /// The two `က`s flanking the text-size slider, small and large.
  static let sizeMarkerSmall: CGFloat = 14
  static let sizeMarkerLarge: CGFloat = 24

  // MARK: - Control ranges
  //
  // These are the model's raw values, not display values: `PrayerSettings`
  // stores letter spacing 2 / line spacing 15 / verse spacing 10 as its
  // defaults, and the sliders move those numbers directly.

  static let minTextSize: Double = 14

  /// The ceiling on a phone.
  ///
  /// Past this a line of Burmese stops fitting across the column and the page
  /// turns into two or three words a line, which is harder to recite from than
  /// the smaller setting it was meant to improve on. An iPad has the width to
  /// carry more, so it gets its own ceiling rather than this one.
  static let compactMaxTextSize: Double = 32

  /// The ceiling on an iPad.
  static let regularMaxTextSize: Double = 48

  /// Two points a step, as the reader's own stepper used: one point is a change
  /// nobody can see, and the range is wide enough that it would take forever to
  /// cross. Both ceilings are an even number of steps above ``minTextSize``, so
  /// the top of the track is always reachable.
  static let textSizeStep: Double = 2

  static let letterSpacingRange: ClosedRange<Double> = 0...12
  static let letterSpacingStep: Double = 0.5

  static let lineSpacingRange: ClosedRange<Double> = 0...40
  static let verseSpacingRange: ClosedRange<Double> = 0...40
}

// MARK: - Screen

/// Sets how a prayer is laid out on the page, over the page it is laying out.
///
/// Presented as a sheet from ``PrayerScreen`` and bound to that screen's own
/// settings, so the reader behind reacts as each control moves — the theme cards
/// in the first pass are judged against the real prayer rather than against a
/// sample of it. Apple Books works the same way, and the reader's `settings`
/// state was written for exactly this.
///
/// Two passes on a phone:
///
/// - **Themes & settings** — the pronunciation switch and the three theme cards,
///   at the medium detent so the page stays visible behind it.
/// - **Customize theme** — everything else, at full height. The page is covered
///   at this point, so this pass carries its own specimen (see
///   ``PrayerThemePreview``).
///
/// On iPad both passes are shown at once: a form sheet has the room, and
/// splitting a screenful of controls across two taps there would be ceremony.
///
/// **The two passes keep what they are given differently**, because they are
/// asked different questions.
///
/// The first pass is a choice: a theme, or the respelling on or off. There is
/// nothing to weigh up and nothing to tune, so a tap there is kept on the spot —
/// the same as the identical controls on ``PrayerDetailScreen``, which has no
/// Save button at all. Tapping a theme and closing the sheet has to leave the
/// reader on that theme.
///
/// The second pass is an adjustment: a size, an alignment, three spacings. Those
/// want trying against the real page before they are settled, so they reach the
/// page as they move and reach the store only on **Save**. Swiping the sheet away
/// leaves them on the page for the rest of the session and writes nothing.
public struct PrayerThemeScreen: View {
  @ObserveInjection private var injectionObserver

  /// The reader's own configuration. Written straight through, which is what
  /// makes the page behind react.
  @Binding private var configuration: PrayerConfiguration

  /// Which prayer is being set, so ``save()`` knows what to write against.
  private let prayerID: Prayer.ID

  /// The drawing half of ``configuration``, which is all most of this sheet
  /// touches — the theme cards are the only controls that also move the slot.
  ///
  /// `nonmutating` because it writes through the binding rather than into this
  /// view, so the page behind still reacts to every control.
  private var settings: PrayerSettings {
    get { configuration.settings }
    nonmutating set { configuration.settings = newValue }
  }

  /// The second pass, when it is open.
  @State private var path: [Pass] = []

  @State private var detent: PresentationDetent = .medium

  /// The appearance the app is actually in, whether that came from the system
  /// or from the reader's own override — `PhayarSarApp` applies
  /// `preferredColorScheme` at the root, so this sees both.
  @Environment(\.colorScheme) private var colorScheme

  @Environment(\.dismiss) private var dismiss

  #if os(macOS)
  private var isRegular: Bool { true }
  #else
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  /// Whether to show both passes at once.
  ///
  /// The size class rather than a measured width, unusually for this codebase:
  /// what is being decided here is the *flow* — one pass or two — not how a
  /// piece of content lays out in the room it was given. A form sheet on iPad is
  /// regular at every size it can be presented at, which is the answer wanted.
  private var isRegular: Bool { horizontalSizeClass == .regular }
  #endif

  public init(configuration: Binding<PrayerConfiguration>, prayerID: Prayer.ID) {
    _configuration = configuration
    self.prayerID = prayerID
  }

  /// The second pass, as a route rather than a flag, so the sheet's back button
  /// and its detent can be driven from one place.
  private enum Pass: Hashable {
    case customize
  }

  public var body: some View {
    Group {
      if isRegular {
        Combined()
      } else {
        TwoPass()
      }
    }
    .background(PrayerThemeMetrics.sheetBackground.ignoresSafeArea())
    .onAppear(perform: clampTextSize)
    .onValueChange(colorScheme, perform: followAppearance)
    // Only the discrete choices tick. A slider crossing a detent every few
    // milliseconds under the finger would be a buzz, not feedback.
    .appSelectionFeedback(trigger: DiscreteChoices(configuration: configuration))
    .enableInjection()
  }

  // MARK: - Flow

  /// Phone: the two passes, in a stack of their own inside the sheet.
  @ViewBuilder
  private func TwoPass() -> some View {
    NavigationStack(path: $path) {
      QuickPass()
        .navigationDestination(for: Pass.self) { _ in
          CustomizePass()
        }
    }
    // Two stops: half up and all the way. There is deliberately no third,
    // shallower one — a sheet that stopped at a sliver of itself left a strip of
    // chrome sitting on the page with nothing on it, and dragging down is the
    // gesture people already reach for to be rid of a sheet, not to park one.
    .presentationDetents([.medium, .large], selection: $detent)
    .presentationDragIndicator(.visible)
    // Dismissal is deliberately *not* disabled: the reader's toolbar menu opens
    // this again in one tap, so there is nothing to protect them from losing.
    .undimmedThroughMediumDetent()
  }

  /// iPad: one pass with everything in it.
  @ViewBuilder
  private func Combined() -> some View {
    VStack(spacing: 0) {
      Header(title: L10n.themeAndSettings, leading: .none)

      GeometryReader { proxy in
        if proxy.size.width >= PrayerThemeMetrics.twoColumnMinimumWidth {
          WideBody(width: proxy.size.width)
        } else {
          NarrowBody()
        }
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      ActionBar()
    }
  }

  @ViewBuilder
  private func NarrowBody() -> some View {
    ScrollView {
      VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        Specimen()
          .frame(height: PrayerThemeMetrics.previewHeight)
          .appHorizontalInset()

        QuickControls()
        DetailControls()
      }
      .padding(.top, PrayerThemeMetrics.controlsTopPadding)
      .padding(.bottom, PrayerThemeMetrics.controlsBottomPadding)
    }
  }

  @ViewBuilder
  private func WideBody(width: CGFloat) -> some View {
    let previewWidth = min(
      max(
        width * PrayerThemeMetrics.previewColumnFraction,
        PrayerThemeMetrics.previewColumnMinWidth
      ),
      PrayerThemeMetrics.previewColumnMaxWidth
    )

    HStack(spacing: 0) {
      ScrollView {
        VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
          QuickControls()
          DetailControls()
        }
        .padding(.top, PrayerThemeMetrics.controlsTopPadding)
        .padding(.bottom, PrayerThemeMetrics.controlsBottomPadding)
      }

      // A hairline, like every other edge in the app.
      Rectangle()
        .fill(AppColor.border)
        .frame(width: 0.5)

      Specimen()
        .padding(AppListSectionMetrics.compactHorizontalInset)
        .frame(width: previewWidth)
    }
  }

  // MARK: - Pass one

  /// The quick pass: what someone opening this sheet mid-prayer almost always
  /// came for, and nothing else.
  @ViewBuilder
  private func QuickPass() -> some View {
    ScrollView {
      QuickControls()
        .padding(.top, PrayerThemeMetrics.controlsTopPadding)
        .padding(.bottom, PrayerThemeMetrics.controlsBottomPadding)
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      // Its own header rather than the stack's nav bar: this pass sits at the
      // medium detent, where a full navigation bar would spend a quarter of the
      // visible sheet saying what the reader just tapped.
      Header(title: L10n.themeAndSettings, leading: .none)
        .background(PrayerThemeMetrics.sheetBackground)
    }
    .hideNavBar()
  }

  @ViewBuilder
  private func QuickControls() -> some View {
    VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
      PrayerPronunciationSection(isOn: pronunciation)
      PrayerThemeSection(selection: configuration.themeSlot, onSelect: select)

      if !isRegular {
        CustomizeRow()
      }
    }
  }

  // MARK: - Pass two

  @ViewBuilder
  private func CustomizePass() -> some View {
    ScrollView {
      DetailControls()
        // No top padding: the fade at the foot of the pinned head above already
        // leaves the first section its air, and adding more here would open a
        // gap the specimen appears to float over.
        .padding(.bottom, PrayerThemeMetrics.controlsBottomPadding)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      ActionBar()
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      PinnedHead()
    }
    .hideNavBar()
    .background(PrayerThemeMetrics.sheetBackground.ignoresSafeArea())
  }

  /// The second pass's title bar and specimen, held still while the controls
  /// scroll beneath them.
  ///
  /// Pinned because the specimen is the reason this pass exists: the page is
  /// behind a full-height sheet by now, so this is the only thing left showing
  /// what a slider is doing, and a preview you have to scroll back up to is not
  /// a preview.
  ///
  /// The fill stops at the specimen and a gradient carries it the rest of the
  /// way down, so the controls dissolve as they pass under instead of being cut
  /// off against an edge. Not `AppFadeBlurBackground`, which is built to sit
  /// over `AppBackgroundGradient` and washes with `AppColor.background` — on
  /// this sheet's flat `grey100` that reads as a second, wrongly-tinted panel.
  @ViewBuilder
  private func PinnedHead() -> some View {
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        Header(title: L10n.customizeTheme, leading: .back)

        Specimen()
          .frame(height: PrayerThemeMetrics.previewHeight)
          .appHorizontalInset()
          .padding(.top, PrayerThemeMetrics.specimenTopPadding)
      }
      .background(PrayerThemeMetrics.sheetBackground)

      LinearGradient(
        colors: [
          PrayerThemeMetrics.sheetBackground,
          PrayerThemeMetrics.sheetBackground.opacity(0)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: PrayerThemeMetrics.stickyFadeHeight)
      // Decorative, and it lies over the top of the scrolling controls — without
      // this it would swallow taps meant for the first row under it.
      .allowsHitTesting(false)
    }
  }

  @ViewBuilder
  private func DetailControls() -> some View {
    VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
      Fonts()
      TextSize()
      AlignmentPicker()
      Spacing()
      Reset()
    }
  }

  // MARK: - Header

  /// What sits at the leading edge of a pass's header.
  private enum HeaderLeading {
    case none
    case back
  }

  /// A pass's title bar.
  ///
  /// The close button is on the trailing edge in both passes, where Books puts
  /// it and where a thumb on a phone can reach it.
  @ViewBuilder
  private func Header(title: String, leading: HeaderLeading) -> some View {
    HStack(spacing: 12) {
      if leading == .back {
        CircleButton(systemImage: "chevron.left") {
          path.removeAll()
          detent = .medium
        }
      }

      Text(title)
        .font(AppFont.title)
        .foregroundStyle(AppColor.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Spacer(minLength: 8)

      CircleButton(systemImage: "xmark") {
        dismiss()
      }
    }
    .appHorizontalInset()
    .padding(.top, PrayerThemeMetrics.headerTopPadding)
    .padding(.bottom, PrayerThemeMetrics.headerBottomPadding)
  }

  private func CircleButton(systemImage: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(AppColor.textSecondary)
        .frame(
          width: PrayerThemeMetrics.closeButtonDiameter,
          height: PrayerThemeMetrics.closeButtonDiameter
        )
        .background(AppColor.grey200, in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(PressableButtonStyle())
  }

  /// The way into the second pass.
  @ViewBuilder
  private func CustomizeRow() -> some View {
    AppListSection(contentInsets: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)) {
      Button {
        path = [.customize]
        // The specimen and six controls need the room, and arriving at a
        // half-height sheet the reader then has to drag would be a step they
        // did not ask for.
        detent = .large
      } label: {
        AppSettingsRowLabel(L10n.customize, systemImage: "slider.horizontal.3")
      }
      .buttonStyle(PressableButtonStyle(pressedScale: 1))
    }
  }

  // MARK: - Specimen

  private func Specimen() -> some View {
    PrayerThemePreview(settings: settings)
  }

  // MARK: - Font

  @ViewBuilder
  private func Fonts() -> some View {
    AppListSection(L10n.font) {
      ForEach(Array(PrayerSettings.Face.allCases.enumerated()), id: \.element) { index, face in
        if index > 0 {
          Divider()
        }

        FontRow(face)
      }
    }
  }

  @ViewBuilder
  private func FontRow(_ face: PrayerSettings.Face) -> some View {
    let isSelected = settings.font == face

    Button {
      apply(\.font, face)
    } label: {
      HStack(spacing: 14) {
        // The specimen is the point of the row — the name tells you what it is
        // called, this tells you what it looks like.
        Text("ကခဂ")
          .font(face.font(size: PrayerThemeMetrics.fontSpecimenSize))
          .foregroundStyle(AppColor.textPrimary)

        Text(face.displayText)
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.textSecondary)

        Spacer(minLength: 8)

        Image(systemName: "checkmark")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(AppColor.primary)
          .opacity(isSelected ? 1 : 0)
      }
      .padding(.vertical, PrayerThemeMetrics.fontRowVerticalPadding)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressableButtonStyle(pressedScale: 1))
    .accessibilityLabel(face.displayText)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  // MARK: - Text size

  /// How large the recited text may be set here.
  ///
  /// The ceiling follows the room available, not the model: the same settings
  /// opened on a phone and on an iPad are the same settings, and only the
  /// largest one worth offering differs between them.
  private var textSizeRange: ClosedRange<Double> {
    let maximum = isRegular
      ? PrayerThemeMetrics.regularMaxTextSize
      : PrayerThemeMetrics.compactMaxTextSize

    return PrayerThemeMetrics.minTextSize...maximum
  }

  /// The model stores whole points; the slider works in `Double`.
  ///
  /// Clamped on the way in as well as out. A value set on an iPad can be larger
  /// than a phone offers, and a `Slider` handed a value past the end of its own
  /// range draws its thumb off the track.
  private var textSize: Binding<Double> {
    Binding(
      get: { clamped(Double(settings.textSize)) },
      set: { apply(\.textSize, Int(clamped($0).rounded())) }
    )
  }

  private func clamped(_ size: Double) -> Double {
    min(max(size, textSizeRange.lowerBound), textSizeRange.upperBound)
  }

  /// Brings a size set somewhere roomier back within what this screen offers.
  ///
  /// Without it the slider would sit pinned at its maximum while the page behind
  /// stayed larger than the control claimed — the reading would be right and the
  /// number under it a lie.
  private func clampTextSize() {
    let clamped = Int(clamped(Double(settings.textSize)))

    if clamped != settings.textSize {
      settings.textSize = clamped
    }
  }

  @ViewBuilder
  private func TextSize() -> some View {
    AppListSection {
      // A custom header so the current size can sit on the same line as the
      // label, the way the spec grid on the detail screen reports it.
      HStack {
        Text(L10n.textSize)

        Spacer()

        Text("\(settings.textSize)")
          // Opts out of the header's uppercasing — a number has no case, and
          // the modifier would fight the monospaced digits.
          .textCase(nil)
          .monospacedDigit()
      }
    } content: {
      HStack(spacing: 14) {
        // Set in the chosen face rather than in the UI font, so the two markers
        // double as a hint at what the page will look like. Burmese rather than
        // "Aa" — the Myanmar faces have no Latin of their own to show.
        Text("က")
          .font(settings.font.font(size: PrayerThemeMetrics.sizeMarkerSmall))
          .foregroundStyle(AppColor.textTertiary)

        Slider(
          value: textSize,
          in: textSizeRange,
          step: PrayerThemeMetrics.textSizeStep
        )
        .tint(AppColor.primary)

        Text("က")
          .font(settings.font.font(size: PrayerThemeMetrics.sizeMarkerLarge))
          .foregroundStyle(AppColor.textSecondary)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(L10n.textSize)
      .accessibilityValue("\(settings.textSize)")
    } footer: {
      EmptyView()
    }
  }

  // MARK: - Alignment

  /// Named apart from SwiftUI's `Alignment`, which this file would otherwise
  /// shadow for every later reader of it.
  @ViewBuilder
  private func AlignmentPicker() -> some View {
    AppListSection(L10n.textAlignment) {
      AppSegmentedPicker(
        selection: binding(\.alignment),
        items: PrayerSettings.Alignment.allCases,
        size: .regular
      ) { alignment in
        // The glyph says which one this is more directly than the word does,
        // and it says it in every language.
        Image(systemName: alignment.systemImage)
          .accessibilityLabel(alignment.displayText)
      }
    }
  }

  // MARK: - Spacing

  @ViewBuilder
  private func Spacing() -> some View {
    AppListSection(L10n.spacing) {
      VStack(spacing: AppSliderRowMetrics.rowSpacing) {
        AppSliderRow(
          L10n.letterSpacing,
          systemImage: "arrow.left.and.right",
          value: binding(\.letterSpacing),
          in: PrayerThemeMetrics.letterSpacingRange,
          step: PrayerThemeMetrics.letterSpacingStep
        )

        AppSliderRow(
          L10n.lineSpacing,
          systemImage: "arrow.up.and.down",
          value: binding(\.lineSpacing),
          in: PrayerThemeMetrics.lineSpacingRange
        )

        AppSliderRow(
          L10n.verseSpacing,
          systemImage: "text.quote",
          value: binding(\.verseSpacing),
          in: PrayerThemeMetrics.verseSpacingRange
        )
      }
    }
  }

  // MARK: - Reset

  /// Back to the first theme, untouched.
  ///
  /// Compares the resolved settings rather than just the slot, because being on
  /// a theme does not mean being *at* it — the reader can sit on Classic with a
  /// face and a line spacing of their own, and that is a state reset still has
  /// something to undo.
  @ViewBuilder
  private func Reset() -> some View {
    let first = PrayerTheme.first
    let isDefault = configuration.themeSlot == .one
      && settings == defaultSettings(for: first)

    // `.plain`, not `.secondary`: the action bar pinned below this already has a
    // tinted button in it, and two slabs a few points apart would give undoing
    // the same weight as keeping.
    AppButton(
      L10n.resetTheme,
      systemImage: "arrow.counterclockwise",
      kind: .plain
    ) {
      // Not `select(first)`, which would only change the face — reset has to put
      // the size, alignment and spacings back as well.
      configuration.themeSlot = first.slot
      settings = defaultSettings(for: first)
    }
    .disabled(isDefault)
    // Dimmed rather than hidden: a button that vanished once everything was
    // default would take the row's height with it and shuffle the page.
    .opacity(isDefault ? 0.4 : 1)
    .appHorizontalInset()
  }

  // MARK: - Actions

  /// The way out of the editor.
  ///
  /// One button, not the pair there used to be: "Save and start" made sense when
  /// this was opened from the detail screen with the prayer still ahead of the
  /// reader. Opened from inside the reader there is nothing left to start.
  @ViewBuilder
  private func ActionBar() -> some View {
    AppButton(L10n.save) {
      save()
    }
    .appHorizontalInset()
    .padding(.top, PrayerThemeMetrics.actionBarTopPadding)
    .padding(.bottom, PrayerThemeMetrics.actionBarBottomPadding)
    .background {
      // `AppFadeBlurBackground` is built for a top bar — strongest at its top
      // edge, fading downward. Turning it over puts the solid end against the
      // screen's bottom and the fade against the content, which is what a
      // bottom bar needs. Same treatment as `PrayerDetailScreen.StartBar`.
      AppFadeBlurBackground()
        .rotationEffect(.degrees(180))
        .ignoresSafeArea(edges: .bottom)
    }
  }

  // MARK: - Editing

  /// Changes one setting.
  ///
  /// Note what this does *not* do: it does not clear
  /// ``PrayerConfiguration/themeSlot``. A theme is a
  /// preset, so picking Classic and then setting it in PangLong leaves the
  /// reader on Classic — in PangLong. The card stays lit because the theme is
  /// still what the page was built from.
  private func apply<Value>(_ keyPath: WritableKeyPath<PrayerSettings, Value>, _ value: Value) {
    settings[keyPath: keyPath] = value
  }

  private func binding<Value>(_ keyPath: WritableKeyPath<PrayerSettings, Value>) -> Binding<Value> {
    Binding(
      get: { settings[keyPath: keyPath] },
      set: { apply(keyPath, $0) }
    )
  }

  /// Applies a theme: its face and its paper.
  ///
  /// Everything else is left exactly as the reader had it. A theme is a paper
  /// and a face, so someone trying all three keeps the size, alignment and
  /// spacing they have tuned.
  private func select(_ theme: PrayerTheme) {
    configuration.themeSlot = theme.slot
    settings.font = theme.font
    // Through the resolver rather than `theme.page(for:)` directly, so that the
    // paper is decided in one place for every screen that shows a prayer.
    configuration = configuration.resolvingBackground(for: colorScheme)

    // A theme is a face and a paper, so both halves of it are kept — the face
    // even though it is otherwise the second pass's to change. The paper is not
    // stored at all; it is resolved from the slot.
    keep {
      $0.themeSlot = theme.slot
      $0.settings.font = theme.font
    }
  }

  /// The respelling switch: writes through to the page, and keeps the choice.
  private var pronunciation: Binding<Bool> {
    Binding(
      get: { settings.showsPronunciation },
      set: { isOn in
        settings.showsPronunciation = isOn
        keep { $0.settings.showsPronunciation = isOn }
      }
    )
  }

  /// What the page looks like on a theme with nothing else changed — the
  /// standard settings, wearing that theme's face and paper.
  private func defaultSettings(for theme: PrayerTheme) -> PrayerSettings {
    var resolved = PrayerSettings.standard
    resolved.font = theme.font
    resolved.background = theme.page(for: colorScheme)
    return resolved
  }

  /// Moves the page to the other half of its theme when the appearance changes.
  ///
  /// The pairing, in one line: a reader on the second theme in daylight is on
  /// the second theme after dark too, and only the paper under them changes.
  private func followAppearance() {
    configuration = configuration.resolvingBackground(for: colorScheme)
  }

  /// Keeps one of the first pass's choices, on the spot.
  ///
  /// Changes the *stored* configuration rather than saving the live one, which
  /// matters when the reader has been into the second pass: a size or a spacing
  /// they have moved but not saved is still on the page, and committing it as a
  /// side effect of tapping a theme would take the second pass's Save away from
  /// them. Only the fields named in `change` are kept; everything else stays as
  /// the store already had it.
  private func keep(_ change: (inout PrayerConfiguration) -> Void) {
    var stored = PrayerConfigurationStore.shared.configuration(for: prayerID)
    change(&stored)
    PrayerConfigurationStore.shared.save(stored, for: prayerID)
  }

  /// Keeps the reader's choices, against this prayer.
  ///
  /// Writes the configuration whole, which is what settles the second pass — the
  /// first pass's choices are already in the store by the time this runs, and
  /// writing them again costs nothing.
  ///
  /// This is what makes swiping the sheet away a way to back out of an
  /// adjustment: the screen that presented this reloads from the store on
  /// dismiss either way, so a save is picked up and an abandoned experiment is
  /// dropped, with no "did they save?" flag between them.
  private func save() {
    PrayerConfigurationStore.shared.save(configuration, for: prayerID)
    dismiss()
  }

  /// The choices a tap can change, as opposed to the ones a drag can.
  ///
  /// Grouped into one value so the whole sheet can tick from a single place,
  /// which is what ``SwiftUI/View/appSelectionFeedback(trigger:)`` asks for.
  ///
  /// The paper is deliberately absent: it moves on its own when the appearance
  /// changes, and a haptic for something the reader did not just do would read
  /// as the app twitching.
  private struct DiscreteChoices: Equatable {
    let slot: PrayerThemeSlot
    let font: PrayerSettings.Face
    let alignment: PrayerSettings.Alignment
    let showsPronunciation: Bool

    init(configuration: PrayerConfiguration) {
      slot = configuration.themeSlot
      font = configuration.settings.font
      alignment = configuration.settings.alignment
      showsPronunciation = configuration.settings.showsPronunciation
    }
  }
}

// MARK: - Availability shims

extension View {
  /// Stops a sheet dimming what is behind it, and lets that be touched, while
  /// the sheet is no taller than its medium detent.
  ///
  /// Without it the page the sheet is editing sits under a scrim, which is the
  /// one thing this sheet cannot afford — the reader would be judging colour and
  /// contrast through a grey wash.
  ///
  /// A shim, because `presentationBackgroundInteraction` is iOS 16.4 and the
  /// package ships to 16.0. Below that the page is dimmed at every detent:
  /// still legible, just darker, and there is nothing back-deployable to reach
  /// for.
  @ViewBuilder
  fileprivate func undimmedThroughMediumDetent() -> some View {
    if #available(iOS 16.4, macOS 13.3, *) {
      presentationBackgroundInteraction(.enabled(upThrough: .medium))
    } else {
      self
    }
  }
}

// MARK: - Previews

#Preview("Editor") {
  PrayerThemeScreenPreview()
}

private struct PrayerThemeScreenPreview: View {
  @State private var configuration: PrayerConfiguration = .standard

  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    PrayerThemeScreen(configuration: $configuration, prayerID: "Khandha")
  }
}
