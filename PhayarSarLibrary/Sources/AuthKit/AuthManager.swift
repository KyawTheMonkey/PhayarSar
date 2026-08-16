import AuthenticationServices
import Foundation
import KloudKit
import SwiftUI

/// What AuthKit needs to know about the app it is embedded in.
public struct AuthConfiguration: Sendable {
  /// The iCloud container a signed-in user's data mirrors to, e.g.
  /// `iCloud.com.kyaw.PhayarSar`.
  public let cloudContainerIdentifier: String

  public init(cloudContainerIdentifier: String) {
    self.cloudContainerIdentifier = cloudContainerIdentifier
  }
}

/// Who the user is, and everything that changes when that answer changes.
///
/// ```swift
/// // Once, in the app's init, before the store starts:
/// AuthManager.shared.configure(
///   AuthConfiguration(cloudContainerIdentifier: "iCloud.com.kyaw.PhayarSar")
/// )
/// KloudStack.shared.start(schema: schema, mode: AuthManager.shared.preferredSyncMode)
///
/// // Anywhere:
/// @EnvironmentObject private var auth: AuthManager
/// if auth.isSignedIn { ... }
/// ```
///
/// Signing in is not just an identity change — it moves the app's data from the
/// local store into the user's iCloud one and carries their guest work across.
/// That is why the whole sequence lives in ``signInWithApple()`` rather than
/// being left to call sites to assemble: half of it is worse than none of it.
@MainActor
public final class AuthManager: ObservableObject {
  public static let shared = AuthManager()

  /// Where the user stands. The primary "is the user logged in" signal —
  /// observe it with `@EnvironmentObject` or subscribe to `$state`.
  @Published public private(set) var state: AuthState

  /// A sign-in is in flight. Drives the button's spinner.
  @Published public private(set) var isWorking = false

  /// The signed-in user as a screen should show them — the stored credential,
  /// with any blank filled in from the synced ``AuthProfileRecord``.
  ///
  /// Worth having separately from `state.user` because of Apple's one-shot
  /// name: sign in on a second device and the credential comes back with
  /// `displayName` and `email` nil, so the local copy alone would render as
  /// "Signed in" and nothing else. The record that synced across has the name
  /// the first device captured.
  ///
  /// A stored property rather than a computed one because it is read from view
  /// bodies, and a fetch per redraw is not something a settings screen should
  /// be doing. Refreshed on sign-in and on every foreground.
  @Published public private(set) var profile: AuthUser?

  /// The last sign-in failure, for a screen to show and then clear. Never set
  /// for a user-initiated cancellation.
  @Published public var lastError: AuthError?

  /// Fires on every successful sign-in, including one that happens behind a
  /// feature gate.
  ///
  /// A second way to hear the same news as `$state`, for call sites that want a
  /// one-shot callback rather than a subscription. Set by the app target if it
  /// needs to react app-wide; individual screens are better served by the
  /// `onSignIn:` closure on ``SwiftUI/View/requiresSignIn(_:message:onSignIn:)``.
  public var onSignIn: ((AuthUser) -> Void)?

  /// The feature currently waiting on an account, if any.
  ///
  /// Held here rather than in the view that asked, because the screen it puts up
  /// has a language switcher on it and the app root rebuilds its whole tree when
  /// the language changes (`.id(currentLanguage)` in `PhayarSarApp`). A cover
  /// presented from inside that tree is torn down mid-flow by the very control
  /// it is showing. Presented from the root, above the rebuild, it survives.
  @Published var pendingSignIn: PendingSignIn?

  private var configuration: AuthConfiguration?

  private init() {
    // Resolved synchronously, from the Keychain, because `preferredSyncMode` is
    // read in the app's `init` — before any `await` could have completed. A
    // returning user must never flash the gate.
    if let user = AuthCredentialStore.load() {
      state = .signedIn(user)
    } else if AuthCredentialStore.hasChosenGuest {
      state = .guest
    } else {
      state = .undetermined
    }

    // Only what the Keychain knows: this runs before `KloudStack.start`, so
    // there is no store to read the synced record out of yet. The first
    // `refreshCredentialState()` fills in the rest.
    profile = state.user
  }

  // MARK: - Setup

  public func configure(_ configuration: AuthConfiguration) {
    self.configuration = configuration
  }

  /// Which store `KloudStack` should open at launch.
  ///
  /// A signed-in user goes straight to their cloud store; everyone else, guests
  /// and first-launch alike, gets the local one. The guest store is what
  /// ``signInWithApple()`` later migrates across.
  public var preferredSyncMode: KloudSyncMode {
    guard state.isSignedIn, let configuration else { return .local }
    return .cloud(containerIdentifier: configuration.cloudContainerIdentifier)
  }

  public var isSignedIn: Bool { state.isSignedIn }

  // MARK: - Sign in

  /// Runs Apple's sheet, then moves the user's data to their account.
  ///
  /// - Throws: ``AuthError``. ``AuthError/cancelled`` for a user who backed out,
  ///   which callers should swallow rather than report.
  public func signInWithApple() async throws {
    isWorking = true
    defer { isWorking = false }

    let credential: AuthUser
    do {
      credential = try await AppleSignInCoordinator().signIn()
    } catch let error as AuthError {
      // Cancellation is not a failure — leaving `lastError` unset keeps the
      // screen quiet when the user simply changed their mind.
      if error != .cancelled {
        lastError = error
      }
      throw error
    }

    // Merge rather than replace: a returning sign-in carries no name or email,
    // and overwriting the stored profile with those nils would lose them for
    // good — Apple will not send them a second time.
    let stored = AuthCredentialStore.load()
    let user = stored?.merging(credential) ?? credential
    AuthCredentialStore.save(user)
    AuthCredentialStore.hasChosenGuest = false

    if let configuration {
      do {
        try KloudStack.shared.signIn(to: configuration.cloudContainerIdentifier)
      } catch {
        // The identity is real even if the store move failed — an unreachable
        // iCloud container should not undo a sign-in the user just completed.
        // They stay on the local store and the next launch retries.
        lastError = .failed(error.localizedDescription)
      }
    }

    persistProfile(user)
    state = .signedIn(user)
    refreshProfile()
    onSignIn?(user)
  }

  // MARK: - Feature gate

  /// Raises the sign-in screen on a feature's behalf, or answers straight away
  /// if the user is already signed in.
  ///
  /// Called by ``SwiftUI/View/requiresSignIn(_:message:onSignIn:)``, which is
  /// how a feature should reach this — the modifier is what turns a `Bool` a
  /// call site can drive into a request, and what makes the "already signed in"
  /// case invisible to it.
  func requestSignIn(message: String?, onSignIn: @escaping (AuthUser) -> Void) {
    if let user = state.user {
      onSignIn(user)
      return
    }

    pendingSignIn = PendingSignIn(message: message, onSignIn: onSignIn)
  }

  /// Takes the "Continue as Guest" path. Everything works; nothing syncs.
  public func continueAsGuest() {
    AuthCredentialStore.hasChosenGuest = true
    state = .guest
  }

  /// Forgets the credential and returns to the local store.
  ///
  /// The account's data stays in iCloud, and the cloud store file stays on disk
  /// — signing back in on this device picks it up without a full re-sync.
  /// Lands on ``AuthState/guest`` rather than ``AuthState/undetermined`` so the
  /// launch gate does not reappear; the user has made their choice once already.
  public func signOut() {
    AuthCredentialStore.clear()
    AuthCredentialStore.hasChosenGuest = true
    KloudStack.shared.signOut()
    state = .guest
    profile = nil
  }

  /// Checks the stored credential is still good, and signs out if it is not.
  ///
  /// Worth calling on launch and on every foreground: the user can revoke the
  /// app from Settings › Apple Account › Sign in with Apple at any time, and
  /// nothing tells the app when they do.
  public func refreshCredentialState() async {
    guard let user = state.user else { return }

    let provider = ASAuthorizationAppleIDProvider()
    guard let credentialState = try? await provider.credentialState(forUserID: user.userIdentifier) else {
      // Offline, most likely. Signing someone out because their plane has no
      // wifi would be a far worse bug than briefly trusting a stale credential.
      return
    }

    switch credentialState {
    case .authorized:
      // Also the app's regular "we are back on screen" moment, and the cheapest
      // place to pick up a display name that has synced in since last launch.
      refreshProfile()
      return
    case .revoked, .notFound, .transferred:
      signOut()
    @unknown default:
      return
    }
  }

  // MARK: - Profile

  /// Mirrors the credential into the synced store so other devices see it.
  ///
  /// Failures are swallowed: the profile record is a convenience, and losing it
  /// costs the user a display name on a second device, not their sign-in.
  private func persistProfile(_ user: AuthUser) {
    let store = KloudStack.shared.store(for: AuthProfileRecord.self)

    _ = try? store.upsert(matching: AuthProfileRecord.matching(user.userIdentifier)) { record in
      record.userIdentifier = user.userIdentifier

      // Only ever written when there is something to write, for the same reason
      // the credential is merged above.
      if let displayName = user.displayName {
        record.displayName = displayName
      }
      if let email = user.email {
        record.email = email
      }
      if record.signedInAt == nil {
        record.signedInAt = .now
      }
    }
  }

  /// Re-reads ``profile`` from the credential and the synced record.
  ///
  /// The credential wins wherever it has a value — it is what this device's user
  /// authorized, and it is what a rename on this device would have written. The
  /// record only fills gaps.
  private func refreshProfile() {
    guard let user = state.user else {
      profile = nil
      return
    }

    let store = KloudStack.shared.store(for: AuthProfileRecord.self)
    let record = try? store.first(where: AuthProfileRecord.matching(user.userIdentifier))

    profile = record?.asUser?.merging(user) ?? user
  }
}
