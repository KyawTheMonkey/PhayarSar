import DesignKit
import EnvironmentKit
import Inject
import SwiftUI

/// The service is down on purpose, and will be back.
///
/// ```swift
/// MaintenanceScreen(
///   title: L10n.maintenanceTitle,
///   message: L10n.maintenanceMessage,
///   estimatedReturn: formatter.string(from: window.end),
///   retryTitle: L10n.tryAgain,
///   onRetry: { Task { await check() } }
/// )
/// ```
///
/// Separate from ``ErrorScreen`` because it is not an error — nothing has gone
/// wrong, and a user who is told "something went wrong" during planned downtime
/// will look for the fault in their own device. The wording, the symbol and the
/// absence of a technical detail block all follow from that.
///
/// `estimatedReturn` is an already formatted string. Passing a `Date` would drag
/// a formatter, a locale and a calendar into a view whose entire job is to draw
/// the words it is handed.
public struct MaintenanceScreen: View {
  @ObserveInjection private var injectionObserver

  private let title: String
  private let message: String
  private let estimatedReturn: String?
  private let retryTitle: String?
  private let isRetrying: Bool
  private let onRetry: (() -> Void)?
  private let statusTitle: String?
  private let onStatus: (() -> Void)?

  /// - Parameters:
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///   - message: What is unavailable, and what still works without it. Most of
  ///     the app usually still works, and saying so keeps the user in it.
  ///   - estimatedReturn: When it is expected back, already formatted. Omit it
  ///     rather than guessing — a time that passes without the service
  ///     returning is worse than no time at all.
  ///   - isRetrying: Puts the retry button in its loading state while the caller
  ///     checks again.
  ///   - onRetry: Omit — along with `retryTitle` — when the app polls by itself.
  ///   - onStatus: Opens a status page. Only worth offering when there is a real
  ///     page behind it.
  public init(
    title: String,
    message: String,
    estimatedReturn: String? = nil,
    retryTitle: String? = nil,
    isRetrying: Bool = false,
    onRetry: (() -> Void)? = nil,
    statusTitle: String? = nil,
    onStatus: (() -> Void)? = nil
  ) {
    self.title = title
    self.message = message
    self.estimatedReturn = estimatedReturn
    self.retryTitle = retryTitle
    self.isRetrying = isRetrying
    self.onRetry = onRetry
    self.statusTitle = statusTitle
    self.onStatus = onStatus
  }

  public var body: some View {
    MiscStatusLayout(
      systemImage: "wrench.and.screwdriver.fill",
      tint: AppColor.warning,
      title: title,
      message: message
    ) {
      estimate
    } actions: {
      if let retryTitle, let onRetry {
        AppButton(
          retryTitle,
          systemImage: "arrow.clockwise",
          isLoading: isRetrying,
          action: onRetry
        )
      }

      if let statusTitle, let onStatus {
        AppButton(statusTitle, kind: .plain, action: onStatus)
      }
    }
    .enableInjection()
  }

  // MARK: - Estimate

  @ViewBuilder
  private var estimate: some View {
    if let estimatedReturn {
      Label {
        Text(estimatedReturn)
      } icon: {
        Image(systemName: "clock")
      }
      .font(AppFont.subheadline)
      .foregroundStyle(AppColor.textSecondary)
      .padding(.horizontal, Metrics.pillHorizontalPadding)
      .padding(.vertical, Metrics.pillVerticalPadding)
      .background(AppColor.surface, in: Capsule())
    }
  }

  // MARK: - Metrics

  private enum Metrics {
    static let pillHorizontalPadding: CGFloat = 16
    static let pillVerticalPadding: CGFloat = 10
  }
}

// MARK: - Previews

#Preview("With an estimate") {
  MaintenanceScreen(
    title: "Back shortly",
    message: "We are doing some maintenance on syncing. Your prayers are still on this device and still readable.",
    estimatedReturn: "Expected back by 6:00 PM",
    retryTitle: "Check again",
    onRetry: {}
  )
}

#Preview("Checking") {
  MaintenanceScreen(
    title: "Back shortly",
    message: "We are doing some maintenance on syncing.",
    estimatedReturn: "Expected back by 6:00 PM",
    retryTitle: "Check again",
    isRetrying: true,
    onRetry: {}
  )
}

#Preview("No estimate, with status page") {
  MaintenanceScreen(
    title: "Back shortly",
    message: "We are doing some maintenance on syncing. Your prayers are still on this device and still readable.",
    retryTitle: "Check again",
    onRetry: {},
    statusTitle: "See service status",
    onStatus: {}
  )
}
