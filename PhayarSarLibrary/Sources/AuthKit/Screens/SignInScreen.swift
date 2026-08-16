import AuthenticationServices
import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI

/// The one sign-in screen, in either of the two places it is used.
///
/// ```swift
/// SignInScreen { outcome in
///   // .signedIn(user), .guest, or .dismissed
/// }
/// ```
///
/// One screen rather than two because the difference between the launch gate and
/// a feature gate is two controls, not two designs — and a user who meets both
/// should recognise the second from the first.
public struct SignInScreen: View {
  /// Which of the two jobs this instance is doing.
  public enum Presentation: Equatable, Sendable {
    /// The launch gate. No way out except making a choice, so it offers the
    /// guest path and has no close button.
    case gate

    /// Raised by a feature that requires an account. Guest is not on offer —
    /// that is the entire point — so the close button is the way out, and the
    /// caller is left on whatever screen they were on.
    case feature
  }

  @ObserveInjection private var injectionObserver

  /// The shared manager is observed directly rather than taken from the
  /// environment: it is a singleton either way, and a screen presented as a
  /// cover does not reliably inherit the environment of the view that raised it.
  @ObservedObject private var auth = AuthManager.shared

  /// Same reasoning as `auth` above, and the same instance the settings screen
  /// writes to — a language picked here is the app's language from then on.
  @ObservedObject private var localisation = LocalisationManager.shared

  @Environment(\.colorScheme) private var colorScheme

  private let presentation: Presentation
  private let message: String?
  private let onFinish: (AuthOutcome) -> Void

  /// - Parameters:
  ///   - presentation: Defaults to the launch gate.
  ///   - message: Replaces the standard subtitle. For a feature gate, say what
  ///     the feature is — "Sign in to sync your worship plans" beats a generic
  ///     line the user has already read once at launch.
  ///   - onFinish: Called exactly once, with how the screen ended.
  public init(
    presentation: Presentation = .gate,
    message: String? = nil,
    onFinish: @escaping (AuthOutcome) -> Void
  ) {
    self.presentation = presentation
    self.message = message
    self.onFinish = onFinish
  }

  public var body: some View {
    ZStack(alignment: .top) {
      content
      topBar
    }
    // A flat fill rather than `appBackground()`'s gradient. This screen is one
    // logo on a lot of empty space, and the gradient's band across the middle
    // lands right behind it — the artwork carries the screen better with
    // nothing competing behind it. Every screen the user reaches *after* the
    // gate keeps the gradient.
    .background(AppColor.background.ignoresSafeArea())
    .enableInjection()
  }

  // MARK: - Top bar

  private var topBar: some View {
    HStack(spacing: 0) {
      if presentation == .feature {
        closeButton
      }

      Spacer(minLength: 0)

      languageSwitcher
    }
    .padding(.horizontal, 8)
    // Keeps the bar clear of `content`'s own top inset, which the logo shares.
    .padding(.top, 4)
  }

  /// Language, in reach before the user has committed to anything.
  ///
  /// It matters most on this screen: the gate is the first thing a new user
  /// sees, and asking them to sign in — or to understand what "Continue as
  /// Guest" costs them — in a language they do not read is asking them to guess.
  /// Settings has the same control, but only past a decision made here.
  ///
  /// A menu rather than a toggle even though there are two languages today,
  /// because a toggle labelled with the *current* language reads as a statement
  /// rather than a control, and a third language would break it outright.
  private var languageSwitcher: some View {
    Menu {
      ForEach(Language.allCases, id: \.self) { language in
        Button {
          localisation.setLanguage(language)
        } label: {
          if language == localisation.currentLanguage {
            Label(language.displayName, systemImage: "checkmark")
          } else {
            Text(language.displayName)
          }
        }
      }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "globe")
          // A notch larger than the label, the way the glyph on a system
          // control sits — at matched size it reads as a letter in the word.
          .imageScale(.large)

        Text(localisation.currentLanguage.displayName)
      }
      .font(AppFont.headline)
      .foregroundStyle(AppColor.textPrimary)
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
    }
    .capsuleGlass()
    .accessibilityLabel(L10n.language)
    .accessibilityValue(localisation.currentLanguage.displayName)
  }

  // MARK: - Content

  private var content: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)

      logo
      titleBlock

      Spacer(minLength: 0)

      actions
    }
    // Asymmetric: the top inset also has to clear `topBar`, which is overlaid
    // rather than stacked and so takes no space of its own.
    .padding(.top, 88)
    .padding(.bottom, 32)
    .appHorizontalInset()
    // The gate is the whole window, so it has to fill it rather than shrink to
    // its content the way a pushed screen would.
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var logo: some View {
    Image(Metrics.logoAsset, bundle: .module)
      .resizable()
      .scaledToFit()
      .frame(width: Metrics.logoSize, height: Metrics.logoSize)
      .clipShape(RoundedRectangle(cornerRadius: Metrics.logoCornerRadius, style: .continuous))
      // Grounds the mark against the gradient, which is too soft on its own to
      // give the artwork an edge.
      .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
      .accessibilityHidden(true)
  }

  private var titleBlock: some View {
    VStack(spacing: 12) {
      Text(presentation == .gate ? L10n.signInTitle : L10n.signInRequiredTitle)
        .font(AppFont.title)
        .foregroundStyle(AppColor.textPrimary)

      Text(message ?? (presentation == .gate ? L10n.signInSubtitle : L10n.signInRequiredMessage))
        .font(AppFont.body)
        .foregroundStyle(AppColor.textSecondary)
        // Burmese stacks diacritics above and below the baseline, so the
        // default leading crowds consecutive lines.
        .lineSpacing(6)
    }
    .multilineTextAlignment(.center)
    .padding(.top, 28)
    .padding(.horizontal, 8)
  }

  // MARK: - Actions

  private var actions: some View {
    VStack(spacing: 12) {
      if let error = auth.lastError, error != .cancelled {
        Text(error.errorDescription ?? L10n.signInFailed)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.error)
          .multilineTextAlignment(.center)
          .transition(.opacity)
      }

      appleButton

      if presentation == .gate {
        AppButton(L10n.continueAsGuest, kind: .secondary) {
          auth.continueAsGuest()
          onFinish(.guest)
        }
      }
    }
    .animation(.easeOut(duration: 0.2), value: auth.lastError)
  }

  /// Apple's own button, not an ``AppButton``.
  ///
  /// The Human Interface Guidelines require the system control — its wording,
  /// mark and proportions are not ours to restyle. Only the height and corner
  /// radius are set, to line it up with the guest button beneath it.
  private var appleButton: some View {
    SignInWithAppleButton(.signIn) { request in
      request.requestedScopes = [.fullName, .email]
    } onCompletion: { _ in
      // Intentionally empty. The real request goes through `AuthManager`, which
      // owns the store migration that has to follow a successful sign-in — this
      // builder's own result would skip all of it.
    }
    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
    .frame(height: Metrics.appleButtonHeight)
    .clipShape(RoundedRectangle(cornerRadius: AppButtonMetrics.cornerRadius, style: .continuous))
    // Apple's button does not expose an action closure that can be `async`, and
    // its own completion bypasses `AuthManager`. Overlaying a transparent button
    // keeps the required system appearance while routing the tap through the one
    // path that also moves the user's data into their account.
    .overlay {
      Button {
        Task { await signIn() }
      } label: {
        Color.clear.contentShape(Rectangle())
      }
      .buttonStyle(PressableButtonStyle())
    }
    .opacity(auth.isWorking ? 0.5 : 1)
    .overlay {
      if auth.isWorking {
        ProgressView()
          .tint(colorScheme == .dark ? .black : .white)
      }
    }
    .disabled(auth.isWorking)
    .accessibilityAddTraits(.isButton)
  }

  private var closeButton: some View {
    Button {
      onFinish(.dismissed)
    } label: {
      Image(systemName: "xmark")
        .font(AppFont.button)
        .foregroundStyle(AppColor.textSecondary)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(PressableButtonStyle())
    .accessibilityLabel(L10n.close)
  }

  private func signIn() async {
    do {
      try await auth.signInWithApple()
      if let user = auth.state.user {
        onFinish(.signedIn(user))
      }
    } catch {
      // `AuthManager` has already published anything worth showing to
      // `lastError`; a cancellation leaves the screen exactly as it was.
    }
  }

  // MARK: - Metrics

  private enum Metrics {
    /// Ships inside AuthKit rather than being read from the app's catalog, so
    /// the screen renders in a package preview and cannot be broken by a rename
    /// in a target this one does not depend on.
    static let logoAsset = "AppLogo"
    static let logoSize: CGFloat = 128
    static let logoCornerRadius: CGFloat = 28

    /// Apple's minimum for the system button, and tall enough to match
    /// `AppButton`'s own height.
    static let appleButtonHeight: CGFloat = 52
  }
}

// MARK: - Previews

#Preview("Launch gate") {
  SignInScreen { _ in }
}

#Preview("Feature gate") {
  SignInScreen(presentation: .feature) { _ in }
}

#Preview("Feature gate, custom message") {
  SignInScreen(
    presentation: .feature,
    message: "Sign in to keep your worship plans on all your devices."
  ) { _ in }
}
