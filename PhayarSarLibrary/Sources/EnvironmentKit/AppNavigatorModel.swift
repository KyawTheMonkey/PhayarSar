import SwiftUI

@MainActor
public final class AppNavigatorModel: ObservableObject {
  @Published public var path: [RouterDestination] = []
  @Published public var presentedSheet: SheetDestination?
  
  public init() {}
  
  public func navigate(to: RouterDestination) {
    path.append(to)
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
