import SwiftUI

extension View {
  /// Puts the sign-in screen in front of the whole app until the user chooses.
  ///
  /// Applied once, in the app target, to the root view:
  ///
  /// ```swift
  /// AppTabView()
  ///   .authGate()
  /// ```
  ///
  /// The gate only appears on the very first launch. Once the user has signed in
  /// or chosen to continue as a guest, that choice is stored and this becomes a
  /// pass-through — so it is safe to leave applied permanently.
  ///
  /// It also revalidates the stored credential whenever the app becomes active,
  /// which is the only way to notice a user revoking the app from Settings, and
  /// hosts the cover that ``requiresSignIn(_:message:onSignIn:)`` raises from
  /// anywhere in the app.
  ///
  /// Apply it *outside* the app's `.id(currentLanguage)`, so that a language
  /// change rebuilds the app behind the gate without taking the sign-in screen
  /// — which is where the language is switched from — down with it.
  public func authGate() -> some View {
    modifier(AuthGateModifier())
  }

  /// Demands a signed-in account before a feature can be used.
  ///
  /// ```swift
  /// @State private var needsAccount = false
  /// ...
  /// Button("Sync my plans") { needsAccount = true }
  ///   .requiresSignIn($needsAccount, message: L10n.plansNeedAccount) { user in
  ///     // Only reached once the user really is signed in.
  ///     startSyncing(for: user)
  ///   }
  /// ```
  ///
  /// If the user is already signed in, nothing is presented and `onSignIn` fires
  /// straight away — so a call site never needs to check first.
  ///
  /// A view modifier rather than a `SheetDestination` case on `AppNavigatorModel`
  /// because that enum is `Codable` by design, to survive deep links and state
  /// restoration, and a route that has to carry a closure back to its caller
  /// cannot be.
  ///
  /// - Parameters:
  ///   - isPresented: Set it `true` to demand sign-in. Cleared as soon as the
  ///     request has been handed on — it is the ask, not the presentation
  ///     state, so it goes back to `false` while the screen is still up.
  ///   - message: What the feature needs the account for. Worth writing —
  ///     the default is generic.
  ///   - onSignIn: Called only on success, never on dismissal.
  public func requiresSignIn(
    _ isPresented: Binding<Bool>,
    message: String? = nil,
    onSignIn: @escaping (AuthUser) -> Void
  ) -> some View {
    modifier(
      RequiresSignInModifier(
        isPresented: isPresented,
        message: message,
        onSignIn: onSignIn
      )
    )
  }
}

// MARK: - Request

/// One feature's outstanding demand for an account.
///
/// Carries the closure, which is the reason this cannot be a route on
/// `AppNavigatorModel` — see ``SwiftUI/View/requiresSignIn(_:message:onSignIn:)``.
/// `Identifiable` because it is presented with `sheet(item:)`, so that a second
/// request arriving while the first is up replaces it rather than being dropped.
@MainActor
final class PendingSignIn: Identifiable {
  let id = UUID()
  let message: String?
  let onSignIn: (AuthUser) -> Void

  init(message: String?, onSignIn: @escaping (AuthUser) -> Void) {
    self.message = message
    self.onSignIn = onSignIn
  }
}

// MARK: - Launch gate

private struct AuthGateModifier: ViewModifier {
  @ObservedObject private var auth = AuthManager.shared
  @Environment(\.scenePhase) private var scenePhase

  func body(content: Content) -> some View {
    gated(content)
      .animation(.easeInOut(duration: 0.25), value: auth.state.needsChoice)
      // `task(id:)` rather than `onChange`: it fires on first appearance *and*
      // on every subsequent change, so launch and foreground are one code path
      // instead of two — and it avoids the iOS 16/17 `onChange` signature split.
      .task(id: scenePhase) {
        guard scenePhase == .active else { return }
        await auth.refreshCredentialState()
      }
  }

  private func gated(_ content: Content) -> some View {
    // `fullScreenCover` is iOS-only; the package also builds for macOS 13,
    // where a sheet is the equivalent presentation.
    #if os(iOS)
    launchGate(content).fullScreenCover(item: $auth.pendingSignIn) { cover(for: $0) }
    #else
    launchGate(content).sheet(item: $auth.pendingSignIn) { cover(for: $0) }
    #endif
  }

  private func launchGate(_ content: Content) -> some View {
    Group {
      if auth.state.needsChoice {
        SignInScreen { _ in
          // Nothing to do — `AuthManager` has already moved `state` off
          // `.undetermined`, which is what takes this branch away.
        }
        .transition(.opacity)
      } else {
        content
      }
    }
  }

  private func cover(for request: PendingSignIn) -> some View {
    SignInScreen(presentation: .feature, message: request.message) { outcome in
      auth.pendingSignIn = nil

      if case let .signedIn(user) = outcome {
        request.onSignIn(user)
      }
    }
  }
}

// MARK: - Feature gate

private struct RequiresSignInModifier: ViewModifier {
  @Binding var isPresented: Bool

  let message: String?
  let onSignIn: (AuthUser) -> Void

  init(isPresented: Binding<Bool>, message: String?, onSignIn: @escaping (AuthUser) -> Void) {
    self._isPresented = isPresented
    self.message = message
    self.onSignIn = onSignIn
  }

  /// Hands the request to ``AuthManager`` and gets out of the way. Nothing is
  /// presented from here — the screen goes up at the app root, which is what
  /// keeps it alive when the user changes language on it.
  ///
  /// The flag is cleared immediately rather than held for the duration, so a
  /// call site that sets it again gets a second request instead of a no-op
  /// against a value that was never lowered.
  func body(content: Content) -> some View {
    content.task(id: isPresented) {
      guard isPresented else { return }
      isPresented = false

      // Also the "already signed in" case: `requestSignIn` answers straight
      // away rather than presenting, so a call site never has to check first.
      AuthManager.shared.requestSignIn(message: message, onSignIn: onSignIn)
    }
  }
}
