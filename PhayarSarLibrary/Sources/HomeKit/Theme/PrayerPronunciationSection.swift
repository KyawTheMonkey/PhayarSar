import DesignKit
import LocalisationKit
import SwiftUI

/// The switch for the Burmese respelling above each line.
///
/// Shared by the two screens that offer it — the reader's own editor
/// (``PrayerThemeScreen``) and the prayer's detail screen — so the switch, its
/// label and the caveat under it stay one thing. The footer travels with it
/// because the caveat is about the setting, not about either screen: several
/// prayers ship no respelling, and turning this on for one of those shows
/// nothing.
///
/// Not part of ``PrayerThemeSection`` even though it sits directly above it: a
/// theme is a paper and a face, and this is neither.
struct PrayerPronunciationSection: View {
  @Binding var isOn: Bool

  var body: some View {
    AppListSection(footer: L10n.pronunciationFooter) {
      Toggle(isOn: $isOn) {
        Text(L10n.showPronunciation)
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.textPrimary)
      }
      .tint(AppColor.primary)
    }
  }
}

// MARK: - Previews

#Preview("Pronunciation") {
  PrayerPronunciationSectionPreview()
}

private struct PrayerPronunciationSectionPreview: View {
  @State private var isOn = true

  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    PrayerPronunciationSection(isOn: $isOn)
      .frame(maxHeight: .infinity)
      .background(AppColor.background.ignoresSafeArea())
  }
}
