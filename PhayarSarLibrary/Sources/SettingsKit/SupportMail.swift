import Foundation
import LocalisationKit

#if canImport(UIKit)
import UIKit
#endif

/// The mail the Contact Support row composes.
///
/// The whole point of the row is that the reply is useful, and a reply is only
/// useful if the person answering knows which build on which device is being
/// described. So the message arrives with that already in it, below a blank
/// space for the user to write in — the metadata is at the bottom rather than
/// the top so an empty compose window still opens with the cursor above
/// anything, and the user is not asked to scroll past a machine block before
/// they can start typing.
///
/// Everything here is already public knowledge about the device: version
/// numbers and a model identifier. Nothing identifies the person.
public enum SupportMail {
  /// Names the app and the build in the subject, so support mail sorts itself
  /// by version in an inbox without anything being opened.
  public static var subject: String {
    "\(AppInfo.name) Support — v\(AppInfo.displayVersion)"
  }

  public static var body: String {
    """


    ——————————————
    \(AppInfo.name) \(AppInfo.displayVersion)
    \(systemDescription)
    Language: \(LocalisationManager.shared.currentLanguage.rawValue)
    """
  }

  /// The standard `mailto:`, which opens whichever client the user has set as
  /// their default — Mail, Gmail, Outlook, or nothing at all.
  public static var mailtoURL: URL? {
    URL(string: "mailto:\(SettingsLink.supportAddress)?subject=\(encoded(subject))&body=\(encoded(body))")
  }

  /// Gmail's own scheme, for the phone with no default mail client set — which
  /// is every phone whose owner deleted Mail and reads their mail in Gmail.
  /// Tried only after ``mailtoURL`` is refused; see `SettingsScreen`.
  public static var gmailURL: URL? {
    URL(string: "googlegmail:///co?to=\(SettingsLink.supportAddress)&subject=\(encoded(subject))&body=\(encoded(body))")
  }

  /// Model identifier, OS and version — `iPhone16,2 · iOS 18.0`.
  ///
  /// The raw identifier rather than `UIDevice.model`, which answers "iPhone"
  /// for every iPhone ever made and so answers nothing.
  private static var systemDescription: String {
    #if canImport(UIKit) && !os(watchOS)
    let device = UIDevice.current
    return "\(modelIdentifier) · \(device.systemName) \(device.systemVersion)"
    #else
    let version = ProcessInfo.processInfo.operatingSystemVersionString
    return "\(modelIdentifier) · \(version)"
    #endif
  }

  private static var modelIdentifier: String {
    var info = utsname()
    uname(&info)

    // `machine` is a C char tuple; reflection walks it without having to know
    // how long it is.
    let identifier = Mirror(reflecting: info.machine).children.reduce(into: "") { result, element in
      guard let value = element.value as? CChar, value != 0 else { return }
      result.append(Character(UnicodeScalar(UInt8(bitPattern: value))))
    }

    return identifier.isEmpty ? "Unknown" : identifier
  }

  /// Percent-encodes for a URL *query value*, not a URL.
  ///
  /// `urlQueryAllowed` leaves `&`, `=` and `+` alone, and any of the three in a
  /// subject or body would end the parameter early or turn into a space. This
  /// set keeps only the characters that never need escaping anywhere.
  private static func encoded(_ value: String) -> String {
    let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    return value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
  }
}
