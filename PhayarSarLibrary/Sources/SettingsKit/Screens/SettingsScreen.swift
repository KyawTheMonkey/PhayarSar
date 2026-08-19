import AuthKit
import DesignKit
import EnvironmentKit
import Inject
import KloudKit
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
  @ObservedObject private var kloud = KloudStack.shared

  @EnvironmentObject private var navigator: AppNavigatorModel

  @Environment(\.openURL) private var openURL

  /// Which options sheet is up, if any.
  ///
  /// One piece of state for both rows rather than a `Bool` each: they present
  /// the same kind of sheet, and two independent flags can both be true.
  @State private var optionSheet: OptionSheet?

  /// How the last manual sync ended, or `nil` before one has been asked for.
  ///
  /// Kept on the screen rather than on `KloudStack`: it is the answer to a
  /// question this screen asked, and it should not outlive the visit — coming
  /// back to Settings tomorrow to "Everything is up to date" from yesterday
  /// would be reporting a fact about a sync the user no longer remembers
  /// requesting. The durable half of the story is `kloud.lastSyncedAt`, which
  /// the row's detail line shows.
  @State private var syncOutcome: KloudSyncOutcome?

  private enum OptionSheet: String, Identifiable {
    case appearance
    case language
    /// Not a preference like the other two — it lists the developer's links
    /// rather than a value to pick — but it is the same sheet in the same
    /// place, and the state that says "a sheet is up" should stay singular.
    case developer

    var id: String { rawValue }
  }

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppSettingsRowMetrics.groupSpacing) {
        AccountSection(onAccountSettings: openAccountSettings)
        syncGroup
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

    case .developer:
      AppActionPickerSheet(
        title: L10n.followDeveloper,
        options: DeveloperLink.allCases,
        label: { $0.displayName },
        systemImage: { $0.symbolName },
        action: { open($0.url) }
      )
      .optionSheetDetent(for: DeveloperLink.allCases.count)
    }
  }

  // MARK: - iCloud

  /// Sync on demand, for the user who has just changed something on another
  /// device and does not want to wait for the system to get around to it.
  ///
  /// Separate from the read-only status line in ``AccountSection`` and directly
  /// under it: that one says what the mirror is doing, this one is the only
  /// thing on the screen that can make it do anything.
  private var syncGroup: some View {
    AppSettingsGroup(L10n.icloudSync) {
      AppSettingsRow(
        L10n.syncNow,
        systemImage: "arrow.triangle.2.circlepath",
        detail: syncDetail,
        // Nothing is pushed and nothing leaves the app — a chevron would promise
        // a screen that does not exist.
        accessory: .none,
        action: startSync
      )
      .disabled(kloud.isSyncing)

      syncFooter
    }
  }

  /// The trailing text on the row: what is happening now if anything is, and
  /// otherwise when this last worked.
  private var syncDetail: String {
    if kloud.isSyncing {
      return L10n.syncInProgress
    }

    // A guest has a local store and nothing to sync. Saying so here rather than
    // only after a tap — the row stays visible so the feature is findable, and
    // tapping it explains what to do about it.
    guard kloud.mode.containerIdentifier != nil else {
      return L10n.syncOff
    }

    guard let lastSyncedAt = kloud.lastSyncedAt else {
      return L10n.syncNever
    }

    return L10n.syncLastSynced(Self.timestamp(lastSyncedAt))
  }

  /// The outcome of the last tap, in the colour that outcome deserves.
  ///
  /// Under the row rather than in an alert. Every one of these is something the
  /// user can read and act on at their own pace — a modal for "your iCloud is
  /// full" interrupts them to tell them something they cannot fix from here.
  @ViewBuilder
  private var syncFooter: some View {
    if let syncOutcome, !kloud.isSyncing {
      Text(Self.message(for: syncOutcome))
        .font(AppFont.caption)
        .foregroundStyle(Self.tint(for: syncOutcome))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
  }

  private static func message(for outcome: KloudSyncOutcome) -> String {
    switch outcome {
    case .completed:
      return L10n.syncCompleted
    case .notSyncing:
      return L10n.syncNotSyncing
    case .quotaExceeded:
      return L10n.icloudFull
    case .stillRunning:
      return L10n.syncStillRunning
    case .failed:
      // The underlying message is a CloudKit string in the device's language,
      // not the app's, and it names records rather than prayers. It belongs in a
      // crash report, not on this row.
      return L10n.syncFailed
    case let .accountUnavailable(status):
      return status == .needsAttention ? L10n.icloudNeedsAttention : L10n.icloudUnavailable
    }
  }

  private static func tint(for outcome: KloudSyncOutcome) -> Color {
    switch outcome {
    case .completed:
      return AppColor.success
    case .stillRunning, .notSyncing:
      return AppColor.textSecondary
    case .quotaExceeded, .accountUnavailable:
      return AppColor.warning
    case .failed:
      return AppColor.error
    }
  }

  /// The date in both languages, so the row reads in whichever one the app is
  /// set to rather than whichever one the device is set to.
  ///
  /// `L10n.Arg` exists for exactly this — see the accessibility label in
  /// `PrayerPageSwitcher`, which passes numbers through it for the same reason.
  private static func timestamp(_ date: Date) -> L10n.Arg {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short

    formatter.locale = Locale(identifier: "en_US")
    let english = formatter.string(from: date)

    formatter.locale = Locale(identifier: "my_MM")
    let myanmar = formatter.string(from: date)

    return L10n.Arg(en: english, mm: myanmar)
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
      AppSettingsRow(L10n.contactSupport, systemImage: "envelope", accessory: .externalLink, action: contactSupport)

      AppSettingsRow(L10n.rateInAppStore, systemImage: "star", accessory: .externalLink) {
        open(SettingsLink.appStoreReview)
      }

      // A chevron rather than the external-link arrow its two neighbours carry:
      // this one opens a sheet still inside the app. The links in it are marked
      // as leaving.
      AppSettingsRow(L10n.followDeveloper, systemImage: "heart") {
        optionSheet = .developer
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

  /// Pushes onto the settings tab rather than jumping to home's copy of the
  /// same screen — the user asked from here, so they should come back to here.
  private func openAccountSettings() {
    navigator.navigate(to: .profile)
  }

  /// Asks the store to sync and keeps the answer.
  ///
  /// The previous outcome is cleared first, so a second tap does not sit under
  /// yesterday's verdict while it works.
  ///
  /// No error handling here because `syncNow()` does not throw — every way this
  /// can end is a ``KloudSyncOutcome`` worth showing, including the ones that
  /// are not failures.
  private func startSync() {
    syncOutcome = nil

    Task {
      syncOutcome = await kloud.syncNow()
    }
  }

  /// No-ops until their screens exist. Named rather than inlined as empty
  /// closures so that "what is still missing" is one search away.
  private func openNotifications() {
    // TODO: Push the notification preferences screen once it exists.
  }

  private func openDataSources() {
    // TODO: Push the data sources / attribution screen once it exists.
  }

  /// Hands the user a pre-addressed mail, with the build and device already in
  /// it, and a blank line at the top to write on.
  ///
  /// `mailto:` first, because it goes wherever the user has said their mail
  /// should go. It is refused on a device with no default mail client — Mail
  /// deleted, everything read in Gmail — and rather than a tap that visibly
  /// does nothing, that case falls through to Gmail's own scheme. If Gmail is
  /// not installed either, the second open is refused too and the row is
  /// genuinely inert; there is no third thing to try that would not be worse
  /// than silence.
  private func contactSupport() {
    guard let mailto = SupportMail.mailtoURL else { return }

    openURL(mailto) { accepted in
      guard !accepted, let gmail = SupportMail.gmailURL else { return }
      openURL(gmail)
    }
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
  .environmentObject(AppNavigatorModel())
}
