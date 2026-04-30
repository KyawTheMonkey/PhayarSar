import SwiftUI

@MainActor
final class AppNavigatorModel: ObservableObject {
  @Published var path: [RouterDestination] = []
  @Published var presentedSheet: SheetDestination?
  @Published private(set) var selectedTab = AppTab.explore
  
  func navigate(to: RouterDestination) {
    path.append(to)
  }
  
  func changeTabSelection(to tab: AppTab) {
    if self.selectedTab == tab {
      // TODO: We may need to scroll to top or refresh, don't know yet
    } else {
      self.selectedTab = tab
    }
  }
}

enum RouterDestination: Hashable {
  case dummy
}

enum SheetDestination: Identifiable, Hashable {
  case dummy

  var id: String {
    switch self {
    case .dummy:
      return "dummy"
    }
  }

  static func == (lhs: SheetDestination, rhs: SheetDestination) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
