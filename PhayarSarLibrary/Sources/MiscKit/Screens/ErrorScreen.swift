import DesignKit
import EnvironmentKit
import Inject
import SwiftUI

/// Something failed and the screen behind it has nothing to show.
///
/// ```swift
/// ErrorScreen(
///   title: L10n.somethingWentWrongTitle,
///   message: L10n.somethingWentWrongMessage,
///   details: error.localizedDescription,
///   retryTitle: L10n.tryAgain,
///   isRetrying: isLoading
/// ) {
///   Task { await load() }
/// }
/// ```
///
/// For a failure that has taken the whole screen. A field that failed to
/// validate, or a save that did not go through, belongs in an alert or inline —
/// not here.
///
/// `isRetrying` is a parameter rather than internal state on purpose. The caller
/// owns the work being retried, so the caller owns the spinner; a screen that
/// tracked it itself would have to guess when the work finished, and guessing is
/// the logic these screens are meant not to have.
public struct ErrorScreen: View {
  @ObserveInjection private var injectionObserver

  /// Technical detail starts collapsed. It is there for the user who is about to
  /// report the problem, and it is noise for everyone else.
  @State private var isShowingDetails = false

  private let systemImage: String
  private let title: String
  private let message: String
  private let details: String?
  private let retryTitle: String?
  private let isRetrying: Bool
  private let onRetry: (() -> Void)?
  private let secondaryTitle: String?
  private let onSecondary: (() -> Void)?

  /// - Parameters:
  ///   - systemImage: Override when the failure has a better symbol than the
  ///     generic triangle — a lock for a permissions failure, say.
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///   - message: What the user can do about it, in their words. Save the
  ///     technical wording for `details`.
  ///   - details: The underlying error, behind a disclosure. Safe to omit, and
  ///     worth omitting when it says nothing a user could act on or repeat.
  ///   - isRetrying: Puts the retry button in its loading state and stops it
  ///     responding. Drive it from the caller's own loading flag.
  ///   - onRetry: Omit — along with `retryTitle` — when there is nothing to
  ///     retry. Both are needed for the button to appear.
  ///   - onSecondary: The way out when retrying is not it: go back, contact
  ///     support, work offline.
  public init(
    systemImage: String = "exclamationmark.triangle.fill",
    title: String,
    message: String,
    details: String? = nil,
    retryTitle: String? = nil,
    isRetrying: Bool = false,
    onRetry: (() -> Void)? = nil,
    secondaryTitle: String? = nil,
    onSecondary: (() -> Void)? = nil
  ) {
    self.systemImage = systemImage
    self.title = title
    self.message = message
    self.details = details
    self.retryTitle = retryTitle
    self.isRetrying = isRetrying
    self.onRetry = onRetry
    self.secondaryTitle = secondaryTitle
    self.onSecondary = onSecondary
  }

  public var body: some View {
    MiscStatusLayout(
      systemImage: systemImage,
      tint: AppColor.error,
      title: title,
      message: message
    ) {
      detailDisclosure
    } actions: {
      if let retryTitle, let onRetry {
        AppButton(
          retryTitle,
          systemImage: "arrow.clockwise",
          isLoading: isRetrying,
          action: onRetry
        )
      }

      if let secondaryTitle, let onSecondary {
        AppButton(secondaryTitle, kind: .plain, action: onSecondary)
      }
    }
    .enableInjection()
  }

  // MARK: - Details

  @ViewBuilder
  private var detailDisclosure: some View {
    if let details {
      VStack(spacing: Metrics.disclosureSpacing) {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            isShowingDetails.toggle()
          }
        } label: {
          HStack(spacing: 6) {
            // Reuses the app's existing disclosure vocabulary rather than
            // adding a key that would say the same thing in other words.
            Text(isShowingDetails ? L10n.showLess : L10n.showMore)

            Image(systemName: "chevron.down")
              .rotationEffect(.degrees(isShowingDetails ? 180 : 0))
          }
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textTertiary)
          .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 1))

        if isShowingDetails {
          Text(details)
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textTertiary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.detailPadding)
            .background(
              AppColor.surface,
              in: RoundedRectangle(
                cornerRadius: AppListSectionMetrics.cornerRadius,
                style: .continuous
              )
            )
            // Long enough to be worth copying rather than retyping.
            .textSelection(.enabled)
            .frame(maxWidth: Metrics.detailWidth)
        }
      }
    }
  }

  // MARK: - Metrics

  private enum Metrics {
    static let disclosureSpacing: CGFloat = 12
    static let detailPadding: CGFloat = 14

    /// Matches `ForceUpdateScreen`'s highlight card — the two are the same kind
    /// of supporting block and should not be different widths.
    static let detailWidth: CGFloat = 320
  }
}

// MARK: - Previews

#Preview("Retryable") {
  ErrorScreen(
    title: "Could not load prayers",
    message: "Something went wrong while fetching the prayer library. Try again in a moment.",
    retryTitle: "Try again"
  ) {}
}

#Preview("Retrying") {
  ErrorScreen(
    title: "Could not load prayers",
    message: "Something went wrong while fetching the prayer library.",
    retryTitle: "Try again",
    isRetrying: true
  ) {}
}

#Preview("With details and a way out") {
  ErrorScreen(
    title: "Sync is not working",
    message: "Your prayers are safe on this device, but they are not reaching your other devices.",
    details: "CKError 4097: connection to service named com.apple.cloudkit.daemon was interrupted",
    retryTitle: "Try again",
    onRetry: {},
    secondaryTitle: "Continue without syncing",
    onSecondary: {}
  )
}

#Preview("Nothing to retry") {
  ErrorScreen(
    systemImage: "lock.fill",
    title: "No access",
    message: "This prayer is not available in your region."
  )
}
