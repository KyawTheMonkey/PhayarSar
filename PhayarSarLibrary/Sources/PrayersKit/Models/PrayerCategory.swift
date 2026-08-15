import Foundation
import LocalisationKit

/// A grouping of prayers, as presented on the home list.
///
/// The raw value is the key used by `manifest.json` — keep the two in step when
/// adding a category. `protection` spells its raw value `"protective"` to match
/// the existing `L10n` key.
public enum PrayerCategory: String, Hashable, CaseIterable, Sendable, Decodable {
  case precepts
  case virtues
  case parittas
  case protection = "protective"
  case discourses
  case metta

  public var displayText: String {
    switch self {
    case .precepts:
      return L10n.precepts
    case .virtues:
      return L10n.virtues
    case .parittas:
      return L10n.parittas
    case .protection:
      return L10n.protective
    case .discourses:
      return L10n.discourses
    case .metta:
      return L10n.metta
    }
  }
}
