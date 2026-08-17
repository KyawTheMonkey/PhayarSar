import AuthenticationServices
import Foundation

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Bridges `ASAuthorizationController`'s delegate callbacks to `async`/`await`.
///
/// One instance per attempt, and it keeps a reference to itself for the duration
/// of the flow. That looks like a leak and is not: `ASAuthorizationController`
/// holds its delegate weakly, so without the self-reference the coordinator is
/// deallocated the moment `signIn()` suspends and the callbacks never arrive.
/// The reference is dropped as soon as the continuation resumes.
@MainActor
final class AppleSignInCoordinator: NSObject {
  private var continuation: CheckedContinuation<AuthUser, Error>?
  private var controller: ASAuthorizationController?
  private var keepAlive: AppleSignInCoordinator?

  func signIn() async throws -> AuthUser {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      self.keepAlive = self

      let request = ASAuthorizationAppleIDProvider().createRequest()
      // Both are only ever honoured on the user's first authorization; every
      // sign-in after that returns them as `nil` no matter what is asked for.
      request.requestedScopes = [.fullName, .email]

      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      self.controller = controller
      controller.performRequests()
    }
  }

  private func finish(with result: Result<AuthUser, Error>) {
    // Guarded because Apple can report both a completion and a cancellation for
    // one flow, and resuming a continuation twice is a crash.
    guard let continuation else { return }
    self.continuation = nil
    self.controller = nil
    self.keepAlive = nil
    continuation.resume(with: result)
  }
}

// MARK: - Delegate

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard
      let credential = authorization.credential as? ASAuthorizationAppleIDCredential
    else {
      finish(with: .failure(AuthError.unexpectedCredential))
      return
    }

    finish(with: .success(
      AuthUser(
        userIdentifier: credential.user,
        displayName: Self.fullName(from: credential.fullName),
        email: credential.email
      )
    ))
  }

  /// The user's whole name, in the order their locale writes it.
  ///
  /// `.long` rather than the default `.medium`: the default is given plus
  /// family, which drops a middle name and any prefix or suffix. Apple hands
  /// these over exactly once, on the first authorization and never again, so
  /// anything not read here is lost for the life of the account — there is no
  /// second chance to decide a middle name was worth keeping after all.
  ///
  /// Returns `nil` rather than an empty string when the user chose to hide
  /// their name, so that "no name" stays one value everywhere downstream.
  private static func fullName(from components: PersonNameComponents?) -> String? {
    guard let components else { return nil }

    let formatted = PersonNameComponentsFormatter
      .localizedString(from: components, style: .long)
      // A name missing its middle components formats with the gaps left in.
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return formatted.isEmpty ? nil : formatted
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    // Backing out of Apple's sheet is a normal thing to do, not a failure worth
    // putting an error message on screen for.
    if let error = error as? ASAuthorizationError, error.code == .canceled {
      finish(with: .failure(AuthError.cancelled))
      return
    }

    finish(with: .failure(AuthError.failed(error.localizedDescription)))
  }
}

// MARK: - Presentation

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    #if canImport(UIKit)
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }

    // The empty fallback never presents anything, but returning it is better
    // than trapping — a missing key window means the app is backgrounded, and
    // the request simply fails instead of crashing.
    return window ?? ASPresentationAnchor()
    #else
    return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    #endif
  }
}
