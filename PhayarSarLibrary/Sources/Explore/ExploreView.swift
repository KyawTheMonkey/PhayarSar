import DesignKit
import EnvironmentKit
import Inject
import SwiftUI

public struct ExploreView: View {
  @EnvironmentObject var navigator: AppNavigatorModel
  @ObserveInjection var inject

  public init() {}

  public var body: some View {
    NavigationStack(path: $navigator.path) {
      List {
        Section("Quick actions") {
          NavigationLink(value: "prayers") {
            Label("All Prayers", systemImage: "books.vertical")
              .font(AppFont.bodySemibold)
          }

          NavigationLink(value: "audios") {
            Label("Chantings", systemImage: "music.note.list")
              .font(AppFont.bodySemibold)
          }
        }
        .listRowBackground(AppColor.card)

        ForYouCardView()
        
        ForYouCardView()
        
        ForYouCardView()
        
        ForYouCardView()
        
        ForYouCardView()
      }
      .scrollContentBackground(.hidden)
      .background(AppColor.background)
      .safeAreaInset(edge: .top) {
        ExploreNavView()
      }
      .enableInjection()
    }
  }
}
