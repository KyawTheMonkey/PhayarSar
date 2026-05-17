import SwiftUI
import LocalisationKit
 
@MainActor
public enum AppTab: @MainActor Identifiable, Hashable, CaseIterable, Codable {
  case explore
  case plan
  case settings
  case search
  case bookmark
  case statistics
  case downloads
  
  public var id: Int {
    switch self {
    case .explore:
      return 0
    case .plan:
      return 1
    case .settings:
      return 2
    case .search:
      return 3
    case .bookmark:
      return 4
    case .statistics:
      return 5
    case .downloads:
      return 6
    }
  }
  
  public static func allTabs() -> [AppTab] {
    return [.explore, .plan, .settings]
  }
  
  @ViewBuilder
  public func label(isSelected: Bool) -> some View {
    Label(
      title,
      systemImage: isSelected ? iconNameSelected : iconName
    )
    .fontWeight(.medium)
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
    case .bookmark:
      L10n.bookmarkTab
    case .statistics:
      L10n.statisticsTab
    case .downloads:
      L10n.downloadsTab
    }
  }
  
  var iconName: String {
    switch self {
    case .explore:
      return "square.stack"
    case .plan:
      return "calendar.badge.clock"
    case .settings:
      return "gear"
    case .search:
      return "magnifyingglass"
    case .bookmark:
      return "bookmark"
    case .statistics:
      return "chart.bar"
    case .downloads:
      return "square.and.arrow.down"
    }
  }
  
  var iconNameSelected: String {
    switch self {
    case .explore:
      return "square.stack.fill"
    case .plan:
      return "calendar.badge.clock"
    case .settings:
      return "gear"
    case .search:
      return "magnifyingglass"
    case .bookmark:
      return "bookmark.fill"
    case .statistics:
      return "chart.bar.fill"
    case .downloads:
      return "square.and.arrow.down.fill"
    }
  }
}
