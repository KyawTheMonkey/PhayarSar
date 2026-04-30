import SwiftUI
import LocalisationKit
 
@MainActor
enum AppTab: @MainActor Identifiable, Hashable, CaseIterable, Codable {
  case explore
  case plan
  case settings
  case search
  
  var id: Int {
    switch self {
    case .explore:
      return 0
    case .plan:
      return 1
    case .settings:
      return 2
    case .search:
      return 3
    }
  }
  
  static func allTabs() -> [AppTab] {
    return [.explore, .plan, .settings]
  }
  
  @ViewBuilder
  var label: some View {
    Label(
      title,
      systemImage: iconName
    )
  }
  
  var title: String {
    switch self {
    case .explore:
      L10n.exploreTab
    case .plan:
      L10n.planTab
    case .settings:
      L10n.settingsTab
    case .search:
      L10n.searchTab
    }
  }
  
  var iconName: String {
    switch self {
    case .explore:
      return "square.stack"
    case .plan:
      return "text.pad.header.badge.clock"
    case .settings:
      return "gear"
    case .search:
      return "magnifyingglass"
    }
  }
}
