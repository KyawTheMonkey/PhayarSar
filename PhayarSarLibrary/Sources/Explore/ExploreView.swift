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
        if #unavailable(iOS 26) {
          ExploreNavView()
            .listRowInsets(.init(top: 0, leading: -10, bottom: 0, trailing: -10))
        }
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
      .navTitle_iOS26()
      .tint(AppColor.accent)
      .enableInjection()
    }
    .overlay(alignment: .top) {
      if #unavailable(iOS 26) {
        Rectangle()
          .fill(
            LinearGradient(
              colors: [AppColor.background, AppColor.background.opacity(0.9), AppColor.background.opacity(0.1)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(maxWidth: .infinity)
          .frame(height: 90)
          .ignoresSafeArea()
      }
    }
  }
}

fileprivate extension View {
  @ViewBuilder func navTitle_iOS26() -> some View {
    if #available(iOS 26, *) {
      self.navigationTitle("PhayarSar")
    } else if #available(iOS 18, *) {
      self
        .toolbarVisibility(.hidden, for: .navigationBar)
    } else {
      self.navigationBarHidden(true)
    }
  }
}
