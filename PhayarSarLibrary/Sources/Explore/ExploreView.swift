import EnvironmentKit
import SwiftUI

public struct ExploreView: View {
  @EnvironmentObject var navigator: AppNavigatorModel
  public init() {}

  public var body: some View {
    NavigationStack(path: $navigator.path) {
      Text("Explore")
    }
  }
}
