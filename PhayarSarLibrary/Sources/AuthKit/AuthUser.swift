import Foundation

/// Who is signed in.
///
/// Deliberately thin. Sign in with Apple hands back a stable identifier and, on
/// the *very first* authorization only, a name and email — Apple never sends
/// either again, on this device or any other, even after a reinstall. So both
/// are captured the moment they arrive and stored; a later sign-in that comes
/// back with them missing must not overwrite what is already known.
public struct AuthUser: Codable, Hashable, Sendable, Identifiable {
  /// Apple's stable, per-developer-account identifier for this user. The key
  /// everything else hangs off, and the value passed back to
  /// `getCredentialState(forUserID:)`.
  public let userIdentifier: String

  /// `nil` when the user chose to hide it, or when this is a returning sign-in.
  public let displayName: String?

  /// May be a private relay address (`…@privaterelay.appleid.com`) if the user
  /// chose to hide their real one.
  public let email: String?

  /// The user's picture, if the app ever learns of one.
  ///
  /// Always `nil` today: Sign in with Apple returns no photo, on the first
  /// authorization or any later one, and the app has no other place a user can
  /// give it one. It is modelled anyway because every surface that shows the
  /// user — the home nav button, the settings header, the profile screen — has
  /// to decide what to draw when there is no picture, and having them all read
  /// one optional means adding a real source later is a change in one place
  /// rather than three. See ``AuthKit/ProfileAvatarView``.
  public let avatarURL: URL?

  public var id: String { userIdentifier }

  public init(
    userIdentifier: String,
    displayName: String? = nil,
    email: String? = nil,
    avatarURL: URL? = nil
  ) {
    self.userIdentifier = userIdentifier
    self.displayName = displayName
    self.email = email
    self.avatarURL = avatarURL
  }

  /// Fills in blanks from `other` without ever clearing a value already held.
  ///
  /// This is what protects the one-shot name and email: a returning
  /// authorization arrives with both `nil`, and merging rather than replacing
  /// means the stored profile survives it.
  public func merging(_ other: AuthUser) -> AuthUser {
    AuthUser(
      userIdentifier: other.userIdentifier,
      displayName: other.displayName ?? displayName,
      email: other.email ?? email,
      avatarURL: other.avatarURL ?? avatarURL
    )
  }
}

/// Where the user stands with the app.
public enum AuthState: Equatable, Sendable {
  /// Nothing decided yet — the gate is showing. Only ever the state before the
  /// user's first choice; it is not a loading state on later launches, because
  /// the stored choice is read synchronously at startup.
  case undetermined

  /// Chose to carry on without an account. Everything works; nothing syncs.
  case guest

  case signedIn(AuthUser)

  public var user: AuthUser? {
    if case let .signedIn(user) = self { return user }
    return nil
  }

  public var isSignedIn: Bool {
    user != nil
  }

  /// Whether the app should be showing the launch gate.
  public var needsChoice: Bool {
    self == .undetermined
  }
}

/// How a ``SignInScreen`` ended.
public enum AuthOutcome: Equatable, Sendable {
  case signedIn(AuthUser)
  case guest
  /// Closed with the X. Only reachable from the feature gate — the launch gate
  /// has no dismiss.
  case dismissed
}

/// Why a sign-in did not happen.
public enum AuthError: LocalizedError, Equatable {
  /// The user backed out of Apple's sheet. Not worth showing an error for.
  case cancelled
  /// Apple returned a credential in a shape we cannot read.
  case unexpectedCredential
  /// Anything else, carrying the underlying description.
  case failed(String)

  public var errorDescription: String? {
    switch self {
    case .cancelled:
      return nil
    case .unexpectedCredential:
      return "Apple returned an unexpected credential."
    case let .failed(message):
      return message
    }
  }
}
