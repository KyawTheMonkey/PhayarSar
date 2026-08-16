import Foundation
import Security

/// The user's Apple identifier and profile, on the Keychain.
///
/// Not in KloudKit, for a reason worth stating: ``AuthManager`` has to know
/// whether the user is signed in *before* the store opens, because that answer
/// decides which store opens. A record inside the store cannot answer a question
/// asked before the store exists.
///
/// The Keychain is also the right home for it on its own merits — the value
/// survives a reinstall, which is what lets a returning user land straight back
/// on their own data instead of being asked to sign in again.
enum AuthCredentialStore {
  private static let service = "com.kyaw.PhayarSar.auth"
  private static let account = "appleUser"

  /// Marks a user who chose "Continue as Guest", so the launch gate does not ask
  /// again. In `UserDefaults` rather than the Keychain because, unlike the
  /// credential, it *should* be forgotten on a reinstall — a fresh install is a
  /// fair moment to offer the choice once more.
  private static let guestKey = "auth.hasChosenGuest"

  // MARK: - Credential

  static func load() -> AuthUser? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    guard
      SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else {
      return nil
    }

    return try? JSONDecoder().decode(AuthUser.self, from: data)
  }

  static func save(_ user: AuthUser) {
    guard let data = try? JSONEncoder().encode(user) else { return }

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    let attributes: [String: Any] = [
      kSecValueData as String: data,
      // The credential is only ever read while the app is in the foreground
      // deciding what to show, so it does not need to be readable before first
      // unlock — and `ThisDeviceOnly` keeps it out of a Keychain backup that
      // could restore it onto someone else's device.
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    // Update first, because `SecItemAdd` fails with `errSecDuplicateItem` rather
    // than overwriting, and a sign-in on an account that is already stored is
    // the ordinary case after a credential refresh.
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
    }
  }

  static func clear() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    SecItemDelete(query as CFDictionary)
  }

  // MARK: - Guest

  static var hasChosenGuest: Bool {
    get { UserDefaults.standard.bool(forKey: guestKey) }
    set { UserDefaults.standard.set(newValue, forKey: guestKey) }
  }
}
