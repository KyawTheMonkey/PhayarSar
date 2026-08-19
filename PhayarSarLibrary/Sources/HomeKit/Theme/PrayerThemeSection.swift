import DesignKit
import LocalisationKit
import PrayersKit
import SwiftUI

// MARK: - Metrics

/// Layout constants for `PrayerThemeSection`.
private enum PrayerThemeCardMetrics {
  /// A theme card's height. Squarer and far larger than a chip — the card *is*
  /// the specimen for its theme, so the face has to be readable at a glance
  /// rather than merely present.
  static let cardHeight: CGFloat = 96
  static let cardCornerRadius: CGFloat = 14
  static let cardSpacing: CGFloat = 12

  /// Size of the `အက` shown on a theme card.
  static let specimenSize: CGFloat = 30

  /// The selected card's border. Heavy enough to read as a ring rather than as
  /// the hairline every unselected card already carries.
  static let selectedBorderWidth: CGFloat = 3
}

// MARK: - Section

/// The three themes as cards, headed and footed as a list section.
///
/// Shared by the two places a theme is picked — the editor sheet
/// (``PrayerThemeScreen``), where the page behind answers the tap, and the
/// prayer's detail screen, where the spec grid under it does. The header and
/// footer are part of this view rather than each caller's, because the pairing
/// the footer explains is a fact about the cards, not about the screen they
/// happen to be on.
///
/// Stateless: the lit card and what a tap does are both the caller's, since the
/// two hosts write a chosen theme to different places.
struct PrayerThemeSection: View {
  /// Which card is lit, or `nil` when the page matches none of the themes.
  ///
  /// A slot rather than a `PrayerSettings`. A reader who picked Classic and then
  /// changed the face is still on Classic, and the card has to say so —
  /// comparing values would drop the highlight the moment anything moved.
  let selection: PrayerThemeSlot?

  let onSelect: (PrayerTheme) -> Void

  /// The appearance the app is actually in, whether that came from the system
  /// or from the reader's own override — `PhayarSarApp` applies
  /// `preferredColorScheme` at the root, so this sees both.
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    AppListSection(L10n.themePresets, footer: L10n.themePairingFooter) {
      // Only one set is ever on screen: the light themes are unreachable in the
      // dark and vice versa, because a light page chosen in the dark would be
      // the thing the appearance switch exists to avoid.
      HStack(spacing: PrayerThemeCardMetrics.cardSpacing) {
        ForEach(PrayerTheme.all) { theme in
          Card(theme)
        }
      }
    }
  }

  @ViewBuilder
  private func Card(_ theme: PrayerTheme) -> some View {
    let page = theme.page(for: colorScheme)
    let isSelected = selection == theme.slot
    let shape = RoundedRectangle(
      cornerRadius: PrayerThemeCardMetrics.cardCornerRadius,
      style: .continuous
    )

    Button {
      onSelect(theme)
    } label: {
      VStack(spacing: 2) {
        // The theme's own face, not the one currently in use — the card has to
        // show what tapping it would give you.
        Text("အက")
          .font(theme.font.font(size: PrayerThemeCardMetrics.specimenSize))

        Text(page.displayText)
          .font(AppFont.caption)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      // The paper's own ink for both, so the card reads as a scrap of the page
      // it stands for rather than as a swatch with a label stuck on it.
      .foregroundStyle(page.foreground)
      .frame(maxWidth: .infinity)
      .frame(height: PrayerThemeCardMetrics.cardHeight)
      .background(page.color, in: shape)
      .overlay {
        shape.strokeBorder(
          isSelected ? AppColor.primary : AppColor.border,
          lineWidth: isSelected ? PrayerThemeCardMetrics.selectedBorderWidth : 0.5
        )
      }
      .contentShape(shape)
    }
    .buttonStyle(PressableButtonStyle())
    .accessibilityLabel(page.displayText)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}

// MARK: - Appearance changes

extension View {
  /// Runs `perform` whenever `value` changes.
  ///
  /// Takes the value rather than reading the environment itself, so the caller's
  /// own `@Environment` stays the single source of it.
  ///
  /// A shim, because `onChange(of:)` has a different signature either side of
  /// iOS 17 — the same split `AppSelectionSoundModifier` in `UtilKit` straddles.
  /// It lives beside the cards because what both hosts of them watch is the
  /// appearance, which is the half of a theme the reader does not set directly.
  func onValueChange<Value: Equatable>(
    _ value: Value,
    perform: @escaping () -> Void
  ) -> some View {
    modifier(OnValueChange(value: value, perform: perform))
  }
}

private struct OnValueChange<Value: Equatable>: ViewModifier {
  let value: Value
  let perform: () -> Void

  func body(content: Content) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      content.onChange(of: value) { _, _ in perform() }
    } else {
      content.onChange(of: value) { _ in perform() }
    }
  }
}

// MARK: - Previews

#Preview("Theme cards") {
  PrayerThemeSectionPreview()
}

private struct PrayerThemeSectionPreview: View {
  @State private var slot: PrayerThemeSlot? = .one

  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    PrayerThemeSection(selection: slot) { slot = $0.slot }
      .frame(maxHeight: .infinity)
      .background(AppColor.background.ignoresSafeArea())
  }
}
