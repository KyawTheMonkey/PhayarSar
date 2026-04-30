import SwiftUI

@MainActor
public final class AppNavigatorModel: ObservableObject {
  @Published public var path: [RouterDestination] = []
  @Published public var presentedSheet: SheetDestination?
  @Published public private(set) var selectedTab = AppTab.explore
  
  public init() {}
  
  public func navigate(to: RouterDestination) {
    path.append(to)
  }
  
  public func changeTabSelection(to tab: AppTab) {
    if self.selectedTab == tab {
      // TODO: We may need to scroll to top or refresh, don't know yet
    } else {
      self.selectedTab = tab
    }
  }
}

public enum RouterDestination: Hashable {
  case dummy
}

public enum SheetDestination: Identifiable, Hashable {
  case dummy

  public var id: String {
    switch self {
    case .dummy:
      return "dummy"
    }
  }

  public static func == (lhs: SheetDestination, rhs: SheetDestination) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
