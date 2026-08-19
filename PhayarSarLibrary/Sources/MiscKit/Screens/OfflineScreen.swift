import DesignKit
import EnvironmentKit
import Inject
import SwiftUI

/// There is no connection, and this screen needs one.
///
/// ```swift
/// OfflineScreen(
///   title: L10n.offlineTitle,
///   message: L10n.offlineMessage,
///   retryTitle: L10n.tryAgain,
///   isRetrying: isChecking,
///   onRetry: { Task { await reload() } },
///   settingsTitle: L10n.openSettings,
///   onOpenSettings: { UIApplication.shared.open(settingsURL) }
/// )
/// ```
///
/// Distinct from ``ErrorScreen`` because the fix is on the user's side, and
/// distinct from ``MaintenanceScreen`` because nothing is wrong with the
/// service. Only reach for it where the network is genuinely required — most of
/// PhayarSar reads from the bundled prayer library and works with the radio off,
/// and showing this screen there would be a lie.
///
/// The screen holds no reachability state of its own. Watching the network is
/// the app's job; this draws the consequence.
public struct OfflineScreen: View {
  @ObserveInjection private var injectionObserver

  private let title: String
  private let message: String
  private let retryTitle: String
  private let isRetrying: Bool
  private let onRetry: () -> Void
  private let settingsTitle: String?
  private let onOpenSettings: (() -> Void)?

  /// - Parameters:
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///   - message: Say what needs the connection. "You are offline" is something
  ///     the user's status bar already told them.
  ///   - retryTitle: Required, unlike the other status screens — a connectivity
  ///     screen with no way to try again strands the user until they think to
  ///     leave and come back.
  ///   - isRetrying: Puts the retry button in its loading state and stops it
  ///     responding while the caller checks.
  ///   - onOpenSettings: Where the caller opens Wi-Fi settings. Omit on macOS
  ///     and anywhere the deep link is not available.
  public init(
    title: String,
    message: String,
    retryTitle: String,
    isRetrying: Bool = false,
    onRetry: @escaping () -> Void,
    settingsTitle: String? = nil,
    onOpenSettings: (() -> Void)? = nil
  ) {
    self.title = title
    self.message = message
    self.retryTitle = retryTitle
    self.isRetrying = isRetrying
    self.onRetry = onRetry
    self.settingsTitle = settingsTitle
    self.onOpenSettings = onOpenSettings
  }

  public var body: some View {
    MiscStatusLayout(
      systemImage: "wifi.slash",
      tint: AppColor.textSecondary,
      title: title,
      message: message
    ) {
      AppButton(
        retryTitle,
        systemImage: "arrow.clockwise",
        isLoading: isRetrying,
        action: onRetry
      )

      if let settingsTitle, let onOpenSettings {
        AppButton(settingsTitle, kind: .plain, action: onOpenSettings)
      }
    }
    .enableInjection()
  }
}

// MARK: - Previews

#Preview("Offline") {
  OfflineScreen(
    title: "No connection",
    message: "PhayarSar needs a connection to sync your prayers to your other devices. Everything on this device is still here.",
    retryTitle: "Try again"
  ) {}
}

#Preview("Checking") {
  OfflineScreen(
    title: "No connection",
    message: "PhayarSar needs a connection to sync your prayers to your other devices.",
    retryTitle: "Try again",
    isRetrying: true
  ) {}
}

#Preview("With settings") {
  OfflineScreen(
    title: "No connection",
    message: "PhayarSar needs a connection to sync your prayers to your other devices.",
    retryTitle: "Try again",
    onRetry: {},
    settingsTitle: "Open Settings",
    onOpenSettings: {}
  )
}
