import DesignKit
import Foundation
import LocalisationKit

/// The destinations the settings screen's outbound rows point at.
///
/// Gathered in one place. The ones that are still `nil` do not exist yet — a
/// row whose link is `nil` still appears but does nothing when tapped, because
/// hiding it would make the screen's shape change as these are filled in, and
/// the layout is easier to judge with every row present.
///
/// Fill one in and its row starts working; no other change is needed.
public enum SettingsLink {
  /// The App Store listing, opened straight onto the review sheet.
  ///
  /// `action=write-review` rather than the plain product page: the row says
  /// "Rate in App Store", and landing on the page with the compose sheet
  /// already up saves the user hunting for it below the screenshots.
  public static let appStoreReview = URL(string: "https://apps.apple.com/app/id\(AppInfo.appStoreID)?action=write-review")

  /// Where support mail goes. See ``SupportMail`` for the message itself.
  public static let supportAddress = "kyaw.codes@gmail.com"

  /// Terms of service and privacy policy, on one page or a landing page for
  /// both.
  public static let termsAndPrivacy: URL? = nil
}

// MARK: - The developer

/// The places the person who makes this app can be followed.
///
/// An enum rather than three rows: they are one idea — "more of this developer"
/// — and three near-identical rows in Resources would outweigh everything else
/// in the group. One row opens a sheet listing all three.
public enum DeveloperLink: String, CaseIterable, Sendable {
  case website
  case linkedin
  case twitter

  public var url: URL? {
    switch self {
    case .website:
      return URL(string: "https://kyawthemonkey.com/")
    case .linkedin:
      return URL(string: "https://www.linkedin.com/in/kyaw-monkey")
    case .twitter:
      return URL(string: "https://x.com/KyawTheMonkey")
    }
  }

  var displayName: String {
    switch self {
    case .website:
      return L10n.website
    case .linkedin:
      return L10n.linkedin
    case .twitter:
      return L10n.twitter
    }
  }

  /// SF Symbols has no brand marks, so these are the nearest honest generics:
  /// what the destination *is*, not whose logo is on it.
  var symbolName: String {
    switch self {
    case .website:
      return "globe"
    case .linkedin:
      return "briefcase"
    case .twitter:
      return "bubble.left.and.bubble.right"
    }
  }
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
