import AuthKit
import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI

/// The settings screen: who you are, then what you can change, then where to go
/// for everything the app itself cannot answer.
///
/// A flat list rather than the `AppListSection` cards the rest of the app uses.
/// Every other screen shows content — prayers, plans — that benefits from being
/// grouped into panels. This one is a column of single actions, and a card
/// around each group adds a border per idea without adding a distinction the
/// labels do not already make.
public struct SettingsScreen: View {
  @ObserveInjection private var injectionObserver

  /// The shared managers are observed directly rather than taken from the
  /// environment: each is a singleton either way, and this screen is where they
  /// are written to.
  @ObservedObject private var localisation = LocalisationManager.shared
  @ObservedObject private var theme = ThemeSwitcher.shared

  @Environment(\.openURL) private var openURL

  /// Which options sheet is up, if any.
  ///
  /// One piece of state for both rows rather than a `Bool` each: they present
  /// the same kind of sheet, and two independent flags can both be true.
  @State private var optionSheet: OptionSheet?

  private enum OptionSheet: String, Identifiable {
    case appearance
    case language

    var id: String { rawValue }
  }

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppSettingsRowMetrics.groupSpacing) {
        AccountSection(onAccountSettings: openAccountSettings)
        preferencesGroup
        resourcesGroup
        AccountSignOutRow()
        footer
      }
      .padding(.top, 8)
      .padding(.bottom, 40)
    }
    // A flat fill rather than `appBackground()`'s gradient: the rows have no
    // card behind them to separate them from it, so the gradient's band would
    // tint the top third of the list and nothing below it.
    .background(AppColor.background.ignoresSafeArea())
    .sheet(item: $optionSheet) { optionsSheet(for: $0) }
    .enableInjection()
  }

  // MARK: - Options sheets

  @ViewBuilder
  private func optionsSheet(for route: OptionSheet) -> some View {
    switch route {
    case .appearance:
      AppOptionPickerSheet(
        title: L10n.appearance,
        options: Theme.allCases,
        selection: themeSelection,
        label: { $0.displayName },
        systemImage: { $0.symbolName }
      )
      .optionSheetDetent(for: Theme.allCases.count)

    case .language:
      AppOptionPickerSheet(
        title: L10n.language,
        options: Language.allCases,
        selection: languageSelection,
        label: { $0.displayName }
      )
      .optionSheetDetent(for: Language.allCases.count)
    }
  }

  // MARK: - Preferences

  private var preferencesGroup: some View {
    AppSettingsGroup(L10n.preferences) {
      AppSettingsRow(L10n.notifications, systemImage: "bell", action: openNotifications)
      appearanceRow
      languageRow
    }
  }

  /// Light, dark, or whatever the device is doing.
  private var appearanceRow: some View {
    AppSettingsRow(
      L10n.appearance,
      systemImage: "circle.lefthalf.filled",
      detail: theme.currentTheme.displayName
    ) {
      optionSheet = .appearance
    }
    .accessibilityValue(theme.currentTheme.displayName)
  }

  /// `ThemeSwitcher` persists through a method rather than a settable property,
  /// so the `Picker` needs a binding built around it.
  private var themeSelection: Binding<Theme> {
    Binding(
      get: { theme.currentTheme },
      set: { theme.switchTheme(to: $0) }
    )
  }

  private var languageRow: some View {
    AppSettingsRow(
      L10n.language,
      systemImage: "globe",
      detail: localisation.currentLanguage.displayName
    ) {
      optionSheet = .language
    }
    .accessibilityValue(localisation.currentLanguage.displayName)
  }

  private var languageSelection: Binding<Language> {
    Binding(
      get: { localisation.currentLanguage },
      set: { localisation.setLanguage($0) }
    )
  }

  // MARK: - Resources

  /// Everything that leaves the app, plus the one page that explains where the
  /// prayers came from.
  ///
  /// The outbound three are marked with ``AppSettingsRowAccessory/externalLink``
  /// rather than a chevron: they hand the user to Safari or the App Store, and
  /// that is worth saying before the tap rather than after it.
  private var resourcesGroup: some View {
    AppSettingsGroup(L10n.resources) {
      AppSettingsRow(L10n.contactSupport, systemImage: "envelope", accessory: .externalLink) {
        open(SettingsLink.support)
      }

      AppSettingsRow(L10n.rateInAppStore, systemImage: "star", accessory: .externalLink) {
        open(SettingsLink.appStoreReview)
      }

      AppSettingsRow(L10n.followUs, systemImage: "heart", accessory: .externalLink) {
        open(SettingsLink.social)
      }

      AppSettingsRow(L10n.dataSources, systemImage: "text.book.closed", action: openDataSources)
    }
  }

  // MARK: - Footer

  /// The app's own name and version, centred and quiet, the way an about box
  /// signs off. Last on the screen because it is the only thing here that is
  /// not a control.
  private var footer: some View {
    VStack(spacing: 4) {
      Text(AppInfo.name)
        .font(AppFont.title)
        .foregroundStyle(AppColor.textTertiary)

      // Marketing version only. The build number is for crash reports and
      // TestFlight, and means nothing to the person reading this screen.
      Text("\(L10n.version) \(AppInfo.version)")
        .font(AppFont.caption)
        .foregroundStyle(AppColor.textTertiary)

      Button {
        open(SettingsLink.termsAndPrivacy)
      } label: {
        Text(L10n.termsAndPrivacy)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textTertiary)
          .underline()
      }
      .buttonStyle(.plain)
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 16)
  }

  // MARK: - Actions

  /// No-ops until their screens exist. Named rather than inlined as empty
  /// closures so that "what is still missing" is one search away.
  private func openAccountSettings() {
    // TODO: Push the account settings screen once it exists.
  }

  private func openNotifications() {
    // TODO: Push the notification preferences screen once it exists.
  }

  private func openDataSources() {
    // TODO: Push the data sources / attribution screen once it exists.
  }

  /// Opens a ``SettingsLink``, or does nothing if it has not been filled in yet.
  private func open(_ url: URL?) {
    guard let url else { return }
    openURL(url)
  }
}

// MARK: - Detent

private extension View {
  /// Sizes an options sheet to exactly its rows.
  ///
  /// `presentationDetents` is iOS-only; the package also builds for macOS 13,
  /// where a sheet is sized by its content anyway and needs no help.
  @ViewBuilder
  func optionSheetDetent(for count: Int) -> some View {
    #if os(iOS)
    presentationDetents([.height(AppOptionPickerMetrics.height(for: count))])
      .presentationDragIndicator(.visible)
    #else
    self
    #endif
  }
}

// MARK: - Previews

#Preview {
  NavigationStack {
    SettingsScreen()
      .navigationTitle(L10n.settingsTab)
  }
}
