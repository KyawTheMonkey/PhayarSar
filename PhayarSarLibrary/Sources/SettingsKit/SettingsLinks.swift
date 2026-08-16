import DesignKit
import Foundation
import LocalisationKit

/// The destinations the settings screen's outbound rows point at.
///
/// Gathered in one place, and all `nil` until they exist. A row whose link is
/// `nil` still appears but does nothing when tapped — the alternative, hiding
/// it, would make the screen's shape change as these are filled in, and the
/// layout is easier to judge with every row present.
///
/// Fill one in and its row starts working; no other change is needed.
public enum SettingsLink {
  /// `https://apps.apple.com/app/id<APP_ID>?action=write-review` once the app
  /// has an App Store ID.
  public static let appStoreReview: URL? = nil

  /// A `mailto:` address or a support page.
  public static let support: URL? = nil

  /// Wherever the app is worth following — a Facebook page, most likely, for
  /// this audience.
  public static let social: URL? = nil

  /// Terms of service and privacy policy, on one page or a landing page for
  /// both.
  public static let termsAndPrivacy: URL? = nil
}

// MARK: - Theme names

extension Theme {
  /// The localised name for this option.
  ///
  /// Lives in SettingsKit rather than beside ``Theme`` in DesignKit, which has
  /// no dependency on LocalisationKit — design tokens should not need a
  /// translation table to compile.
  var displayName: String {
    switch self {
    case .system:
      return L10n.themeSystem
    case .light:
      return L10n.themeLight
    case .dark:
      return L10n.themeDark
    }
  }

  /// The SF Symbol shown beside it in the menu.
  var symbolName: String {
    switch self {
    case .system:
      return "iphone"
    case .light:
      return "sun.max"
    case .dark:
      return "moon"
    }
  }
}
