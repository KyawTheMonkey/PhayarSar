import CloudKit
import Foundation

/// Whether the device can reach the user's private database.
public enum KloudAccountStatus: Equatable, Sendable {
  /// Signed in and reachable. Mirroring will work.
  case available

  /// No iCloud account on the device.
  case noAccount

  /// Blocked by parental controls or an MDM profile.
  case restricted

  /// Signed in, but the account needs attention — usually re-entering the
  /// password in Settings.
  case needsAttention

  /// The status could not be determined, typically because the device is
  /// offline. Worth retrying rather than reporting.
  case unknown
}

/// The iCloud account behind the CloudKit container.
///
/// Worth being precise about, because it is the single most confusing thing in
/// this area: **Sign in with Apple and iCloud are not the same account.**
/// Signing in with Apple returns a stable identifier for the user and grants no
/// access to CloudKit whatsoever. The private database is reached through
/// whatever Apple ID the *device* is signed into in Settings — which may be a
/// different account, or none at all.
///
/// So a user can be signed in to the app and still have nothing sync. Ask here
/// before promising them otherwise.
public enum KloudAccount {
  public static func status(containerIdentifier: String) async -> KloudAccountStatus {
    let container = CKContainer(identifier: containerIdentifier)

    do {
      switch try await container.accountStatus() {
      case .available:
        return .available
      case .noAccount:
        return .noAccount
      case .restricted:
        return .restricted
      case .temporarilyUnavailable:
        return .needsAttention
      case .couldNotDetermine:
        return .unknown
      @unknown default:
        return .unknown
      }
    } catch {
      return .unknown
    }
  }
}
