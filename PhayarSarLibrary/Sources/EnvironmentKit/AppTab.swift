import LocalisationKit
import SwiftUI
 
@MainActor
public enum AppTab: @MainActor Identifiable, Hashable, CaseIterable, Codable {
  case home
  case meditation
  case beads
  case plans
  case settings
  
  public var id: Int {
    switch self {
    case .home:
      return 0
    case .meditation:
      return 1
    case .beads:
      return 2
    case .plans:
      return 3
    case .settings:
      return 4
    }
  }
  
  @ViewBuilder
  public func label(isSelected: Bool) -> some View {
    Label(
      title,
      systemImage: isSelected ? iconNameSelected : iconName
    )
    .fontWeight(.medium)
  }
  
  public var title: String {
    switch self {
    case .home: return L10n.homeTab
    case .meditation: return L10n.meditationTab
    case .beads: return L10n.beadsTab
    case .plans: return L10n.plansTab
    case .settings: return L10n.settingsTab
    }
  }
  
  var iconName: String {
    switch self {
    case .home:
      return "square.stack"
    case .meditation:
      return "figure.mind.and.body"
    case .beads:
      return "circle.hexagonpath"
    case .plans:
      return "calendar.badge.clock"
    case .settings:
      return "gear"
    }
  }
  
  var iconNameSelected: String {
    switch self {
    case .home:
      return "square.stack.fill"
    case .meditation:
      return "figure.mind.and.body"
    case .beads:
      return "circle.hexagonpath"
    case .plans:
      return "calendar.badge.clock"
    case .settings:
      return "gear"
    }
  }
}
