import Foundation
import KloudKit
import LocalisationKit

/// The signed-in user, in the synced store.
///
/// A near-duplicate of what ``AuthCredentialStore`` already holds on the
/// Keychain, and deliberately so — the two answer different questions. The
/// Keychain copy is local, and is read before the store opens to decide *which*
/// store to open. This copy travels with the account, so a second device sees
/// the display name without the user having to sign in again to produce it.
///
/// It is also the first real consumer of ``KloudEntity``, which is why it exists
/// in this shape rather than as a preference blob: it keeps the registry API
/// exercised by something the app actually reads.
@objc(AuthProfileRecord)
public final class AuthProfileRecord: NSManagedObject, KloudEntity {
  @NSManaged public var userIdentifier: String?
  @NSManaged public var displayName: String?
  @NSManaged public var email: String?
  /// The user's picture, as an absolute URL string. See ``AuthUser/avatarURL``
  /// for why it is here before anything writes it.
  @NSManaged public var avatarURL: String?
  /// When this account first signed in on any device. Not updated on later
  /// sign-ins — the earliest value wins once it has synced.
  @NSManaged public var signedInAt: Date?

  public static var storageLabel: String { L10n.account }

  /// Never offered for deletion. This is the one thing in the store that is
  /// identity rather than content: a name and an email Apple hands over exactly
  /// once and will not send again, in about a hundred bytes. Clearing it would
  /// blank the user's name on every other device and free nothing worth having,
  /// so it is kept out of the storage screen entirely rather than shown there
  /// with the delete disabled.
  public static var isUserClearable: Bool { false }

  public static func makeEntity() -> NSEntityDescription {
    let entity = NSEntityDescription()
    entity.properties = [
      KloudAttribute.make("userIdentifier", .stringAttributeType),
      KloudAttribute.make("displayName", .stringAttributeType),
      KloudAttribute.make("email", .stringAttributeType),
      KloudAttribute.make("avatarURL", .stringAttributeType),
      KloudAttribute.make("signedInAt", .dateAttributeType),
    ]
    return entity
  }
}

extension AuthProfileRecord {
  /// The record for one user, matched on ``userIdentifier``.
  ///
  /// A predicate rather than a uniqueness constraint because CloudKit does not
  /// support those — see ``KloudSchema``. Two devices signing in at once can
  /// both insert; ``AuthManager`` upserts against this, so the pair converges to
  /// one row on the next write after they have synced.
  static func matching(_ userIdentifier: String) -> NSPredicate {
    NSPredicate(format: "userIdentifier == %@", userIdentifier)
  }

  var asUser: AuthUser? {
    guard let userIdentifier else { return nil }
    return AuthUser(
      userIdentifier: userIdentifier,
      displayName: displayName,
      email: email,
      avatarURL: avatarURL.flatMap(URL.init(string:))
    )
  }
}
