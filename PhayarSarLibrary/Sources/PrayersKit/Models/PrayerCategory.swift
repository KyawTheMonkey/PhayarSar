import Foundation
import LocalisationKit

public enum PrayerCategory: Int, Hashable, CaseIterable {
  case precepts
  case virtues
  case parittas
  case protection
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
